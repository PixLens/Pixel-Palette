import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:pixel_lens/core/storage/color_hex.dart';
import 'package:pixel_lens/core/storage/home_directory.dart';
import 'package:pixel_lens/features/canvas/data/export/mask_pair_export.dart';
import 'package:pixel_lens/features/canvas/data/export/png_export.dart';
import 'package:pixel_lens/features/canvas/data/frame.dart';
import 'package:pixel_lens/features/canvas/data/import/image_import.dart';
import 'package:pixel_lens/features/canvas/data/layer.dart';
import 'package:pixel_lens/features/labeling/data/label_set_json.dart';
import 'package:pixel_lens/features/project/data/workspace_asset.dart';
import 'package:pixel_lens/features/project/data/workspace_project.dart';

/// 프로젝트 데이터를 디스크에 저장/로드하고, Finder(또는 OS 파일 탐색기)에서
/// 해당 경로를 열어주는 기능을 담당한다.
///
/// 저장 형식:
/// ```
/// ~/Documents/PixelLens/<프로젝트 폴더>/
///   project.json              프로젝트/라벨셋/팔레트/에셋 메타데이터
///   assets/<assetId>/
///     frame_0001.png ...      에셋 프레임 (드로잉 레이어 합성)
///     masks/frame_0001.png .. 세그멘테이션 레이어 (인덱스 마스크, 있을 때만)
/// ```

// ── 경로 ──────────────────────────────────────────────────────

/// 테스트에서 저장 루트를 임시 디렉터리로 바꿔치기하기 위한 오버라이드.
@visibleForTesting
String? debugPixelLensRoot;

/// `~/Documents/PixelLens` 루트 디렉터리. 없으면 생성한다.
Future<Directory> pixelLensRootDir() =>
    documentsSubDir('PixelLens', override: debugPixelLensRoot);

String _sanitize(String name) {
  final cleaned = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  return cleaned.isEmpty ? 'Untitled' : cleaned;
}

/// 새 프로젝트의 저장 폴더 경로를 만든다. 동일한 이름이 있으면 ` (1)`, ` (2)`...를 붙인다.
Future<String> createProjectStoragePath(String projectName) async {
  final root = await pixelLensRootDir();
  final base = _sanitize(projectName);
  var dir = Directory('${root.path}/$base');
  for (var i = 1; await dir.exists(); i++) {
    dir = Directory('${root.path}/$base ($i)');
  }
  await dir.create(recursive: true);
  return dir.path;
}

String _frameFileName(int index) =>
    'frame_${(index + 1).toString().padLeft(4, '0')}.png';

// ── 저장 ──────────────────────────────────────────────────────

/// 프로젝트별 저장 작업을 순서대로 직렬화하기 위한 큐.
/// (state가 빠르게 연속 변경될 때 디스크 쓰기 순서가 뒤바뀌어
/// 오래된 내용이 마지막에 남는 것을 방지한다)
final Map<String, Future<void>> _saveQueues = {};

/// [project]를 디스크에 저장한다. 같은 프로젝트에 대한 이전 저장이
/// 끝난 뒤에 실행되도록 순서를 보장한다 (fire-and-forget 호출용).
Future<void> queueSaveProjectToDisk(WorkspaceProject project) {
  final previous = _saveQueues[project.id] ?? Future.value();
  final next = previous
      .then((_) => saveProjectToDisk(project))
      .catchError((_) {});
  _saveQueues[project.id] = next;
  return next;
}

/// [project]를 `<storagePath>/project.json` + 에셋별 PNG로 저장한다.
Future<void> saveProjectToDisk(WorkspaceProject project) async {
  final dir = Directory(project.storagePath);
  await dir.create(recursive: true);

  final json = {
    'id': project.id,
    'name': project.name,
    'description': project.description,
    'width': project.width,
    'height': project.height,
    'activeLabelSetId': project.activeLabelSetId,
    'labelSets': project.labelSets.map(labelSetToJson).toList(),
    'palette': project.palette.map(colorToHex).toList(),
    'createdAt': project.createdAt.toIso8601String(),
    'modifiedAt': project.modifiedAt.toIso8601String(),
    'isFavorite': project.isFavorite,
    'assets': project.assets.map(_assetMetaToJson).toList(),
  };
  await File('${dir.path}/project.json')
      .writeAsString(const JsonEncoder.withIndent('  ').convert(json));

  final assetsDir = Directory('${dir.path}/assets');
  for (final asset in project.assets) {
    await _saveAssetFrames(assetsDir, asset, project);
  }
}

Future<void> _saveAssetFrames(
  Directory assetsDir,
  WorkspaceAsset asset,
  WorkspaceProject project,
) async {
  final assetDir = Directory('${assetsDir.path}/${asset.id}');
  // 프레임 수가 줄어든 경우 등 이전 출력물이 남지 않도록 매번 새로 쓴다.
  if (await assetDir.exists()) await assetDir.delete(recursive: true);
  await assetDir.create(recursive: true);

  final w = asset.width ?? project.width;
  final h = asset.height ?? project.height;

  Directory? masksDir;
  Directory? debugDir;
  for (var i = 0; i < asset.frames.length; i++) {
    final frame = asset.frames[i];
    final fileName = _frameFileName(i);

    final pixels = frame.flattenDrawingLayers(w, h);
    final bytes = encodePixelsToPng(pixels, w, h);
    await File('${assetDir.path}/$fileName').writeAsBytes(bytes);

    final segLayers = frame.layers.whereType<SegmentationLayer>();
    if (segLayers.isNotEmpty) {
      final labelIds = _flattenSegmentationLayers(frame, w, h);
      final maskBytes = encodeIndexedMaskPng(labelIds, w, h);
      masksDir ??= Directory('${assetDir.path}/masks')
        ..createSync(recursive: true);
      await File('${masksDir.path}/$fileName').writeAsBytes(maskBytes);

      // 디버깅용: 픽셀 그림 위에 레이블 색상을 겹쳐 그린 미리보기
      final debugBytes = encodeDebugOverlayPng(
          pixels, labelIds, project.activeLabelSet.labels, w, h, 0.5);
      debugDir ??= Directory('${assetDir.path}/debug')
        ..createSync(recursive: true);
      await File('${debugDir.path}/$fileName').writeAsBytes(debugBytes);
    }
  }
}

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

/// 프로젝트를 디스크에서 더 이상 불러오지 않도록 `project.json`만 제거한다.
/// (에셋 PNG 등 나머지 파일은 보존되어 사용자가 직접 복구/정리할 수 있다)
Future<void> forgetProjectOnDisk(WorkspaceProject project) async {
  final file = File('${project.storagePath}/project.json');
  if (await file.exists()) await file.delete();
}

// ── 로드 ──────────────────────────────────────────────────────

/// `~/Documents/PixelLens` 아래의 모든 프로젝트 폴더를 스캔해 불러온다.
/// `project.json`이 없거나 읽기에 실패한 폴더는 건너뛴다.
Future<List<WorkspaceProject>> loadAllProjectsFromDisk() async {
  final root = await pixelLensRootDir();
  final result = <WorkspaceProject>[];
  await for (final entry in root.list()) {
    if (entry is! Directory) continue;
    final projectFile = File('${entry.path}/project.json');
    if (!await projectFile.exists()) continue;
    try {
      result.add(await _loadProject(entry.path, projectFile));
    } catch (_) {
      // 손상된 프로젝트 폴더는 건너뛴다.
    }
  }
  return result;
}

Future<WorkspaceProject> _loadProject(String dirPath, File projectFile) async {
  final json = jsonDecode(await projectFile.readAsString()) as Map<String, dynamic>;
  final width = json['width'] as int;
  final height = json['height'] as int;
  final labelSets = (json['labelSets'] as List)
      .map((e) => labelSetFromJson(e as Map<String, dynamic>))
      .toList();
  final palette = (json['palette'] as List)
      .map((e) => colorFromHex(e as String))
      .toList();

  final assets = <WorkspaceAsset>[];
  for (final entry in (json['assets'] as List? ?? const [])) {
    assets.add(await _loadAsset(
        dirPath, entry as Map<String, dynamic>, width, height));
  }

  return WorkspaceProject(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    storagePath: dirPath,
    width: width,
    height: height,
    assets: assets,
    labelSets: labelSets,
    activeLabelSetId: json['activeLabelSetId'] as int,
    palette: palette,
    createdAt: DateTime.parse(json['createdAt'] as String),
    modifiedAt: DateTime.parse(json['modifiedAt'] as String),
    isFavorite: json['isFavorite'] as bool? ?? false,
  );
}

Future<WorkspaceAsset> _loadAsset(
  String projectDir,
  Map<String, dynamic> json,
  int projectWidth,
  int projectHeight,
) async {
  final id = json['id'] as String;
  final assetDir = Directory('$projectDir/assets/$id');
  final frameCount = json['frameCount'] as int? ?? 1;
  final durations = (json['frameDurations'] as List?)?.cast<int>() ?? const [];
  final labels = (json['frameLabels'] as List?) ?? const [];

  final frames = <Frame>[];
  for (var i = 0; i < frameCount; i++) {
    frames.add(await _loadFrame(
      assetDir,
      i,
      projectWidth,
      projectHeight,
      durationMs: i < durations.length ? durations[i] : 100,
      label: i < labels.length ? labels[i] as String? : null,
    ));
  }

  return WorkspaceAsset(
    id: id,
    name: json['name'] as String,
    tags: (json['tags'] as List?)?.cast<String>() ?? const [],
    description: json['description'] as String? ?? '',
    frames: frames,
    createdAt: DateTime.parse(json['createdAt'] as String),
    modifiedAt: DateTime.parse(json['modifiedAt'] as String),
    isFavorite: json['isFavorite'] as bool? ?? false,
  );
}

Future<Frame> _loadFrame(
  Directory assetDir,
  int index,
  int fallbackWidth,
  int fallbackHeight, {
  required int durationMs,
  String? label,
}) async {
  final fileName = _frameFileName(index);
  final pngFile = File('${assetDir.path}/$fileName');

  List<List<Color?>> pixels;
  int w = fallbackWidth;
  int h = fallbackHeight;
  if (await pngFile.exists()) {
    final decoded = decodeImagePixels(await pngFile.readAsBytes());
    if (decoded != null) {
      pixels = decoded.pixels;
      w = decoded.width;
      h = decoded.height;
    } else {
      pixels = List.generate(h, (_) => List<Color?>.filled(w, null));
    }
  } else {
    pixels = List.generate(h, (_) => List<Color?>.filled(w, null));
  }

  final layers = <Layer>[DrawingLayer(name: 'Layer 1', pixels: pixels)];

  final maskFile = File('${assetDir.path}/masks/$fileName');
  if (await maskFile.exists()) {
    final decoded = img.decodeImage(await maskFile.readAsBytes());
    if (decoded != null) {
      final labelIds = List.generate(
        h,
        (y) => List<int?>.generate(w, (x) {
          final value = decoded.getPixel(x, y).r.toInt();
          return value == 0 ? null : value;
        }),
      );
      layers.add(SegmentationLayer(name: 'Seg', labelIds: labelIds));
    }
  }

  return Frame(layers: layers, durationMs: durationMs, label: label);
}

// ── JSON 변환 ─────────────────────────────────────────────────

Map<String, dynamic> _assetMetaToJson(WorkspaceAsset a) => {
      'id': a.id,
      'name': a.name,
      'tags': a.tags,
      'description': a.description,
      'frameCount': a.frameCount,
      'frameDurations': a.frames.map((f) => f.durationMs).toList(),
      'frameLabels': a.frames.map((f) => f.label).toList(),
      'createdAt': a.createdAt.toIso8601String(),
      'modifiedAt': a.modifiedAt.toIso8601String(),
      'isFavorite': a.isFavorite,
    };


// ── Finder / 파일 탐색기 ─────────────────────────────────────────

/// [path]를 Finder(macOS) / 탐색기(Windows) / 파일 관리자(Linux)에서 연다.
/// 파일이면 해당 항목을 선택한 채로, 폴더면 그 폴더를 연다.
Future<void> revealInFileExplorer(String path) async {
  final isDir = await FileSystemEntity.isDirectory(path);
  if (Platform.isMacOS) {
    await Process.run('open', isDir ? [path] : ['-R', path]);
  } else if (Platform.isWindows) {
    await Process.run('explorer', [isDir ? path : '/select,$path']);
  } else if (Platform.isLinux) {
    final target = isDir ? path : File(path).parent.path;
    await Process.run('xdg-open', [target]);
  }
}
