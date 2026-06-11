import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pixel_lens/core/storage/color_hex.dart';
import 'package:pixel_lens/core/storage/home_directory.dart';
import 'package:pixel_lens/features/labeling/data/label_set_json.dart';
import 'package:pixel_lens/features/labeling/data/label_set.dart';
import 'package:pixel_lens/features/palette/data/palette_set.dart';

/// 모든 프로젝트/에셋이 공유하는 전역 프리셋(커스텀 팔레트, 레이블 셋)을
/// `~/Documents/PixelPalette/`에 저장/로드한다.
///
/// 저장 형식:
/// ```
/// ~/Documents/PixelPalette/
///   palettes.json     커스텀 팔레트 셋 목록 + 활성 팔레트 id
///   label_sets.json   레이블 셋 목록 + 활성 레이블 셋 id
/// ```

/// 테스트에서 저장 루트를 임시 디렉터리로 바꿔치기하기 위한 오버라이드.
@visibleForTesting
String? debugPixelPaletteRoot;

/// `~/Documents/PixelPalette` 루트 디렉터리. 없으면 생성한다.
Future<Directory> pixelPaletteRootDir() =>
    documentsSubDir('PixelPalette', override: debugPixelPaletteRoot);

// ── 팔레트 ────────────────────────────────────────────────────

Future<void> saveGlobalPaletteSets(
    List<PaletteSet> sets, String activePaletteId) async {
  final root = await pixelPaletteRootDir();
  final json = {
    'activePaletteId': activePaletteId,
    'sets': sets.map(_paletteSetToJson).toList(),
  };
  await File('${root.path}/palettes.json')
      .writeAsString(const JsonEncoder.withIndent('  ').convert(json));
}

/// 저장된 전역 팔레트 셋을 불러온다. 파일이 없거나 읽기에 실패하면 `null`.
Future<(List<PaletteSet> sets, String activePaletteId)?>
    loadGlobalPaletteSets() async {
  final root = await pixelPaletteRootDir();
  final file = File('${root.path}/palettes.json');
  if (!await file.exists()) return null;
  try {
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final sets = (json['sets'] as List)
        .map((e) => _paletteSetFromJson(e as Map<String, dynamic>))
        .toList();
    if (sets.isEmpty) return null;
    return (sets, json['activePaletteId'] as String);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _paletteSetToJson(PaletteSet s) => {
      'id': s.id,
      'name': s.name,
      'colors': s.colors.map(colorToHex).toList(),
    };

PaletteSet _paletteSetFromJson(Map<String, dynamic> j) => PaletteSet(
      id: j['id'] as String,
      name: j['name'] as String,
      colors: (j['colors'] as List)
          .map((e) => colorFromHex(e as String))
          .toList(),
    );

// ── 레이블 셋 ─────────────────────────────────────────────────

Future<void> saveGlobalLabelSets(
    List<LabelSet> sets, int activeLabelSetId) async {
  final root = await pixelPaletteRootDir();
  final json = {
    'activeLabelSetId': activeLabelSetId,
    'sets': sets.map(labelSetToJson).toList(),
  };
  await File('${root.path}/label_sets.json')
      .writeAsString(const JsonEncoder.withIndent('  ').convert(json));
}

/// 저장된 전역 레이블 셋을 불러온다. 파일이 없거나 읽기에 실패하면 `null`.
Future<(List<LabelSet> sets, int activeLabelSetId)?>
    loadGlobalLabelSets() async {
  final root = await pixelPaletteRootDir();
  final file = File('${root.path}/label_sets.json');
  if (!await file.exists()) return null;
  try {
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final sets = (json['sets'] as List)
        .map((e) => labelSetFromJson(e as Map<String, dynamic>))
        .toList();
    if (sets.isEmpty) return null;
    return (sets, json['activeLabelSetId'] as int);
  } catch (_) {
    return null;
  }
}
