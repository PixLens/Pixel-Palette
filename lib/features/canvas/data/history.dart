import 'package:flutter/material.dart';
import 'package:pixel_lens/features/canvas/data/layer.dart';
import 'package:pixel_lens/features/project/data/project.dart';

// ── Diff 타입 ─────────────────────────────────────────────────

typedef DrawingPixelDiff  = Map<(int, int), ({Color? before, Color? after})>;
typedef SegPixelDiff      = Map<(int, int), ({int?   before, int?   after})>;

// ── LayerChange (sealed) ──────────────────────────────────────

sealed class LayerChange { const LayerChange(); }

final class DrawingChange extends LayerChange {
  final DrawingPixelDiff pixels;
  const DrawingChange(this.pixels);
}

final class SegmentationChange extends LayerChange {
  final SegPixelDiff pixels;
  const SegmentationChange(this.pixels);
}

// ── HistoryEntry ──────────────────────────────────────────────

@immutable
class HistoryEntry {
  final int frameIndex;
  final int layerIndex;
  final LayerChange change;
  final String description;
  final DateTime timestamp;

  const HistoryEntry({
    required this.frameIndex,
    required this.layerIndex,
    required this.change,
    required this.description,
    required this.timestamp,
  });

  factory HistoryEntry.now({
    required int frameIndex,
    required int layerIndex,
    required LayerChange change,
    required String description,
  }) =>
      HistoryEntry(
        frameIndex: frameIndex,
        layerIndex: layerIndex,
        change: change,
        description: description,
        timestamp: DateTime.now(),
      );
}

// ── HistoryStack ──────────────────────────────────────────────

/// diff 기반 undo/redo 스택.
/// ProjectNotifier 내부에서만 사용합니다.
class HistoryStack {
  final int maxSize;
  final List<HistoryEntry> _entries = [];
  int _cursor = -1;

  HistoryStack({this.maxSize = 100});

  bool get canUndo => _cursor >= 0;
  bool get canRedo => _cursor < _entries.length - 1;
  String? get undoDescription => canUndo ? _entries[_cursor].description : null;
  String? get redoDescription => canRedo ? _entries[_cursor + 1].description : null;

  void push(HistoryEntry entry) {
    if (_cursor < _entries.length - 1) {
      _entries.removeRange(_cursor + 1, _entries.length);
    }
    _entries.add(entry);
    if (_entries.length > maxSize) {
      _entries.removeAt(0);
    } else {
      _cursor++;
    }
  }

  Project? undo(Project project) {
    if (!canUndo) return null;
    final entry = _entries[_cursor--];
    return _apply(project, entry, invert: true);
  }

  Project? redo(Project project) {
    if (!canRedo) return null;
    final entry = _entries[++_cursor];
    return _apply(project, entry, invert: false);
  }

  void clear() {
    _entries.clear();
    _cursor = -1;
  }

  // ── 내부 적용 ─────────────────────────────────────────────

  static Project _apply(Project p, HistoryEntry e, {required bool invert}) {
    final frame = p.frameAt(e.frameIndex);
    final layer = frame.layerAt(e.layerIndex);

    final updatedLayer = switch ((e.change, layer)) {
      (DrawingChange dc, DrawingLayer dl) => dl.withPixelChanges(
          {for (final x in dc.pixels.entries) x.key: invert ? x.value.before : x.value.after},
          p.width,
          p.height,
        ),
      (SegmentationChange sc, SegmentationLayer sl) => sl.withLabelChanges(
          {for (final x in sc.pixels.entries) x.key: invert ? x.value.before : x.value.after},
          p.width,
          p.height,
        ),
      // 변경 타입과 레이어 타입이 불일치하면 원본 유지
      _ => layer,
    };

    return p.replaceFrameAt(
      e.frameIndex,
      frame.replaceLayerAt(e.layerIndex, updatedLayer),
    );
  }
}
