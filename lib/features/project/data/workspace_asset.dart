import 'package:flutter/material.dart';
import 'package:pixel_lens/features/canvas/data/frame.dart';
import 'package:pixel_lens/features/canvas/data/layer.dart';

@immutable
class WorkspaceAsset {
  final String id;
  final String name;
  final List<String> tags;
  final String description;
  final List<Frame> frames;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final bool isFavorite;

  const WorkspaceAsset({
    required this.id,
    required this.name,
    this.tags = const [],
    this.description = '',
    required this.frames,
    required this.createdAt,
    required this.modifiedAt,
    this.isFavorite = false,
  });

  int get frameCount => frames.length;

  int get maskFrameCount =>
      frames.where((f) => f.layers.any((l) => l is SegmentationLayer)).length;

  bool get hasMask => maskFrameCount > 0;

  String get typeLabel => hasMask ? 'Pixel Art + Mask' : 'Pixel Art';

  Frame? get firstFrame => frames.isEmpty ? null : frames.first;

  /// 실제 저장된 픽셀 데이터 기준의 가로/세로 크기.
  /// 프레임/레이어가 비어 있으면 null (호출 측에서 프로젝트 기본 크기로 대체).
  int? get width => _pixelDimensions?.$1;
  int? get height => _pixelDimensions?.$2;

  (int, int)? get _pixelDimensions {
    final frame = firstFrame;
    if (frame == null || frame.layers.isEmpty) return null;
    final layer = frame.layers.first;
    return switch (layer) {
      DrawingLayer dl =>
        dl.pixels.isEmpty ? null : (dl.pixels.first.length, dl.pixels.length),
      SegmentationLayer sl => sl.labelIds.isEmpty
          ? null
          : (sl.labelIds.first.length, sl.labelIds.length),
    };
  }

  DrawingLayer? get firstDrawingLayer {
    for (final f in frames) {
      for (final l in f.layers) {
        if (l is DrawingLayer) return l;
      }
    }
    return null;
  }

  WorkspaceAsset copyWith({
    String? id,
    String? name,
    List<String>? tags,
    String? description,
    List<Frame>? frames,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isFavorite,
  }) =>
      WorkspaceAsset(
        id: id ?? this.id,
        name: name ?? this.name,
        tags: tags ?? this.tags,
        description: description ?? this.description,
        frames: frames ?? this.frames,
        createdAt: createdAt ?? this.createdAt,
        modifiedAt: modifiedAt ?? this.modifiedAt,
        isFavorite: isFavorite ?? this.isFavorite,
      );
}
