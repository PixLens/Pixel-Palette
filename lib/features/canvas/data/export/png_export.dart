import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// 픽셀 그리드를 PNG 바이트로 인코딩한다. 빈 픽셀(null)은 투명(alpha=0)으로 처리한다.
Uint8List encodePixelsToPng(List<List<Color?>> pixels, int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final (r, g, b, a) = _channelsOf(pixels[y][x]);
      image.setPixelRgba(x, y, r, g, b, a);
    }
  }
  return img.encodePng(image);
}

(int, int, int, int) _channelsOf(Color? c) {
  if (c == null) return (0, 0, 0, 0);
  final argb = c.toARGB32();
  return (
    (argb >> 16) & 0xFF,
    (argb >> 8) & 0xFF,
    argb & 0xFF,
    (argb >> 24) & 0xFF,
  );
}
