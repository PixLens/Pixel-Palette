import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_lens/features/canvas/providers/tool_provider.dart';
import 'package:pixel_lens/features/palette/data/palette_set.dart';
import 'package:pixel_lens/features/palette/providers/palette_provider.dart';

class RightPanel extends ConsumerWidget {
  const RightPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 340,
      color: const Color(0xFF13151F),
      child: const Column(
        children: [
          _BrushSizeSection(),
          Divider(color: Colors.white10, height: 1),
          Expanded(child: _PaletteSetsSection()),
          Divider(color: Colors.white10, height: 1),
          _ActivePaletteSection(),
          Divider(color: Colors.white10, height: 1),
          _ColorPickerPanel(),
        ],
      ),
    );
  }
}

// ── Palette Sets ──────────────────────────────────────────────

class _PaletteSetsSection extends ConsumerStatefulWidget {
  const _PaletteSetsSection();

  @override
  ConsumerState<_PaletteSetsSection> createState() =>
      _PaletteSetsSectionState();
}

class _PaletteSetsSectionState extends ConsumerState<_PaletteSetsSection> {
  static const _pageSize = 4;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    final sets = palette.sets;
    final pageCount = (sets.length / _pageSize).ceil();
    final page = pageCount == 0 ? 0 : _page.clamp(0, pageCount - 1);
    final visible = sets.skip(page * _pageSize).take(_pageSize);

    const pagerHeight = 40.0;
    // 페이지가 1개뿐이어도 "1 / 1"로 항상 표시한다 (화살표는 자연히 비활성화됨).
    final pager = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PageArrowBtn(
            icon: Icons.chevron_left,
            onTap: page > 0 ? () => setState(() => _page = page - 1) : null,
          ),
          const SizedBox(width: 12),
          Text('${page + 1} / $pageCount',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(width: 12),
          _PageArrowBtn(
            icon: Icons.chevron_right,
            onTap: page < pageCount - 1
                ? () => setState(() => _page = page + 1)
                : null,
          ),
        ],
      ),
    );

    // 목록은 ListView가 알아서 스크롤로 흡수하므로 오버플로 걱정이 없고,
    // 페이지 컨트롤은 Positioned로 항상 하단에 고정해 스크롤해도 가려지지 않는다.
    return Stack(
      fit: StackFit.expand,
      children: [
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ListView(
            padding: const EdgeInsets.only(bottom: pagerHeight),
            children: [
              _SectionHeader(
                title: 'Palette List',
                actions: [
                  IconButton(
                    onPressed: () {
                      ref.read(paletteProvider.notifier).addPaletteSet();
                      // 새 팔레트는 목록 끝에 추가되므로, 보이도록 마지막 페이지로 이동한다.
                      final count = ref.read(paletteProvider).sets.length;
                      setState(() => _page = (count - 1) ~/ _pageSize);
                    },
                    icon: const Icon(Icons.add, size: 18),
                  ),
                ],
              ),
              ...visible.map((s) => _PaletteSetTile(
                    set: s,
                    isActive: s.id == palette.activePaletteId,
                    canDelete: sets.length > 1,
                    onTap: () =>
                        ref.read(paletteProvider.notifier).selectPalette(s.id),
                    onDelete: () => ref
                        .read(paletteProvider.notifier)
                        .removePaletteSet(s.id),
                  )),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ColoredBox(color: const Color(0xFF13151F), child: pager),
        ),
      ],
    );
  }
}

class _PageArrowBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _PageArrowBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      color: Colors.white38,
      disabledColor: Colors.white12,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }
}

class _PaletteSetTile extends StatelessWidget {
  final PaletteSet set;
  final bool isActive;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PaletteSetTile({
    required this.set,
    required this.isActive,
    required this.canDelete,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: isActive
            ? const Color(0xFF6D28D9).withValues(alpha: 0.2)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            // 대표 색상
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: set.thumbnail,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(set.name,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  )),
            ),
            // 미리보기 칩
            SizedBox(
              width: 40,
              height: 16,
              child: Row(
                children: set.colors
                    .take(4)
                    .map((c) => Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 0.5),
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(width: 8),
            Text('${set.colors.length}',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            IconButton(
              onPressed: canDelete ? onDelete : null,
              icon: const Icon(Icons.delete_outline, size: 14),
              color: Colors.white24,
              disabledColor: Colors.white12,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Active Palette Grid ───────────────────────────────────────

class _ActivePaletteSection extends ConsumerWidget {
  const _ActivePaletteSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final toolNotifier = ref.read(toolProvider.notifier);
    final currentColor = ref.watch(toolProvider).currentColor;
    final colors = palette.activePalette.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          titleWidget: Row(
            children: [
              Expanded(
                child: _PaletteNameField(
                  key: ValueKey(palette.activePaletteId),
                  name: palette.activePalette.name,
                  onChanged: (name) => ref
                      .read(paletteProvider.notifier)
                      .renamePalette(palette.activePaletteId, name),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () => ref
                  .read(paletteProvider.notifier)
                  .addColorToActive(currentColor),
              icon: const Icon(Icons.add, size: 18),
            ),
            IconButton(
              onPressed: palette.selectedColorIndex == null
                  ? null
                  : () => ref
                      .read(paletteProvider.notifier)
                      .removeColorFromActive(palette.selectedColorIndex!),
              icon: const Icon(Icons.delete_outline, size: 18),
              disabledColor: Colors.white12,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const crossAxisCount = 8;
              const spacing = 3.0;
              final cellSize =
                  (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                      crossAxisCount;
              // 색상이 늘어나도 항상 2줄 높이로 고정하고, 넘치면 스크롤로 본다
              final maxHeight = cellSize * 2 + spacing;
              return SizedBox(
                height: maxHeight,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    childAspectRatio: 1,
                  ),
                  itemCount: colors.length,
                  itemBuilder: (_, i) {
                    final c = colors[i];
                    final selected = i == palette.selectedColorIndex;
                    return GestureDetector(
                      onTap: () {
                        toolNotifier.setColor(c);
                        ref.read(paletteProvider.notifier).selectColorAt(i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 80),
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: selected ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── 팔레트 이름 편집 필드 ──────────────────────────────────────

class _PaletteNameField extends StatefulWidget {
  final String name;
  final ValueChanged<String> onChanged;
  const _PaletteNameField({
    super.key,
    required this.name,
    required this.onChanged,
  });

  @override
  State<_PaletteNameField> createState() => _PaletteNameFieldState();
}

class _PaletteNameFieldState extends State<_PaletteNameField> {
  late TextEditingController _ctrl;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.name);
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_PaletteNameField old) {
    super.didUpdateWidget(old);
    if (!_focusNode.hasFocus && _ctrl.text != widget.name) {
      _ctrl.text = widget.name;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // 포커스를 잃으면(혹은 Enter 입력 시) 변경된 이름을 커밋한다.
  void _onFocusChange() {
    if (_focusNode.hasFocus) return;
    final value = _ctrl.text.trim();
    if (value.isEmpty || value == widget.name) {
      _ctrl.text = widget.name;
    } else {
      widget.onChanged(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focusNode,
      style: const TextStyle(
          color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
      decoration: const InputDecoration(
        isDense: true,
        isCollapsed: true,
        border: InputBorder.none,
      ),
      onSubmitted: (_) => _focusNode.unfocus(),
    );
  }
}

// ── Brush Size Bars (펜 / 지우개 — 아이콘으로 구분) ────────────

class _BrushSizeSection extends ConsumerWidget {
  const _BrushSizeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tool = ref.watch(toolProvider);
    final notifier = ref.read(toolProvider.notifier);

    return Column(
      children: [
        _SizeBar(
          icon: AppTool.pen.icon,
          label: 'Pen',
          value: tool.penSize,
          onChanged: notifier.setPenSize,
        ),
        const Divider(color: Colors.white10, height: 1),
        _SizeBar(
          icon: AppTool.eraser.icon,
          label: 'Eraser',
          value: tool.eraserSize,
          onChanged: notifier.setEraserSize,
        ),
      ],
    );
  }
}

class _SizeBar extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _SizeBar({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(icon, size: 13, color: Colors.white38),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              child: Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  activeTrackColor: const Color(0xFF7C3AED),
                  inactiveTrackColor: const Color(0xFF2D2F3E),
                  thumbColor: Colors.white,
                  overlayColor: Colors.transparent,
                ),
                child: Slider(
                  value: value.toDouble().clamp(1, 100),
                  min: 1,
                  max: 100,
                  onChanged: (v) => onChanged(v.round()),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 36,
              child: Text('${value}px',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorPickerPanel extends ConsumerStatefulWidget {
  const _ColorPickerPanel();

  @override
  ConsumerState<_ColorPickerPanel> createState() => _ColorPickerPanelState();
}

class _ColorPickerPanelState extends ConsumerState<_ColorPickerPanel> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(ref.read(toolProvider).currentColor);
  }

  void _apply(HSVColor hsv) {
    setState(() => _hsv = hsv);
    final color = hsv.toColor();
    ref.read(toolProvider.notifier).setColor(color);
    // 팔레트에서 선택해 둔 색상이 있다면, 피커에서 바꾼 색을 그대로 반영한다.
    ref.read(paletteProvider.notifier).updateSelectedColor(color);
  }

  @override
  Widget build(BuildContext context) {
    final color = ref.watch(toolProvider).currentColor;

    // currentColor(RGB)에서 매번 HSVColor.fromColor로 역산하면 무채색 부근에서
    // hue/saturation 정보가 소실되어 드래그 중 썸네일이 튀거나 멈춰 보이는
    // 문제가 생긴다. 그래서 평소엔 로컬 _hsv를 그대로 쓰고, 외부(스포이드,
    // 팔레트 클릭, Hex 입력 등)에서 색이 바뀐 경우에만 동기화한다.
    if (_hsv.toColor().toARGB32() != color.toARGB32()) {
      _hsv = HSVColor.fromColor(color);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Color Picker'),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
          child: Column(
            children: [
              // 선택 색 미리보기 + 2D 채도/명도 영역
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 160,
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Container(color: color)),
                      Expanded(
                        flex: 7,
                        child:
                            _SaturationValueArea(hsv: _hsv, onChanged: _apply),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Hue 슬라이더
              SizedBox(
                height: 20,
                child: _HueSlider(hsv: _hsv, onChanged: _apply),
              ),
              const SizedBox(height: 14),
              // Hex / RGB 입력 — 한 줄에 나란히 배치
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _HexInput(
                      color: color,
                      onChanged: (c) => _apply(HSVColor.fromColor(c)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _RgbBox(color: color)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 2D 채도 / 명도 선택 영역 ──────────────────────────────────
//
// flutter_colorpicker의 ColorPickerArea는 내부 CustomPainter들이
// shouldRepaint를 항상 false로 반환해 hsvColor가 바뀌어도 다시 그려지지
// 않는다(그라데이션과 인디케이터가 멈춰 보임). 그래서 직접 그린다.
class _SaturationValueArea extends StatelessWidget {
  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;
  const _SaturationValueArea({required this.hsv, required this.onChanged});

  void _handle(Offset local, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final s = (local.dx / size.width).clamp(0.0, 1.0);
    final v = (1 - local.dy / size.height).clamp(0.0, 1.0);
    onChanged(hsv.withSaturation(s).withValue(v));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _handle(d.localPosition, size),
          onPanUpdate: (d) => _handle(d.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: _SaturationValuePainter(hsv),
          ),
        );
      },
    );
  }
}

class _SaturationValuePainter extends CustomPainter {
  final HSVColor hsv;
  const _SaturationValuePainter(this.hsv);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hueColor = HSVColor.fromAHSV(1.0, hsv.hue, 1.0, 1.0).toColor();

    // 가로축: 흰색 → 색상(채도), 세로축: 흰색 → 검정(곱연산으로 명도) 합성
    canvas.drawRect(
      rect,
      Paint()
        ..shader =
            LinearGradient(colors: [Colors.white, hueColor]).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.multiply
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.black],
        ).createShader(rect),
    );

    final indicator =
        Offset(size.width * hsv.saturation, size.height * (1 - hsv.value));
    canvas.drawCircle(indicator, 7, Paint()..color = Colors.white);
    canvas.drawCircle(
      indicator,
      7,
      Paint()
        ..color = Colors.black45
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SaturationValuePainter oldDelegate) =>
      oldDelegate.hsv != hsv;
}

// ── Hue 슬라이더 ──────────────────────────────────────────────
//
// flutter_colorpicker의 ColorPickerSlider 역시 내부 ThumbPainter/TrackPainter가
// shouldRepaint를 항상 false로 반환해, 드래그로 hue가 바뀌어도 썸의 색이
// 갱신되지 않고 멈춰 보인다(위치만 움직임). 그래서 직접 그린다.
const _hueSpectrum = [
  Color(0xFFFF0000),
  Color(0xFFFFFF00),
  Color(0xFF00FF00),
  Color(0xFF00FFFF),
  Color(0xFF0000FF),
  Color(0xFFFF00FF),
  Color(0xFFFF0000),
];

class _HueSlider extends StatelessWidget {
  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;
  const _HueSlider({required this.hsv, required this.onChanged});

  void _handle(double dx, double width) {
    if (width <= 0) return;
    final hue = (dx / width).clamp(0.0, 1.0) * 359.0;
    onChanged(hsv.withHue(hue));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _handle(d.localPosition.dx, size.width),
          onPanUpdate: (d) => _handle(d.localPosition.dx, size.width),
          child: CustomPaint(size: size, painter: _HueSliderPainter(hsv.hue)),
        );
      },
    );
  }
}

class _HueSliderPainter extends CustomPainter {
  final double hue;
  const _HueSliderPainter(this.hue);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = size.height / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()
        ..shader =
            const LinearGradient(colors: _hueSpectrum).createShader(rect),
    );

    final cx = radius + (size.width - radius * 2) * (hue / 360);
    final center = Offset(cx, size.height / 2);
    final thumbColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    canvas.drawCircle(center, radius - 3, Paint()..color = thumbColor);
  }

  @override
  bool shouldRepaint(covariant _HueSliderPainter oldDelegate) =>
      oldDelegate.hue != hue;
}

class _HexInput extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onChanged;
  const _HexInput({required this.color, required this.onChanged});

  @override
  State<_HexInput> createState() => _HexInputState();
}

class _HexInputState extends State<_HexInput> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _toHex(widget.color));
  }

  @override
  void didUpdateWidget(_HexInput old) {
    super.didUpdateWidget(old);
    final hex = _toHex(widget.color);
    if (_ctrl.text.toLowerCase() != hex.toLowerCase()) {
      _ctrl.text = hex;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _toHex(Color c) {
    final argb = c.toARGB32();
    return '#${(argb & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _toHex(widget.color)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('HEX',
            style: TextStyle(
                color: Colors.white38, fontSize: 10, letterSpacing: 0.6)),
        const SizedBox(height: 6),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF1E2235),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const SizedBox(width: 32),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                  onSubmitted: (v) {
                    final parsed =
                        int.tryParse(v.replaceAll('#', ''), radix: 16);
                    if (parsed != null) {
                      widget.onChanged(Color(0xFF000000 | parsed));
                    }
                  },
                ),
              ),
              SizedBox(
                width: 32,
                child: IconButton(
                  onPressed: _copy,
                  tooltip: '복사',
                  icon: const Icon(Icons.copy_rounded,
                      size: 13, color: Colors.white38),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── RGB 표시 + 복사 ───────────────────────────────────────────
//
// _HexInput과 같은 모양(라벨 + 박스 + 복사 버튼)으로 나란히 배치된다.
class _RgbBox extends StatelessWidget {
  final Color color;
  const _RgbBox({required this.color});

  String _toRgb(Color c) {
    final argb = c.toARGB32();
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    return '$r, $g, $b';
  }

  void _copy() => Clipboard.setData(ClipboardData(text: _toRgb(color)));

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('RGB',
            style: TextStyle(
                color: Colors.white38, fontSize: 10, letterSpacing: 0.6)),
        const SizedBox(height: 6),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF1E2235),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const SizedBox(width: 32),
              Expanded(
                child: Text(
                  _toRgb(color),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 32,
                child: IconButton(
                  onPressed: _copy,
                  tooltip: '복사',
                  icon: const Icon(Icons.copy_rounded,
                      size: 13, color: Colors.white38),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 공통 섹션 헤더 ────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget> actions;

  const _SectionHeader({this.title, this.titleWidget, this.actions = const []})
      : assert(title != null || titleWidget != null);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: titleWidget ??
                Text(title!,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
          ),
          ...actions.map((a) => IconTheme(
                data: const IconThemeData(color: Colors.white38, size: 18),
                child: a,
              )),
        ],
      ),
    );
  }
}
