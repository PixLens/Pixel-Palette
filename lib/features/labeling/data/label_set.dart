import 'package:flutter/material.dart';
import 'label_class.dart';

@immutable
class LabelSet {
  final int id;
  final String name;
  final List<LabelClass> labels;

  const LabelSet({required this.id, required this.name, this.labels = const []});

  LabelSet copyWith({int? id, String? name, List<LabelClass>? labels}) =>
      LabelSet(
        id: id ?? this.id,
        name: name ?? this.name,
        labels: labels ?? this.labels,
      );

  Color get thumbnail =>
      labels.isEmpty ? const Color(0xFF616161) : labels.first.color;

  @override
  bool operator ==(Object other) => other is LabelSet && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'LabelSet($id, "$name")';
}
