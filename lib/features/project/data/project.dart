import 'package:flutter/material.dart';
import 'package:pixel_lens/features/canvas/data/frame.dart';
import 'package:pixel_lens/features/canvas/data/layer.dart';
import 'package:pixel_lens/features/labeling/data/label_class.dart';
import 'package:pixel_lens/features/labeling/data/label_set.dart';

// ── 메타데이터 ─────────────────────────────────────────────────

@immutable
class ProjectMetadata {
  final String author;
  final String description;
  final DateTime createdAt;
  final DateTime modifiedAt;

  const ProjectMetadata({
    this.author = '',
    this.description = '',
    required this.createdAt,
    required this.modifiedAt,
  });

  ProjectMetadata copyWith({
    String? author,
    String? description,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) =>
      ProjectMetadata(
        author: author ?? this.author,
        description: description ?? this.description,
        createdAt: createdAt ?? this.createdAt,
        modifiedAt: modifiedAt ?? this.modifiedAt,
      );

  ProjectMetadata touched() => copyWith(modifiedAt: DateTime.now());
}

// ── 내보내기 설정 ──────────────────────────────────────────────

enum ExportFormat { png, maskPng, indexedPng, cocoJson, spriteSheet }

@immutable
class ExportConfig {
  final ExportFormat format;
  final int scale;
  final bool includeAlpha;

  const ExportConfig({
    this.format = ExportFormat.png,
    this.scale = 8,
    this.includeAlpha = true,
  });

  ExportConfig copyWith(
          {ExportFormat? format, int? scale, bool? includeAlpha}) =>
      ExportConfig(
        format: format ?? this.format,
        scale: scale ?? this.scale,
        includeAlpha: includeAlpha ?? this.includeAlpha,
      );
}

// ── Project ───────────────────────────────────────────────────

@immutable
class Project {
  final String name;
  final int width;
  final int height;
  final List<Frame> frames;
  final List<LabelSet> labelSets;
  final int activeLabelSetId;
  final List<Color> palette;
  final ProjectMetadata metadata;
  final ExportConfig exportConfig;

  const Project({
    required this.name,
    required this.width,
    required this.height,
    required this.frames,
    required this.labelSets,
    required this.activeLabelSetId,
    required this.palette,
    required this.metadata,
    this.exportConfig = const ExportConfig(),
  });

  factory Project.create({
    String name = 'v1.0.0',
    int width = 16,
    int height = 16,
  }) {
    final now = DateTime.now();
    final sets = _defaultLabelSets();
    return Project(
      name: name,
      width: width,
      height: height,
      frames: [Frame.initial(width: width, height: height)],
      labelSets: sets,
      activeLabelSetId: sets.first.id,
      palette: _defaultPalette(),
      metadata: ProjectMetadata(createdAt: now, modifiedAt: now),
    );
  }

  factory Project.fromImage({
    String name = 'Untitled',
    required int width,
    required int height,
    required List<List<Color?>> pixels,
  }) {
    final now = DateTime.now();
    final sets = _defaultLabelSets();
    return Project(
      name: name,
      width: width,
      height: height,
      frames: [
        Frame(layers: [DrawingLayer(name: 'Layer 1', pixels: pixels)])
      ],
      labelSets: sets,
      activeLabelSetId: sets.first.id,
      palette: _defaultPalette(),
      metadata: ProjectMetadata(createdAt: now, modifiedAt: now),
    );
  }

  // ── Computed properties ───────────────────────────────────────

  int get frameCount => frames.length;
  int get totalPixels => width * height;
  Frame frameAt(int index) => frames[index];

  LabelSet get activeLabelSet {
    try {
      return labelSets.firstWhere((s) => s.id == activeLabelSetId);
    } catch (_) {
      return labelSets.first;
    }
  }

  // Flat list of all label classes across all sets (for canvas rendering/export)
  List<LabelClass> get labelClasses =>
      labelSets.expand((s) => s.labels).toList();

  int get nextLabelSetId => labelSets.isEmpty
      ? 1
      : labelSets.map((s) => s.id).reduce((a, b) => a > b ? a : b) + 1;

  int get nextLabelClassId {
    final all = labelClasses;
    return all.isEmpty
        ? 1
        : all.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  LabelClass? labelClassById(int id) {
    try {
      return labelClasses.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── copyWith ─────────────────────────────────────────────────

  Project copyWith({
    String? name,
    int? width,
    int? height,
    List<Frame>? frames,
    List<LabelSet>? labelSets,
    int? activeLabelSetId,
    List<Color>? palette,
    ProjectMetadata? metadata,
    ExportConfig? exportConfig,
  }) =>
      Project(
        name: name ?? this.name,
        width: width ?? this.width,
        height: height ?? this.height,
        frames: frames ?? this.frames,
        labelSets: labelSets ?? this.labelSets,
        activeLabelSetId: activeLabelSetId ?? this.activeLabelSetId,
        palette: palette ?? this.palette,
        metadata: metadata ?? this.metadata,
        exportConfig: exportConfig ?? this.exportConfig,
      );

  // ── 프레임 ──────────────────────────────────────────────────

  Project addFrame() => copyWith(
        frames: [...frames, Frame.initial(width: width, height: height)],
        metadata: metadata.touched(),
      );

  Project duplicateFrame(int index) => copyWith(
        frames: [
          ...frames.sublist(0, index + 1),
          frames[index],
          ...frames.sublist(index + 1),
        ],
        metadata: metadata.touched(),
      );

  Project removeFrameAt(int index) {
    assert(frames.length > 1);
    return copyWith(
      frames: List<Frame>.from(frames)..removeAt(index),
      metadata: metadata.touched(),
    );
  }

  Project replaceFrameAt(int index, Frame frame) => copyWith(
        frames: List<Frame>.from(frames)..[index] = frame,
        metadata: metadata.touched(),
      );

  // ── Label Sets ───────────────────────────────────────────────

  Project addLabelSet(LabelSet set) =>
      copyWith(labelSets: [...labelSets, set], metadata: metadata.touched());

  Project updateLabelSet(LabelSet set) => copyWith(
      labelSets: [for (final s in labelSets) s.id == set.id ? set : s],
      metadata: metadata.touched());

  Project removeLabelSet(int id) => copyWith(
      labelSets: labelSets.where((s) => s.id != id).toList(),
      metadata: metadata.touched());

  Project setActiveLabelSet(int id) => copyWith(activeLabelSetId: id);

  // ── Labels within sets ────────────────────────────────────────

  // Adds to the currently active set.
  Project addLabelClass(LabelClass lc) {
    final set = activeLabelSet;
    return updateLabelSet(set.copyWith(labels: [...set.labels, lc]));
  }

  // Updates globally (searches all sets by label id).
  Project updateLabelClass(LabelClass lc) => copyWith(
      labelSets: labelSets.map((s) {
        final idx = s.labels.indexWhere((l) => l.id == lc.id);
        if (idx == -1) return s;
        final updated = [...s.labels]..[idx] = lc;
        return s.copyWith(labels: updated);
      }).toList(),
      metadata: metadata.touched());

  // Removes globally (searches all sets by label id).
  Project removeLabelClass(int id) => copyWith(
      labelSets: labelSets
          .map((s) =>
              s.copyWith(labels: s.labels.where((l) => l.id != id).toList()))
          .toList(),
      metadata: metadata.touched());

  Project reorderLabelsInSet(int setId, List<LabelClass> newOrder) {
    final set = labelSets.firstWhere((s) => s.id == setId);
    return updateLabelSet(set.copyWith(labels: newOrder));
  }

  // ── 캔버스 리사이즈 ──────────────────────────────────────────

  Project resize(int newWidth, int newHeight) {
    final newFrames = frames.map((frame) {
      final newLayers = frame.layers
          .map((layer) => switch (layer) {
                DrawingLayer dl => _resizeDrawing(dl, newWidth, newHeight),
                SegmentationLayer sl => _resizeSeg(sl, newWidth, newHeight),
              })
          .toList();
      return frame.copyWith(layers: newLayers);
    }).toList();
    return copyWith(
        width: newWidth,
        height: newHeight,
        frames: newFrames,
        metadata: metadata.touched());
  }

  // ── 기본값 ───────────────────────────────────────────────────

  static List<LabelSet> _defaultLabelSets() => [
        const LabelSet(
          id: 1,
          name: 'Default',
          labels: [
            LabelClass(
                id: 1,
                name: 'Background',
                color: Color(0x00000000),
                shortcut: '1'),
            LabelClass(
                id: 2, name: 'Object', color: Color(0xFF2196F3), shortcut: '2'),
            LabelClass(
                id: 3, name: 'Person', color: Color(0xFF4CAF50), shortcut: '3'),
          ],
        ),
      ];

  static List<Color> _defaultPalette() => const [
        Color(0xFF000000),
        Color(0xFFFFFFFF),
        Color(0xFFE94560),
        Color(0xFFFF6B35),
        Color(0xFFFFD700),
        Color(0xFF4CAF50),
        Color(0xFF00BCD4),
        Color(0xFF2196F3),
        Color(0xFF9C27B0),
        Color(0xFFFF80AB),
        Color(0xFF795548),
        Color(0xFF607D8B),
        Color(0xFF9E9E9E),
        Color(0xFFBDBDBD),
        Color(0xFF1A237E),
        Color(0xFF1B5E20),
      ];

  static DrawingLayer _resizeDrawing(DrawingLayer dl, int w, int h) {
    final p = List.generate(h, (y) => List<Color?>.filled(w, null));
    for (int y = 0; y < h && y < dl.pixels.length; y++) {
      for (int x = 0; x < w && x < dl.pixels[y].length; x++) {
        p[y][x] = dl.pixels[y][x];
      }
    }
    return dl.copyWith(pixels: p);
  }

  static SegmentationLayer _resizeSeg(SegmentationLayer sl, int w, int h) {
    final ids = List.generate(h, (y) => List<int?>.filled(w, null));
    for (int y = 0; y < h && y < sl.labelIds.length; y++) {
      for (int x = 0; x < w && x < sl.labelIds[y].length; x++) {
        ids[y][x] = sl.labelIds[y][x];
      }
    }
    return sl.copyWith(labelIds: ids);
  }
}
