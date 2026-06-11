import 'package:flutter/material.dart';
import 'package:pixel_lens/features/canvas/data/layer.dart';

/// 애니메이션 타임라인의 단일 프레임.
@immutable
class Frame {
  final List<Layer> layers;
  final int durationMs;
  final String? label;

  const Frame({
    required this.layers,
    this.durationMs = 100,
    this.label,
  });

  factory Frame.initial({required int width, required int height}) => Frame(
        layers: [DrawingLayer.empty(name: 'Layer 1', width: width, height: height)],
      );

  int get layerCount => layers.length;
  Layer layerAt(int index) => layers[index];

  Frame copyWith({List<Layer>? layers, int? durationMs, String? label}) => Frame(
        layers: layers ?? this.layers,
        durationMs: durationMs ?? this.durationMs,
        label: label ?? this.label,
      );

  Frame addLayer(Layer layer) => copyWith(layers: [...layers, layer]);

  Frame removeLayerAt(int index) {
    assert(layers.length > 1);
    return copyWith(layers: List<Layer>.from(layers)..removeAt(index));
  }

  Frame replaceLayerAt(int index, Layer layer) =>
      copyWith(layers: List<Layer>.from(layers)..[index] = layer);

  Frame moveLayer(int from, int to) {
    final list = List<Layer>.from(layers);
    list.insert(to, list.removeAt(from));
    return copyWith(layers: list);
  }

  /// 모든 드로잉 레이어를 아래→위 순서로 병합한 플랫 픽셀 맵
  List<List<Color?>> flattenDrawingLayers(int width, int height) {
    final result = List.generate(height, (_) => List<Color?>.filled(width, null));
    for (final layer in layers) {
      if (!layer.isVisible) continue;
      if (layer case DrawingLayer dl) {
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final c = dl.pixels[y][x];
            if (c != null) result[y][x] = c;
          }
        }
      }
    }
    return result;
  }
}
