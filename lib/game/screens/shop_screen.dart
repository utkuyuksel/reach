import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/iap_config.dart';
import '../../services/analytics_service.dart';
import '../state/entitlement_controller.dart';
import '../state/providers.dart';
import '../state/settings_controller.dart';
import '../state/wallet_controller.dart';
import '../theme/app_text.dart';
import '../theme/palette.dart';
import '../widgets/coin_chip.dart';
import '../widgets/paper_background.dart';
import '../widgets/pressable.dart';
import '../widgets/soft_button.dart';

/// The shop: earn/buy coins, unlock Premium, and unlock cosmetic themes with
/// coins. Coins have two sinks (hints + themes), giving a reason to keep them.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  bool _adBusy = false;

  void _toast(String msg, GamePalette palette) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: AppText.mono(size: 12.5, color: Colors.white)),
      backgroundColor: palette.ink,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _watchAdForCoins() async {
    if (_adBusy) return;
    setState(() => _adBusy = true);
    final earned = await ref.read(adServiceProvider).showRewardedAd();
    if (!mounted) return;
    setState(() => _adBusy = false);
    ref.read(analyticsServiceProvider)
        .log(AnalyticsEvents.rewardedAdShown, {'earned': earned, 'src': 'shop'});
    if (earned) {
      ref.read(walletControllerProvider.notifier).earn(
            ref.read(gameConfigProvider).coinsPerRewardedAd,
            reason: 'shop_ad',
          );
    }
  }

  void _selectOrBuyTheme(GamePalette p, bool premium, GamePalette palette) {
    final ctrl = ref.read(settingsControllerProvider.notifier);
    if (ctrl.isUnlocked(p, premium: premium)) {
      ctrl.setPalette(p.id);
      return;
    }
    // Locked → buy with coins.
    if (ctrl.buyPalette(p)) return;
    _toast('Not enough coins for ${p.name}.', palette);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    final premium = ref.watch(entitlementControllerProvider);
    final coins = ref.watch(walletControllerProvider);
    final settings = ref.watch(settingsControllerProvider);

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
                    Text('Shop',
                        style: AppText.fraunces(
                            size: 28, weight: 600, color: palette.ink)),
                    const Spacer(),
                    CoinChip(coins: coins, palette: palette),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    if (!premium) ...[
                      _SectionLabel(palette: palette, text: 'COINS'),
                      _RowCard(
                        palette: palette,
                        onTap: _adBusy ? null : _watchAdForCoins,
                        leading: Icons.play_circle_outline_rounded,
                        label: 'Watch a video',
                        trailing: _CoinAmount(
                          palette: palette,
                          amount: ref.read(gameConfigProvider).coinsPerRewardedAd,
                        ),
                      ),
                      for (final id in IapConfig.coinPackOrder)
                        _RowCard(
                          palette: palette,
                          onTap: () => ref
                              .read(walletControllerProvider.notifier)
                              .buyPack(id),
                          leading: Icons.monetization_on_rounded,
                          label: '${IapConfig.coinsFor(id)} coins',
                          trailing: _PriceTag(
                            palette: palette,
                            price: ref
                                    .read(walletControllerProvider.notifier)
                                    .priceFor(id) ??
                                '—',
                          ),
                        ),
                      const SizedBox(height: 22),
                      _SectionLabel(palette: palette, text: 'PREMIUM'),
                      _PremiumCard(palette: palette),
                      const SizedBox(height: 22),
                    ] else ...[
                      _SectionLabel(palette: palette, text: 'PREMIUM'),
                      _RowCard(
                        palette: palette,
                        onTap: null,
                        leading: Icons.verified_rounded,
                        label: 'Premium unlocked',
                        trailing: Icon(Icons.check_rounded,
                            color: palette.good, size: 20),
                      ),
                      const SizedBox(height: 22),
                    ],
                    _SectionLabel(palette: palette, text: 'THEMES'),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (final p in GamePalette.all)
                          _ThemeTile(
                            palette: p,
                            current: palette,
                            selected: settings.paletteId == p.id,
                            unlocked: ref
                                .read(settingsControllerProvider.notifier)
                                .isUnlocked(p, premium: premium),
                            onTap: () => _selectOrBuyTheme(p, premium, palette),
                          ),
                      ],
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

class _RowCard extends StatelessWidget {
  final GamePalette palette;
  final VoidCallback? onTap;
  final IconData leading;
  final String label;
  final Widget trailing;

  const _RowCard({
    required this.palette,
    required this.onTap,
    required this.leading,
    required this.label,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: onTap,
        depth: 1.5,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: palette.tile,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: palette.tileEdge),
          ),
          child: Row(
            children: [
              Icon(leading, size: 22, color: palette.accent),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: AppText.mono(size: 13.5, color: palette.ink)),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _CoinAmount extends StatelessWidget {
  final GamePalette palette;
  final int amount;
  const _CoinAmount({required this.palette, required this.amount});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, size: 15, color: palette.accent),
          Text('$amount',
              style: AppText.mono(
                  size: 13, weight: FontWeight.w500, color: palette.ink)),
          const SizedBox(width: 4),
          Icon(Icons.monetization_on_rounded, size: 15, color: palette.accent),
        ],
      );
}

class _PriceTag extends StatelessWidget {
  final GamePalette palette;
  final String price;
  const _PriceTag({required this.palette, required this.price});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: palette.accent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(price,
            style: AppText.mono(
                size: 12.5, weight: FontWeight.w500, color: Colors.white)),
      );
}

class _PremiumCard extends ConsumerWidget {
  final GamePalette palette;
  const _PremiumCard({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.read(entitlementControllerProvider.notifier);
    final price = entitlement.price;
    return Container(
      decoration: BoxDecoration(
        color: palette.tile,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.tileEdge),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No ads · unlimited hints · all themes',
              style: AppText.mono(size: 12.5, color: palette.inkSoft)),
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
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final GamePalette palette; // the theme this tile represents
  final GamePalette current; // active palette (for chrome)
  final bool selected;
  final bool unlocked;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.palette,
    required this.current,
    required this.selected,
    required this.unlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      depth: 1.5,
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: palette.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? current.accent : palette.tileEdge,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Swatch.
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
                border: Border.all(color: palette.tile, width: 2),
              ),
            ),
            const SizedBox(height: 8),
            Text(palette.name,
                style: AppText.mono(size: 11, color: current.ink)),
            const SizedBox(height: 6),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 16, color: current.accent)
            else if (unlocked)
              Icon(Icons.circle_outlined, size: 14, color: current.inkSoft)
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monetization_on_rounded,
                      size: 12, color: current.accent),
                  const SizedBox(width: 3),
                  Text('${palette.coinPrice}',
                      style: AppText.mono(
                          size: 11,
                          weight: FontWeight.w500,
                          color: current.ink)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
