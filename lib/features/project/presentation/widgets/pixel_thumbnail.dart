import 'package:flutter/material.dart';
import 'package:pixel_lens/features/canvas/data/layer.dart';
import 'package:pixel_lens/features/project/data/workspace_asset.dart';

class PixelThumbnail extends StatelessWidget {
  final WorkspaceAsset? asset;
  final double size;

  const PixelThumbnail({super.key, required this.asset, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final layer = asset?.firstDrawingLayer;
    final fallback = _assetColor(asset?.id ?? '');

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox.square(
        dimension: size,
        child: layer != null && _hasPixels(layer)
            ? CustomPaint(painter: _PixelPainter(layer: layer))
            : ColoredBox(
                color: fallback,
                child: Center(
                  child: Text(
                    (asset?.name.isNotEmpty == true)
                        ? asset!.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: size * 0.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  bool _hasPixels(DrawingLayer layer) =>
      layer.pixels.any((row) => row.any((c) => c != null));

  Color _assetColor(String id) {
    const palette = [
      Color(0xFF4C1D95), Color(0xFF1E3A5F), Color(0xFF064E3B),
      Color(0xFF7C1D1D), Color(0xFF92400E), Color(0xFF1E1B4B),
    ];
    final hash = id.codeUnits.fold(0, (s, c) => s + c);
    return palette[hash % palette.length];
  }
}

class _PixelPainter extends CustomPainter {
  final DrawingLayer layer;
  _PixelPainter({required this.layer});

  @override
  void paint(Canvas canvas, Size size) {
    final pixels = layer.pixels;
    final h = pixels.length;
    if (h == 0) return;
    final w = pixels[0].length;
    if (w == 0) return;
    final pw = size.width / w;
    final ph = size.height / h;
    final paint = Paint()..isAntiAlias = false;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final c = pixels[y][x];
        if (c != null) {
          paint.color = c;
          canvas.drawRect(Rect.fromLTWH(x * pw, y * ph, pw, ph), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PixelPainter old) => old.layer != layer;
}
