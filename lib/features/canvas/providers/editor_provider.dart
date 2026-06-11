import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 에디터 UI 상태 (어느 프레임/레이어가 선택돼 있는지)
@immutable
class EditorState {
  final int activeFrameIndex;
  final int activeLayerIndex;

  const EditorState({
    this.activeFrameIndex = 0,
    this.activeLayerIndex = 0,
  });

  EditorState copyWith({int? activeFrameIndex, int? activeLayerIndex}) =>
      EditorState(
        activeFrameIndex: activeFrameIndex ?? this.activeFrameIndex,
        activeLayerIndex: activeLayerIndex ?? this.activeLayerIndex,
      );
}

class EditorNotifier extends Notifier<EditorState> {
  @override
  EditorState build() => const EditorState();

  void selectFrame(int index) =>
      state = state.copyWith(activeFrameIndex: index);

  void selectLayer(int index) =>
      state = state.copyWith(activeLayerIndex: index);

  void clampToProject(int frameCount, int layerCount) {
    state = EditorState(
      activeFrameIndex: state.activeFrameIndex.clamp(0, frameCount - 1),
      activeLayerIndex: state.activeLayerIndex.clamp(0, layerCount - 1),
    );
  }
}

final editorProvider =
    NotifierProvider<EditorNotifier, EditorState>(EditorNotifier.new);
