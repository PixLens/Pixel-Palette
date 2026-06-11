import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pixel_lens/features/canvas/presentation/widgets/canvas_area.dart';
import 'package:pixel_lens/features/canvas/presentation/widgets/canvas_toolbar.dart';
import 'package:pixel_lens/features/canvas/presentation/widgets/right_panel.dart';
import 'package:pixel_lens/features/canvas/presentation/widgets/seg_right_panel.dart';
import 'package:pixel_lens/features/canvas/presentation/widgets/timeline_bar.dart';
import 'package:pixel_lens/features/canvas/providers/tool_provider.dart';
import 'package:pixel_lens/features/project/providers/project_provider.dart';
import 'package:pixel_lens/features/project/providers/workspace_provider.dart';
import 'package:pixel_lens/router/app_router.dart';

class CanvasScreen extends ConsumerStatefulWidget {
  final String? projectId;
  final String? assetId;

  const CanvasScreen({super.key, this.projectId, this.assetId});

  @override
  ConsumerState<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends ConsumerState<CanvasScreen> {
  final _canvasAreaKey = GlobalKey<CanvasAreaState>();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final projectId = widget.projectId;
      final assetId = widget.assetId;
      if (projectId == null || assetId == null) return;

      final workspace = ref.read(workspaceProvider);
      if (workspace.activeProjectId != projectId ||
          workspace.activeAssetId != assetId) {
        ref.read(workspaceProvider.notifier).openAsset(projectId, assetId);
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }

    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext?.findAncestorStateOfType<EditableTextState>() != null) {
      return false;
    }

    final isCmdOrCtrl = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;

    // Undo / Redo: ⌘Z / ⌘⇧Z (Alt 조합 시에는 무시)
    if (isCmdOrCtrl &&
        !HardwareKeyboard.instance.isAltPressed &&
        event.logicalKey == LogicalKeyboardKey.keyZ) {
      final projectNotifier = ref.read(projectProvider.notifier);
      if (HardwareKeyboard.instance.isShiftPressed) {
        projectNotifier.redo();
      } else {
        projectNotifier.undo();
      }
      return true;
    }

    // 저장: ⌘S / Ctrl+S
    if (isCmdOrCtrl &&
        !HardwareKeyboard.instance.isAltPressed &&
        event.logicalKey == LogicalKeyboardKey.keyS) {
      ref.read(projectProvider.notifier).commitStroke();
      ref.read(workspaceProvider.notifier).saveCurrentAsset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('에셋을 저장했습니다.'),
          duration: Duration(seconds: 1),
        ),
      );
      return true;
    }

    // 그 외 Cmd / Ctrl / Alt 조합키는 무시
    if (isCmdOrCtrl || HardwareKeyboard.instance.isAltPressed) {
      return false;
    }

    final notifier = ref.read(toolProvider.notifier);
    switch (event.logicalKey) {
      // case LogicalKeyboardKey.digit1:
      // case LogicalKeyboardKey.numpad1:
      //   _canvasAreaKey.currentState?.fitToScreen();
      //   return true;
      case LogicalKeyboardKey.keyP:
        notifier.selectTool(
            ref.read(toolProvider).mode == EditorMode.segmentation
                ? AppTool.annotate
                : AppTool.pen);
        return true;
      case LogicalKeyboardKey.keyE:
        notifier.selectTool(
            ref.read(toolProvider).mode == EditorMode.segmentation
                ? AppTool.labelEraser
                : AppTool.eraser);
        return true;
      case LogicalKeyboardKey.keyS:
        notifier.selectTool(AppTool.eyedropper);
        return true;
      case LogicalKeyboardKey.keyG:
        notifier.selectTool(AppTool.grab);
        return true;
      case LogicalKeyboardKey.keyC:
        notifier.swapColors();
        return true;
      case LogicalKeyboardKey.equal:
      case LogicalKeyboardKey.numpadAdd:
        notifier.adjustBrushSize(1);
        return true;
      case LogicalKeyboardKey.minus:
      case LogicalKeyboardKey.numpadSubtract:
        notifier.adjustBrushSize(-1);
        return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07080F),
      body: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _TopBar(
                projectId: widget.projectId,
                assetId: widget.assetId,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: const CanvasToolbar(),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CanvasArea(key: _canvasAreaKey),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: const TimelineBar(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child:
                        ref.watch(toolProvider).mode == EditorMode.segmentation
                            ? const SegRightPanel()
                            : const RightPanel(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 상단 바 ───────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  final String? projectId;
  final String? assetId;

  const _TopBar({this.projectId, this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tool = ref.watch(toolProvider);
    final project = ref.watch(projectProvider);
    final isWorkspaceAsset = projectId != null && assetId != null;

    void saveAsset() {
      ref.read(projectProvider.notifier).commitStroke();
      ref.read(workspaceProvider.notifier).saveCurrentAsset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('에셋을 저장했습니다.'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    void closeAsset() {
      ref.read(projectProvider.notifier).commitStroke();
      ref.read(workspaceProvider.notifier).saveCurrentAsset(close: true);
      context.go(AppRoutes.projectPath(projectId!));
    }

    return Container(
      height: 48,
      color: const Color(0xFF1A1D27),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 앱 아이콘 + 이름
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.asset(
              'assets/images/ci_logo.png',
              width: 22,
              height: 22,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          if (isWorkspaceAsset) ...[
            _TopBarBtn(
              icon: Icons.arrow_back,
              tooltip: '에셋 목록으로',
              onTap: closeAsset,
            ),
            const SizedBox(width: 4),
          ],
          const Text(
            'PixelPalette',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            project.name,
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(width: 12),
          _CanvasSizeButton(width: project.width, height: project.height),
          const Spacer(),
          // 모드 토글
          _ModeToggle(
            mode: tool.mode,
            onChanged: (mode) =>
                ref.read(projectProvider.notifier).switchMode(mode),
          ),
          const Spacer(),

          // 액션 버튼들
          _TopBarBtn(
            icon: Icons.undo,
            tooltip: 'Undo (⌘Z)',
            onTap: () => ref.read(projectProvider.notifier).undo(),
          ),
          _TopBarBtn(
            icon: Icons.redo,
            tooltip: 'Redo (⌘⇧Z)',
            onTap: () => ref.read(projectProvider.notifier).redo(),
          ),
          const SizedBox(width: 8),
          _TopBarBtn(
            icon: Icons.save_outlined,
            tooltip: '저장',
            onTap: isWorkspaceAsset ? saveAsset : () {},
          ),
          _TopBarBtn(
            icon: Icons.folder_open,
            tooltip: 'Finder에서 열기',
            onTap: isWorkspaceAsset
                ? () => _openInFinder(ref, projectId!, assetId!)
                : () {},
          ),
        ],
      ),
    );
  }
}

/// 현재 에셋이 저장된 폴더를 Finder에서 연다.
void _openInFinder(WidgetRef ref, String projectId, String assetId) {
  final project = ref.read(workspaceProvider).findProject(projectId);
  if (project == null) return;
  final assetDir = '${project.storagePath}/assets/$assetId';
  Process.run('open', [assetDir]);
}

class _ModeToggle extends StatelessWidget {
  final EditorMode mode;
  final ValueChanged<EditorMode> onChanged;

  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFF0E1017),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeBtn(
            label: 'Pixel',
            icon: Icons.edit,
            active: mode == EditorMode.pixel,
            onTap: () => onChanged(EditorMode.pixel),
          ),
          _ModeBtn(
            label: 'Segmentation',
            icon: Icons.layers_outlined,
            active: mode == EditorMode.segmentation,
            onTap: () => onChanged(EditorMode.segmentation),
          ),
        ],
      ),
    );
  }
}

class _ModeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ModeBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6D28D9) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : Colors.white38),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white38,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }
}

class _TopBarBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TopBarBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18, color: Colors.white54),
        ),
      ),
    );
  }
}

// ── 캔버스 크기 조정 ──────────────────────────────────────────

class _CanvasSizeButton extends StatelessWidget {
  final int width;
  final int height;
  const _CanvasSizeButton({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '캔버스 크기 조정',
      child: GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) =>
              _ResizeCanvasDialog(initialWidth: width, initialHeight: height),
        ),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1017),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.aspect_ratio, size: 13, color: Colors.white38),
              const SizedBox(width: 6),
              Text('$width × $height',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResizeCanvasDialog extends ConsumerStatefulWidget {
  final int initialWidth;
  final int initialHeight;
  const _ResizeCanvasDialog(
      {required this.initialWidth, required this.initialHeight});

  @override
  ConsumerState<_ResizeCanvasDialog> createState() =>
      _ResizeCanvasDialogState();
}

class _ResizeCanvasDialogState extends ConsumerState<_ResizeCanvasDialog> {
  late final TextEditingController _widthCtrl =
      TextEditingController(text: '${widget.initialWidth}');
  late final TextEditingController _heightCtrl =
      TextEditingController(text: '${widget.initialHeight}');
  String? _error;

  @override
  void dispose() {
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final w = int.tryParse(_widthCtrl.text.trim());
    final h = int.tryParse(_heightCtrl.text.trim());
    if (w == null || h == null || w < 1 || h < 1 || w > 1024 || h > 1024) {
      setState(() => _error = '1 ~ 1024 사이의 값을 입력하세요');
      return;
    }
    ref.read(projectProvider.notifier).resize(w, h);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1D27),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('캔버스 크기 조정',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              '크기를 줄이면 가장자리 픽셀이 잘리고, 늘리면 빈 공간이 추가됩니다.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _SizeField(label: 'WIDTH', controller: _widthCtrl)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('×', style: TextStyle(color: Colors.white38)),
                ),
                Expanded(
                    child:
                        _SizeField(label: 'HEIGHT', controller: _heightCtrl)),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style:
                      const TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child:
                      const Text('취소', style: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _apply,
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6D28D9)),
                  child: const Text('적용'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _SizeField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white38, fontSize: 10, letterSpacing: 0.6)),
        const SizedBox(height: 6),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF1E2235),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(borderSide: BorderSide.none),
              suffixText: 'px',
              suffixStyle: TextStyle(color: Colors.white24, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}
