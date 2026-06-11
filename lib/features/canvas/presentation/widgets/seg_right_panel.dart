import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_lens/features/canvas/providers/tool_provider.dart';
import 'package:pixel_lens/features/labeling/data/label_class.dart';
import 'package:pixel_lens/features/labeling/data/label_set.dart';
import 'package:pixel_lens/features/project/providers/project_provider.dart';

// Cycling colors for newly created label classes.
const _kLabelColors = [
  Color(0xFFEF4444),
  Color(0xFF22C55E),
  Color(0xFF3B82F6),
  Color(0xFFF97316),
  Color(0xFFA855F7),
  Color(0xFF14B8A6),
  Color(0xFFEC4899),
  Color(0xFFEAB308),
  Color(0xFF06B6D4),
  Color(0xFF84CC16),
];

// Cycling colors for newly created label sets.
const _kSetColors = [
  Color(0xFF6366F1),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
];

class SegRightPanel extends ConsumerWidget {
  const SegRightPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 340,
      color: const Color(0xFF13151F),
      child: const Column(
        children: [
          _SegBrushSizeSection(),
          Divider(color: Colors.white10, height: 1),
          Expanded(flex: 1, child: _LabelSetsSection()),
          Divider(color: Colors.white10, height: 1),
          Expanded(flex: 2, child: _LabelsSection()),
        ],
      ),
    );
  }
}

// ── Brush Size (Annotator / Erase) ───────────────────────────

class _SegBrushSizeSection extends ConsumerWidget {
  const _SegBrushSizeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tool = ref.watch(toolProvider);
    final notifier = ref.read(toolProvider.notifier);

    return Column(
      children: [
        _SizeBar(
          icon: AppTool.annotate.icon,
          label: 'Annotator',
          value: tool.penSize,
          onChanged: notifier.setPenSize,
        ),
        const Divider(color: Colors.white10, height: 1),
        _SizeBar(
          icon: AppTool.labelEraser.icon,
          label: 'Erase',
          value: tool.eraserSize,
          onChanged: notifier.setEraserSize,
        ),
        const Divider(color: Colors.white10, height: 1),
        _OpacityBar(
          value: tool.segOverlayOpacity,
          onChanged: notifier.setSegOverlayOpacity,
        ),
      ],
    );
  }
}

// ── Segmentation Overlay Opacity ──────────────────────────────

class _OpacityBar extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _OpacityBar({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const Icon(Icons.opacity, size: 13, color: Colors.white38),
            const SizedBox(width: 8),
            const SizedBox(
              width: 52,
              child: Text('Overlay',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
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
                  value: value.clamp(0.0, 1.0),
                  min: 0,
                  max: 1,
                  onChanged: onChanged,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 36,
              child: Text('${(value * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Label Sets (paginated, same design as Palette List) ───────

class _LabelSetsSection extends ConsumerStatefulWidget {
  const _LabelSetsSection();

  @override
  ConsumerState<_LabelSetsSection> createState() => _LabelSetsSectionState();
}

class _LabelSetsSectionState extends ConsumerState<_LabelSetsSection> {
  static const _pageSize = 4;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider);
    final sets = project.labelSets;
    final pageCount = (sets.length / _pageSize).ceil();
    final page = pageCount == 0 ? 0 : _page.clamp(0, pageCount - 1);
    final visible = sets.skip(page * _pageSize).take(_pageSize);

    const pagerHeight = 40.0;

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

    return Stack(
      fit: StackFit.expand,
      children: [
        ScrollConfiguration(
          behavior:
              ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ListView(
            padding: const EdgeInsets.only(bottom: pagerHeight),
            children: [
              _SectionHeader(
                title: 'Label Sets',
                actions: [
                  IconButton(
                    onPressed: () {
                      final count = sets.length;
                      final nextId = project.nextLabelSetId;
                      final newSet = LabelSet(
                        id: nextId,
                        name: 'Set $nextId',
                        labels: [
                          LabelClass(
                            id: project.nextLabelClassId,
                            name: 'Label 1',
                            color: _kSetColors[count % _kSetColors.length],
                          ),
                        ],
                      );
                      ref.read(projectProvider.notifier).addLabelSet(newSet);
                      ref
                          .read(projectProvider.notifier)
                          .setActiveLabelSet(newSet.id);
                      final newCount =
                          ref.read(projectProvider).labelSets.length;
                      setState(() => _page = (newCount - 1) ~/ _pageSize);
                    },
                    icon: const Icon(Icons.add, size: 18),
                  ),
                ],
              ),
              ...visible.map((set) {
                final isActive = set.id == project.activeLabelSetId;
                return _LabelSetTile(
                  key: ValueKey(set.id),
                  set: set,
                  isActive: isActive,
                  canDelete: sets.length > 1,
                  onTap: () => ref
                      .read(projectProvider.notifier)
                      .setActiveLabelSet(set.id),
                  onDelete: () =>
                      ref.read(projectProvider.notifier).removeLabelSet(set.id),
                );
              }),
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

class _LabelSetTile extends StatelessWidget {
  final LabelSet set;
  final bool isActive;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _LabelSetTile({
    super.key,
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
            // Thumbnail: first label color
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
              child: Text(
                set.name,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Mini color chips (first 4 labels)
            SizedBox(
              width: 40,
              height: 16,
              child: Row(
                children: set.labels
                    .take(4)
                    .map((l) => Expanded(
                          child: Container(
                            margin:
                                const EdgeInsets.symmetric(horizontal: 0.5),
                            decoration: BoxDecoration(
                              color: l.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(width: 8),
            Text('${set.labels.length}',
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

// ── Labels (active set, drag-to-reorder) ─────────────────────

class _LabelsSection extends ConsumerWidget {
  const _LabelsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    final tool = ref.watch(toolProvider);
    final activeSet = project.activeLabelSet;
    final allLabels = activeSet.labels;

    return Column(
      children: [
        _SectionHeader(
          titleWidget: _NameField(
            name: activeSet.name,
            bold: true,
            onChanged: (name) => ref
                .read(projectProvider.notifier)
                .updateLabelSet(activeSet.copyWith(name: name)),
          ),
          actions: [
            IconButton(
              onPressed: () {
                final count = allLabels.length;
                final newLabel = LabelClass(
                  id: project.nextLabelClassId,
                  name: 'Label ${count + 1}',
                  color: _kLabelColors[count % _kLabelColors.length],
                );
                ref.read(projectProvider.notifier).addLabelClass(newLabel);
              },
              icon: const Icon(Icons.add, size: 18),
            ),
          ],
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: allLabels.length,
            onReorderItem: (oldIdx, newIdx) {
              if (oldIdx == 0 || newIdx == 0) return;
              final reordered = [...allLabels];
              reordered.insert(newIdx, reordered.removeAt(oldIdx));
              ref
                  .read(projectProvider.notifier)
                  .reorderLabelsInSet(activeSet.id, reordered);
            },
            itemBuilder: (ctx, i) {
              final label = allLabels[i];
              final isBackground = i == 0;
              final tile = _LabelTile(
                label: label,
                index: i,
                isActive: label.id == tool.currentLabelClassId,
                isBackground: isBackground,
                showDragHandle: !isBackground,
                onTap: () =>
                    ref.read(toolProvider.notifier).setLabelClass(label.id),
                onDelete: !isBackground && allLabels.length > 1
                    ? () {
                        ref
                            .read(projectProvider.notifier)
                            .removeLabelClass(label.id);
                        if (ref.read(toolProvider).currentLabelClassId ==
                            label.id) {
                          ref.read(toolProvider.notifier).setLabelClass(null);
                        }
                      }
                    : null,
                onRenamed: isBackground
                    ? null
                    : (name) => ref
                        .read(projectProvider.notifier)
                        .updateLabelClass(label.copyWith(name: name)),
              );
              if (isBackground) {
                return Container(key: ValueKey(label.id), child: tile);
              }
              return ReorderableDragStartListener(
                key: ValueKey(label.id),
                index: i,
                child: tile,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LabelTile extends StatelessWidget {
  final LabelClass label;
  final int index;
  final bool isActive;
  final bool isBackground;
  final bool showDragHandle;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onRenamed;

  const _LabelTile({
    required this.label,
    required this.index,
    required this.isActive,
    this.isBackground = false,
    this.showDragHandle = false,
    required this.onTap,
    required this.onDelete,
    this.onRenamed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: 32,
        color: isActive
            ? const Color(0xFF6D28D9).withValues(alpha: 0.25)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            if (showDragHandle)
              const Icon(Icons.drag_handle, size: 14, color: Colors.white24)
            else
              const SizedBox(width: 14),
            const SizedBox(width: 6),
            // Color swatch — border-only for background (transparent)
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: isBackground ? Colors.transparent : label.color,
                borderRadius: BorderRadius.circular(2),
                border: isBackground
                    ? Border.all(color: Colors.white24, width: 1)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            // Name — editable unless this is the locked background entry
            Expanded(
              child: onRenamed != null
                  ? _NameField(
                      name: label.name,
                      bold: isActive,
                      onChanged: onRenamed!,
                    )
                  : Text(
                      label.name,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            // Index (0-based position)
            SizedBox(
              width: 24,
              child: Text(
                '$index',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 4),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 13),
                color: Colors.white24,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ] else
              const SizedBox(width: 28),
          ],
        ),
      ),
    );
  }
}

// ── Shared utilities ──────────────────────────────────────────

/// Generic inline name edit field used by both set tiles and label tiles.
class _NameField extends StatefulWidget {
  final String name;
  final bool bold;
  final ValueChanged<String> onChanged;

  const _NameField(
      {required this.name, required this.onChanged, this.bold = false});

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late TextEditingController _ctrl;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.name);
    _focus = FocusNode()..addListener(_onFocus);
  }

  @override
  void didUpdateWidget(_NameField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _ctrl.text != widget.name) {
      _ctrl.text = widget.name;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focus.hasFocus) return;
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
      focusNode: _focus,
      style: TextStyle(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: widget.bold ? FontWeight.w600 : FontWeight.normal,
      ),
      decoration: const InputDecoration(
        isDense: true,
        isCollapsed: true,
        border: InputBorder.none,
      ),
      onSubmitted: (_) => _focus.unfocus(),
    );
  }
}

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
              width: 52,
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
