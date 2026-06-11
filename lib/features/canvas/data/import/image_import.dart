import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// 디코딩된 이미지를 캔버스 픽셀 그리드로 변환한 결과.
typedef DecodedImagePixels = ({
  int width,
  int height,
  List<List<Color?>> pixels,
});

/// 이미지 파일 바이트를 캔버스 픽셀 그리드로 디코딩한다.
/// 알파 0인 픽셀은 빈 픽셀(null)로 처리한다. 디코딩에 실패하면 null을 반환한다.
DecodedImagePixels? decodeImagePixels(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final width = decoded.width;
  final height = decoded.height;
  final pixels = List.generate(height, (y) {
    return List<Color?>.generate(width, (x) {
      final p = decoded.getPixel(x, y);
      final a = p.a.toInt();
      if (a == 0) return null;
      return Color.fromARGB(a, p.r.toInt(), p.g.toInt(), p.b.toInt());
    });
  });

  return (width: width, height: height, pixels: pixels);
}
