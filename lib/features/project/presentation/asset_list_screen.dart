import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pixel_lens/features/project/data/project_storage.dart';
import 'package:pixel_lens/features/project/data/workspace_asset.dart';
import 'package:pixel_lens/features/project/data/workspace_project.dart';
import 'package:pixel_lens/features/project/presentation/widgets/pixel_thumbnail.dart';
import 'package:pixel_lens/features/project/presentation/widgets/workspace_sidebar.dart';
import 'package:pixel_lens/features/project/providers/workspace_provider.dart';
import 'package:pixel_lens/router/app_router.dart';

String _timeAgo(DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.inMinutes < 1) return '방금 전';
  if (d.inHours < 1) return '${d.inMinutes}분 전';
  if (d.inHours < 24) return '${d.inHours}시간 전';
  if (d.inDays == 1) return '어제';
  if (d.inDays < 30) return '${d.inDays}일 전';
  return '${(d.inDays / 30).round()}달 전';
}

String _formatDate(DateTime dt) =>
    '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';

String _formatDateTime(DateTime dt) =>
    '${_formatDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

/// 에셋의 실제 픽셀 크기를 우선 사용하고, 없으면 프로젝트 기본 크기로 대체한다.
String _assetSizeLabel(WorkspaceAsset asset, WorkspaceProject project) {
  final w = asset.width ?? project.width;
  final h = asset.height ?? project.height;
  return '${w}x$h';
}

// ── Screen ────────────────────────────────────────────────────

class AssetListScreen extends ConsumerStatefulWidget {
  final String projectId;
  const AssetListScreen({super.key, required this.projectId});

  @override
  ConsumerState<AssetListScreen> createState() => _AssetListScreenState();
}

class _AssetListScreenState extends ConsumerState<AssetListScreen> {
  WorkspaceAsset? _selected;
  String _query = '';
  String _type = '전체';
  String _tag = '전체';
  String _sort = '이름 (A-Z)';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wp = ref.read(workspaceProvider).findProject(widget.projectId);
      if (wp != null && wp.assets.isNotEmpty) {
        setState(() => _selected = wp.assets.first);
      }
    });
  }

  void _openAsset(WorkspaceAsset asset) {
    ref.read(workspaceProvider.notifier).openAsset(widget.projectId, asset.id);
    context.go(AppRoutes.assetPath(widget.projectId, asset.id));
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceProvider);
    final wp = workspace.findProject(widget.projectId);

    if (wp == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0F1A),
        body: Center(
            child: Text('프로젝트를 찾을 수 없습니다.',
                style: TextStyle(color: Colors.white54))),
      );
    }

    // keep selection in sync
    if (_selected != null) {
      final refreshed = wp.findAsset(_selected!.id);
      if (refreshed != null && refreshed != _selected) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => setState(() => _selected = refreshed));
      } else if (refreshed == null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => setState(() => _selected = null));
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      body: Row(
        children: [
          WorkspaceSidebar(
            isProjectContext: true,
            currentProject: wp,
            active: SidebarNavItem.assetList,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  project: wp,
                  onNewAsset: () {
                    final assetId =
                        ref.read(workspaceProvider.notifier).newAsset(wp.id);
                    if (assetId != null) {
                      context.go(AppRoutes.assetPath(wp.id, assetId));
                    }
                  },
                  onBack: () => context.go(AppRoutes.home),
                ),
                Expanded(
                  child: _AssetContent(
                    assets: wp.assets,
                    selected: _selected,
                    query: _query,
                    type: _type,
                    tag: _tag,
                    sort: _sort,
                    onSelect: (a) => setState(() => _selected = a),
                    onOpen: _openAsset,
                    onQueryChanged: (value) => setState(() => _query = value),
                    onTypeChanged: (value) => setState(() => _type = value),
                    onTagChanged: (value) => setState(() => _tag = value),
                    onSortChanged: (value) => setState(() => _sort = value),
                  ),
                ),
              ],
            ),
          ),
          if (_selected != null)
            _AssetDetailPanel(
              key: ValueKey(_selected!.id),
              asset: _selected!,
              project: wp,
              onOpen: () => _openAsset(_selected!),
              onDelete: () {
                _confirmDelete(wp, _selected!);
              },
              onRename: () => _renameAsset(wp, _selected!),
              onDuplicate: () => ref
                  .read(workspaceProvider.notifier)
                  .duplicateAsset(wp.id, _selected!.id),
              onToggleFavorite: () => ref
                  .read(workspaceProvider.notifier)
                  .toggleAssetFavorite(wp.id, _selected!.id),
            ),
        ],
      ),
    );
  }

  Future<void> _renameAsset(
      WorkspaceProject project, WorkspaceAsset asset) async {
    final controller = TextEditingController(text: asset.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D27),
        title: const Text('에셋 이름 변경',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: '에셋 이름'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('변경')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    ref
        .read(workspaceProvider.notifier)
        .renameAsset(project.id, asset.id, name);
  }

  Future<void> _confirmDelete(
      WorkspaceProject project, WorkspaceAsset asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D27),
        title: const Text('에셋 삭제',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Text('${asset.name} 에셋을 삭제할까요?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref.read(workspaceProvider.notifier).deleteAsset(project.id, asset.id);
    setState(() => _selected = null);
  }
}

// ── Top bar ───────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final WorkspaceProject project;
  final VoidCallback onNewAsset;
  final VoidCallback onBack;

  const _TopBar(
      {required this.project, required this.onNewAsset, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: const Color(0xFF13151F),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Breadcrumb
          GestureDetector(
            onTap: onBack,
            child: const Text('프로젝트',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ),
          const Icon(Icons.chevron_right, size: 16, color: Colors.white24),
          Text(project.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          // Import
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.upload_outlined, size: 15),
            label: const Text('에셋 가져오기', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Color(0xFF2D2F3E)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          // New asset
          FilledButton.icon(
            onPressed: onNewAsset,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('새 에셋', style: TextStyle(fontSize: 13)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6D28D9),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Asset content ─────────────────────────────────────────────

class _AssetContent extends StatelessWidget {
  final List<WorkspaceAsset> assets;
  final WorkspaceAsset? selected;
  final ValueChanged<WorkspaceAsset> onSelect;
  final ValueChanged<WorkspaceAsset> onOpen;
  final String query;
  final String type;
  final String tag;
  final String sort;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onTagChanged;
  final ValueChanged<String> onSortChanged;

  const _AssetContent({
    required this.assets,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
    required this.query,
    required this.type,
    required this.tag,
    required this.sort,
    required this.onQueryChanged,
    required this.onTypeChanged,
    required this.onTagChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tags = assets.expand((asset) => asset.tags).toSet().toList()..sort();
    final filtered = assets.where((asset) {
      final matchesQuery =
          asset.name.toLowerCase().contains(query.toLowerCase()) ||
              asset.tags.any(
                  (value) => value.toLowerCase().contains(query.toLowerCase()));
      final matchesType =
          type == '전체' || (type == 'Mask 포함' ? asset.hasMask : !asset.hasMask);
      final matchesTag = tag == '전체' || asset.tags.contains(tag);
      return matchesQuery && matchesType && matchesTag;
    }).toList()
      ..sort((a, b) => switch (sort) {
            '최근 수정' => b.modifiedAt.compareTo(a.modifiedAt),
            '프레임 많은 순' => b.frameCount.compareTo(a.frameCount),
            _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toolbar
        Container(
          color: const Color(0xFF0D0F1A),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          child: Row(
            children: [
              const Text('에셋 목록',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              _Badge(assets.length),
              const SizedBox(width: 20),
              Expanded(
                child: _SearchBox(
                  value: query,
                  onChanged: onQueryChanged,
                ),
              ),
              const SizedBox(width: 8),
              _FilterMenu(
                label: '타입',
                value: type,
                values: const ['전체', 'Pixel Art', 'Mask 포함'],
                onChanged: onTypeChanged,
              ),
              const SizedBox(width: 8),
              _FilterMenu(
                label: '태그',
                value: tag,
                values: ['전체', ...tags],
                onChanged: onTagChanged,
              ),
              const SizedBox(width: 8),
              _FilterMenu(
                label: '정렬',
                value: sort,
                values: const ['이름 (A-Z)', '최근 수정', '프레임 많은 순'],
                onChanged: onSortChanged,
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('조건에 맞는 에셋이 없습니다.',
                      style: TextStyle(color: Colors.white38)))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final a = filtered[i];
                    return _AssetCard(
                      asset: a,
                      isSelected: a.id == selected?.id,
                      onTap: () => onSelect(a),
                      onDoubleTap: () => onOpen(a),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge(this.count);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2F3E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$count',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      );
}

class _SearchBox extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _SearchBox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => TextFormField(
        initialValue: value,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
        decoration: InputDecoration(
          hintText: '에셋 검색...',
          hintStyle: const TextStyle(color: Colors.white30),
          prefixIcon: const Icon(Icons.search, size: 17, color: Colors.white30),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFF1A1D27),
          contentPadding: const EdgeInsets.symmetric(vertical: 9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFF2D2F3E)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFF2D2F3E)),
          ),
        ),
      );
}

class _FilterMenu extends StatelessWidget {
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  const _FilterMenu({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: const Color(0xFF1A1D27),
      onSelected: onChanged,
      itemBuilder: (_) => values
          .map((item) => PopupMenuItem(
                value: item,
                child: Text(item,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D27),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2D2F3E)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label: $value',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 14, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

// ── Asset card ────────────────────────────────────────────────

class _AssetCard extends StatelessWidget {
  final WorkspaceAsset asset;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const _AssetCard({
    required this.asset,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D27),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF6D28D9) : const Color(0xFF2D2F3E),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(9)),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: PixelThumbnail(asset: asset, size: double.infinity),
                  ),
                ),
                if (asset.isFavorite)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1D27).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(Icons.star,
                          size: 12, color: Color(0xFFFBBF24)),
                    ),
                  ),
                if (asset.hasMask)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6D28D9).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Mask',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asset.name,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text('${asset.frameCount} 프레임',
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 1),
                  Text('마지막 수정: ${_timeAgo(asset.modifiedAt)}',
                      style:
                          const TextStyle(color: Colors.white24, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Asset detail panel ────────────────────────────────────────

class _AssetDetailPanel extends StatelessWidget {
  final WorkspaceAsset asset;
  final WorkspaceProject project;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;

  const _AssetDetailPanel({
    super.key,
    required this.asset,
    required this.project,
    required this.onOpen,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.onRename,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      color: const Color(0xFF13151F),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: PixelThumbnail(asset: asset, size: double.infinity),
              ),
            ),
            const SizedBox(height: 14),
            // Name + star
            Row(
              children: [
                Expanded(
                  child: Text(asset.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
                GestureDetector(
                  onTap: onToggleFavorite,
                  child: Icon(
                    asset.isFavorite ? Icons.star : Icons.star_border,
                    size: 18,
                    color: asset.isFavorite
                        ? const Color(0xFFFBBF24)
                        : Colors.white38,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${asset.frameCount} 프레임  ·  ${asset.typeLabel}  ·  ${_assetSizeLabel(asset, project)}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            // Tags
            if (asset.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: asset.tags
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D2F3E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(t,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 14),
            // Open buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: FilledButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('열기', style: TextStyle(fontSize: 13)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6D28D9),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionBtn(
                    icon: Icons.edit_outlined, label: '이름 변경', onTap: onRename),
                _ActionBtn(
                    icon: Icons.copy_outlined, label: '복사', onTap: onDuplicate),
                _ActionBtn(
                    icon: Icons.folder_open_outlined,
                    label: 'Finder',
                    onTap: () => revealInFileExplorer(
                        '${project.storagePath}/assets/${asset.id}')),
                _ActionBtn(
                    icon: Icons.delete_outline,
                    label: '삭제',
                    onTap: onDelete,
                    danger: true),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            const _Label('정보'),
            const SizedBox(height: 10),
            _InfoTable(rows: [
              (
                '에셋 ID',
                asset.id.length > 12
                    ? '${asset.id.substring(0, 12)}...'
                    : asset.id
              ),
              ('생성일', _formatDate(asset.createdAt)),
              ('마지막 수정', _formatDateTime(asset.modifiedAt)),
              ('프레임 수', '${asset.frameCount}'),
              ('해상도', _assetSizeLabel(asset, project)),
              ('타입', asset.typeLabel),
              if (asset.description.isNotEmpty) ('설명', asset.description),
            ]),
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            Row(
              children: [
                const _Label('프레임 미리보기'),
                const Spacer(),
                Text('${asset.frameCount}개 프레임 전체 보기',
                    style: const TextStyle(
                        color: Color(0xFF7C3AED), fontSize: 11)),
              ],
            ),
            const SizedBox(height: 10),
            _FramePreviewStrip(asset: asset),
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            const _Label('구성'),
            const SizedBox(height: 10),
            _CompositionRow(
              icon: Icons.image_outlined,
              label: 'Pixel Art',
              count: asset.frameCount,
            ),
            if (asset.hasMask)
              _CompositionRow(
                icon: Icons.layers_outlined,
                label: 'Mask (선택)',
                count: asset.maskFrameCount,
              ),
          ],
        ),
      ),
    );
  }
}

class _FramePreviewStrip extends StatelessWidget {
  final WorkspaceAsset asset;
  const _FramePreviewStrip({required this.asset});

  @override
  Widget build(BuildContext context) {
    final count = asset.frameCount.clamp(0, 5);
    return SizedBox(
      height: 56,
      child: Row(
        children: List.generate(count, (i) {
          final frame = asset.frames[i];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D27),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: i == 0
                            ? const Color(0xFF6D28D9)
                            : const Color(0xFF2D2F3E)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: PixelThumbnail(
                      asset: WorkspaceAsset(
                        id: '${asset.id}_f$i',
                        name: '',
                        frames: [frame],
                        createdAt: asset.createdAt,
                        modifiedAt: asset.modifiedAt,
                      ),
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text((i + 1).toString().padLeft(4, '0'),
                    style: const TextStyle(color: Colors.white24, fontSize: 9)),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _CompositionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _CompositionRow(
      {required this.icon, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D27),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2D2F3E)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          Text('$count 파일',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, size: 14, color: Colors.white24),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.danger = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D27),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2D2F3E)),
            ),
            child: Icon(icon,
                size: 16,
                color: danger ? const Color(0xFFEF4444) : Colors.white54),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: danger ? const Color(0xFFEF4444) : Colors.white38,
                  fontSize: 10)),
        ],
      ),
    );
  }
}

class _InfoTable extends StatelessWidget {
  final List<(String, String)> rows;
  const _InfoTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rows
          .map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(r.$1,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ),
                    Expanded(
                      child: Text(r.$2,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                          textAlign: TextAlign.right),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600));
}
