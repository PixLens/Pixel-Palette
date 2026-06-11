import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_lens/features/canvas/presentation/widgets/canvas_viewport.dart';
import 'package:pixel_lens/features/canvas/providers/editor_provider.dart';
import 'package:pixel_lens/features/project/providers/project_provider.dart';

class TimelineBar extends ConsumerStatefulWidget {
  const TimelineBar({super.key});

  @override
  ConsumerState<TimelineBar> createState() => _TimelineBarState();
}

class _TimelineBarState extends ConsumerState<TimelineBar> {
  bool _showOnionSkin = false;
  int _fps = 12;
  final ScrollController _scroll = ScrollController();

  static const _fpsOptions = [1, 2, 4, 6, 8, 12, 15, 24, 30];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider);
    final editor  = ref.watch(editorProvider);
    final editorNotifier   = ref.read(editorProvider.notifier);
    final projectNotifier  = ref.read(projectProvider.notifier);

    return Container(
      height: 120,
      color: const Color(0xFF13151F),
      child: Column(
        children: [
          // ── 헤더 ──────────────────────────────────────────────
          Container(
            height: 36,
            color: const Color(0xFF1A1D27),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Text('Timeline',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                // FPS 드롭다운
                _FpsDropdown(
                  fps: _fps,
                  options: _fpsOptions,
                  onChanged: (v) => setState(() => _fps = v),
                ),
                const SizedBox(width: 12),
                // 재생 버튼
                _PlayButton(icon: Icons.skip_previous, onTap: () => editorNotifier.selectFrame(0)),
                _PlayButton(icon: Icons.play_arrow, onTap: () {}),
                _PlayButton(icon: Icons.skip_next, onTap: () => editorNotifier.selectFrame(project.frames.length - 1)),
                const SizedBox(width: 12),
                // 어니언 스킨
                GestureDetector(
                  onTap: () => setState(() => _showOnionSkin = !_showOnionSkin),
                  child: Row(
                    children: [
                      Icon(
                        _showOnionSkin ? Icons.check_box : Icons.check_box_outline_blank,
                        size: 14,
                        color: Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      const Text('Show Onion Skin',
                          style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                const Spacer(),
                // 프레임 추가
                TextButton.icon(
                  onPressed: projectNotifier.addFrame,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add Frame', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white54,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ],
            ),
          ),

          // ── 프레임 썸네일 ───────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              itemCount: project.frames.length,
              itemBuilder: (context, i) {
                final frame  = project.frames[i];
                final isActive = i == editor.activeFrameIndex;
                final pixels = frame.flattenDrawingLayers(project.width, project.height);

                return GestureDetector(
                  onTap: () => editorNotifier.selectFrame(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 72,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFF7C3AED)
                            : Colors.white12,
                        width: isActive ? 2 : 1,
                      ),
                      color: const Color(0xFF1E2235),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(
                            painter: FrameThumbnailPainter(
                              pixels: pixels,
                              width: project.width,
                              height: project.height,
                            ),
                          ),
                          // 프레임 번호
                          Positioned(
                            bottom: 3,
                            right: 5,
                            child: Text('${i + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isActive ? Colors.white : Colors.white38,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                )),
                          ),
                          // 삭제 버튼 (마우스 오버 시)
                          if (project.frames.length > 1)
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => projectNotifier.removeFrame(i),
                                child: const Icon(Icons.close,
                                    size: 12, color: Colors.white38),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FpsDropdown extends StatelessWidget {
  final int fps;
  final List<int> options;
  final ValueChanged<int> onChanged;

  const _FpsDropdown({
    required this.fps,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      color: const Color(0xFF1E2235),
      tooltip: 'FPS',
      itemBuilder: (_) => options
          .map((f) => PopupMenuItem(
                value: f,
                child: Text('$f FPS',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ))
          .toList(),
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2235),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$fps FPS',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 12, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PlayButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2235),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(icon, size: 16, color: Colors.white54),
      ),
    );
  }
}
