import 'package:pixel_lens/core/storage/color_hex.dart';
import 'package:pixel_lens/features/labeling/data/label_class.dart';
import 'package:pixel_lens/features/labeling/data/label_set.dart';

Map<String, dynamic> labelClassToJson(LabelClass c) => {
      'id': c.id,
      'name': c.name,
      'color': colorToHex(c.color),
      'shortcut': c.shortcut,
      'isVisible': c.isVisible,
      'isLocked': c.isLocked,
    };

LabelClass labelClassFromJson(Map<String, dynamic> j) => LabelClass(
      id: j['id'] as int,
      name: j['name'] as String,
      color: colorFromHex(j['color'] as String),
      shortcut: j['shortcut'] as String?,
      isVisible: j['isVisible'] as bool? ?? true,
      isLocked: j['isLocked'] as bool? ?? false,
    );

Map<String, dynamic> labelSetToJson(LabelSet s) => {
      'id': s.id,
      'name': s.name,
      'labels': s.labels.map(labelClassToJson).toList(),
    };

LabelSet labelSetFromJson(Map<String, dynamic> j) => LabelSet(
      id: j['id'] as int,
      name: j['name'] as String,
      labels: (j['labels'] as List)
          .map((e) => labelClassFromJson(e as Map<String, dynamic>))
          .toList(),
    );
