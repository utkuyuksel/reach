# Music licensing

Every track bundled here MUST have a row in this table before shipping —
App Store / Play Store reviews can ask for proof of license.

| File | Title | Artist | Source | License | Date added |
|---|---|---|---|---|---|
| leberch_513745.m4a | Piano | Leberch | pixabay.com/music (id 513745) | Pixabay Content License | 2026-06-12 |
| dreamscape_529861.m4a | Calm Ambient Dreamscape | Morgan | pixabay.com/music (id 529861) | Pixabay Content License | 2026-06-12 |
| paulyudin_508963.m4a | Piano Music | Paul Yudin | pixabay.com/music (id 508963) | Pixabay Content License | 2026-06-12 |
| mountain_522474.m4a | Piano | The Mountain | pixabay.com/music (id 522474) | Pixabay Content License | 2026-06-12 |
| mountain_490009.m4a | Piano Music | The Mountain | pixabay.com/music (id 490009) | Pixabay Content License | 2026-06-12 |

Originals were 256 kbps Pixabay MP3s, re-encoded to 112 kbps AAC (M4A) via
`afconvert` (22 MB → 9.5 MB). The old synthesized pad
(`assets/sounds/ambient.wav`, from `_spec/synth_sfx.py`) remains only as an
unused in-house asset.

Sourcing rule (owner decision, June 2026): use **Pixabay Music**
(https://pixabay.com/music/) — its Content License allows free commercial
use in apps, no attribution required. Avoid CC-BY (attribution chores) and
freesound (mixed licenses). Compress to ~96–128 kbps M4A, seamless loop,
target < 2 MB per track and < 6 MB total.
