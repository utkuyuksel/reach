import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/persisted_models.dart';
import '../theme/palette.dart';
import 'providers.dart';
import 'wallet_controller.dart';

/// Holds [Settings] and persists every change.
class SettingsController extends Notifier<Settings> {
  @override
  Settings build() => ref.read(storageServiceProvider).loadSettings();

  void setHaptics(bool value) => _update(state.copyWith(hapticsOn: value));
  void setSfx(bool value) => _update(state.copyWith(sfxOn: value));
  void setMusic(bool value) => _update(state.copyWith(musicOn: value));
  void setColorblind(bool value) => _update(state.copyWith(colorblind: value));
  void setOnboardingDone(bool value) =>
      _update(state.copyWith(onboardingDone: value));
  void markMosaicIntroSeen() =>
      _update(state.copyWith(seenMosaicIntro: true));

  /// Select an already-unlocked palette.
  void setPalette(String paletteId) =>
      _update(state.copyWith(paletteId: paletteId));

  bool ownsPalette(String id) => state.ownedPaletteIds.contains(id);

  /// Whether [palette] is usable. Exclusive palettes (Starter Pack) are owned
  /// or nothing — coins and Premium can't reach them. Everything else: free,
  /// Premium-unlocked, or coin-purchased.
  bool isUnlocked(GamePalette palette, {required bool premium}) {
    if (palette.exclusive) return ownsPalette(palette.id);
    return palette.isFree || premium || ownsPalette(palette.id);
  }

  /// Buy [palette] with coins and select it. Returns true on success (false if
  /// not enough coins, or the palette isn't coin-purchasable). Free/owned
  /// palettes are simply selected.
  bool buyPalette(GamePalette palette) {
    if (palette.isFree || ownsPalette(palette.id)) {
      setPalette(palette.id);
      return true;
    }
    if (palette.exclusive) return false; // granted, never sold
    final wallet = ref.read(walletControllerProvider.notifier);
    if (!wallet.trySpend(palette.coinPrice, reason: 'palette:${palette.id}')) {
      return false;
    }
    _update(state.copyWith(
      ownedPaletteIds: [...state.ownedPaletteIds, palette.id],
      paletteId: palette.id,
    ));
    return true;
  }

  /// Grant ownership of [paletteId] without payment (Starter Pack delivery).
  void grantPalette(String paletteId) {
    if (ownsPalette(paletteId)) return;
    _update(state.copyWith(
      ownedPaletteIds: [...state.ownedPaletteIds, paletteId],
    ));
  }

  void _update(Settings next) {
    state = next;
    ref.read(storageServiceProvider).saveSettings(next);
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, Settings>(SettingsController.new);
