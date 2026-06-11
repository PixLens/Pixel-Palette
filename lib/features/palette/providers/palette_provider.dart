import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_lens/core/storage/global_presets_storage.dart';
import 'package:pixel_lens/features/palette/data/palette_set.dart';

@immutable
class PaletteState {
  final List<PaletteSet> sets;
  final String activePaletteId;
  // 활성 팔레트에서 클릭으로 선택해 둔 색상의 인덱스.
  // 컬러 피커에서 색을 바꾸면 이 인덱스의 팔레트 색상도 함께 갱신된다.
  final int? selectedColorIndex;

  const PaletteState({
    required this.sets,
    required this.activePaletteId,
    this.selectedColorIndex,
  });

  PaletteSet get activePalette =>
      sets.firstWhere((s) => s.id == activePaletteId, orElse: () => sets.first);

  PaletteState copyWith({
    List<PaletteSet>? sets,
    String? activePaletteId,
    int? selectedColorIndex,
  }) =>
      PaletteState(
        sets: sets ?? this.sets,
        activePaletteId: activePaletteId ?? this.activePaletteId,
        selectedColorIndex: selectedColorIndex ?? this.selectedColorIndex,
      );
}

class PaletteNotifier extends Notifier<PaletteState> {
  // 디스크 로드가 끝나기 전에 사용자가 이미 팔레트를 수정했다면,
  // 디스크 결과로 그 변경 사항을 덮어쓰지 않기 위한 플래그.
  bool _userEdited = false;
  Future<void> _saveQueue = Future.value();

  @override
  PaletteState build() {
    Future(_loadFromDisk);
    return PaletteState(
      sets: PaletteSet.defaults(),
      activePaletteId: 'pastel',
    );
  }

  Future<void> _loadFromDisk() async {
    final loaded = await loadGlobalPaletteSets();
    if (loaded == null || _userEdited) return;
    final (sets, activePaletteId) = loaded;
    state = PaletteState(sets: sets, activePaletteId: activePaletteId);
  }

  // 전역 프리셋 파일에 현재 팔레트 셋 목록을 저장한다 (모든 프로젝트/에셋 공용).
  void _persist() {
    _userEdited = true;
    final sets = state.sets;
    final activeId = state.activePaletteId;
    _saveQueue = _saveQueue
        .then((_) => saveGlobalPaletteSets(sets, activeId))
        .catchError((_) {});
  }

  // 팔레트 셋을 바꾸면 이전 셋의 선택 인덱스는 의미가 없어지므로 초기화한다.
  void selectPalette(String id) {
    state = PaletteState(sets: state.sets, activePaletteId: id);
    _persist();
  }

  // 새 팔레트 셋을 만들어 목록 끝에 추가하고 바로 활성 팔레트로 선택한다.
  void addPaletteSet() {
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final name = 'New Palette ${state.sets.length + 1}';
    state = PaletteState(
      sets: [...state.sets, PaletteSet(id: id, name: name, colors: const [])],
      activePaletteId: id,
    );
    _persist();
  }

  // 팔레트 셋을 삭제한다. 마지막 하나는 남겨 둔다.
  // 활성 팔레트를 삭제한 경우 남은 첫 번째 셋으로 활성 팔레트를 옮긴다.
  void removePaletteSet(String id) {
    if (state.sets.length <= 1) return;
    final removingActive = id == state.activePaletteId;
    final updated = state.sets.where((s) => s.id != id).toList();
    state = PaletteState(
      sets: updated,
      activePaletteId: removingActive ? updated.first.id : state.activePaletteId,
      selectedColorIndex: removingActive ? null : state.selectedColorIndex,
    );
    _persist();
  }

  // 팔레트 셋의 이름을 바꾼다.
  void renamePalette(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final updated = state.sets
        .map((s) => s.id == id ? s.copyWith(name: trimmed) : s)
        .toList();
    state = state.copyWith(sets: updated);
    _persist();
  }

  // 활성 팔레트에서 색상 스와치를 클릭해 선택한다.
  void selectColorAt(int index) =>
      state = PaletteState(
        sets: state.sets,
        activePaletteId: state.activePaletteId,
        selectedColorIndex: index,
      );

  // 컬러 피커에서 색을 바꿀 때, 선택해 둔 팔레트 색상이 있다면 함께 갱신한다.
  void updateSelectedColor(Color color) {
    final index = state.selectedColorIndex;
    if (index == null) return;

    final updated = state.sets.map((s) {
      if (s.id != state.activePaletteId) return s;
      if (index < 0 || index >= s.colors.length) return s;
      final colors = List<Color>.from(s.colors);
      colors[index] = color;
      return s.copyWith(colors: colors);
    }).toList();
    state = state.copyWith(sets: updated);
    _persist();
  }

  void addColorToActive(Color color) {
    final updated = state.sets.map((s) {
      if (s.id != state.activePaletteId) return s;
      return s.copyWith(colors: [...s.colors, color]);
    }).toList();
    state = state.copyWith(sets: updated);
    _persist();
  }

  void removeColorFromActive(int index) {
    final selected = state.selectedColorIndex;
    final updated = state.sets.map((s) {
      if (s.id != state.activePaletteId) return s;
      final colors = List<Color>.from(s.colors)..removeAt(index);
      return s.copyWith(colors: colors);
    }).toList();
    state = PaletteState(
      sets: updated,
      activePaletteId: state.activePaletteId,
      selectedColorIndex: switch (selected) {
        null => null,
        _ when selected == index => null,
        _ when selected > index => selected - 1,
        _ => selected,
      },
    );
    _persist();
  }
}

final paletteProvider =
    NotifierProvider<PaletteNotifier, PaletteState>(PaletteNotifier.new);
