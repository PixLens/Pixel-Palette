import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_lens/features/canvas/providers/tool_provider.dart';

class CanvasToolbar extends ConsumerWidget {
  const CanvasToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tool = ref.watch(toolProvider);

    final drawingTools = tool.mode == EditorMode.pixel
        ? [AppTool.pen, AppTool.eraser, AppTool.eyedropper, AppTool.grab]
        : [
            AppTool.annotate,
            AppTool.labelEraser,
            AppTool.labelFill,
            AppTool.labelEyedropper
          ];

    return Container(
      width: 80,
      color: const Color(0xFF13151F),
      child: Column(
        children: [
          const SizedBox(height: 12),
          ...drawingTools.map(
              (t) => _ToolButton(tool: t, selected: tool.currentTool == t)),
          const Spacer(),
          _ColorSwatches(fg: tool.currentColor, bg: tool.backgroundColor),
          const SizedBox(height: 8),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz, color: Colors.white38, size: 20),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ToolButton extends ConsumerStatefulWidget {
  final AppTool tool;
  final bool selected;
  const _ToolButton({required this.tool, required this.selected});

  @override
  ConsumerState<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends ConsumerState<_ToolButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;

    Color bgColor;
    if (selected) {
      bgColor = const Color(0xFF6D28D9).withValues(alpha: 0.3);
    } else if (_hovered) {
      bgColor = const Color(0xFF6D28D9).withValues(alpha: 0.1);
    } else {
      bgColor = Colors.transparent;
    }

    return Tooltip(
      message: widget.tool.label,
      preferBelow: false,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => ref.read(toolProvider.notifier).selectTool(widget.tool),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border(
                left: BorderSide(
                  color:
                      selected ? const Color(0xFF7C3AED) : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.tool.icon,
                    color: selected ? const Color(0xFFDDD6FE) : Colors.white54,
                    size: 22),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.tool.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: selected ? const Color(0xFFDDD6FE) : Colors.white38,
                      ),
                    ),
                    if (widget.tool.shortcut != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        widget.tool.shortcut!,
                        style: TextStyle(
                          fontSize: 10,
                          color: selected
                              ? const Color(0xFFDDD6FE).withValues(alpha: 0.6)
                              : Colors.white24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorSwatches extends ConsumerWidget {
  final Color fg;
  final Color bg;
  const _ColorSwatches({required this.fg, required this.bg});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        children: [
          // 배경색
          Positioned(
            right: 0,
            bottom: 0,
            child: _swatch(bg, () {}, isBack: true),
          ),
          // 전경색
          Positioned(
            left: 0,
            top: 0,
            child: _swatch(fg, () {}, isBack: false),
          ),
          // 교체 버튼
          Positioned(
            right: 2,
            top: 2,
            child: GestureDetector(
              onTap: () => ref.read(toolProvider.notifier).swapColors(),
              child:
                  const Icon(Icons.swap_horiz, size: 14, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _swatch(Color color, VoidCallback onTap, {required bool isBack}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(
              color: isBack ? Colors.white24 : Colors.white60,
              width: isBack ? 1 : 1.5,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
}
