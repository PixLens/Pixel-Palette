import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pixel_lens/features/project/data/workspace_project.dart';
import 'package:pixel_lens/router/app_router.dart';

class WorkspaceSidebar extends StatelessWidget {
  final bool isProjectContext;
  final WorkspaceProject? currentProject;
  final SidebarNavItem active;

  const WorkspaceSidebar({
    super.key,
    this.isProjectContext = false,
    this.currentProject,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: const Color(0xFF13151F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: isProjectContext
                  ? _buildProjectNav(context)
                  : _buildHomeNav(context),
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          _buildStorageInfo(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.asset(
                  'assets/images/ci_logo.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6D28D9),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'PixelLens',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (isProjectContext) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => context.go(AppRoutes.home),
              child: const Row(
                children: [
                  Icon(Icons.chevron_left, size: 16, color: Colors.white38),
                  SizedBox(width: 4),
                  Text(
                    '프로젝트로 돌아가기',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHomeNav(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _NavSection(label: '프로젝트'),
        _NavTile(
          icon: Icons.folder_outlined,
          label: '프로젝트 목록',
          active: active == SidebarNavItem.projectList,
          onTap: () => context.go(AppRoutes.home),
        ),
        _NavTile(
          icon: Icons.star_outline,
          label: '즐겨찾기',
          active: active == SidebarNavItem.favorites,
          onTap: () {},
        ),
        _NavTile(
          icon: Icons.delete_outline,
          label: '휴지통',
          active: active == SidebarNavItem.trash,
          onTap: () {},
        ),
        const SizedBox(height: 8),
        const _NavSection(label: '관리'),
        _NavTile(
          icon: Icons.bar_chart_outlined,
          label: '데이터 통계',
          active: active == SidebarNavItem.dataStats,
          onTap: () {},
        ),
        _NavTile(
          icon: Icons.label_outline,
          label: '라벨 관리',
          active: active == SidebarNavItem.labelMgmt,
          onTap: () {},
        ),
        _NavTile(
          icon: Icons.download_outlined,
          label: '내보내기',
          active: active == SidebarNavItem.exportNav,
          onTap: () {},
        ),
        _NavTile(
          icon: Icons.settings_outlined,
          label: '설정',
          active: active == SidebarNavItem.settings,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildProjectNav(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currentProject != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D27),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder, size: 16, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentProject!.name,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (currentProject!.isFavorite)
                    const Icon(Icons.star, size: 12, color: Color(0xFFFBBF24)),
                ],
              ),
            ),
          ),
        _NavTile(
          icon: Icons.grid_view_outlined,
          label: '에셋 목록',
          active: active == SidebarNavItem.assetList,
          onTap: currentProject != null
              ? () => context.go(AppRoutes.projectPath(currentProject!.id))
              : null,
        ),
        _NavTile(
          icon: Icons.bar_chart_outlined,
          label: '데이터 통계',
          active: active == SidebarNavItem.dataStats,
          onTap: () {},
        ),
        _NavTile(
          icon: Icons.label_outline,
          label: '라벨 관리',
          active: active == SidebarNavItem.labelMgmt,
          onTap: () {},
        ),
        _NavTile(
          icon: Icons.download_outlined,
          label: '내보내기',
          active: active == SidebarNavItem.exportNav,
          onTap: () {},
        ),
        _NavTile(
          icon: Icons.settings_outlined,
          label: '설정',
          active: active == SidebarNavItem.settings,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildStorageInfo() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.folder_open_outlined, size: 14, color: Colors.white38),
              SizedBox(width: 6),
              Text('저장 위치',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '~/Documents/PixelLens',
            style: TextStyle(color: Colors.white54, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          const Text('128.4 GB / 500 GB 사용 중',
              style: TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: const LinearProgressIndicator(
              value: 128.4 / 500,
              minHeight: 4,
              backgroundColor: Color(0xFF2D2F3E),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6D28D9)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 28,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white12),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Finder에서 보기',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

enum SidebarNavItem {
  projectList,
  favorites,
  trash,
  dataStats,
  labelMgmt,
  exportNav,
  settings,
  assetList
}

class _NavSection extends StatelessWidget {
  final String label;
  const _NavSection({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5)),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _NavTile(
      {required this.icon,
      required this.label,
      required this.active,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF6D28D9).withValues(alpha: 0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: active ? const Color(0xFF7C3AED) : Colors.white38),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white60,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Public alias ──────────────────────────────────────────────
// Re-export the SidebarNavItem enum under a public name for use in screens
typedef WorkspaceSidebarNavItem = SidebarNavItem;
