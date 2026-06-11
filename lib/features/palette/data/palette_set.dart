import 'package:flutter/material.dart';

@immutable
class PaletteSet {
  final String id;
  final String name;
  final List<Color> colors;

  const PaletteSet({
    required this.id,
    required this.name,
    required this.colors,
  });

  Color get thumbnail => colors.isNotEmpty ? colors.first : Colors.grey;

  PaletteSet copyWith({String? name, List<Color>? colors}) => PaletteSet(
        id: id,
        name: name ?? this.name,
        colors: colors ?? this.colors,
      );

  static List<PaletteSet> defaults() => const [
        PaletteSet(id: 'pastel', name: 'Pastel Tones', colors: _pastel),
        PaletteSet(id: 'ase', name: 'Aseprite Default', colors: _aseprite),
      ];

  // ── 기본 팔레트 ───────────────────────────────────────────────

  static const _pastel = [
    Color(0xFFFFB3BA),
    Color(0xFFFFDFBA),
    Color(0xFFFFFFBA),
    Color(0xFFBAFFBA),
    Color(0xFFBAFFFF),
    Color(0xFFBABAFF),
    Color(0xFFFFBAFF),
    Color(0xFFFFCCCC),
    Color(0xFFCCFFCC),
    Color(0xFFCCCCFF),
    Color(0xFFFFF0CC),
    Color(0xFFCCF0FF),
    Color(0xFFE8D5B7),
    Color(0xFFD5E8D4),
    Color(0xFFD4D5E8),
    Color(0xFFE8D4D5),
  ];

  static const _aseprite = [
    Color(0xFF000000),
    Color(0xFF1D2B53),
    Color(0xFF7E2553),
    Color(0xFF008751),
    Color(0xFFAB5236),
    Color(0xFF5F574F),
    Color(0xFFC2C3C7),
    Color(0xFFFFF1E8),
    Color(0xFFFF004D),
    Color(0xFFFFA300),
    Color(0xFFFFEC27),
    Color(0xFF00E436),
    Color(0xFF29ADFF),
    Color(0xFF83769C),
    Color(0xFFFF77A8),
    Color(0xFFFFCCAA),
  ];
}
