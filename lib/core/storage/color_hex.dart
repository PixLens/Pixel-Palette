import 'package:flutter/material.dart';

String colorToHex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}';

Color colorFromHex(String hex) =>
    Color(int.parse(hex.replaceFirst('#', ''), radix: 16));
