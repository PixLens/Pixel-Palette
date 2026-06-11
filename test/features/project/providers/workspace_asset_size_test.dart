import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_lens/core/storage/global_presets_storage.dart';
import 'package:pixel_lens/features/canvas/data/import/image_import.dart';
import 'package:pixel_lens/features/project/data/project_storage.dart';
import 'package:pixel_lens/features/project/providers/project_provider.dart';
import 'package:pixel_lens/features/project/providers/workspace_provider.dart';

void main() {
  late Directory tempRoot;
  late Directory tempPaletteRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('pixel_lens_storage_test_');
    debugPixelLensRoot = tempRoot.path;
    tempPaletteRoot =
        await Directory.systemTemp.createTemp('pixel_palette_storage_test_');
    debugPixelPaletteRoot = tempPaletteRoot.path;
  });

  tearDown(() async {
    debugPixelLensRoot = null;
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
    debugPixelPaletteRoot = null;
    if (await tempPaletteRoot.exists()) {
      await tempPaletteRoot.delete(recursive: true);
    }
  });

  test('서로 다른 크기의 이미지를 저장한 후 에셋 목록에 표시되는 크기가 실제 픽셀 크기와 일치해야 한다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // 1. 64x64 기본 프로젝트 생성
    await container
        .read(workspaceProvider.notifier)
        .newProject(width: 64, height: 64);
    final projectId = container.read(workspaceProvider).projects.first.id;

    // 2. 새 에셋 생성 (64x64 프레임으로 시작) 후 캔버스에서 열기
    final assetId =
        container.read(workspaceProvider.notifier).newAsset(projectId);
    expect(assetId, isNotNull);

    // 3. Character_1.png(32x32)를 디코딩해서 활성 프레임에 불러오기
    //    (importImageIntoActiveFrame 은 캔버스 크기를 이미지 크기로 resize 한다)
    final bytes = await File('data/Character_1.png').readAsBytes();
    final decoded = decodeImagePixels(bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 32);
    expect(decoded.height, 32);

    container.read(projectProvider.notifier).importImageIntoActiveFrame(
          layerName: 'Character_1',
          imageWidth: decoded.width,
          imageHeight: decoded.height,
          pixels: decoded.pixels,
        );

    // 캔버스(편집 중인 Project) 크기는 32x32로 바뀐다
    final editedProject = container.read(projectProvider);
    expect(editedProject.width, 32);
    expect(editedProject.height, 32);

    // 4. 저장
    container.read(workspaceProvider.notifier).saveCurrentAsset(close: true);

    // 5. 에셋 목록에서 보여지는 값들 확인
    final wp = container.read(workspaceProvider).findProject(projectId)!;
    final asset = wp.findAsset(assetId!)!;

    final savedFrame = asset.firstFrame!;
    final savedDrawing = asset.firstDrawingLayer!;
    final actualWidth = savedDrawing.pixels.first.length;
    final actualHeight = savedDrawing.pixels.length;

    // 실제로 저장된 프레임의 픽셀 크기는 32x32 (가져온 이미지 크기)
    expect(actualWidth, 32);
    expect(actualHeight, 32);
    expect(savedFrame, isNotNull);

    // 워크스페이스 프로젝트의 기본 크기는 여전히 생성 당시의 64x64 (프로젝트 전역 기본값)
    expect(wp.width, 64);
    expect(wp.height, 64);
    expect(wp.sizeLabel, '64x64');

    // 그러나 에셋 자체는 실제 픽셀 크기(32x32)를 알고 있으므로,
    // 에셋 목록/상세 패널은 이 값을 사용해 실제 에셋과 동일한 크기를 표시해야 한다
    expect(asset.width, actualWidth);
    expect(asset.height, actualHeight);
    expect('${asset.width}x${asset.height}', '${actualWidth}x$actualHeight');

    // 6. 다시 에셋을 열면(assetToProject) 캔버스 크기도 실제 저장된 크기(32x32)와 일치해야 한다
    container.read(workspaceProvider.notifier).openAsset(projectId, assetId);
    final reopened = container.read(projectProvider);
    expect(reopened.width, actualWidth);
    expect(reopened.height, actualHeight);

    // 저장된 파일 IO가 끝날 때까지 대기 (saveProjectToDisk는 fire-and-forget으로 호출됨)
    await Future.delayed(const Duration(milliseconds: 200));

    // 7. 디스크에 실제 파일이 생성되었는지 확인
    final projectJson = File('${wp.storagePath}/project.json');
    final framePng =
        File('${wp.storagePath}/assets/$assetId/frame_0001.png');
    expect(await projectJson.exists(), isTrue);
    expect(await framePng.exists(), isTrue);

    // 8. 디스크에서 다시 불러왔을 때도 동일한 32x32 크기로 복원되어야 한다
    final reloaded = await loadAllProjectsFromDisk();
    final reloadedProject = reloaded.firstWhere((p) => p.id == projectId);
    final reloadedAsset = reloadedProject.findAsset(assetId)!;
    expect(reloadedAsset.width, actualWidth);
    expect(reloadedAsset.height, actualHeight);
  });
}
