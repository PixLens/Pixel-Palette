import 'dart:io';
import 'dart:typed_data';

import 'package:pixel_lens/features/canvas/data/export/mask_pair_export.dart';
import 'package:pixel_lens/features/canvas/data/export/png_export.dart';
import 'package:pixel_lens/features/canvas/data/frame.dart';
import 'package:pixel_lens/features/canvas/data/layer.dart';
import 'package:pixel_lens/features/project/data/project.dart';

/// [project]를 [format]에 따라 사용자가 선택한 [targetDir] 아래에 내보낸다.
/// 같은 이름의 폴더/파일이 이미 있으면 ` (1)`, ` (2)`...를 붙여 충돌을 피한다.
/// 실제로 기록된 최상위 경로(파일 또는 폴더)를 반환한다.
Future<String> exportProject({
  required Project project,
  required ExportFormat format,
  required String targetDir,
  double debugOverlayOpacity = 0.5,
}) async {
  return switch (format) {
    ExportFormat.png => _exportCompositePng(project, targetDir),
    ExportFormat.maskPng => _exportMaskPairs(project, targetDir,
        indexed: false, debugOverlayOpacity: debugOverlayOpacity),
    ExportFormat.indexedPng => _exportMaskPairs(project, targetDir,
        indexed: true, debugOverlayOpacity: debugOverlayOpacity),
    ExportFormat.cocoJson ||
    ExportFormat.spriteSheet =>
      throw UnsupportedError('$format 내보내기는 아직 지원하지 않습니다'),
  };
}

// ── PNG (합성 이미지) ──────────────────────────────────────────
//
// 프레임이 하나면 `<프로젝트 이름>.png` 단일 파일로, 여럿이면
// `<프로젝트 이름>/frame_0001.png` ... 폴더로 내보낸다.

Future<String> _exportCompositePng(Project project, String targetDir) async {
  if (project.frames.length == 1) {
    final bytes = _encodeFramePng(project.frames.first, project);
    final file = _collisionFreeFile(targetDir, project.name, 'png');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  final dir = _collisionFreeDir(targetDir, project.name);
  await dir.create(recursive: true);
  for (var i = 0; i < project.frames.length; i++) {
    final bytes = _encodeFramePng(project.frames[i], project);
    await File('${dir.path}/${_frameFileName(i)}').writeAsBytes(bytes);
  }
  return dir.path;
}

Uint8List _encodeFramePng(Frame frame, Project project) => encodePixelsToPng(
      frame.flattenDrawingLayers(project.width, project.height),
      project.width,
      project.height,
    );

// ── 이미지 + 마스크 쌍 ─────────────────────────────────────────
//
// `<프로젝트 이름>/images/frame_0001.png` + `masks/frame_0001.png` 쌍과
// 클래스 매핑을 담은 `label_classes.json`으로 구성된 ML 데이터셋 레이아웃.

Future<String> _exportMaskPairs(
  Project project,
  String targetDir, {
  required bool indexed,
  required double debugOverlayOpacity,
}) async {
  final dir = _collisionFreeDir(targetDir, project.name);
  final imagesDir = Directory('${dir.path}/images');
  final masksDir = Directory('${dir.path}/masks');
  final debugDir = Directory('${dir.path}/debug');
  await imagesDir.create(recursive: true);
  await masksDir.create(recursive: true);
  await debugDir.create(recursive: true);

  for (var i = 0; i < project.frames.length; i++) {
    final frame = project.frames[i];
    final fileName = _frameFileName(i);

    final pixels = frame.flattenDrawingLayers(project.width, project.height);
    final imageBytes = encodePixelsToPng(pixels, project.width, project.height);
    await File('${imagesDir.path}/$fileName').writeAsBytes(imageBytes);

    final labelIds = _flattenSegmentationLayers(frame, project.width, project.height);
    final maskBytes = indexed
        ? encodeIndexedMaskPng(labelIds, project.width, project.height)
        : encodeColorMaskPng(labelIds, project.labelClasses, project.width, project.height);
    await File('${masksDir.path}/$fileName').writeAsBytes(maskBytes);

    // 디버깅용: 픽셀 그림 위에 레이블 색상을 캔버스와 동일한 투명도로 겹쳐 그린 미리보기
    final debugBytes = encodeDebugOverlayPng(pixels, labelIds,
        project.labelClasses, project.width, project.height, debugOverlayOpacity);
    await File('${debugDir.path}/$fileName').writeAsBytes(debugBytes);
  }

  await File('${dir.path}/label_classes.json')
      .writeAsString(encodeLabelClassesJson(project.labelClasses));

  return dir.path;
}

/// 프레임의 모든 세그멘테이션 레이어를 아래→위 순서로 병합한 플랫 레이블 맵.
List<List<int?>> _flattenSegmentationLayers(Frame frame, int width, int height) {
  final result = List.generate(height, (_) => List<int?>.filled(width, null));
  for (final layer in frame.layers) {
    if (!layer.isVisible) continue;
    if (layer case SegmentationLayer sl) {
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final id = sl.labelIds[y][x];
          if (id != null) result[y][x] = id;
        }
      }
    }
  }
  return result;
}

// ── 파일명 / 충돌 처리 ─────────────────────────────────────────

String _frameFileName(int index) =>
    'frame_${(index + 1).toString().padLeft(4, '0')}.png';

Directory _collisionFreeDir(String parentDir, String name) {
  var dir = Directory('$parentDir/$name');
  for (var i = 1; dir.existsSync(); i++) {
    dir = Directory('$parentDir/$name ($i)');
  }
  return dir;
}

File _collisionFreeFile(String parentDir, String baseName, String ext) {
  var file = File('$parentDir/$baseName.$ext');
  for (var i = 1; file.existsSync(); i++) {
    file = File('$parentDir/$baseName ($i).$ext');
  }
  return file;
}
