import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_constants.dart';
import '../state/providers.dart';
import '../state/settings_controller.dart';
import '../theme/app_text.dart';
import '../theme/palette.dart';
import '../widgets/paper_background.dart';
import '../widgets/pressable.dart';
import '../widgets/soft_button.dart';
import 'help_screen.dart';
import 'shop_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final settings = ref.watch(settingsControllerProvider);
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
                    Text('Settings',
                        style: AppText.fraunces(
                            size: 28, weight: 600, color: palette.ink)),
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
                      icon: Icons.graphic_eq_rounded,
                      label: 'Sound effects',
                      value: settings.sfxOn,
                      onChanged: settingsCtrl.setSfx,
                    ),
                    _ToggleRow(
                      palette: palette,
                      icon: Icons.music_note_rounded,
                      label: 'Music',
                      value: settings.musicOn,
                      onChanged: settingsCtrl.setMusic,
                    ),
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
                    _SectionLabel(palette: palette, text: 'STORE'),
                    _LinkRow(
                      palette: palette,
                      icon: Icons.storefront_rounded,
                      label: 'Shop — coins, Premium & themes',
                      trailing: Icons.chevron_right_rounded,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ShopScreen()),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _SectionLabel(palette: palette, text: 'ABOUT'),
                    _LinkRow(
                      palette: palette,
                      icon: Icons.help_outline_rounded,
                      label: 'How things work',
                      trailing: Icons.chevron_right_rounded,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      ),
                    ),
                    _LinkRow(
                      palette: palette,
                      icon: Icons.privacy_tip_outlined,
                      label: 'Privacy policy',
                      trailing: Icons.open_in_new_rounded,
                      onTap: () => _openUrl(kPrivacyPolicyUrl),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text('$kAppName · v$kAppVersion',
                          style: AppText.mono(
                              size: 10.5,
                              color: palette.inkSoft,
                              letterSpacing: 2)),
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
}

class _SectionLabel extends StatelessWidget {
  final GamePalette palette;
  final String text;
  const _SectionLabel({required this.palette, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(text,
            style: AppText.mono(
                size: 10.5,
                weight: FontWeight.w500,
                color: palette.inkSoft,
                letterSpacing: 3)),
      );
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
      child: Container(
        decoration: BoxDecoration(
          color: palette.tile,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: palette.tileEdge),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
          child: Row(
            children: [
              Icon(icon, size: 20, color: palette.inkSoft),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: AppText.mono(size: 13.5, color: palette.ink)),
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

class _LinkRow extends StatelessWidget {
  final GamePalette palette;
  final IconData icon;
  final String label;
  final IconData trailing;
  final VoidCallback onTap;

  const _LinkRow({
    required this.palette,
    required this.icon,
    required this.label,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      depth: 1,
      child: Container(
        decoration: BoxDecoration(
          color: palette.tile,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: palette.tileEdge),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: palette.inkSoft),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: AppText.mono(size: 13.5, color: palette.ink)),
              ),
              Icon(trailing, size: 16, color: palette.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
