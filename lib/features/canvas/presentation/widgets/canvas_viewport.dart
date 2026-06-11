import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_lens/features/canvas/data/fill_algorithm.dart';
import 'package:pixel_lens/features/canvas/data/frame.dart';
import 'package:pixel_lens/features/canvas/data/layer.dart';
import 'package:pixel_lens/features/canvas/providers/editor_provider.dart';
import 'package:pixel_lens/features/canvas/providers/tool_provider.dart';
import 'package:pixel_lens/features/labeling/data/label_class.dart';
import 'package:pixel_lens/features/project/data/project.dart';
import 'package:pixel_lens/features/project/providers/project_provider.dart';

// ── 픽셀 크기 상수 ────────────────────────────────────────────
const double kPixelSize = 24.0;

// 캔버스 체커보드(투명 영역 표시) 색상 — 캐시 타일/직접 그리기/오버레이가
// 모두 같은 패턴을 그려야 하므로 한 곳에서 공유한다.
const Color kCheckerLight = Color(0xFF2A2A3E);
const Color kCheckerDark = Color(0xFF1E1E30);

// ── CanvasViewport ────────────────────────────────────────────

class CanvasViewport extends ConsumerStatefulWidget {
  final TransformationController transformController;
  const CanvasViewport({super.key, required this.transformController});

  @override
  ConsumerState<CanvasViewport> createState() => _CanvasViewportState();
}

class _CanvasViewportState extends ConsumerState<CanvasViewport> {
  final Set<(int, int)> _strokePixels = {};
  bool _isPainting = false;
  (int, int)? _hoverPixel;
  // 직전에 칠한 픽셀 위치. 빠르게 드래그하면 한 번에 여러 픽셀을 건너뛰므로
  // 이전 위치와 현재 위치 사이를 보간해 끊김 없는 궤적을 만드는 데 사용한다.
  (int, int)? _lastPaintedPos;

  // ── Grab 툴 상태 ──────────────────────────────────────────────
  (int, int)? _grabAnchor;       // 선택 드래그 시작 픽셀
  Rect? _grabRect;               // 현재 선택 영역 (픽셀 단위, right/bottom은 exclusive)
  Map<(int, int), Color?>? _grabPixels; // 이동 중인 픽셀 스냅샷
  (int, int) _grabDelta = (0, 0);       // 이동 오프셋
  bool _isGrabMoving = false;    // 이동 단계 여부
  bool _grabHasMoved = false;    // 현재 드래그에서 실제 이동이 있었는지

  // ── 렌더 캐시 (성능) ──────────────────────────────────────────
  // 매 프레임 모든 픽셀을 다시 그리는 대신, 실제 내용이 바뀔 때만
  // 네이티브 해상도로 래스터화한 dart:ui.Image를 캐싱해 두고
  // canvas.drawImageRect 한 번으로 확대해 그린다 (FilterQuality.none = 최근접 보간).
  ui.Image? _checkerTile;

  ui.Image? _layersImage;
  Object? _layersKey;
  bool _layersBusy = false;
  (Frame, int, int)? _layersPending;

  ui.Image? _segOverlayImage;
  Object? _segOverlayKey;
  bool _segOverlayBusy = false;
  (Frame, List<LabelClass>, int, int, double)? _segOverlayPending;

  // 그리는 도중에는 래스터 캐시가 따라잡기 전까지 한두 프레임의 지연이 생긴다.
  // 그 사이에 칠해진 픽셀들을 직접 덧그려 입력에 즉시 반응하는 것처럼 보이게 하고,
  // 캐시가 현재 프레임을 따라잡으면 자동으로 비운다 (_recordLayers 참고).
  static const _maxOverlayPixels = 8192;
  final Set<(int, int)> _pendingOverlayPixels = {};
  int _overlayFrameIndex = -1;
  int _overlayLayerIndex = -1;

  // 세그멘테이션 어노테이트/지우개의 즉각적인 시각 반응용 pending 오버레이.
  // drawing pending과 동일한 원리: 캐시 갱신 완료 전까지 변경 픽셀을 직접 덧그린다.
  // 값이 null 이면 지운 픽셀(saveLayer + BlendMode.clear로 처리).
  final Map<(int, int), int?> _pendingSegOverlayPixels = {};

  void _trackOverlayPixels(Iterable<(int, int)> coords) {
    _pendingOverlayPixels.addAll(coords);
    if (_pendingOverlayPixels.length > _maxOverlayPixels) {
      // 비정상적으로 많이 쌓이면(예: 매우 굵은 브러시 + 느린 캐시) 포기하고
      // 캐시가 따라잡을 때까지 기존 합성 결과를 그대로 보여준다.
      _pendingOverlayPixels.clear();
    }
  }

  void _trackSegOverlayPixels(Map<(int, int), int?> changes) {
    _pendingSegOverlayPixels.addAll(changes);
    if (_pendingSegOverlayPixels.length > _maxOverlayPixels) {
      _pendingSegOverlayPixels.clear();
    }
  }

  TransformationController get _ctrl => widget.transformController;

  static const _brushPreviewTools = {
    AppTool.pen,
    AppTool.eraser,
    AppTool.annotate,
    AppTool.labelEraser,
  };

  @override
  void initState() {
    super.initState();
    _buildCheckerTile();
  }

  @override
  void dispose() {
    _checkerTile?.dispose();
    _layersImage?.dispose();
    _segOverlayImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider);
    final editor = ref.watch(editorProvider);
    final tool = ref.watch(toolProvider);

    final frame = project.frameAt(editor.activeFrameIndex);
    final activeLayer = frame.layerAt(editor.activeLayerIndex);

    final showBrushPreview = _brushPreviewTools.contains(tool.currentTool);
    final isGrab = tool.currentTool == AppTool.grab &&
        tool.mode == EditorMode.pixel;

    // Grab 커서: 이동 중 → grabbing, 선택 위 hover → grab, 나머지 → crosshair
    MouseCursor grabCursor = MouseCursor.defer;
    if (isGrab) {
      final hp = _hoverPixel;
      if (_isGrabMoving) {
        grabCursor = SystemMouseCursors.grabbing;
      } else if (_grabRect != null && hp != null &&
          _pixelInRect(hp.$1, hp.$2, _grabRect!)) {
        grabCursor = SystemMouseCursors.grab;
      } else {
        grabCursor = SystemMouseCursors.precise;
      }
    }

    // 활성 레이어/프레임이 바뀌면 직전 오버레이 픽셀 좌표는 새 레이어의 데이터와
    // 무관해지므로 비운다 (좌표는 같아도 가리키는 픽셀의 실제 값이 달라짐).
    if (editor.activeFrameIndex != _overlayFrameIndex ||
        editor.activeLayerIndex != _overlayLayerIndex) {
      _overlayFrameIndex = editor.activeFrameIndex;
      _overlayLayerIndex = editor.activeLayerIndex;
      _pendingOverlayPixels.clear();
    }

    final showSegOverlay = tool.showSegmentationOverlay &&
        tool.mode == EditorMode.segmentation;
    _syncRenderCaches(
        frame, project, showSegOverlay, tool.segOverlayOpacity);

    return InteractiveViewer(
      transformationController: _ctrl,
      minScale: 0.25,
      maxScale: 32.0,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      child: MouseRegion(
        cursor: grabCursor,
        onHover: _onHover,
        onExit: (_) => setState(() => _hoverPixel = null),
        child: GestureDetector(
          onPanStart: _onDragStart,
          onPanUpdate: _onDragUpdate,
          onPanEnd: _onDragEnd,
          onTapDown: _onTapDown,
          child: CustomPaint(
            painter: _CanvasPainter(
              project: project,
              frameIndex: editor.activeFrameIndex,
              activeLayerIndex: editor.activeLayerIndex,
              activeLayer: activeLayer,
              showSegOverlay: showSegOverlay,
              checkerTile: _checkerTile,
              layersImage: _layersImage,
              segOverlayImage: _segOverlayImage,
              pendingOverlayPixels: _pendingOverlayPixels,
              pendingSegOverlayPixels: _pendingSegOverlayPixels,
              segOverlayOpacity: tool.segOverlayOpacity,
              hoverPixel: showBrushPreview ? _hoverPixel : null,
              brushSize: tool.activeBrushSize,
              grabRect: isGrab ? _grabRect : null,
              grabPixels: isGrab && _isGrabMoving ? _grabPixels : null,
              grabDelta: _grabDelta,
            ),
            size: Size(
              project.width * kPixelSize,
              project.height * kPixelSize,
            ),
          ),
        ),
      ),
    );
  }

  void _onHover(PointerHoverEvent e) {
    _updateHoverPixel(_toPixel(e.position));
  }

  void _updateHoverPixel((int, int)? pos) {
    if (pos != _hoverPixel) setState(() => _hoverPixel = pos);
  }

  // ── 좌표 변환 ─────────────────────────────────────────────────

  (int, int)? _toPixel(Offset globalPos) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalPos);
    final t = MatrixUtils.transformPoint(Matrix4.inverted(_ctrl.value), local);
    final x = (t.dx / kPixelSize).floor();
    final y = (t.dy / kPixelSize).floor();
    final project = ref.read(projectProvider);
    if (x < 0 || x >= project.width || y < 0 || y >= project.height) {
      return null;
    }
    return (x, y);
  }

  // ── 이벤트 ────────────────────────────────────────────────────

  void _onTapDown(TapDownDetails d) {
    final pos = _toPixel(d.globalPosition);
    _updateHoverPixel(pos);
    if (ref.read(toolProvider).currentTool == AppTool.grab &&
        ref.read(toolProvider).mode == EditorMode.pixel) {
      // 단순 클릭은 onPan* 미발화 → 여기서 직접 처리
      final rect = _grabRect;
      if (rect != null && (pos == null || !_pixelInRect(pos.$1, pos.$2, rect))) {
        setState(() {
          _grabRect = null;
          _grabPixels = null;
          _grabDelta = (0, 0);
          _isGrabMoving = false;
          _grabAnchor = null;
        });
      }
      return;
    }
    if (pos != null) _applyTool(pos.$1, pos.$2, commit: true);
  }

  void _onDragStart(DragStartDetails d) {
    final pos = _toPixel(d.globalPosition);
    _updateHoverPixel(pos);
    if (ref.read(toolProvider).currentTool == AppTool.grab &&
        ref.read(toolProvider).mode == EditorMode.pixel) {
      if (pos != null) _grabOnDragStart(pos.$1, pos.$2);
      return;
    }
    _strokePixels.clear();
    _isPainting = true;
    _lastPaintedPos = pos;
    if (pos != null) _applyTool(pos.$1, pos.$2, commit: false);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (ref.read(toolProvider).currentTool == AppTool.grab &&
        ref.read(toolProvider).mode == EditorMode.pixel) {
      final pos = _toPixel(d.globalPosition);
      _updateHoverPixel(pos);
      if (pos != null) _grabOnDragUpdate(pos.$1, pos.$2);
      return;
    }
    if (!_isPainting) return;
    final pos = _toPixel(d.globalPosition);
    _updateHoverPixel(pos);
    if (pos == null) {
      // 캔버스 밖으로 나가면 궤적을 끊어, 다시 들어왔을 때 엉뚱한 직선으로
      // 잇지 않고 새 위치에서부터 다시 시작하게 한다.
      _lastPaintedPos = null;
      return;
    }
    if (pos == _lastPaintedPos) return;

    final from = _lastPaintedPos;
    if (from == null) {
      if (!_strokePixels.contains(pos)) _applyTool(pos.$1, pos.$2, commit: false);
    } else {
      // 마우스를 빠르게 움직이면 한 번의 업데이트로 여러 픽셀을 건너뛸 수 있으므로,
      // 직전 위치와 현재 위치 사이를 보간해 끊김 없는 궤적으로 칠한다.
      for (final p in _linePixels(from, pos).skip(1)) {
        if (!_strokePixels.contains(p)) _applyTool(p.$1, p.$2, commit: false);
      }
    }
    _lastPaintedPos = pos;
  }

  void _onDragEnd(DragEndDetails _) {
    if (ref.read(toolProvider).currentTool == AppTool.grab &&
        ref.read(toolProvider).mode == EditorMode.pixel) {
      _grabOnDragEnd();
      return;
    }
    _isPainting = false;
    _strokePixels.clear();
    _lastPaintedPos = null;
    // 드래그 도중 commit:false로 누적된 변경들을 하나의 undo 단계로 확정
    ref.read(projectProvider.notifier).commitStroke();
  }

  void _applyTool(int x, int y, {required bool commit}) {
    final tool = ref.read(toolProvider);

    // Segmentation 모드에서는 세그멘테이션 전용 툴만 동작한다.
    if (tool.mode == EditorMode.segmentation &&
        !tool.currentTool.isSegmentationTool) {
      return;
    }

    final project = ref.read(projectProvider);
    final editor = ref.read(editorProvider);
    final notifier = ref.read(projectProvider.notifier);
    final size = tool.activeBrushSize;

    switch (tool.currentTool) {
      case AppTool.pen:
        final changes = _blockChanges(x, y, size, tool.currentColor);
        notifier.applyDrawingChanges(changes, commit: commit, description: '펜');
        _strokePixels.add((x, y));
        _trackOverlayPixels(changes.keys);

      case AppTool.eraser:
        final changes = _blockChanges(x, y, size, null);
        notifier.applyDrawingChanges(changes,
            commit: commit, description: '지우개');
        _strokePixels.add((x, y));
        _trackOverlayPixels(changes.keys);

      case AppTool.fill:
        final fi = editor.activeFrameIndex;
        final li = editor.activeLayerIndex;
        final layer = project.frameAt(fi).layerAt(li);
        if (layer case DrawingLayer dl) {
          final fills = floodFill(
            pixels: dl.pixels,
            startX: x,
            startY: y,
            fillColor: tool.currentColor,
            width: project.width,
            height: project.height,
          );
          notifier.applyDrawingChanges(fills, commit: true, description: '채우기');
        }

      case AppTool.eyedropper:
        final fi = editor.activeFrameIndex;
        final li = editor.activeLayerIndex;
        final layer = project.frameAt(fi).layerAt(li);
        if (layer case DrawingLayer dl) {
          final c = dl.getPixel(x, y);
          if (c != null) ref.read(toolProvider.notifier).setColor(c);
        }

      case AppTool.annotate:
        if (tool.currentLabelClassId == null) return;
        final annotateChanges = {
          for (final (dx, dy) in brushOffsets(size))
            (x + dx, y + dy): tool.currentLabelClassId,
        };
        notifier.applySegmentationChanges(annotateChanges,
            commit: commit, description: '레이블');
        _strokePixels.add((x, y));
        _trackSegOverlayPixels(annotateChanges);

      case AppTool.labelEraser:
        final eraseChanges = {
          for (final (dx, dy) in brushOffsets(size))
            (x + dx, y + dy): null as int?,
        };
        notifier.applySegmentationChanges(eraseChanges,
            commit: commit, description: '레이블 지우기');
        _strokePixels.add((x, y));
        _trackSegOverlayPixels(eraseChanges);

      case AppTool.labelFill:
        if (tool.currentLabelClassId == null) return;
        final fi = editor.activeFrameIndex;
        final li = editor.activeLayerIndex;
        final layer = project.frameAt(fi).layerAt(li);
        if (layer case SegmentationLayer sl) {
          final fills = floodFillLabel(
            labelIds: sl.labelIds,
            startX: x,
            startY: y,
            fillLabel: tool.currentLabelClassId,
            width: project.width,
            height: project.height,
          );
          notifier.applySegmentationChanges(fills,
              commit: true, description: '레이블 채우기');
        }

      case AppTool.labelEyedropper:
        final fi = editor.activeFrameIndex;
        final li = editor.activeLayerIndex;
        final layer = project.frameAt(fi).layerAt(li);
        if (layer case SegmentationLayer sl) {
          final id = sl.getLabelId(x, y);
          if (id != null) ref.read(toolProvider.notifier).pickLabelClass(id);
        }

      case AppTool.grab:
      case AppTool.rectSelect:
      case AppTool.move:
        break;
    }
  }

  Map<(int, int), Color?> _blockChanges(
      int cx, int cy, int size, Color? color) {
    return {
      for (final (dx, dy) in brushOffsets(size)) (cx + dx, cy + dy): color,
    };
  }

  // ── Grab 툴 핸들러 ────────────────────────────────────────────

  bool _pixelInRect(int x, int y, Rect r) =>
      x >= r.left && x < r.right && y >= r.top && y < r.bottom;

  // dragStart: 시작 위치만 기록. 선택/이동 여부는 첫 움직임이 있을 때 결정.
  void _grabOnDragStart(int x, int y) {
    _grabHasMoved = false;
    setState(() {
      _grabAnchor = (x, y);
      _grabDelta = (0, 0);
    });
  }

  void _grabOnDragUpdate(int x, int y) {
    final anchor = _grabAnchor;
    if (anchor == null) return;
    final (ax, ay) = anchor;

    if (!_grabHasMoved) {
      _grabHasMoved = true;
      final rect = _grabRect;
      if (rect != null && _pixelInRect(ax, ay, rect)) {
        // 선택 영역 안에서 시작 → 이동 모드 진입
        final project = ref.read(projectProvider);
        final editor = ref.read(editorProvider);
        final layer = project
            .frameAt(editor.activeFrameIndex)
            .layerAt(editor.activeLayerIndex);
        if (layer is! DrawingLayer) return;

        final pixels = <(int, int), Color?>{};
        for (int py = rect.top.toInt(); py < rect.bottom.toInt(); py++) {
          for (int px = rect.left.toInt(); px < rect.right.toInt(); px++) {
            pixels[(px, py)] = layer.getPixel(px, py);
          }
        }
        setState(() {
          _isGrabMoving = true;
          _grabPixels = pixels;
        });
      } else {
        // 선택 영역 밖 → 새 선택 그리기 시작 (이전 선택 제거)
        setState(() {
          _grabRect = null;
          _grabPixels = null;
        });
      }
    }

    if (_isGrabMoving) {
      final r = _grabRect!;
      final w = ref.read(projectProvider).width;
      final h = ref.read(projectProvider).height;
      final dx = (x - ax).clamp(-r.left.toInt(), w - r.right.toInt());
      final dy = (y - ay).clamp(-r.top.toInt(), h - r.bottom.toInt());
      setState(() => _grabDelta = (dx, dy));
    } else {
      // 선택 rect 갱신
      setState(() {
        _grabRect = Rect.fromLTRB(
          min(ax, x).toDouble(),
          min(ay, y).toDouble(),
          (max(ax, x) + 1).toDouble(),
          (max(ay, y) + 1).toDouble(),
        );
      });
    }
  }

  void _grabOnDragEnd() {
    if (_isGrabMoving) {
      _commitGrabMove();
    } else if (!_grabHasMoved) {
      // 실제 이동 없이 드래그 종료 → 탭으로 처리
      final anchor = _grabAnchor;
      final rect = _grabRect;
      if (anchor != null && (rect == null || !_pixelInRect(anchor.$1, anchor.$2, rect))) {
        setState(() { _grabRect = null; });
      }
    }
    setState(() {
      _isGrabMoving = false;
      _grabAnchor = null;
    });
  }

  void _commitGrabMove() {
    final pixels = _grabPixels;
    if (pixels == null) return;
    final (dx, dy) = _grabDelta;
    if (dx == 0 && dy == 0) {
      setState(() { _grabPixels = null; });
      return;
    }

    final project = ref.read(projectProvider);
    final changes = <(int, int), Color?>{};

    // 원본 위치 초기화
    for (final pos in pixels.keys) {
      changes[pos] = null;
    }
    // 이동된 위치에 픽셀 적용 (캔버스 범위 내만)
    for (final entry in pixels.entries) {
      final (ox, oy) = entry.key;
      final nx = ox + dx;
      final ny = oy + dy;
      if (nx >= 0 && nx < project.width && ny >= 0 && ny < project.height) {
        changes[(nx, ny)] = entry.value;
      }
    }

    ref.read(projectProvider.notifier)
        .applyDrawingChanges(changes, commit: true, description: '그랩');

    // 캐시가 갱신되기 전까지 변경된 픽셀을 pendingOverlay로 덧그려 깜빡임 방지
    _trackOverlayPixels(changes.keys);

    setState(() {
      _grabRect = _grabRect?.translate(dx.toDouble(), dy.toDouble());
      _grabPixels = null;
      _grabDelta = (0, 0);
    });
  }

  // ── 렌더 캐시 빌드 ────────────────────────────────────────────
  // 체커보드/레이어/세그멘테이션 오버레이를 매 프레임 픽셀 단위로 다시 그리는 대신
  // 실제 내용이 바뀔 때만 네이티브 해상도(width × height)로 한 번 래스터화해 캐싱한다.
  // Frame/LabelClass 목록은 내용이 실제로 바뀔 때만 새 인스턴스로 교체되므로,
  // 레코드 키를 동일성(==) 비교하는 것만으로 화면이 다시 그려질 뿐 변경이 없는
  // 호버/팬/줌 등의 리빌드와 실제 데이터 변경을 값싸게 구분할 수 있다.

  void _syncRenderCaches(
      Frame frame, Project project, bool showSegOverlay, double segOverlayOpacity) {
    final layersKey = (frame, project.width, project.height);
    if (layersKey != _layersKey) {
      _layersKey = layersKey;
      _requestLayersRasterization(frame, project.width, project.height);
    }

    if (showSegOverlay) {
      final segKey = (frame, project.labelClasses, project.width,
          project.height, segOverlayOpacity);
      if (segKey != _segOverlayKey) {
        _segOverlayKey = segKey;
        _requestSegOverlayRasterization(frame, project.labelClasses,
            project.width, project.height, segOverlayOpacity);
      }
    }
  }

  Future<void> _buildCheckerTile() async {
    const cell = kPixelSize;
    const tileCells = 2;
    const tileSize = cell * tileCells;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final light = Paint()..color = kCheckerLight;
    final dark = Paint()..color = kCheckerDark;
    for (int r = 0; r < tileCells; r++) {
      for (int c = 0; c < tileCells; c++) {
        canvas.drawRect(
          Rect.fromLTWH(c * cell, r * cell, cell, cell),
          (r + c) % 2 == 0 ? light : dark,
        );
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(tileSize.toInt(), tileSize.toInt());
    picture.dispose();
    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() => _checkerTile = image);
  }

  // ── 레이어 래스터화 (코얼레싱) ────────────────────────────────
  // applyDrawingChanges는 드래그 중에도 매 픽셀마다 state를 갱신하므로,
  // 요청이 올 때마다 즉시 래스터화하면 비동기 작업이 쌓인다.
  // busy 플래그 + 단일 대기 슬롯으로 항상 "가장 최신 상태"만 처리하고
  // 중간 상태는 자연스럽게 버려지도록 한다.

  Future<void> _requestLayersRasterization(
      Frame frame, int width, int height) async {
    if (_layersBusy) {
      _layersPending = (frame, width, height);
      return;
    }
    _layersBusy = true;
    var current = (frame, width, height);
    while (true) {
      await _runLayersRasterization(current.$1, current.$2, current.$3);
      final pending = _layersPending;
      if (pending == null) break;
      _layersPending = null;
      current = pending;
    }
    _layersBusy = false;
  }

  Future<void> _runLayersRasterization(Frame frame, int width, int height) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = false;
    for (final layer in frame.layers) {
      if (!layer.isVisible) continue;
      if (layer case DrawingLayer dl) {
        final opacity = layer.opacity.clamp(0.0, 1.0);
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final c = dl.pixels[y][x];
            if (c == null) continue;
            paint.color = c.withValues(alpha: c.a * opacity);
            canvas.drawRect(
                Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
          }
        }
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    _recordLayers(image, frame);
  }

  void _recordLayers(ui.Image image, Frame rasterizedFrame) {
    if (!mounted) {
      image.dispose();
      return;
    }
    final old = _layersImage;
    final editor = ref.read(editorProvider);
    final liveFrame = ref.read(projectProvider).frameAt(editor.activeFrameIndex);
    setState(() {
      _layersImage = image;
      // 캐시가 "현재" 프레임을 정확히 반영하게 됐을 때만 오버레이를 비운다.
      // (그 사이 더 그려졌다면 liveFrame이 달라져 있으므로 오버레이를 유지해
      //  방금 그린 픽셀이 잠깐 사라지는 깜빡임을 막는다)
      if (identical(rasterizedFrame, liveFrame)) _pendingOverlayPixels.clear();
    });
    old?.dispose();
  }

  // ── 세그멘테이션 오버레이 래스터화 (코얼레싱) ────────────────

  Future<void> _requestSegOverlayRasterization(Frame frame,
      List<LabelClass> labelClasses, int width, int height, double opacity) async {
    if (_segOverlayBusy) {
      _segOverlayPending = (frame, labelClasses, width, height, opacity);
      return;
    }
    _segOverlayBusy = true;
    var current = (frame, labelClasses, width, height, opacity);
    while (true) {
      await _runSegOverlayRasterization(
          current.$1, current.$2, current.$3, current.$4, current.$5);
      final pending = _segOverlayPending;
      if (pending == null) break;
      _segOverlayPending = null;
      current = pending;
    }
    _segOverlayBusy = false;
  }

  Future<void> _runSegOverlayRasterization(Frame frame,
      List<LabelClass> labelClasses, int width, int height, double opacity) async {
    final colorById = {for (final c in labelClasses) c.id: c.color};
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = false;
    for (final layer in frame.layers) {
      if (!layer.isVisible) continue;
      if (layer case SegmentationLayer sl) {
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final id = sl.labelIds[y][x];
            if (id == null) continue;
            final color = colorById[id];
            if (color == null || color.a == 0) continue;
            paint.color = color.withValues(alpha: opacity);
            canvas.drawRect(
                Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
          }
        }
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    _recordSegOverlay(image, frame);
  }

  void _recordSegOverlay(ui.Image image, Frame rasterizedFrame) {
    if (!mounted) {
      image.dispose();
      return;
    }
    final old = _segOverlayImage;
    final editor = ref.read(editorProvider);
    final liveFrame =
        ref.read(projectProvider).frameAt(editor.activeFrameIndex);
    setState(() {
      _segOverlayImage = image;
      if (identical(rasterizedFrame, liveFrame)) {
        _pendingSegOverlayPixels.clear();
      }
    });
    old?.dispose();
  }
}

// Bresenham 직선 알고리즘으로 두 픽셀 좌표 사이의 모든 격자 좌표를 순서대로 나열한다.
// (양 끝점 포함) 빠른 드래그로 인해 샘플 사이가 멀리 떨어져도 궤적에 빈틈이 생기지 않게 한다.
Iterable<(int, int)> _linePixels((int, int) from, (int, int) to) sync* {
  var x0 = from.$1, y0 = from.$2;
  final x1 = to.$1, y1 = to.$2;
  final dx = (x1 - x0).abs();
  final dy = -(y1 - y0).abs();
  final sx = x0 < x1 ? 1 : -1;
  final sy = y0 < y1 ? 1 : -1;
  var err = dx + dy;
  while (true) {
    yield (x0, y0);
    if (x0 == x1 && y0 == y1) break;
    final e2 = 2 * err;
    if (e2 >= dy) {
      err += dy;
      x0 += sx;
    }
    if (e2 <= dx) {
      err += dx;
      y0 += sy;
    }
  }
}

// 원형 브러시를 구성하는 (dx, dy) 오프셋 목록 (페인터의 가이드 렌더링과 공유)
Iterable<(int, int)> brushOffsets(int size) sync* {
  final half = size ~/ 2;
  // 3x3 영역(half == 1)은 모서리까지 포함하면 사각형과 구분이 안 되므로
  // 십자가 모양으로 고정해 1→점, 2·3→십자가, 4 이상→점점 둥근 모양으로 자연스럽게 이어지게 함
  final r2 = half == 1 ? 1.0 : (size / 2.0) * (size / 2.0);
  for (int dy = -half; dy <= half; dy++) {
    for (int dx = -half; dx <= half; dx++) {
      if (dx * dx + dy * dy <= r2) yield (dx, dy);
    }
  }
}

// ── CustomPainter ─────────────────────────────────────────────

class _CanvasPainter extends CustomPainter {
  final Project project;
  final int frameIndex;
  final int activeLayerIndex;
  final Layer activeLayer;
  final bool showSegOverlay;
  final ui.Image? checkerTile;
  final ui.Image? layersImage;
  final ui.Image? segOverlayImage;
  final Set<(int, int)> pendingOverlayPixels;
  final Map<(int, int), int?> pendingSegOverlayPixels;
  final double segOverlayOpacity;
  final (int, int)? hoverPixel;
  final int brushSize;
  // Grab 툴 시각화
  final Rect? grabRect;
  final Map<(int, int), Color?>? grabPixels;
  final (int, int) grabDelta;

  const _CanvasPainter({
    required this.project,
    required this.frameIndex,
    required this.activeLayerIndex,
    required this.activeLayer,
    required this.showSegOverlay,
    required this.checkerTile,
    required this.layersImage,
    required this.segOverlayImage,
    required this.pendingOverlayPixels,
    required this.pendingSegOverlayPixels,
    required this.segOverlayOpacity,
    this.hoverPixel,
    this.brushSize = 1,
    this.grabRect,
    this.grabPixels,
    this.grabDelta = (0, 0),
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawCheckerboard(canvas, size);
    _drawLayers(canvas, size);
    if (showSegOverlay) {
      _drawSegOverlay(canvas, size);
      _drawSegBorders(canvas);
    }
    if (grabPixels != null) _drawGrabMovePreview(canvas);
    _drawGrid(canvas, size);
    _drawBrushPreview(canvas);
    if (grabRect != null) _drawGrabSelection(canvas);
  }

  // 이동 미리보기: 원본 위치는 체커보드로 지우고, 새 위치에 픽셀을 그린다
  void _drawGrabMovePreview(Canvas canvas) {
    final pixels = grabPixels!;
    final (dx, dy) = grabDelta;

    final reset = Paint()
      ..isAntiAlias = false
      ..blendMode = BlendMode.src;
    for (final (x, y) in pixels.keys) {
      final rect = Rect.fromLTWH(
          x * kPixelSize, y * kPixelSize, kPixelSize, kPixelSize);
      reset.color = (x + y).isEven ? kCheckerLight : kCheckerDark;
      canvas.drawRect(rect, reset);
    }

    final draw = Paint()..isAntiAlias = false;
    for (final entry in pixels.entries) {
      final color = entry.value;
      if (color == null) continue;
      final (x, y) = entry.key;
      draw.color = color;
      canvas.drawRect(
        Rect.fromLTWH(
            (x + dx) * kPixelSize, (y + dy) * kPixelSize, kPixelSize, kPixelSize),
        draw,
      );
    }
  }

  // 점선 선택 영역: 연한 파란 반투명 fill + 흰색 점선 테두리
  void _drawGrabSelection(Canvas canvas) {
    var r = grabRect!;
    // 이동 중이면 delta만큼 박스도 함께 이동
    if (grabPixels != null) {
      final (dx, dy) = grabDelta;
      r = r.translate(dx.toDouble(), dy.toDouble());
    }
    final rect = Rect.fromLTWH(
      r.left * kPixelSize,
      r.top * kPixelSize,
      r.width * kPixelSize,
      r.height * kPixelSize,
    );

    canvas.drawRect(
      rect,
      Paint()..color = const Color(0xFF3B82F6).withValues(alpha: 0.15),
    );

    _drawDashedRect(
      canvas,
      rect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke
        ..isAntiAlias = false,
    );
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    const dash = kPixelSize * 0.6;
    const gap = kPixelSize * 0.4;
    final path = Path()..addRect(rect);
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(
            metric.extractPath(d, (d + dash).clamp(0, metric.length)), paint);
        d += dash + gap;
      }
    }
  }

  void _drawBrushPreview(Canvas canvas) {
    if (hoverPixel == null) return;
    final (cx, cy) = hoverPixel!;

    final fill = Paint()..color = Colors.white.withValues(alpha: 0.12);
    final outline = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // 실제로 칠해질 픽셀 모양(점/십자가/다이아몬드 …)을 그대로 가이드로 표시
    final cells = brushOffsets(brushSize).toSet();
    for (final (dx, dy) in cells) {
      final px = (cx + dx) * kPixelSize;
      final py = (cy + dy) * kPixelSize;
      canvas.drawRect(Rect.fromLTWH(px, py, kPixelSize, kPixelSize), fill);

      // 인접 셀이 브러시 영역 밖일 때만 윤곽선을 그려 실루엣만 강조
      if (!cells.contains((dx, dy - 1))) {
        canvas.drawLine(Offset(px, py), Offset(px + kPixelSize, py), outline);
      }
      if (!cells.contains((dx, dy + 1))) {
        canvas.drawLine(Offset(px, py + kPixelSize),
            Offset(px + kPixelSize, py + kPixelSize), outline);
      }
      if (!cells.contains((dx - 1, dy))) {
        canvas.drawLine(Offset(px, py), Offset(px, py + kPixelSize), outline);
      }
      if (!cells.contains((dx + 1, dy))) {
        canvas.drawLine(Offset(px + kPixelSize, py),
            Offset(px + kPixelSize, py + kPixelSize), outline);
      }
    }
  }

  // 체커보드는 절대 변하지 않으므로 작은 타일 이미지를 ImageShader로 반복 출력한다.
  // (캐시가 아직 준비되지 않았으면 기존 방식대로 직접 그린다)
  void _drawCheckerboard(Canvas canvas, Size size) {
    final tile = checkerTile;
    if (tile == null) {
      _drawCheckerboardDirect(canvas, size);
      return;
    }
    final paint = Paint()
      ..shader = ImageShader(
        tile,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.identity().storage,
        filterQuality: FilterQuality.none,
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _drawCheckerboardDirect(Canvas canvas, Size size) {
    const cell = kPixelSize;
    final light = Paint()..color = kCheckerLight;
    final dark = Paint()..color = kCheckerDark;
    for (int r = 0; r < (size.height / cell).ceil(); r++) {
      for (int c = 0; c < (size.width / cell).ceil(); c++) {
        canvas.drawRect(
          Rect.fromLTWH(c * cell, r * cell, cell, cell),
          (r + c) % 2 == 0 ? light : dark,
        );
      }
    }
  }

  // 네이티브 해상도로 미리 래스터화해 둔 이미지를 캔버스 크기로 한 번에 확대해 그린다.
  // FilterQuality.none = 최근접 보간이라 픽셀아트 특유의 또렷한 경계가 유지된다.
  void _drawLayers(Canvas canvas, Size size) {
    final image = layersImage;
    if (image == null) {
      _drawLayersDirect(canvas);
      return;
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.none,
    );
    _drawPendingOverlay(canvas);
  }

  // 래스터 캐시가 그리는 도중의 변경사항을 따라잡기 전까지, 방금 칠해진 픽셀들만
  // 직접 덧그려 입력에 바로 반응하는 것처럼 보이게 한다 (캐시가 따라잡으면
  // _CanvasViewportState._recordLayers가 자동으로 비운다).
  // 셀마다 먼저 체커보드를 BlendMode.src로 다시 그려 캐시에 남아있는 오래된
  // 픽셀 값을 "리셋"한 뒤(그래야 지우개로 투명해진 자리가 캐시의 옛 색이 아니라
  // 체커보드로 보인다), 그 위에 새 값을 정상 합성(srcOver)한다 — 반투명 색이
  // 체커보드와 자연스럽게 섞인다. 활성 레이어가 아닌 다른 레이어와의 합성은
  // 일시적으로 무시되지만, 캐시가 따라잡으면 곧바로 정확한 결과로 교체된다.
  void _drawPendingOverlay(Canvas canvas) {
    if (pendingOverlayPixels.isEmpty) return;
    final layer = activeLayer;
    if (layer is! DrawingLayer) return;
    final opacity = layer.opacity.clamp(0.0, 1.0);
    final reset = Paint()
      ..isAntiAlias = false
      ..blendMode = BlendMode.src;
    final composite = Paint()..isAntiAlias = false;
    for (final (x, y) in pendingOverlayPixels) {
      if (y < 0 || y >= layer.pixels.length) continue;
      final row = layer.pixels[y];
      if (x < 0 || x >= row.length) continue;
      final rect = Rect.fromLTWH(
          x * kPixelSize, y * kPixelSize, kPixelSize, kPixelSize);

      reset.color = (x + y).isEven ? kCheckerLight : kCheckerDark;
      canvas.drawRect(rect, reset);

      final c = row[x];
      if (c != null) {
        composite.color = c.withValues(alpha: c.a * opacity);
        canvas.drawRect(rect, composite);
      }
    }
  }

  void _drawLayersDirect(Canvas canvas) {
    final frame = project.frameAt(frameIndex);
    final paint = Paint()..isAntiAlias = false;
    for (final layer in frame.layers) {
      if (!layer.isVisible) continue;
      if (layer case DrawingLayer dl) {
        final opacity = layer.opacity.clamp(0.0, 1.0);
        for (int y = 0; y < project.height; y++) {
          for (int x = 0; x < project.width; x++) {
            final c = dl.pixels[y][x];
            if (c == null) continue;
            paint.color = c.withValues(alpha: c.a * opacity);
            canvas.drawRect(
              Rect.fromLTWH(
                  x * kPixelSize, y * kPixelSize, kPixelSize, kPixelSize),
              paint,
            );
          }
        }
      }
    }
  }

  void _drawSegOverlay(Canvas canvas, Size size) {
    final image = segOverlayImage;
    final hasPending = pendingSegOverlayPixels.isNotEmpty;

    if (!hasPending) {
      if (image == null) {
        _drawSegOverlayDirect(canvas);
      } else {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Offset.zero & size,
          Paint()..filterQuality = FilterQuality.none,
        );
      }
      return;
    }

    // saveLayer 로 그룹화하면 BlendMode.clear 가 레이어 내부에서만 작동해
    // 지운 픽셀이 하위 레이어(드로잉)를 건드리지 않는다.
    canvas.saveLayer(Offset.zero & size, Paint());
    if (image != null) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.none,
      );
    } else {
      _drawSegOverlayDirect(canvas);
    }
    _drawPendingSegOverlay(canvas);
    canvas.restore();
  }

  void _drawPendingSegOverlay(Canvas canvas) {
    final colorById = {for (final c in project.labelClasses) c.id: c.color};
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    final drawPaint = Paint()..isAntiAlias = false;
    for (final entry in pendingSegOverlayPixels.entries) {
      final (x, y) = entry.key;
      final rect = Rect.fromLTWH(
          x * kPixelSize, y * kPixelSize, kPixelSize, kPixelSize);
      final labelId = entry.value;
      if (labelId == null) {
        canvas.drawRect(rect, clearPaint);
      } else {
        final color = colorById[labelId];
        if (color != null && color.a != 0) {
          drawPaint.color = color.withValues(alpha: segOverlayOpacity);
          canvas.drawRect(rect, drawPaint);
        }
      }
    }
  }

  void _drawSegOverlayDirect(Canvas canvas) {
    final frame = project.frameAt(frameIndex);
    final colorById = {for (final c in project.labelClasses) c.id: c.color};
    final paint = Paint()..isAntiAlias = false;
    for (final layer in frame.layers) {
      if (!layer.isVisible) continue;
      if (layer case SegmentationLayer sl) {
        for (int y = 0; y < project.height; y++) {
          for (int x = 0; x < project.width; x++) {
            final id = sl.labelIds[y][x];
            if (id == null) continue;
            final color = colorById[id];
            if (color == null || color.a == 0) continue;
            paint.color = color.withValues(alpha: segOverlayOpacity);
            canvas.drawRect(
              Rect.fromLTWH(
                  x * kPixelSize, y * kPixelSize, kPixelSize, kPixelSize),
              paint,
            );
          }
        }
      }
    }
  }

  // 같은 레이블끼리 뭉친 영역(서로 다른 레이블 또는 미레이블 영역과의 경계)의
  // 테두리에 흰색 선을 그려 영역 구분을 눈에 띄게 한다.
  // pendingSegOverlayPixels 도 반영해 그리는 즉시 테두리가 따라온다.
  void _drawSegBorders(Canvas canvas) {
    final frame = project.frameAt(frameIndex);
    SegmentationLayer? sl;
    for (final layer in frame.layers) {
      if (layer.isVisible && layer is SegmentationLayer) {
        sl = layer;
        break;
      }
    }
    if (sl == null) return;
    final w = project.width, h = project.height;

    int? labelAt(int x, int y) {
      if (x < 0 || x >= w || y < 0 || y >= h) return null;
      final pending = pendingSegOverlayPixels[(x, y)];
      if (pending != null || pendingSegOverlayPixels.containsKey((x, y))) {
        return pending;
      }
      return sl!.labelIds[y][x];
    }

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square;

    // 각 변은 라벨이 있는 픽셀 쪽에서만 그린다. 이웃이 미레이블(null)이면
    // 그 이웃 픽셀은 순회 시 건너뛰므로(continue), 라벨↔미레이블 경계는
    // 한쪽(라벨 있는 쪽)에서만 그려져야 빠지는 변 없이 전부 채워진다.
    // 라벨↔라벨 경계는 양쪽에서 한 번씩 그려져 겹치지만 시각적으로 무해하다.
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final id = labelAt(x, y);
        if (id == null) continue;

        // 위쪽 경계
        if (labelAt(x, y - 1) != id) {
          canvas.drawLine(Offset(x * kPixelSize, y * kPixelSize),
              Offset((x + 1) * kPixelSize, y * kPixelSize), paint);
        }
        // 왼쪽 경계
        if (labelAt(x - 1, y) != id) {
          canvas.drawLine(Offset(x * kPixelSize, y * kPixelSize),
              Offset(x * kPixelSize, (y + 1) * kPixelSize), paint);
        }
        // 오른쪽 경계
        if (labelAt(x + 1, y) != id) {
          canvas.drawLine(
            Offset((x + 1) * kPixelSize, y * kPixelSize),
            Offset((x + 1) * kPixelSize, (y + 1) * kPixelSize),
            paint,
          );
        }
        // 아래쪽 경계
        if (labelAt(x, y + 1) != id) {
          canvas.drawLine(
            Offset(x * kPixelSize, (y + 1) * kPixelSize),
            Offset((x + 1) * kPixelSize, (y + 1) * kPixelSize),
            paint,
          );
        }
      }
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 0.5;
    for (int x = 0; x <= project.width; x++) {
      canvas.drawLine(Offset(x * kPixelSize, 0),
          Offset(x * kPixelSize, size.height), paint);
    }
    for (int y = 0; y <= project.height; y++) {
      canvas.drawLine(
          Offset(0, y * kPixelSize), Offset(size.width, y * kPixelSize), paint);
    }
  }

  @override
  bool shouldRepaint(_CanvasPainter old) => true;
}

// ── FrameThumbnailPainter (타임라인용) ────────────────────────

class FrameThumbnailPainter extends CustomPainter {
  final List<List<Color?>> pixels;
  final int width;
  final int height;

  const FrameThumbnailPainter({
    required this.pixels,
    required this.width,
    required this.height,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pw = size.width / max(width, 1);
    final ph = size.height / max(height, 1);
    final paint = Paint()..isAntiAlias = false;

    // 체커보드
    final light = Paint()..color = const Color(0xFF2A2A3E);
    final dark = Paint()..color = const Color(0xFF1E1E30);
    const cell = 4.0;
    for (int r = 0; r < (size.height / cell).ceil(); r++) {
      for (int c = 0; c < (size.width / cell).ceil(); c++) {
        canvas.drawRect(
          Rect.fromLTWH(c * cell, r * cell, cell, cell),
          (r + c) % 2 == 0 ? light : dark,
        );
      }
    }

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final c = pixels[y][x];
        if (c == null) continue;
        paint.color = c;
        canvas.drawRect(Rect.fromLTWH(x * pw, y * ph, pw, ph), paint);
      }
    }
  }

  @override
  bool shouldRepaint(FrameThumbnailPainter old) => true;
}
