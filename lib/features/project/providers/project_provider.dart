import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_lens/core/storage/global_presets_storage.dart';
import 'package:pixel_lens/features/canvas/data/history.dart';
import 'package:pixel_lens/features/canvas/data/layer.dart';
import 'package:pixel_lens/features/canvas/providers/editor_provider.dart';
import 'package:pixel_lens/features/canvas/providers/tool_provider.dart';
import 'package:pixel_lens/features/labeling/data/label_class.dart';
import 'package:pixel_lens/features/labeling/data/label_set.dart';
import 'package:pixel_lens/features/project/data/project.dart';

/// 드래그(스트로크) 도중 commit:false로 들어오는 변경들을 누적해 두었다가
/// 스트로크가 끝나는 시점에 하나의 [HistoryEntry]로 합쳐 기록하기 위한 버퍼.
/// (누적하지 않으면 스트로크가 지나간 픽셀 하나하나가 개별 undo 단계가 된다)
class _PendingChange<T> {
  final int frameIndex;
  final int layerIndex;
  final String description;
  final Map<(int, int), ({T before, T after})> diff = {};

  _PendingChange({
    required this.frameIndex,
    required this.layerIndex,
    required this.description,
  });

  void merge(Map<(int, int), ({T before, T after})> incoming) {
    for (final e in incoming.entries) {
      final firstBefore = diff[e.key]?.before ?? e.value.before;
      diff[e.key] = (before: firstBefore, after: e.value.after);
    }
  }
}

/// 프로젝트 데이터 + undo/redo 를 관리하는 Notifier.
///
/// [Project]가 Riverpod state, [HistoryStack]은 Notifier 내부 소유.
class ProjectNotifier extends Notifier<Project> {
  final _history = HistoryStack();

  _PendingChange<Color?>? _pendingDrawing;
  _PendingChange<int?>? _pendingSegmentation;

  @override
  Project build() => Project.create();

  // ── undo / redo ──────────────────────────────────────────────

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  String? get undoDescription => _history.undoDescription;
  String? get redoDescription => _history.redoDescription;

  void undo() {
    final updated = _history.undo(state);
    if (updated != null) state = updated;
  }

  void redo() {
    final updated = _history.redo(state);
    if (updated != null) state = updated;
  }

  // ── 드로잉 픽셀 편집 ──────────────────────────────────────────

  void applyDrawingChanges(
    Map<(int, int), Color?> changes, {
    required bool commit,
    String description = '그리기',
  }) {
    final editor = ref.read(editorProvider);
    final fi = editor.activeFrameIndex;
    final li = editor.activeLayerIndex;
    final layer = state.frameAt(fi).layerAt(li);
    if (layer is! DrawingLayer) return;

    final diff = <(int, int), ({Color? before, Color? after})>{};
    for (final e in changes.entries) {
      final (x, y) = e.key;
      if (x >= 0 && x < state.width && y >= 0 && y < state.height) {
        final before = layer.pixels[y][x];
        if (before != e.value) diff[e.key] = (before: before, after: e.value);
      }
    }

    if (diff.isNotEmpty) {
      final updated =
          layer.withPixelChanges(changes, state.width, state.height);
      state = state.replaceFrameAt(
          fi, state.frameAt(fi).replaceLayerAt(li, updated));

      _pendingDrawing ??= _PendingChange(
          frameIndex: fi, layerIndex: li, description: description);
      _pendingDrawing!.merge(diff);
    }

    if (commit) _flushPendingDrawing();
  }

  void _flushPendingDrawing() {
    final pending = _pendingDrawing;
    _pendingDrawing = null;
    if (pending == null || pending.diff.isEmpty) return;
    _history.push(HistoryEntry.now(
      frameIndex: pending.frameIndex,
      layerIndex: pending.layerIndex,
      change: DrawingChange(pending.diff),
      description: pending.description,
    ));
  }

  // ── 세그멘테이션 레이블 편집 ──────────────────────────────────

  void applySegmentationChanges(
    Map<(int, int), int?> changes, {
    required bool commit,
    String description = '레이블 칠하기',
  }) {
    final editor = ref.read(editorProvider);
    final fi = editor.activeFrameIndex;
    final li = editor.activeLayerIndex;
    final layer = state.frameAt(fi).layerAt(li);
    if (layer is! SegmentationLayer) return;

    final diff = <(int, int), ({int? before, int? after})>{};
    for (final e in changes.entries) {
      final (x, y) = e.key;
      if (x >= 0 && x < state.width && y >= 0 && y < state.height) {
        final before = layer.labelIds[y][x];
        if (before != e.value) diff[e.key] = (before: before, after: e.value);
      }
    }

    if (diff.isNotEmpty) {
      final updated =
          layer.withLabelChanges(changes, state.width, state.height);
      state = state.replaceFrameAt(
          fi, state.frameAt(fi).replaceLayerAt(li, updated));

      _pendingSegmentation ??= _PendingChange(
          frameIndex: fi, layerIndex: li, description: description);
      _pendingSegmentation!.merge(diff);
    }

    if (commit) _flushPendingSegmentation();
  }

  void _flushPendingSegmentation() {
    final pending = _pendingSegmentation;
    _pendingSegmentation = null;
    if (pending == null || pending.diff.isEmpty) return;
    _history.push(HistoryEntry.now(
      frameIndex: pending.frameIndex,
      layerIndex: pending.layerIndex,
      change: SegmentationChange(pending.diff),
      description: pending.description,
    ));
  }

  /// 진행 중인 스트로크(드래그)를 하나의 undo 단계로 확정한다.
  /// 펜/지우개/어노테이트/레이블 지우개 등 commit:false로 누적해 온
  /// 변경이 있다면 모아서 history에 기록하고, 없으면 아무 일도 하지 않는다.
  void commitStroke() {
    _flushPendingDrawing();
    _flushPendingSegmentation();
  }

  // ── 레이어 관리 ───────────────────────────────────────────────

  void addDrawingLayer() {
    final editor = ref.read(editorProvider);
    final fi = editor.activeFrameIndex;
    final frame = state.frameAt(fi);
    final layer = DrawingLayer.empty(
      name: 'Layer ${frame.layerCount + 1}',
      width: state.width,
      height: state.height,
    );
    state = state.replaceFrameAt(fi, frame.addLayer(layer));
    ref
        .read(editorProvider.notifier)
        .selectLayer(state.frameAt(fi).layerCount - 1);
  }

  void addSegmentationLayer() {
    final editor = ref.read(editorProvider);
    final fi = editor.activeFrameIndex;
    final frame = state.frameAt(fi);
    final layer = SegmentationLayer.empty(
      name: 'Seg ${frame.layerCount + 1}',
      width: state.width,
      height: state.height,
    );
    state = state.replaceFrameAt(fi, frame.addLayer(layer));
    ref
        .read(editorProvider.notifier)
        .selectLayer(state.frameAt(fi).layerCount - 1);
  }

  /// 모드 전환 + 레이어 선택을 함께 처리한다.
  ///
  /// - pixel → segmentation: SegmentationLayer가 없으면 생성, 있으면 첫 번째를 선택
  /// - segmentation → pixel: 마지막 DrawingLayer를 선택
  void switchMode(EditorMode mode) {
    ref.read(toolProvider.notifier).setMode(mode);
    final fi = ref.read(editorProvider).activeFrameIndex;
    final frame = state.frameAt(fi);

    if (mode == EditorMode.segmentation) {
      final segIdx = frame.layers.indexWhere((l) => l is SegmentationLayer);
      if (segIdx == -1) {
        addSegmentationLayer(); // 생성 후 자동 선택됨
      } else {
        ref.read(editorProvider.notifier).selectLayer(segIdx);
      }

      // 선택된 레이블 클래스가 없으면 그려도 아무 변화가 없으므로
      // (annotate 도구는 currentLabelClassId == null이면 무시한다)
      // 첫 번째 레이블 클래스를 기본 선택해 둔다.
      if (ref.read(toolProvider).currentLabelClassId == null &&
          state.labelClasses.isNotEmpty) {
        ref
            .read(toolProvider.notifier)
            .setLabelClass(state.labelClasses.first.id);
      }
    } else {
      final drawIdx = frame.layers.lastIndexWhere((l) => l is DrawingLayer);
      if (drawIdx >= 0) {
        ref.read(editorProvider.notifier).selectLayer(drawIdx);
      }
    }
  }

  /// Segmentation 모드 진입 시 활성 프레임에 SegmentationLayer가 없으면 자동 생성.
  void ensureSegmentationLayer() {
    final editor = ref.read(editorProvider);
    final fi = editor.activeFrameIndex;
    final frame = state.frameAt(fi);
    final hasSeg = frame.layers.any((l) => l is SegmentationLayer);
    if (!hasSeg) addSegmentationLayer();
  }

  void removeActiveLayer() {
    final editor = ref.read(editorProvider);
    final fi = editor.activeFrameIndex;
    final li = editor.activeLayerIndex;
    if (state.frameAt(fi).layerCount <= 1) return;
    state = state.replaceFrameAt(fi, state.frameAt(fi).removeLayerAt(li));
    ref
        .read(editorProvider.notifier)
        .clampToProject(state.frameCount, state.frameAt(fi).layerCount);
  }

  void setLayerVisibility(int layerIndex, bool visible) {
    final fi = ref.read(editorProvider).activeFrameIndex;
    final frame = state.frameAt(fi);
    final updated = frame.layerAt(layerIndex).copyWithBase(isVisible: visible);
    state = state.replaceFrameAt(fi, frame.replaceLayerAt(layerIndex, updated));
  }

  void setLayerOpacity(int layerIndex, double opacity) {
    final fi = ref.read(editorProvider).activeFrameIndex;
    final frame = state.frameAt(fi);
    final updated = frame
        .layerAt(layerIndex)
        .copyWithBase(opacity: opacity.clamp(0.0, 1.0));
    state = state.replaceFrameAt(fi, frame.replaceLayerAt(layerIndex, updated));
  }

  void moveLayer(int from, int to) {
    final fi = ref.read(editorProvider).activeFrameIndex;
    state = state.replaceFrameAt(fi, state.frameAt(fi).moveLayer(from, to));
  }

  // ── 프레임 관리 ───────────────────────────────────────────────

  void addFrame() {
    state = state.addFrame();
    ref.read(editorProvider.notifier).selectFrame(state.frameCount - 1);
  }

  void duplicateFrame(int index) {
    state = state.duplicateFrame(index);
  }

  void removeFrame(int index) {
    if (state.frameCount <= 1) return;
    state = state.removeFrameAt(index);
    ref
        .read(editorProvider.notifier)
        .clampToProject(state.frameCount, state.frameAt(0).layerCount);
  }

  // ── 레이블 클래스 관리 ────────────────────────────────────────

  void addLabelClass(LabelClass lc) {
    state = state.addLabelClass(lc);
    _persistGlobalLabelSets();
  }

  void updateLabelClass(LabelClass lc) {
    state = state.updateLabelClass(lc);
    _persistGlobalLabelSets();
  }

  void removeLabelClass(int id) {
    state = state.removeLabelClass(id);
    _persistGlobalLabelSets();
  }

  void reorderLabelsInSet(int setId, List<LabelClass> newOrder) {
    state = state.reorderLabelsInSet(setId, newOrder);
    _persistGlobalLabelSets();
  }

  // ── 레이블 셋 관리 ────────────────────────────────────────────

  void addLabelSet(LabelSet ls) {
    state = state.addLabelSet(ls);
    _persistGlobalLabelSets();
  }

  void updateLabelSet(LabelSet ls) {
    state = state.updateLabelSet(ls);
    _persistGlobalLabelSets();
  }

  void setActiveLabelSet(int id) {
    state = state.setActiveLabelSet(id);
    _persistGlobalLabelSets();
  }

  void removeLabelSet(int id) {
    if (state.labelSets.length <= 1) return;
    final wasActive = state.activeLabelSetId == id;
    state = state.removeLabelSet(id);
    if (wasActive) {
      state = state.setActiveLabelSet(state.labelSets.first.id);
    }
    _persistGlobalLabelSets();
  }

  // 레이블 셋/클래스 변경 사항을 모든 프로젝트/에셋이 공유하는 전역
  // 프리셋(`~/Documents/PixelPalette/label_sets.json`)에 저장한다.
  Future<void> _persistGlobalLabelSets() =>
      saveGlobalLabelSets(state.labelSets, state.activeLabelSetId);

  // ── 캔버스 리사이즈 / 초기화 ──────────────────────────────────

  void _clearHistory() {
    _history.clear();
    _pendingDrawing = null;
    _pendingSegmentation = null;
  }

  void resize(int w, int h) {
    state = state.resize(w, h);
    _clearHistory();
  }

  void clearActiveLayer() {
    final editor = ref.read(editorProvider);
    final fi = editor.activeFrameIndex;
    final li = editor.activeLayerIndex;
    final layer = state.frameAt(fi).layerAt(li);
    final cleared = switch (layer) {
      DrawingLayer dl => DrawingLayer.empty(
              name: dl.name, width: state.width, height: state.height)
          .copyWith(isVisible: dl.isVisible, opacity: dl.opacity),
      SegmentationLayer sl => SegmentationLayer.empty(
              name: sl.name, width: state.width, height: state.height)
          .copyWith(isVisible: sl.isVisible, opacity: sl.opacity),
    };
    state =
        state.replaceFrameAt(fi, state.frameAt(fi).replaceLayerAt(li, cleared));
    _clearHistory();
  }

  void setProject(Project project) {
    state = project;
    _clearHistory();
    ref.read(editorProvider.notifier).selectFrame(0);
    ref.read(editorProvider.notifier).selectLayer(0);
  }

  void newProject({String name = 'Untitled', int width = 16, int height = 16}) {
    state = Project.create(name: name, width: width, height: height);
    _clearHistory();
    ref.read(editorProvider.notifier).selectFrame(0);
    ref.read(editorProvider.notifier).selectLayer(0);
  }

  /// 불러온 이미지를 새 프로젝트로 적용한다. 캔버스 크기는 이미지 크기에 맞춘다.
  void loadImage({
    required String name,
    required int width,
    required int height,
    required List<List<Color?>> pixels,
  }) {
    state = Project.fromImage(
        name: name, width: width, height: height, pixels: pixels);
    _clearHistory();
    ref.read(editorProvider.notifier).selectFrame(0);
    ref.read(editorProvider.notifier).selectLayer(0);
  }

  /// 불러온 이미지를 현재 선택된 프레임에 채운다.
  ///
  /// 프로젝트 캔버스 크기를 이미지 크기로 먼저 바꿔 모든 프레임의 크기를 통일한 뒤,
  /// 현재 선택된 프레임에 이미지 픽셀을 채운다.
  /// 현재 선택된 레이어가 드로잉 레이어면 그 레이어를 덮어쓰고,
  /// 세그멘테이션 레이어면 이미지용 드로잉 레이어를 현재 프레임에 새로 추가한다.
  void importImageIntoActiveFrame({
    required String layerName,
    required int imageWidth,
    required int imageHeight,
    required List<List<Color?>> pixels,
  }) {
    final editor = ref.read(editorProvider);
    final fi = editor.activeFrameIndex.clamp(0, state.frameCount - 1);

    if (state.width != imageWidth || state.height != imageHeight) {
      state = state.resize(imageWidth, imageHeight);
    }

    final frame = state.frameAt(fi);
    final activeLayerIndex =
        editor.activeLayerIndex.clamp(0, frame.layerCount - 1);
    final activeLayer = frame.layerAt(activeLayerIndex);

    final changes = <(int, int), Color?>{
      for (int y = 0; y < state.height; y++)
        for (int x = 0; x < state.width; x++) (x, y): pixels[y][x],
    };

    if (activeLayer is DrawingLayer) {
      ref.read(editorProvider.notifier).selectFrame(fi);
      ref.read(editorProvider.notifier).selectLayer(activeLayerIndex);
      applyDrawingChanges(changes, commit: true, description: '이미지 불러오기');
      return;
    }

    final drawingLayer = DrawingLayer.empty(
      name: layerName.isEmpty ? 'Imported Image' : layerName,
      width: state.width,
      height: state.height,
    ).withPixelChanges(changes, state.width, state.height);

    state = state.replaceFrameAt(fi, frame.addLayer(drawingLayer));
    ref.read(editorProvider.notifier).selectFrame(fi);
    ref.read(editorProvider.notifier).selectLayer(frame.layerCount);
    _clearHistory();
  }
}

final projectProvider =
    NotifierProvider<ProjectNotifier, Project>(ProjectNotifier.new);
