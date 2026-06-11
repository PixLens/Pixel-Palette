import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:pixel_lens/features/labeling/data/label_class.dart';

/// 컬러 마스크 PNG로 인코딩한다. 각 픽셀을 해당 레이블 클래스의 색상으로 채우고,
/// 레이블이 없는 영역은 투명 처리한다. (ExportFormat.maskPng)
Uint8List encodeColorMaskPng(
  List<List<int?>> labelIds,
  List<LabelClass> classes,
  int width,
  int height,
) {
  final colorById = {for (final c in classes) c.id: c.color};
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final color = colorById[labelIds[y][x]];
      final (r, g, b, a) = color == null ? (0, 0, 0, 0) : _channelsOf(color);
      image.setPixelRgba(x, y, r, g, b, a);
    }
  }
  return img.encodePng(image);
}

/// 인덱스 마스크 PNG로 인코딩한다. 픽셀 값 자체가 레이블 클래스 ID인 단일 채널
/// 그레이스케일 이미지. 레이블이 없는 영역은 0. (ExportFormat.indexedPng)
Uint8List encodeIndexedMaskPng(
  List<List<int?>> labelIds,
  int width,
  int height,
) {
  final image = img.Image(width: width, height: height, numChannels: 1);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      image.setPixelR(x, y, labelIds[y][x] ?? 0);
    }
  }
  return img.encodePng(image);
}

/// 디버깅용 미리보기 PNG로 인코딩한다. 캔버스에 그려지는 모습 그대로
/// 픽셀 그림 위에 레이블 클래스 색상을 [overlayOpacity]로 반투명하게 겹쳐 그림
Uint8List encodeDebugOverlayPng(
  List<List<Color?>> pixels,
  List<List<int?>> labelIds,
  List<LabelClass> classes,
  int width,
  int height,
  double overlayOpacity,
) {
  final colorById = {for (final c in classes) c.id: c.color};
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final (dr, dg, db, da) = _channelsOf(pixels[y][x]);
      final labelColor = colorById[labelIds[y][x]];
      final (r, g, b, a) = labelColor == null
          ? (dr, dg, db, da)
          : _blendOver(dr, dg, db, da, labelColor, overlayOpacity);
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

/// [src]를 [opacity]만큼 반투명하게 (dr,dg,db,da) 위에 알파 합성한다 ("over" 연산).
(int, int, int, int) _blendOver(
    int dr, int dg, int db, int da, Color src, double opacity) {
  final (sr, sg, sb, srcA) = _channelsOf(src);
  final sa = (srcA / 255.0) * opacity;
  if (sa <= 0) return (dr, dg, db, da);

  final daF = da / 255.0;
  final outA = sa + daF * (1 - sa);
  if (outA <= 0) return (0, 0, 0, 0);

  int mix(int s, int d) =>
      ((s * sa + d * daF * (1 - sa)) / outA).round().clamp(0, 255);

  return (
    mix(sr, dr),
    mix(sg, dg),
    mix(sb, db),
    (outA * 255).round().clamp(0, 255)
  );
}

/// `label_classes.json` 파일 내용을 생성한다. 마스크 픽셀 값(또는 색상)과
/// 레이블 클래스 사이의 매핑을 기록해, 외부 ML 파이프라인에서 마스크를 해석할 수 있게 한다.
String encodeLabelClassesJson(List<LabelClass> classes) {
  final list = classes
      .map((c) => {
            'id': c.id,
            'name': c.name,
            'color':
                '#${(c.color.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}',
          })
      .toList();
  return const JsonEncoder.withIndent('  ').convert({'classes': list});
}
