import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_constants.dart';
import '../state/entitlement_controller.dart';
import '../state/providers.dart';
import '../state/settings_controller.dart';
import '../theme/app_text.dart';
import '../theme/palette.dart';
import '../widgets/paper_background.dart';
import '../widgets/pressable.dart';
import '../widgets/soft_button.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final settings = ref.watch(settingsControllerProvider);
    final premium = ref.watch(entitlementControllerProvider);
    final settingsCtrl = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      backgroundColor: palette.paper,
      body: PaperBackground(
        palette: palette,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    SoftButton(
                      icon: Icons.arrow_back_rounded,
                      palette: palette,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Settings',
                      style: AppText.fraunces(
                        size: 28,
                        weight: 600,
                        color: palette.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    _SectionLabel(palette: palette, text: 'FEEL'),
                    _ToggleRow(
                      palette: palette,
                      icon: Icons.vibration_rounded,
                      label: 'Haptics',
                      value: settings.hapticsOn,
                      onChanged: settingsCtrl.setHaptics,
                    ),
                    _ToggleRow(
                      palette: palette,
                      icon: Icons.contrast_rounded,
                      label: 'Colourblind marks',
                      value: settings.colorblind,
                      onChanged: settingsCtrl.setColorblind,
                    ),
                    const SizedBox(height: 22),
                    _SectionLabel(palette: palette, text: 'THEME'),
                    _PalettePicker(
                      selectedId: settings.paletteId,
                      premium: premium,
                      onSelect: (p) {
                        if (p.premium && !premium) {
                          _promptPremium(context, ref, palette);
                        } else {
                          settingsCtrl.setPalette(p.id);
                        }
                      },
                    ),
                    const SizedBox(height: 22),
                    _SectionLabel(palette: palette, text: 'PREMIUM'),
                    _PremiumSection(palette: palette, premium: premium),
                    const SizedBox(height: 22),
                    _SectionLabel(palette: palette, text: 'ABOUT'),
                    _LinkRow(
                      palette: palette,
                      icon: Icons.privacy_tip_outlined,
                      label: 'Privacy policy',
                      onTap: () => _openUrl(kPrivacyPolicyUrl),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        '$kAppName · v1',
                        style: AppText.mono(
                          size: 10.5,
                          color: palette.inkSoft,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _promptPremium(BuildContext context, WidgetRef ref, GamePalette palette) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'This palette is part of Premium.',
          style: AppText.mono(size: 12.5, color: Colors.white),
        ),
        backgroundColor: palette.ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final GamePalette palette;
  final String text;
  const _SectionLabel({required this.palette, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: AppText.mono(
          size: 10.5,
          weight: FontWeight.w500,
          color: palette.inkSoft,
          letterSpacing: 3,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final GamePalette palette;
  final Widget child;
  const _Card({required this.palette, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.tile,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.tileEdge),
      ),
      child: child,
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final GamePalette palette;
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.palette,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Card(
        palette: palette,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
          child: Row(
            children: [
              Icon(icon, size: 20, color: palette.inkSoft),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: AppText.mono(size: 13.5, color: palette.ink),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: palette.accent,
                inactiveTrackColor: palette.line,
                inactiveThumbColor: palette.tile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PalettePicker extends StatelessWidget {
  final String selectedId;
  final bool premium;
  final ValueChanged<GamePalette> onSelect;

  const _PalettePicker({
    required this.selectedId,
    required this.premium,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final p in GamePalette.all)
          _Swatch(
            palette: p,
            selected: p.id == selectedId,
            locked: p.premium && !premium,
            onTap: () => onSelect(p),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final GamePalette palette;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  const _Swatch({
    required this.palette,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      depth: 1.5,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: palette.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? palette.accent : palette.tileEdge,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
                border: Border.all(color: palette.tile, width: 2),
              ),
            ),
            if (locked)
              Positioned(
                right: 5,
                top: 5,
                child: Icon(Icons.lock_rounded,
                    size: 13, color: palette.inkSoft),
              ),
            if (selected)
              Positioned(
                right: 4,
                bottom: 4,
                child: Icon(Icons.check_circle_rounded,
                    size: 15, color: palette.accent),
              ),
          ],
        ),
      ),
    );
  }
}

class _PremiumSection extends ConsumerWidget {
  final GamePalette palette;
  final bool premium;
  const _PremiumSection({required this.palette, required this.premium});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.read(entitlementControllerProvider.notifier);
    final price = ref.read(purchaseServiceProvider).premiumPrice;

    if (premium) {
      return _Card(
        palette: palette,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.verified_rounded, color: palette.good, size: 20),
              const SizedBox(width: 12),
              Text(
                'Premium unlocked',
                style: AppText.mono(size: 13.5, color: palette.ink),
              ),
            ],
          ),
        ),
      );
    }

    return _Card(
      palette: palette,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No ads · unlimited hints · all themes',
              style: AppText.mono(size: 12.5, color: palette.inkSoft),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                SoftButton(
                  icon: Icons.lock_open_rounded,
                  label: price == null ? 'Unlock' : 'Unlock $price',
                  palette: palette,
                  primary: true,
                  onTap: () => entitlement.buyPremium(),
                ),
                const SizedBox(width: 10),
                SoftButton(
                  icon: Icons.restore_rounded,
                  label: 'Restore',
                  palette: palette,
                  onTap: () => entitlement.restore(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final GamePalette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LinkRow({
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      depth: 1,
      child: _Card(
        palette: palette,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: palette.inkSoft),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: AppText.mono(size: 13.5, color: palette.ink),
                ),
              ),
              Icon(Icons.open_in_new_rounded,
                  size: 16, color: palette.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
