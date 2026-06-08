export const meta = {
  name: 'reach-engine-audit',
  description: 'Adversarial correctness audit of the REACH pure-Dart engine + stress test',
  phases: [
    { title: 'Audit', detail: 'parallel lenses over the engine' },
    { title: 'Verify', detail: 'adversarially confirm each finding, ideally with a runnable repro' },
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
          detail: { type: 'string', description: 'what is wrong and why it matters' },
          repro: { type: 'string', description: 'concrete seed/grid/input that triggers it, or a Dart snippet; empty if none' },
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
    evidence: { type: 'string', description: 'what you ran/checked; output if you ran a repro' },
    suggestedFix: { type: 'string' },
  },
};

const common = [
  'You are auditing a pure-Dart puzzle engine for a Flutter game called REACH.',
  'Project root: ' + ROOT + '. Engine files are under lib/engine/ (rng.dart, difficulty.dart, solver.dart, generator.dart, models/tile.dart, models/grid.dart, models/puzzle.dart, models/game_state.dart). The stress test is test/engine/generator_stress_test.dart and other tests are in test/engine/.',
  '',
  'THE MECHANIC: an RxC grid of positive-int tiles. Tap a tile then an orthogonally-adjacent tile to FUSE them (sum into one cell; the other empties; no gravity/sliding). Goal: build a tile equal to a target. Solvability is guaranteed by construction: the target is the sum of a randomly grown CONNECTED region, and any connected region can be collapsed to one tile = its sum by fusing spanning-tree leaves into their parents (the parent never moves, so each tree edge stays a physical adjacency at fuse time).',
  '',
  'The stress test currently passes: 20000 seeds/tier x 3 tiers verified solvable+non-degenerate by replaying each puzzle to a win, plus 4000/tier par-consistency checks. dart analyze is clean.',
  '',
  'Read the relevant files first. You MAY run Dart to prove a point: write a temp test under ' + ROOT + '/test/audit_tmp_X.dart and run it with: cd ' + ROOT + ' && flutter test test/audit_tmp_X.dart  (note: flutter analyze is broken in this env, use dart analyze instead). Delete any temp files you create when done.',
  '',
  'Report ONLY concrete, defensible findings. An empty findings list is a perfectly good answer if the area is correct. Do not invent style nits.',
].join('\n');

const LENSES = [
  { key: 'solvability', focus: 'Solvability proof. Scrutinize Solver.contractionSequence and Grid.fuse. Is it TRUE that for ANY connected region, replaying the returned [source,dest] sequence through legal adjacent fuses always (a) keeps both endpoints occupied and orthogonally adjacent at the moment of each fuse, and (b) ends with a single tile equal to the region sum? Look for a region shape (a cycle in the grid graph, a comb, a spiral, a plus) where the BFS-tree / reverse-discovery-order contraction could fail or reference a non-adjacent or already-emptied cell. Try to construct a counterexample region and prove it with a runnable Dart snippet.' },
  { key: 'generator', focus: 'Generator robustness. Scrutinize Generator.generate and _growRegion. Can it throw StateError (exhaust attempts) for any of the 3 tiers or any zenLadder rung? Can regionMin exceed regionCeiling? Can _growRegion fail to reach the requested size? Are the degeneracy rejections (target==single tile, target==whole-board sum) correct and sufficient? Could a trivial puzzle slip through? Check EVERY Difficulty config in difficulty.dart (tiers + zenLadder) for invariant violations (2 <= regionMin <= regionMax < rows*cols).' },
  { key: 'solver', focus: 'Solver minimality and correctness. Scrutinize Solver.minimalRegion. Does its BFS truly return the MINIMUM-size connected region summing to target? Consider the sizeCap claim, the sum-pruning (positive values only), the bitmask visited-set dedup, and whether stratification by popcount==BFS-level is actually guaranteed. Find an input where it returns a non-minimal region, misses an existing region, or returns an invalid one. Prove with a Dart snippet if possible.' },
  { key: 'rng', focus: 'RNG and determinism. Scrutinize rng.dart (DeterministicRng / splitmix64) and Generator.dailySeed. Is the 64-bit wrapping-arithmetic assumption valid on the mobile VM/AOT target, and is the modulo bias negligible? Is (seed)->sequence reproducible across devices/SDK versions (Daily requires identical puzzles for everyone on the same date)? Are there seeds that produce degenerate sequences (seed 0)? Does dailySeed behave oddly at month/year boundaries? Verify the splitmix64 constants against the canonical algorithm.' },
  { key: 'stress-rigor', focus: 'Stress-test rigor: what does the test FAIL to cover? Scrutinize test/engine/generator_stress_test.dart and the other engine tests. Does the replay exercise the SAME tap/fuse logic the UI uses (GameState.tap), including selection/adjacency rules? Gaps: daily-seed puzzles never generated in the stress loop, zenLadder rungs never stress-tested, no explicit assert that a fresh puzzle has NO tile already == target at start, overshoot, the tap-empty-deselects and non-adjacent-reselect branches. List concrete missing coverage that could hide a real bug, ranked by risk.' },
];

phase('Audit');
const results = await pipeline(
  LENSES,
  (lens) => agent(common + '\n\nLENS: ' + lens.focus, { label: 'audit:' + lens.key, phase: 'Audit', schema: FINDINGS_SCHEMA, agentType: 'Explore' }),
  (res, lens) => {
    const findings = (res && res.findings) ? res.findings : [];
    return parallel(findings.map((f) => () =>
      agent(
        common +
        '\n\nA prior auditor reported this finding. ADVERSARIALLY verify whether it is REAL and matters. Default to skepticism. If a repro is given, actually run it (write a temp test, run it, read the output) before concluding. If none, try to construct one. Conclude isReal=false if you cannot demonstrate the problem.\n\n' +
        'FINDING\nTitle: ' + f.title + '\nSeverity: ' + f.severity + '\nFile: ' + f.file + '\nDetail: ' + f.detail + '\nRepro: ' + (f.repro || '(none provided)') + '\nReporter confidence: ' + f.confidence,
        { label: 'verify:' + lens.key, phase: 'Verify', schema: VERDICT_SCHEMA }
      ).then((v) => ({ lens: lens.key, finding: f, verdict: v }))));
  }
);

const flat = results.flat().filter(Boolean);
const confirmed = flat.filter((r) => r.verdict && r.verdict.isReal);
const dismissed = flat.filter((r) => r.verdict && !r.verdict.isReal);

log('Audit complete: ' + flat.length + ' findings examined, ' + confirmed.length + ' confirmed real.');

return {
  confirmedCount: confirmed.length,
  confirmed: confirmed.map((r) => ({
    lens: r.lens,
    title: r.finding.title,
    severity: r.finding.severity,
    file: r.finding.file,
    detail: r.finding.detail,
    explanation: r.verdict.explanation,
    evidence: r.verdict.evidence || '',
    suggestedFix: r.verdict.suggestedFix || '',
  })),
  dismissedTitles: dismissed.map((r) => '[' + r.lens + '] ' + r.finding.title + ' -- ' + r.verdict.explanation),
};
