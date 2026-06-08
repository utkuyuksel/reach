export const meta = {
  name: 'reach-app-review',
  description: 'Read-only adversarial review of the REACH app layer (state, services, UI, spec compliance)',
  phases: [
    { title: 'Review', detail: 'parallel lenses over the app layer' },
    { title: 'Verify', detail: 'adversarially confirm each finding (read-only)' },
  ],
};

const ROOT = '/Users/utku/Desktop/REACH';

const FINDINGS_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['title', 'severity', 'file', 'detail', 'confidence'],
        properties: {
          title: { type: 'string' },
          severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low', 'nit'] },
          file: { type: 'string', description: 'path:line' },
          detail: { type: 'string', description: 'what is wrong and why it matters, plus suggested fix' },
          confidence: { type: 'string', enum: ['certain', 'likely', 'speculative'] },
        },
      },
    },
  },
};

const VERDICT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['isReal', 'explanation'],
  properties: {
    isReal: { type: 'boolean' },
    explanation: { type: 'string' },
    suggestedFix: { type: 'string' },
  },
};

const common = [
  'You are reviewing the Flutter app layer of REACH, a calm number-merge puzzle. Project root: ' + ROOT + '.',
  'READ-ONLY: do NOT modify, create, or delete any files. You MAY run `dart analyze lib test` and `flutter test` to check things, but never edit source.',
  '',
  'THE GAME: tap a tile then an orthogonally-adjacent tile to FUSE (sum into one cell; other empties; no gravity). Win = build a tile EXACTLY equal to the target (overshoot is a soft, undoable state, never a win or fail). Modes: Daily (deterministic per local date, streak, spoiler-free share) and Zen (endless, gentle ramp, fewest-fuses par). Monetization is gentle and NEVER gates progress: rewarded ad grants an optional hint; interstitial every 7 Zen solves (never Daily, never Premium); one-time Premium removes ads + unlimited hints + cosmetic palettes. Pure-Dart engine under lib/engine is already audited and trusted; focus on the APP layer.',
  '',
  'KEY FILES: lib/game/state/*.dart (Riverpod controllers: game_controller, daily_controller, zen_controller, entitlement_controller, settings_controller, providers, game_session), lib/services/*.dart (storage/ad/purchase interfaces + dev + real impls), lib/game/screens/*.dart, lib/game/widgets/*.dart, lib/game/theme/*.dart, lib/main.dart, lib/config/*.dart.',
  '',
  'Report ONLY concrete, defensible problems (bugs, spec violations, crashes, state-management mistakes, async/mounted issues, persistence round-trip bugs, monetization gating progress, accessibility/colourblind gaps). An empty findings list is fine. No style nits.',
].join('\n');

const LENSES = [
  { key: 'state', focus: 'State & controllers. Riverpod wiring correctness; the win-recording guard (no double counting of Zen solves / Daily completion across undo+re-win); daily streak math across day boundaries and gaps (daily_controller + util/date_key); zen ramp; entitlement stream subscription + restore-on-launch + onDispose; hint reveal flow; GameController.tap no-op detection and win side effects. Find logic bugs.' },
  { key: 'spec', focus: 'Spec compliance. Win must be EXACT equality (not >=); overshoot must never win or fail. Monetization must NEVER gate progress (hint optional, no interstitial in Daily, none for Premium, no lives/energy/currency). Daily share must be spoiler-free (no target/positions). Language-independent core (no gameplay words). Colourblind-safe (state via shape/icon not colour alone). Find any violation.' },
  { key: 'ui', focus: 'Flutter/UI correctness. async-gap BuildContext use without mounted checks; setState after dispose; AnimatedSwitcher keying for fuse pops; board sizing/overflow on small screens (RenderFlex overflow), the 6x6 board fitting in portrait; navigation/pop correctness; win sheet overlay intercepting taps appropriately; switch exhaustiveness; potential null derefs on GameSession. Find runtime/layout bugs.' },
  { key: 'services', focus: 'Services. GoogleAdService rewarded/interstitial load+show+reload lifecycle and the earned-reward completer; StorePurchaseService buy/restore/completePurchase/pendingCompletePurchase and the premium stream; PrefsStorageService JSON round-trip for Settings/DailyRecord/ZenRecord (esp. nested maps) and corrupt-data fallback; main.dart service selection + ProviderScope overrides + init order. Find correctness bugs (assume real services path matters).' },
];

phase('Review');
const results = await pipeline(
  LENSES,
  (lens) => agent(common + '\n\nLENS: ' + lens.focus, { label: 'review:' + lens.key, phase: 'Review', schema: FINDINGS_SCHEMA, agentType: 'Explore' }),
  (res, lens) => {
    const findings = (res && res.findings) ? res.findings : [];
    return parallel(findings.map((f) => () =>
      agent(
        common +
        '\n\nA prior reviewer reported this finding. ADVERSARIALLY verify whether it is REAL and matters. Default to skepticism; re-read the actual code (and run dart analyze / flutter test if useful) before concluding. READ-ONLY: do not edit any file. Conclude isReal=false if you cannot demonstrate the problem.\n\n' +
        'FINDING\nTitle: ' + f.title + '\nSeverity: ' + f.severity + '\nFile: ' + f.file + '\nDetail: ' + f.detail + '\nReporter confidence: ' + f.confidence,
        { label: 'verify:' + lens.key, phase: 'Verify', schema: VERDICT_SCHEMA, agentType: 'Explore' }
      ).then((v) => ({ lens: lens.key, finding: f, verdict: v }))));
  }
);

const flat = results.flat().filter(Boolean);
const confirmed = flat.filter((r) => r.verdict && r.verdict.isReal);
const dismissed = flat.filter((r) => r.verdict && !r.verdict.isReal);

log('App review complete: ' + flat.length + ' findings examined, ' + confirmed.length + ' confirmed real.');

return {
  confirmedCount: confirmed.length,
  confirmed: confirmed.map((r) => ({
    lens: r.lens,
    title: r.finding.title,
    severity: r.finding.severity,
    file: r.finding.file,
    detail: r.finding.detail,
    explanation: r.verdict.explanation,
    suggestedFix: r.verdict.suggestedFix || '',
  })),
  dismissedTitles: dismissed.map((r) => '[' + r.lens + '] ' + r.finding.title),
};
