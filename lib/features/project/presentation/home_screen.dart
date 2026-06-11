import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pixel_lens/features/project/data/project_storage.dart';
import 'package:pixel_lens/features/project/data/workspace_project.dart';
import 'package:pixel_lens/features/project/presentation/widgets/pixel_thumbnail.dart';
import 'package:pixel_lens/features/project/presentation/widgets/workspace_sidebar.dart';
import 'package:pixel_lens/features/project/providers/workspace_provider.dart';
import 'package:pixel_lens/router/app_router.dart';

// ── Utilities ─────────────────────────────────────────────────

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

// ── Screen ────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  WorkspaceProject? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final projects = ref.read(workspaceProvider).projects;
      if (projects.isNotEmpty) setState(() => _selected = projects.first);
    });
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceProvider);
    final projects = workspace.projects;

    // keep selection in sync after external changes
    if (_selected != null) {
      final refreshed = workspace.findProject(_selected!.id);
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
          const WorkspaceSidebar(active: SidebarNavItem.projectList),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  count: projects.length,
                  onNewProject: () =>
                      ref.read(workspaceProvider.notifier).newProject(),
                ),
                Expanded(
                  child: _ProjectContent(
                    projects: projects,
                    selected: _selected,
                    onSelect: (p) => setState(() => _selected = p),
                    onOpen: (p) => context.go(AppRoutes.projectPath(p.id)),
                  ),
                ),
              ],
            ),
          ),
          if (_selected != null)
            _ProjectDetailPanel(
              key: ValueKey(_selected!.id),
              project: _selected!,
              onOpen: () => context.go(AppRoutes.projectPath(_selected!.id)),
              onDelete: () {
                ref
                    .read(workspaceProvider.notifier)
                    .deleteProject(_selected!.id);
                setState(() => _selected = null);
              },
              onToggleFavorite: () => ref
                  .read(workspaceProvider.notifier)
                  .toggleProjectFavorite(_selected!.id),
            ),
        ],
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int count;
  final VoidCallback onNewProject;
  const _TopBar({required this.count, required this.onNewProject});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: const Color(0xFF13151F),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const Text('프로젝트',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          _CountBadge(count),
          const Spacer(),
          _SearchBox(),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onNewProject,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('새 프로젝트', style: TextStyle(fontSize: 13)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6D28D9),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge(this.count);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2F3E),
          borderRadius: BorderRadius.circular(10),
        ),
        child:
            Text('$count', style: const TextStyle(color: Colors.white54, fontSize: 12)),
      );
}

class _SearchBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 34,
      child: TextField(
        style: const TextStyle(color: Colors.white70, fontSize: 13),
        decoration: InputDecoration(
          hintText: '프로젝트 검색...',
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
          prefixIcon:
              const Icon(Icons.search, size: 16, color: Colors.white30),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 34),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          filled: true,
          fillColor: const Color(0xFF1A1D27),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2D2F3E))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2D2F3E))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF6D28D9))),
        ),
      ),
    );
  }
}

// ── Project content ───────────────────────────────────────────

class _ProjectContent extends StatelessWidget {
  final List<WorkspaceProject> projects;
  final WorkspaceProject? selected;
  final ValueChanged<WorkspaceProject> onSelect;
  final ValueChanged<WorkspaceProject> onOpen;

  const _ProjectContent({
    required this.projects,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final recent = ([...projects]
          ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt)))
        .take(4)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: [
        _SectionRow(
          title: '최근 프로젝트',
          subtitle: '최근 수정된 프로젝트',
          action: '전체 보기',
          onAction: () {},
        ),
        const SizedBox(height: 14),
        _ProjectGrid(
            projects: recent,
            selected: selected,
            onSelect: onSelect,
            onOpen: onOpen),
        const SizedBox(height: 32),
        _SectionRow(title: '모든 프로젝트', count: projects.length),
        const SizedBox(height: 14),
        _ProjectGrid(
            projects: projects,
            selected: selected,
            onSelect: onSelect,
            onOpen: onOpen),
      ],
    );
  }
}

class _SectionRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int? count;
  final String? action;
  final VoidCallback? onAction;

  const _SectionRow(
      {required this.title,
      this.subtitle,
      this.count,
      this.action,
      this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        if (subtitle != null) ...[
          const SizedBox(width: 12),
          Text(subtitle!,
              style: const TextStyle(color: Colors.white38, fontSize: 13)),
        ],
        if (count != null) ...[
          const SizedBox(width: 10),
          _CountBadge(count!),
        ],
        const Spacer(),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Row(children: [
              Text(action!,
                  style: const TextStyle(
                      color: Color(0xFF7C3AED), fontSize: 13)),
              const Icon(Icons.chevron_right,
                  size: 16, color: Color(0xFF7C3AED)),
            ]),
          ),
      ],
    );
  }
}

class _ProjectGrid extends StatelessWidget {
  final List<WorkspaceProject> projects;
  final WorkspaceProject? selected;
  final ValueChanged<WorkspaceProject> onSelect;
  final ValueChanged<WorkspaceProject> onOpen;

  const _ProjectGrid({
    required this.projects,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final cols = (c.maxWidth / 230).floor().clamp(1, 6);
      final itemW = (c.maxWidth - (cols - 1) * 14) / cols;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: projects
            .map((p) => SizedBox(
                  width: itemW,
                  child: _ProjectCard(
                    project: p,
                    isSelected: p.id == selected?.id,
                    onTap: () => onSelect(p),
                    onDoubleTap: () => onOpen(p),
                  ),
                ))
            .toList(),
      );
    });
  }
}

// ── Project card ──────────────────────────────────────────────

class _ProjectCard extends StatelessWidget {
  final WorkspaceProject project;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const _ProjectCard({
    required this.project,
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
            color: isSelected
                ? const Color(0xFF6D28D9)
                : const Color(0xFF2D2F3E),
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
                    height: 130,
                    width: double.infinity,
                    child: _ProjectThumb(project: project),
                  ),
                ),
                if (project.isFavorite)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1D27).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.star,
                          size: 13, color: Color(0xFFFBBF24)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                      '${project.assetCount} 에셋  ·  ${project.frameCount} 프레임',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(_timeAgo(project.modifiedAt),
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectThumb extends StatelessWidget {
  final WorkspaceProject project;
  const _ProjectThumb({required this.project});

  Color get _color {
    const palette = [
      Color(0xFF3B1F6E), Color(0xFF1A2F5A), Color(0xFF0A3D2E),
      Color(0xFF5A1414), Color(0xFF5A3A08), Color(0xFF1A1A5A),
    ];
    final hash = project.id.codeUnits.fold(0, (s, c) => s + c);
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final first = project.assets.isNotEmpty ? project.assets.first : null;
    if (first != null && first.firstDrawingLayer != null) {
      return PixelThumbnail(asset: first, size: double.infinity);
    }
    return ColoredBox(
      color: _color,
      child: Center(
        child: Text(
          project.name.isNotEmpty ? project.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 44,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Project detail panel ──────────────────────────────────────

class _ProjectDetailPanel extends StatelessWidget {
  final WorkspaceProject project;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  const _ProjectDetailPanel({
    super.key,
    required this.project,
    required this.onOpen,
    required this.onDelete,
    required this.onToggleFavorite,
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
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                  height: 80,
                  width: double.infinity,
                  child: _ProjectThumb(project: project)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(project.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
                GestureDetector(
                  onTap: onToggleFavorite,
                  child: Icon(
                    project.isFavorite ? Icons.star : Icons.star_border,
                    size: 18,
                    color: project.isFavorite
                        ? const Color(0xFFFBBF24)
                        : Colors.white38,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(project.storagePath,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('프로젝트 열기', style: TextStyle(fontSize: 13)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6D28D9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionBtn(icon: Icons.edit_outlined, label: '이름 변경', onTap: () {}),
                _ActionBtn(icon: Icons.copy_outlined, label: '복사', onTap: () {}),
                _ActionBtn(
                    icon: Icons.folder_open_outlined,
                    label: 'Finder',
                    onTap: () => revealInFileExplorer(project.storagePath)),
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
            const _Label('프로젝트 정보'),
            const SizedBox(height: 10),
            _InfoTable(rows: [
              ('생성일', _formatDate(project.createdAt)),
              ('최근 수정', _timeAgo(project.modifiedAt)),
              ('에셋 수', '${project.assetCount}'),
              ('프레임 수', '${project.frameCount}'),
              ('라벨 수', '${project.labelCount}'),
              ('이미지 크기', project.sizeLabel),
              ('총 파일 수', '${project.totalFileCount}'),
            ]),
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            const _Label('데이터셋 분할'),
            const SizedBox(height: 10),
            _DatasetSplitSection(frameCount: project.frameCount),
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            const _Label('라벨 통계'),
            const SizedBox(height: 10),
            _LabelStatsSection(project: project),
          ],
        ),
      ),
    );
  }
}

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

class _DatasetSplitSection extends StatelessWidget {
  final int frameCount;
  const _DatasetSplitSection({required this.frameCount});

  @override
  Widget build(BuildContext context) {
    final train = (frameCount * 0.8).round();
    final valid = (frameCount * 0.1).round();
    final test = frameCount - train - valid;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: const SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(
                    flex: 80,
                    child: ColoredBox(color: Color(0xFF3B82F6))),
                Expanded(
                    flex: 10,
                    child: ColoredBox(color: Color(0xFF14B8A6))),
                Expanded(
                    flex: 10,
                    child: ColoredBox(color: Color(0xFF22C55E))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _SplitRow(color: const Color(0xFF3B82F6), label: 'Train', count: train, pct: '80%'),
        _SplitRow(color: const Color(0xFF14B8A6), label: 'Valid', count: valid, pct: '10%'),
        _SplitRow(color: const Color(0xFF22C55E), label: 'Test', count: test, pct: '10%'),
      ],
    );
  }
}

class _SplitRow extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final String pct;
  const _SplitRow(
      {required this.color,
      required this.label,
      required this.count,
      required this.pct});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          SizedBox(
              width: 40,
              child: Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 12))),
          const Spacer(),
          Text('$pct  ($count)',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}

class _LabelStatsSection extends StatelessWidget {
  final WorkspaceProject project;
  const _LabelStatsSection({required this.project});

  @override
  Widget build(BuildContext context) {
    final labels = project.activeLabelSet.labels;
    if (labels.isEmpty) {
      return const Text('라벨 없음',
          style: TextStyle(color: Colors.white38, fontSize: 12));
    }
    const fakePcts = [9.7, 58.2, 32.1];
    return Column(
      children: labels.asMap().entries.map((e) {
        final lbl = e.value;
        final pct = e.key < fakePcts.length ? fakePcts[e.key] : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: lbl.color.a == 0 ? Colors.transparent : lbl.color,
                  shape: BoxShape.circle,
                  border: lbl.color.a == 0
                      ? Border.all(color: Colors.white24)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(lbl.name,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('${pct.toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        );
      }).toList(),
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
