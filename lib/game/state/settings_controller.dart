import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/persisted_models.dart';
import 'providers.dart';

/// Holds [Settings] and persists every change.
class SettingsController extends Notifier<Settings> {
  @override
  Settings build() => ref.read(storageServiceProvider).loadSettings();

  void setHaptics(bool value) => _update(state.copyWith(hapticsOn: value));
  void setColorblind(bool value) => _update(state.copyWith(colorblind: value));
  void setPalette(String paletteId) =>
      _update(state.copyWith(paletteId: paletteId));
  void setOnboardingDone(bool value) =>
      _update(state.copyWith(onboardingDone: value));

  void _update(Settings next) {
    state = next;
    ref.read(storageServiceProvider).saveSettings(next);
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, Settings>(SettingsController.new);
