import 'package:flutter/material.dart';
import 'package:pixel_lens/features/canvas/data/frame.dart';
import 'package:pixel_lens/features/labeling/data/label_class.dart';
import 'package:pixel_lens/features/labeling/data/label_set.dart';
import 'package:pixel_lens/features/project/data/project.dart';
import 'package:pixel_lens/features/project/data/workspace_asset.dart';

@immutable
class WorkspaceProject {
  final String id;
  final String name;
  final String description;
  final String storagePath;
  final int width;
  final int height;
  final List<WorkspaceAsset> assets;
  final List<LabelSet> labelSets;
  final int activeLabelSetId;
  final List<Color> palette;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final bool isFavorite;

  const WorkspaceProject({
    required this.id,
    required this.name,
    this.description = '',
    required this.storagePath,
    required this.width,
    required this.height,
    required this.assets,
    required this.labelSets,
    required this.activeLabelSetId,
    required this.palette,
    required this.createdAt,
    required this.modifiedAt,
    this.isFavorite = false,
  });

  int get assetCount => assets.length;
  int get frameCount => assets.fold(0, (s, a) => s + a.frameCount);
  int get labelCount => labelSets.expand((s) => s.labels).length;
  String get sizeLabel => '${width}x$height';
  int get totalFileCount =>
      frameCount + assets.where((a) => a.hasMask).fold(0, (s, a) => s + a.frameCount);

  LabelSet get activeLabelSet {
    try {
      return labelSets.firstWhere((s) => s.id == activeLabelSetId);
    } catch (_) {
      return labelSets.first;
    }
  }

  WorkspaceAsset? findAsset(String id) {
    try {
      return assets.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  Project assetToProject(WorkspaceAsset asset) {
    final w = asset.width ?? width;
    final h = asset.height ?? height;
    return Project(
      name: asset.name,
      width: w,
      height: h,
      frames: asset.frames.isEmpty
          ? [Frame.initial(width: w, height: h)]
          : List.from(asset.frames),
      labelSets: List.from(labelSets),
      activeLabelSetId: activeLabelSetId,
      palette: List.from(palette),
      metadata: ProjectMetadata(
        createdAt: asset.createdAt,
        modifiedAt: asset.modifiedAt,
      ),
    );
  }

  static List<LabelSet> defaultLabelSets() => const [
        LabelSet(
          id: 1,
          name: 'Default',
          labels: [
            LabelClass(id: 1, name: 'Background', color: Color(0x00000000), shortcut: '1'),
            LabelClass(id: 2, name: 'Object', color: Color(0xFF2196F3), shortcut: '2'),
            LabelClass(id: 3, name: 'Person', color: Color(0xFF4CAF50), shortcut: '3'),
          ],
        ),
      ];

  static List<Color> defaultPalette() => const [
        Color(0xFF000000), Color(0xFFFFFFFF), Color(0xFFE94560), Color(0xFFFF6B35),
        Color(0xFFFFD700), Color(0xFF4CAF50), Color(0xFF00BCD4), Color(0xFF2196F3),
        Color(0xFF9C27B0), Color(0xFFFF80AB), Color(0xFF795548), Color(0xFF607D8B),
        Color(0xFF9E9E9E), Color(0xFFBDBDBD), Color(0xFF1A237E), Color(0xFF1B5E20),
      ];

  WorkspaceProject copyWith({
    String? id,
    String? name,
    String? description,
    String? storagePath,
    int? width,
    int? height,
    List<WorkspaceAsset>? assets,
    List<LabelSet>? labelSets,
    int? activeLabelSetId,
    List<Color>? palette,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isFavorite,
  }) =>
      WorkspaceProject(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        storagePath: storagePath ?? this.storagePath,
        width: width ?? this.width,
        height: height ?? this.height,
        assets: assets ?? this.assets,
        labelSets: labelSets ?? this.labelSets,
        activeLabelSetId: activeLabelSetId ?? this.activeLabelSetId,
        palette: palette ?? this.palette,
        createdAt: createdAt ?? this.createdAt,
        modifiedAt: modifiedAt ?? this.modifiedAt,
        isFavorite: isFavorite ?? this.isFavorite,
      );

  WorkspaceProject updateAsset(WorkspaceAsset asset) => copyWith(
        assets: [for (final a in assets) a.id == asset.id ? asset : a],
        modifiedAt: DateTime.now(),
      );

  WorkspaceProject addAsset(WorkspaceAsset asset) => copyWith(
        assets: [...assets, asset],
        modifiedAt: DateTime.now(),
      );

  WorkspaceProject removeAsset(String assetId) => copyWith(
        assets: assets.where((a) => a.id != assetId).toList(),
        modifiedAt: DateTime.now(),
      );
}
