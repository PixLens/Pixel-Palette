import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pixel_lens/features/canvas/data/export/export_writer.dart';
import 'package:pixel_lens/features/canvas/data/frame.dart';
import 'package:pixel_lens/features/canvas/data/layer.dart';
import 'package:pixel_lens/features/labeling/data/label_class.dart';
import 'package:pixel_lens/features/labeling/data/label_set.dart';
import 'package:pixel_lens/features/project/data/project.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('export_writer_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  // 2x2 캔버스: (0,0)=픽셀 있음/레이블 1, (1,0)=비어있음, (0,1)=비어있음, (1,1)=픽셀 있음/레이블 2
  Project buildProject({int frameCount = 1}) {
    final classes = [
      const LabelClass(id: 1, name: 'Background', color: Color(0xFFFF0000)),
      const LabelClass(id: 2, name: 'Object', color: Color(0xFF00FF00)),
    ];
    final frames = List.generate(frameCount, (_) {
      const drawing = DrawingLayer(
        name: 'Layer 1',
        pixels: [
          [Color(0xFF112233), null],
          [null, Color(0xFF445566)],
        ],
      );
      const seg = SegmentationLayer(
        name: 'Seg',
        labelIds: [
          [1, null],
          [null, 2],
        ],
      );
      return const Frame(layers: [drawing, seg]);
    });
    return Project(
      name: 'TestProj',
      width: 2,
      height: 2,
      frames: frames,
      labelSets: [LabelSet(id: 1, name: 'Default', labels: classes)],
      activeLabelSetId: 1,
      palette: const [],
      metadata: ProjectMetadata(
          createdAt: DateTime(2024), modifiedAt: DateTime(2024)),
    );
  }

  group('PNG (합성 이미지)', () {
    test('프레임이 하나면 <프로젝트 이름>.png 단일 파일로 내보낸다', () async {
      final project = buildProject();
      final resultPath = await exportProject(
        project: project,
        format: ExportFormat.png,
        targetDir: tempDir.path,
      );

      expect(resultPath, '${tempDir.path}/TestProj.png');
      final file = File(resultPath);
      expect(await file.exists(), isTrue);

      final decoded = img.decodePng(await file.readAsBytes())!;
      expect(decoded.width, 2);
      expect(decoded.height, 2);

      final filled = decoded.getPixel(0, 0);
      expect(
        [
          filled.r.toInt(),
          filled.g.toInt(),
          filled.b.toInt(),
          filled.a.toInt()
        ],
        [0x11, 0x22, 0x33, 0xFF],
      );
      expect(decoded.getPixel(1, 0).a.toInt(), 0); // 빈 픽셀은 투명
    });

    test('프레임이 여럿이면 <프로젝트 이름>/frame_NNNN.png 폴더로 내보낸다', () async {
      final project = buildProject(frameCount: 2);
      final resultPath = await exportProject(
        project: project,
        format: ExportFormat.png,
        targetDir: tempDir.path,
      );

      expect(resultPath, '${tempDir.path}/TestProj');
      expect(await File('$resultPath/frame_0001.png').exists(), isTrue);
      expect(await File('$resultPath/frame_0002.png').exists(), isTrue);
    });

    test('이름이 충돌하면 (1), (2)...로 번호를 붙여 피한다', () async {
      final project = buildProject();
      final first = await exportProject(
          project: project, format: ExportFormat.png, targetDir: tempDir.path);
      final second = await exportProject(
          project: project, format: ExportFormat.png, targetDir: tempDir.path);
      final third = await exportProject(
          project: project, format: ExportFormat.png, targetDir: tempDir.path);

      expect(first, '${tempDir.path}/TestProj.png');
      expect(second, '${tempDir.path}/TestProj (1).png');
      expect(third, '${tempDir.path}/TestProj (2).png');
    });
  });

  group('이미지 + 마스크 쌍', () {
    test('컬러 마스크: images/, masks/, label_classes.json 구조로 내보낸다', () async {
      final project = buildProject();
      final resultPath = await exportProject(
        project: project,
        format: ExportFormat.maskPng,
        targetDir: tempDir.path,
      );

      expect(resultPath, '${tempDir.path}/TestProj');
      expect(await File('$resultPath/images/frame_0001.png').exists(), isTrue);
      expect(await File('$resultPath/masks/frame_0001.png').exists(), isTrue);

      final mask = img.decodePng(
          await File('$resultPath/masks/frame_0001.png').readAsBytes())!;
      final labeled = mask.getPixel(0, 0); // labelId 1 → 빨강
      expect(
        [
          labeled.r.toInt(),
          labeled.g.toInt(),
          labeled.b.toInt(),
          labeled.a.toInt()
        ],
        [0xFF, 0x00, 0x00, 0xFF],
      );
      expect(mask.getPixel(1, 0).a.toInt(), 0); // 레이블 없음 → 투명

      final json = await File('$resultPath/label_classes.json').readAsString();
      expect(json, contains('"name": "Background"'));
      expect(json, contains('"color": "#ff0000"'));
    });

    test('인덱스 마스크: 픽셀 값이 곧 레이블 클래스 ID인 그레이스케일로 내보낸다', () async {
      final project = buildProject();
      final resultPath = await exportProject(
        project: project,
        format: ExportFormat.indexedPng,
        targetDir: tempDir.path,
      );

      final mask = img.decodePng(
          await File('$resultPath/masks/frame_0001.png').readAsBytes())!;
      expect(mask.getPixel(0, 0).r.toInt(), 1);
      expect(mask.getPixel(1, 1).r.toInt(), 2);
      expect(mask.getPixel(1, 0).r.toInt(), 0); // 레이블 없음 → 0
    });
  });
}
