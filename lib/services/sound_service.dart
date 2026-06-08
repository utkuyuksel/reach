import 'package:audioplayers/audioplayers.dart';

/// Sound behind an interface so tests/headless runs use a no-op and the game
/// can stay silent on failure. SFX (clear/win/tap/invalid) are short and
/// fire-and-forget; the ambient pad loops while gating is the caller's job
/// (the screen starts/stops it per the music setting).
///
/// The calm WAVs in assets/sounds/ are synthesized (see _spec/synth_sfx.py).
abstract class SoundService {
  Future<void> init();
  void clear();
  void win();
  void tap();
  void invalid();
  Future<void> startAmbient();
  Future<void> stopAmbient();
  void dispose();
}

/// No-op implementation (tests, or before a real audio backend is wired).
class NoopSoundService implements SoundService {
  @override
  Future<void> init() async {}
  @override
  void clear() {}
  @override
  void win() {}
  @override
  void tap() {}
  @override
  void invalid() {}
  @override
  Future<void> startAmbient() async {}
  @override
  Future<void> stopAmbient() async {}
  @override
  void dispose() {}
}

/// `audioplayers`-backed implementation. One player per SFX so different
/// effects can overlap; a separate looping player for the ambient pad.
class AudioPlayersSoundService implements SoundService {
  final _clear = AudioPlayer();
  final _win = AudioPlayer();
  final _tap = AudioPlayer();
  final _nope = AudioPlayer();
  final _ambient = AudioPlayer();
  bool _ambientPlaying = false;

  @override
  Future<void> init() async {
    try {
      for (final p in [_clear, _win, _tap, _nope]) {
        await p.setReleaseMode(ReleaseMode.stop);
      }
      await _clear.setVolume(0.7);
      await _win.setVolume(0.8);
      await _tap.setVolume(0.35);
      await _nope.setVolume(0.6);
      await _ambient.setReleaseMode(ReleaseMode.loop);
      await _ambient.setVolume(0.35);
    } catch (_) {
      // Audio is non-critical; never let it break the app.
    }
  }

  void _fire(AudioPlayer player, String asset) {
    // Restart from the top each time; ignore audio errors.
    player.play(AssetSource(asset)).catchError((_) {});
  }

  @override
  void clear() => _fire(_clear, 'sounds/clear.wav');
  @override
  void win() => _fire(_win, 'sounds/win.wav');
  @override
  void tap() => _fire(_tap, 'sounds/tap.wav');
  @override
  void invalid() => _fire(_nope, 'sounds/nope.wav');

  @override
  Future<void> startAmbient() async {
    if (_ambientPlaying) return;
    _ambientPlaying = true;
    try {
      await _ambient.play(AssetSource('sounds/ambient.wav'));
    } catch (_) {
      _ambientPlaying = false;
    }
  }

  @override
  Future<void> stopAmbient() async {
    _ambientPlaying = false;
    try {
      await _ambient.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final p in [_clear, _win, _tap, _nope, _ambient]) {
      p.dispose();
    }
  }
}
