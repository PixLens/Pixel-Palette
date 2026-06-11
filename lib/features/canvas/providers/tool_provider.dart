import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── EditorMode ────────────────────────────────────────────────

enum EditorMode { pixel, segmentation }

// ── AppTool ───────────────────────────────────────────────────

enum AppTool {
  // 드로잉
  pen,
  eraser,
  fill,
  eyedropper,
  grab,
  // 세그멘테이션
  annotate,
  labelEraser,
  labelFill,
  labelEyedropper,
  // 공통
  rectSelect,
  move,
}

extension AppToolX on AppTool {
  bool get isDrawingTool => const {
        AppTool.pen,
        AppTool.eraser,
        AppTool.fill,
        AppTool.eyedropper
      }.contains(this);
  bool get isSegmentationTool => const {
        AppTool.annotate,
        AppTool.labelEraser,
        AppTool.labelFill,
        AppTool.labelEyedropper
      }.contains(this);

  String get label => switch (this) {
        AppTool.pen => '펜',
        AppTool.eraser => '지우개',
        AppTool.fill => '채우기',
        AppTool.eyedropper => '스포이드',
        AppTool.annotate => '어노테이트',
        AppTool.labelEraser => '레이블 지우개',
        AppTool.labelFill => '레이블 채우기',
        AppTool.labelEyedropper => '레이블 스포이드',
        AppTool.grab => '그랩',
        AppTool.rectSelect => '선택',
        AppTool.move => '이동',
      };

  IconData get icon => switch (this) {
        AppTool.pen => Icons.edit,
        AppTool.eraser => Icons.auto_fix_normal,
        AppTool.fill => Icons.format_color_fill,
        AppTool.eyedropper => Icons.colorize,
        AppTool.annotate => Icons.brush,
        AppTool.labelEraser => Icons.cleaning_services,
        AppTool.labelFill => Icons.format_paint,
        AppTool.labelEyedropper => Icons.search,
        AppTool.grab => Icons.pan_tool_alt,
        AppTool.rectSelect => Icons.select_all,
        AppTool.move => Icons.open_with,
      };

  String? get shortcut => switch (this) {
        AppTool.pen        => 'P',
        AppTool.eraser     => 'E',
        AppTool.eyedropper => 'S',
        AppTool.grab       => 'G',
        _                  => null,
      };

  // 지우개 계열 도구는 eraserSize, 나머지는 penSize를 사용
  bool get usesEraserSize =>
      this == AppTool.eraser || this == AppTool.labelEraser;
}

// ── ToolState ─────────────────────────────────────────────────

@immutable
class ToolState {
  final EditorMode mode;
  final AppTool currentTool;
  final Color currentColor;
  final Color backgroundColor;
  final int penSize;
  final int eraserSize;
  final int? currentLabelClassId;
  final bool showSegmentationOverlay;
  final double segOverlayOpacity;

  const ToolState({
    this.mode = EditorMode.pixel,
    this.currentTool = AppTool.pen,
    this.currentColor = const Color(0xFF8B5CF6),
    this.backgroundColor = const Color(0xFF000000),
    this.penSize = 1,
    this.eraserSize = 1,
    this.currentLabelClassId,
    this.showSegmentationOverlay = true,
    this.segOverlayOpacity = 0.5,
  });

  ToolState copyWith({
    EditorMode? mode,
    AppTool? currentTool,
    Color? currentColor,
    Color? backgroundColor,
    int? penSize,
    int? eraserSize,
    int? currentLabelClassId,
    bool? showSegmentationOverlay,
    double? segOverlayOpacity,
  }) =>
      ToolState(
        mode: mode ?? this.mode,
        currentTool: currentTool ?? this.currentTool,
        currentColor: currentColor ?? this.currentColor,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        penSize: penSize ?? this.penSize,
        eraserSize: eraserSize ?? this.eraserSize,
        currentLabelClassId: currentLabelClassId ?? this.currentLabelClassId,
        showSegmentationOverlay:
            showSegmentationOverlay ?? this.showSegmentationOverlay,
        segOverlayOpacity: segOverlayOpacity ?? this.segOverlayOpacity,
      );

  // 현재 선택된 도구가 실제로 사용하는 브러시 크기
  int get activeBrushSize => currentTool.usesEraserSize ? eraserSize : penSize;
}

// ── ToolNotifier ──────────────────────────────────────────────

class ToolNotifier extends Notifier<ToolState> {
  @override
  ToolState build() => const ToolState();

  void selectTool(AppTool tool) => state = state.copyWith(currentTool: tool);

  void setColor(Color color) {
    state = state.copyWith(
      currentColor: color,
      // 스포이드 사용 후 자동으로 펜 전환
      currentTool: state.currentTool == AppTool.eyedropper ? AppTool.pen : null,
    );
  }

  void setPenSize(int size) =>
      state = state.copyWith(penSize: size.clamp(1, 100));

  void setEraserSize(int size) =>
      state = state.copyWith(eraserSize: size.clamp(1, 100));

  // 현재 선택된 도구의 브러시 크기를 +/- 만큼 조정
  void adjustBrushSize(int delta) {
    if (state.currentTool.usesEraserSize) {
      setEraserSize(state.eraserSize + delta);
    } else {
      setPenSize(state.penSize + delta);
    }
  }

  void setLabelClass(int? id) {
    state = state.copyWith(
      currentLabelClassId: id,
      // 레이블 선택 시 어노테이트 도구로 자동 전환
      currentTool: id != null && !state.currentTool.isSegmentationTool
          ? AppTool.annotate
          : null,
    );
  }

  void pickLabelClass(int id) => state =
      state.copyWith(currentLabelClassId: id, currentTool: AppTool.annotate);

  void setMode(EditorMode mode) {
    final tool = mode == EditorMode.pixel ? AppTool.pen : AppTool.annotate;
    state = state.copyWith(mode: mode, currentTool: tool);
  }

  void setBackgroundColor(Color color) =>
      state = state.copyWith(backgroundColor: color);

  void swapColors() => state = state.copyWith(
        currentColor: state.backgroundColor,
        backgroundColor: state.currentColor,
      );

  void toggleSegmentationOverlay() => state =
      state.copyWith(showSegmentationOverlay: !state.showSegmentationOverlay);

  void setSegOverlayOpacity(double opacity) =>
      state = state.copyWith(segOverlayOpacity: opacity.clamp(0.0, 1.0));
}

// ── Provider ──────────────────────────────────────────────────

final toolProvider =
    NotifierProvider<ToolNotifier, ToolState>(ToolNotifier.new);
