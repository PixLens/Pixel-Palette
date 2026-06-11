import 'dart:math';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_lens/features/canvas/presentation/widgets/canvas_viewport.dart';
import 'package:pixel_lens/features/canvas/providers/editor_provider.dart';
import 'package:pixel_lens/features/project/providers/project_provider.dart';
import 'package:pixel_lens/features/canvas/data/import/image_import.dart';

class CanvasArea extends ConsumerStatefulWidget {
  const CanvasArea({super.key});

  @override
  ConsumerState<CanvasArea> createState() => CanvasAreaState();
}

Future<void> _pickAndLoadImage(BuildContext context, WidgetRef ref) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
  );
  if (result == null) return;

  final file = result.files.single;
  final bytes = file.bytes;
  final decoded = bytes == null ? null : decodeImagePixels(bytes);
  if (decoded == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이미지를 불러오지 못했습니다.')),
    );
    return;
  }

  final dotIndex = file.name.lastIndexOf('.');
  final baseName = dotIndex > 0 ? file.name.substring(0, dotIndex) : file.name;

  ref.read(projectProvider.notifier).importImageIntoActiveFrame(
        layerName: baseName,
        imageWidth: decoded.width,
        imageHeight: decoded.height,
        pixels: decoded.pixels,
      );
}

class CanvasAreaState extends ConsumerState<CanvasArea> {
  late final TransformationController _ctrl;
  double _zoom = 1.0;
  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _ctrl = TransformationController();
    _ctrl.addListener(_onTransform);
    WidgetsBinding.instance.addPostFrameCallback((_) => fitToScreen());
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTransform);
    _ctrl.dispose();
    super.dispose();
  }

  void _onTransform() {
    final z = _ctrl.value.getMaxScaleOnAxis();
    if ((z - _zoom).abs() > 0.001) setState(() => _zoom = z);
  }

  // 단축키('1')와 헤더 버튼에서 함께 사용하는 화면 맞춤
  void fitToScreen() {
    if (_viewportSize == Size.zero) return;
    final project = ref.read(projectProvider);
    final cw = project.width * kPixelSize;
    final ch = project.height * kPixelSize;
    final scale =
        min(_viewportSize.width / cw, _viewportSize.height / ch) * 0.85;
    _zoomCentered(scale);
  }

  void _zoomCentered(double s) {
    final clamped = s.clamp(0.1, 32.0);
    final project = ref.read(projectProvider);
    final cw = project.width * kPixelSize;
    final ch = project.height * kPixelSize;
    final tx = (_viewportSize.width - cw * clamped) / 2;
    final ty = (_viewportSize.height - ch * clamped) / 2;
    _ctrl.value = Matrix4.translationValues(tx, ty, 0) *
        Matrix4.diagonal3Values(clamped, clamped, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(editorProvider);

    final fi = editor.activeFrameIndex;
    final pct = (_zoom * 100).round();

    return Column(
      children: [
        // ── 헤더 ────────────────────────────────────────────────
        Container(
          height: 40,
          color: const Color(0xFF1A1D27),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Frame ${fi + 1}',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              // 줌 드롭다운
              _ZoomDropdown(zoom: pct, onSelect: _zoomCentered),
              const SizedBox(width: 8),
              // 화면 맞춤
              _HeaderIconBtn(
                icon: Icons.fit_screen_outlined,
                tooltip: '화면에 맞추기',
                onTap: fitToScreen,
              ),
              _HeaderIconBtn(
                icon: Icons.file_open_outlined,
                tooltip: '불러오기',
                onTap: () => _pickAndLoadImage(context, ref),
              ),
            ],
          ),
        ),

        // ── 캔버스 ──────────────────────────────────────────────
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
              return Container(
                color: const Color(0xFF0E1017),
                child: ClipRect(
                  child: CanvasViewport(transformController: _ctrl),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── 헤더 아이콘 버튼 ──────────────────────────────────────────

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconBtn({
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
          width: 30,
          height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: Colors.white38),
        ),
      ),
    );
  }
}

// ── 줌 드롭다운 ───────────────────────────────────────────────

class _ZoomDropdown extends StatelessWidget {
  final int zoom;
  final ValueChanged<double> onSelect;

  const _ZoomDropdown({required this.zoom, required this.onSelect});

  static const _presets = [25, 50, 100, 200, 400, 800, 1600];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      color: const Color(0xFF1E2235),
      tooltip: '줌',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2235),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$zoom%',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 14, color: Colors.white38),
          ],
        ),
      ),
      itemBuilder: (_) => _presets
          .map((p) => PopupMenuItem(
                value: p,
                child: Text('$p%',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
              ))
          .toList(),
      onSelected: (p) => onSelect(p / 100.0),
    );
  }
}
