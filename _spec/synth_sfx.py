"""Synthesizes REACH's calm SFX + ambient as 16-bit PCM WAVs (pure stdlib).

Run from the project root:  python3 _spec/synth_sfx.py
Outputs into assets/sounds/. Re-run to regenerate. Tones are deliberately soft
(sine-based, gentle envelopes) to match the calm/zen aesthetic.
"""
import array
import math
import os
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")


def write_wav(name, samples, sr=SR):
    os.makedirs(OUT, exist_ok=True)
    data = array.array(
        "h", (max(-32767, min(32767, int(s * 32767))) for s in samples)
    )
    with wave.open(os.path.join(OUT, name), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


def tone(freq, dur, harmonics=((1, 1.0), (2, 0.28), (3, 0.10)),
         attack=0.006, decay_k=0.32, sr=SR):
    """A soft, bell-ish tone with quick attack + exponential decay."""
    n = int(dur * sr)
    out = [0.0] * n
    for i in range(n):
        t = i / sr
        if t < attack:
            env = t / attack
        else:
            env = math.exp(-(t - attack) / (dur * decay_k))
        s = 0.0
        for mult, amp in harmonics:
            s += amp * math.sin(2 * math.pi * freq * mult * t)
        out[i] = env * s
    peak = max(1e-9, max(abs(x) for x in out))
    return [0.85 * x / peak for x in out]


def mix_sequence(events, total_dur, sr=SR):
    """events: list of (start_sec, samples). Sum into one buffer."""
    n = int(total_dur * sr)
    out = [0.0] * n
    for start, samples in events:
        off = int(start * sr)
        for i, s in enumerate(samples):
            j = off + i
            if 0 <= j < n:
                out[j] += s
    peak = max(1e-9, max(abs(x) for x in out))
    return [0.85 * x / peak for x in out]


# --- clear: a single warm note (a group is cleared) ---
write_wav("clear.wav", tone(587.33, 0.30))  # D5

# --- win: a gentle ascending major arpeggio (board cleared) ---
notes = [523.25, 659.25, 783.99, 1046.50]  # C5 E5 G5 C6
events = [(i * 0.12, [0.9 * x for x in tone(f, 0.5, decay_k=0.5)])
          for i, f in enumerate(notes)]
write_wav("win.wav", mix_sequence(events, 0.12 * len(notes) + 0.5))

# --- tap: a very soft short tick (a tile joins the trace) ---
write_wav("tap.wav", [0.45 * x for x in tone(
    330.0, 0.055, harmonics=((1, 1.0), (2, 0.15)), attack=0.002, decay_k=0.25)])

# --- nope: a soft low thud (a wrong-sum trace) ---
write_wav("nope.wav", [0.6 * x for x in tone(
    150.0, 0.16, harmonics=((1, 1.0), (2, 0.18)), attack=0.004, decay_k=0.3)])


# --- ambient: a soft, slowly breathing pad that loops seamlessly ---
def ambient(dur=8.0, sr=SR):
    n = int(dur * sr)
    chord = [130.81, 196.00, 261.63, 392.00]  # C3 G3 C4 G4 (open, calm)
    out = [0.0] * n
    for i in range(n):
        t = i / sr
        # slow amplitude breathing
        lfo = 0.5 + 0.5 * math.sin(2 * math.pi * (1 / dur) * t)
        s = 0.0
        for k, f in enumerate(chord):
            amp = 0.5 / (k + 1)
            s += amp * math.sin(2 * math.pi * f * t)
        out[i] = 0.16 * (0.55 + 0.45 * lfo) * s
    # crossfade tail into head, then drop the tail → seamless loop
    fade = int(0.4 * sr)
    for i in range(fade):
        a = i / fade
        out[i] = out[i] * a + out[n - fade + i] * (1 - a)
    return out[: n - fade]


write_wav("ambient.wav", ambient())

print("OK: wrote", os.listdir(OUT))
