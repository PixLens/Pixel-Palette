import 'package:flutter/material.dart';
import 'package:pixel_lens/features/labeling/data/label_class.dart';

enum LayerType { drawing, segmentation }

// ── 베이스 (sealed) ───────────────────────────────────────────

sealed class Layer {
  final String name;
  final bool isVisible;
  final double opacity;

  const Layer({
    required this.name,
    this.isVisible = true,
    this.opacity = 1.0,
  });

  LayerType get type;
  Layer copyWithBase({String? name, bool? isVisible, double? opacity});
}

// ── 드로잉 레이어 ─────────────────────────────────────────────

final class DrawingLayer extends Layer {
  final List<List<Color?>> pixels;

  const DrawingLayer({
    required super.name,
    required this.pixels,
    super.isVisible,
    super.opacity,
  });

  @override
  LayerType get type => LayerType.drawing;

  factory DrawingLayer.empty({
    required String name,
    required int width,
    required int height,
  }) =>
      DrawingLayer(
        name: name,
        pixels: List.generate(height, (_) => List.filled(width, null)),
      );

  Color? getPixel(int x, int y) => pixels[y][x];

  @override
  DrawingLayer copyWithBase({String? name, bool? isVisible, double? opacity}) =>
      DrawingLayer(
        name: name ?? this.name,
        pixels: pixels,
        isVisible: isVisible ?? this.isVisible,
        opacity: opacity ?? this.opacity,
      );

  DrawingLayer copyWith({
    String? name,
    bool? isVisible,
    double? opacity,
    List<List<Color?>>? pixels,
  }) =>
      DrawingLayer(
        name: name ?? this.name,
        pixels: pixels ?? this.pixels,
        isVisible: isVisible ?? this.isVisible,
        opacity: opacity ?? this.opacity,
      );

  DrawingLayer withPixelChanges(
      Map<(int, int), Color?> changes, int width, int height) {
    final newPixels =
        List.generate(height, (y) => List<Color?>.from(pixels[y]));
    for (final e in changes.entries) {
      final (x, y) = e.key;
      if (x >= 0 && x < width && y >= 0 && y < height) newPixels[y][x] = e.value;
    }
    return copyWith(pixels: newPixels);
  }
}

// ── 세그멘테이션 레이어 ───────────────────────────────────────

final class SegmentationLayer extends Layer {
  /// 픽셀당 레이블 클래스 ID. null = 미레이블.
  final List<List<int?>> labelIds;

  const SegmentationLayer({
    required super.name,
    required this.labelIds,
    super.isVisible,
    super.opacity,
  });

  @override
  LayerType get type => LayerType.segmentation;

  factory SegmentationLayer.empty({
    required String name,
    required int width,
    required int height,
  }) =>
      SegmentationLayer(
        name: name,
        labelIds: List.generate(height, (_) => List.filled(width, null)),
      );

  int? getLabelId(int x, int y) => labelIds[y][x];

  @override
  SegmentationLayer copyWithBase({String? name, bool? isVisible, double? opacity}) =>
      SegmentationLayer(
        name: name ?? this.name,
        labelIds: labelIds,
        isVisible: isVisible ?? this.isVisible,
        opacity: opacity ?? this.opacity,
      );

  SegmentationLayer copyWith({
    String? name,
    bool? isVisible,
    double? opacity,
    List<List<int?>>? labelIds,
  }) =>
      SegmentationLayer(
        name: name ?? this.name,
        labelIds: labelIds ?? this.labelIds,
        isVisible: isVisible ?? this.isVisible,
        opacity: opacity ?? this.opacity,
      );

  SegmentationLayer withLabelChanges(
      Map<(int, int), int?> changes, int width, int height) {
    final newIds = List.generate(height, (y) => List<int?>.from(labelIds[y]));
    for (final e in changes.entries) {
      final (x, y) = e.key;
      if (x >= 0 && x < width && y >= 0 && y < height) newIds[y][x] = e.value;
    }
    return copyWith(labelIds: newIds);
  }

  List<LabelStats> computeStats(List<LabelClass> classes, int totalPixels) {
    final counts = <int, int>{};
    for (final row in labelIds) {
      for (final id in row) {
        if (id != null) counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return classes.map((c) {
      final count = counts[c.id] ?? 0;
      return LabelStats(
        labelClass: c,
        pixelCount: count,
        coveragePercent: totalPixels > 0 ? count / totalPixels * 100 : 0,
      );
    }).toList();
  }
}
