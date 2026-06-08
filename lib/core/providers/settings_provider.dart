import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsState {
  final bool darkMode;
  final bool devMode;
  final String exportDefault;

  SettingsState({
    this.darkMode = false,
    this.devMode = false,
    this.exportDefault = 'PNG',
  });

  SettingsState copyWith({
    bool? darkMode,
    bool? devMode,
    String? exportDefault,
  }) {
    return SettingsState(
      darkMode: darkMode ?? this.darkMode,
      devMode: devMode ?? this.devMode,
      exportDefault: exportDefault ?? this.exportDefault,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState());

  void toggleDarkMode(bool value) {
    state = state.copyWith(darkMode: value);
  }

  void toggleDevMode(bool value) {
    state = state.copyWith(devMode: value);
  }

  void setExportDefault(String value) {
    state = state.copyWith(exportDefault: value);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
