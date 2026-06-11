import 'package:flutter/material.dart';

/// 4-방향 BFS 플러드 필
Map<(int, int), Color?> floodFill({
  required List<List<Color?>> pixels,
  required int startX,
  required int startY,
  required Color fillColor,
  required int width,
  required int height,
}) {
  final target = pixels[startY][startX];
  if (_eq(target, fillColor)) return {};

  final result = <(int, int), Color?>{};
  final queue = <(int, int)>[(startX, startY)];
  final visited = <(int, int)>{};

  while (queue.isNotEmpty) {
    final (x, y) = queue.removeAt(0);
    if (visited.contains((x, y))) continue;
    if (x < 0 || x >= width || y < 0 || y >= height) continue;
    if (!_eq(pixels[y][x], target)) continue;
    visited.add((x, y));
    result[(x, y)] = fillColor;
    queue.addAll([(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]);
  }
  return result;
}

/// 세그멘테이션 레이어용 플러드 필
Map<(int, int), int?> floodFillLabel({
  required List<List<int?>> labelIds,
  required int startX,
  required int startY,
  required int? fillLabel,
  required int width,
  required int height,
}) {
  final target = labelIds[startY][startX];
  if (target == fillLabel) return {};

  final result = <(int, int), int?>{};
  final queue = <(int, int)>[(startX, startY)];
  final visited = <(int, int)>{};

  while (queue.isNotEmpty) {
    final (x, y) = queue.removeAt(0);
    if (visited.contains((x, y))) continue;
    if (x < 0 || x >= width || y < 0 || y >= height) continue;
    if (labelIds[y][x] != target) continue;
    visited.add((x, y));
    result[(x, y)] = fillLabel;
    queue.addAll([(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]);
  }
  return result;
}

bool _eq(Color? a, Color? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return a.toARGB32() == b.toARGB32();
}
