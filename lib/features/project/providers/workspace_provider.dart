import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_lens/core/storage/global_presets_storage.dart';
import 'package:pixel_lens/features/canvas/data/frame.dart';
import 'package:pixel_lens/features/canvas/providers/editor_provider.dart';
import 'package:pixel_lens/features/project/data/project_storage.dart';
import 'package:pixel_lens/features/project/data/workspace_asset.dart';
import 'package:pixel_lens/features/project/data/workspace_project.dart';
import 'package:pixel_lens/features/project/providers/project_provider.dart';

// ── State ──────────────────────────────────────────────────────

class WorkspaceState {
  final List<WorkspaceProject> projects;
  final String? activeProjectId;
  final String? activeAssetId;

  const WorkspaceState({
    required this.projects,
    this.activeProjectId,
    this.activeAssetId,
  });

  WorkspaceProject? get activeProject {
    final id = activeProjectId;
    if (id == null) return null;
    try {
      return projects.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  WorkspaceProject? findProject(String id) {
    try {
      return projects.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  WorkspaceState copyWith({
    List<WorkspaceProject>? projects,
    String? activeProjectId,
    String? activeAssetId,
  }) =>
      WorkspaceState(
        projects: projects ?? this.projects,
        activeProjectId: activeProjectId ?? this.activeProjectId,
        activeAssetId: activeAssetId ?? this.activeAssetId,
      );

  WorkspaceState withActiveAsset(String projectId, String assetId) =>
      WorkspaceState(
          projects: projects,
          activeProjectId: projectId,
          activeAssetId: assetId);

  WorkspaceState clearActiveAsset() => WorkspaceState(
      projects: projects,
      activeProjectId: activeProjectId,
      activeAssetId: null);

  WorkspaceState _replaceProject(WorkspaceProject p) {
    queueSaveProjectToDisk(p);
    return copyWith(
      projects: [for (final x in projects) x.id == p.id ? p : x],
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────

class WorkspaceNotifier extends Notifier<WorkspaceState> {
  @override
  WorkspaceState build() {
    Future(_loadFromDisk);
    return const WorkspaceState(projects: []);
  }

  Future<void> _loadFromDisk() async {
    final loaded = await loadAllProjectsFromDisk();
    if (loaded.isEmpty) return;
    // 디스크 스캔이 끝나기 전에 사용자가 이미 프로젝트를 만들었거나
    // 수정했을 수 있으므로, 메모리에 없는 프로젝트만 추가한다
    // (전체를 디스크 결과로 교체하면 그 사이의 변경 사항이 사라진다).
    final existingIds = state.projects.map((p) => p.id).toSet();
    final toAdd = loaded.where((p) => !existingIds.contains(p.id)).toList();
    if (toAdd.isEmpty) return;
    state = state.copyWith(projects: [...state.projects, ...toAdd]);
  }

  // ── Project CRUD ─────────────────────────────────────────────

  Future<void> newProject({int width = 64, int height = 64}) async {
    final now = DateTime.now();
    final id = 'project_${now.millisecondsSinceEpoch}';
    final storagePath = await createProjectStoragePath('New Project');
    final globalLabelSets = await loadGlobalLabelSets();
    final project = WorkspaceProject(
      id: id,
      name: 'New Project',
      storagePath: storagePath,
      width: width,
      height: height,
      assets: const [],
      labelSets: globalLabelSets?.$1 ?? WorkspaceProject.defaultLabelSets(),
      activeLabelSetId: globalLabelSets?.$2 ?? 1,
      palette: WorkspaceProject.defaultPalette(),
      createdAt: now,
      modifiedAt: now,
    );
    state = state.copyWith(projects: [...state.projects, project]);
    await saveProjectToDisk(project);
  }

  void renameProject(String projectId, String name) {
    final p = state.findProject(projectId);
    if (p == null) return;
    state = state
        ._replaceProject(p.copyWith(name: name, modifiedAt: DateTime.now()));
  }

  void deleteProject(String projectId) {
    final p = state.findProject(projectId);
    if (p == null) return;
    forgetProjectOnDisk(p);
    state = state.copyWith(
      projects: state.projects.where((p) => p.id != projectId).toList(),
    );
  }

  void toggleProjectFavorite(String projectId) {
    final p = state.findProject(projectId);
    if (p == null) return;
    state = state._replaceProject(p.copyWith(isFavorite: !p.isFavorite));
  }

  // ── Asset CRUD ───────────────────────────────────────────────

  String? newAsset(String projectId) {
    final wp = state.findProject(projectId);
    if (wp == null) return null;
    final now = DateTime.now();
    final id = 'asset_${now.millisecondsSinceEpoch}';
    final asset = WorkspaceAsset(
      id: id,
      name: 'New Asset',
      frames: [Frame.initial(width: wp.width, height: wp.height)],
      createdAt: now,
      modifiedAt: now,
    );
    final updated = wp.addAsset(asset);
    state = state._replaceProject(updated);
    openAsset(projectId, id);
    return id;
  }

  void renameAsset(String projectId, String assetId, String name) {
    final wp = state.findProject(projectId);
    final a = wp?.findAsset(assetId);
    if (wp == null || a == null) return;
    state = state._replaceProject(
        wp.updateAsset(a.copyWith(name: name, modifiedAt: DateTime.now())));
  }

  void deleteAsset(String projectId, String assetId) {
    final wp = state.findProject(projectId);
    if (wp == null) return;
    state = state._replaceProject(wp.removeAsset(assetId));
  }

  void duplicateAsset(String projectId, String assetId) {
    final wp = state.findProject(projectId);
    final source = wp?.findAsset(assetId);
    if (wp == null || source == null) return;

    final now = DateTime.now();
    final copy = source.copyWith(
      id: 'asset_${now.microsecondsSinceEpoch}',
      name: '${source.name}_copy',
      createdAt: now,
      modifiedAt: now,
      isFavorite: false,
    );
    state = state._replaceProject(wp.addAsset(copy));
  }

  void toggleAssetFavorite(String projectId, String assetId) {
    final wp = state.findProject(projectId);
    final a = wp?.findAsset(assetId);
    if (wp == null || a == null) return;
    state = state
        ._replaceProject(wp.updateAsset(a.copyWith(isFavorite: !a.isFavorite)));
  }

  // ── Canvas Integration ───────────────────────────────────────

  void openAsset(String projectId, String assetId) {
    final wp = state.findProject(projectId);
    final asset = wp?.findAsset(assetId);
    if (wp == null || asset == null) return;

    final project = wp.assetToProject(asset);
    ref.read(projectProvider.notifier).setProject(project);
    ref.read(editorProvider.notifier).selectFrame(0);
    ref.read(editorProvider.notifier).selectLayer(0);
    state = state.withActiveAsset(projectId, assetId);
  }

  void saveCurrentAsset({bool close = false}) {
    final projectId = state.activeProjectId;
    final assetId = state.activeAssetId;
    if (projectId == null || assetId == null) return;

    final wp = state.findProject(projectId);
    final oldAsset = wp?.findAsset(assetId);
    if (wp == null || oldAsset == null) return;

    final canvasProject = ref.read(projectProvider);
    final updatedAsset = oldAsset.copyWith(
      name: canvasProject.name,
      frames: List.from(canvasProject.frames),
      modifiedAt: DateTime.now(),
    );
    final updatedProject = wp.updateAsset(updatedAsset).copyWith(
          labelSets: List.from(canvasProject.labelSets),
          activeLabelSetId: canvasProject.activeLabelSetId,
          palette: List.from(canvasProject.palette),
        );
    final updatedState = state._replaceProject(updatedProject);
    state = close ? updatedState.clearActiveAsset() : updatedState;
  }
}

// ── Provider ──────────────────────────────────────────────────

final workspaceProvider =
    NotifierProvider<WorkspaceNotifier, WorkspaceState>(WorkspaceNotifier.new);
