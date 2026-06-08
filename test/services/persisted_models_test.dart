import 'package:flutter_test/flutter_test.dart';
import 'package:reach/services/persisted_models.dart';

void main() {
  group('round-trips', () {
    test('Settings (incl. onboarding + owned palettes)', () {
      const s = Settings(
        hapticsOn: false,
        colorblind: true,
        paletteId: 'dusk',
        onboardingDone: true,
        ownedPaletteIds: ['sage', 'dusk'],
      );
      final back = Settings.fromMap(s.toMap());
      expect(back.hapticsOn, false);
      expect(back.colorblind, true);
      expect(back.paletteId, 'dusk');
      expect(back.onboardingDone, true);
      expect(back.ownedPaletteIds, ['sage', 'dusk']);
    });

    test('ZenRecord', () {
      const z = ZenRecord(boardsCleared: 23);
      expect(ZenRecord.fromMap(z.toMap()).boardsCleared, 23);
    });

    test('WalletRecord', () {
      const w = WalletRecord(coins: 145);
      expect(WalletRecord.fromMap(w.toMap()).coins, 145);
    });

    test('DailyRecord with nested results (hints + stars)', () {
      final d = DailyRecord(
        currentStreak: 2,
        longestStreak: 4,
        lastCompletedDate: '2026-06-08',
        results: {
          '2026-06-08':
              const DailyResult(dateKey: '2026-06-08', hintsUsed: 1, stars: 2),
        },
      );
      final back = DailyRecord.fromMap(d.toMap());
      expect(back.currentStreak, 2);
      expect(back.longestStreak, 4);
      expect(back.resultFor('2026-06-08')!.hintsUsed, 1);
      expect(back.resultFor('2026-06-08')!.stars, 2);
      expect(back.resultFor('2026-06-08')!.clean, isFalse);
    });
  });

  group('fault tolerance', () {
    test('DailyResult.fromMap tolerates missing fields', () {
      final r = DailyResult.fromMap({});
      expect(r.dateKey, '');
      expect(r.hintsUsed, 0);
      expect(r.clean, isTrue);
    });

    test('one corrupt result does not discard the whole DailyRecord', () {
      final map = {
        'currentStreak': 3,
        'longestStreak': 5,
        'lastCompletedDate': '2026-06-08',
        'results': {
          '2026-06-08': {'dateKey': '2026-06-08'}, // missing hintsUsed
        },
      };
      final rec = DailyRecord.fromMap(map);
      expect(rec.currentStreak, 3);
      expect(rec.resultFor('2026-06-08')!.hintsUsed, 0);
    });
  });
}
