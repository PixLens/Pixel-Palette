import 'package:flutter/material.dart';

/// 세그멘테이션 레이블 클래스 정의.
@immutable
class LabelClass {
  final int id;
  final String name;
  final Color color;
  final String? shortcut;
  final bool isVisible;
  final bool isLocked;

  const LabelClass({
    required this.id,
    required this.name,
    required this.color,
    this.shortcut,
    this.isVisible = true,
    this.isLocked = false,
  });

  LabelClass copyWith({
    int? id,
    String? name,
    Color? color,
    String? shortcut,
    bool? isVisible,
    bool? isLocked,
  }) =>
      LabelClass(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
        shortcut: shortcut ?? this.shortcut,
        isVisible: isVisible ?? this.isVisible,
        isLocked: isLocked ?? this.isLocked,
      );

  @override
  bool operator ==(Object other) => other is LabelClass && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'LabelClass($id, "$name")';
}

/// 세그멘테이션 레이어 픽셀 통계
@immutable
class LabelStats {
  final LabelClass labelClass;
  final int pixelCount;
  final double coveragePercent;

  const LabelStats({
    required this.labelClass,
    required this.pixelCount,
    required this.coveragePercent,
  });
}
