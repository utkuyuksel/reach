import 'package:firebase_analytics/firebase_analytics.dart';

import 'analytics_service.dart';

/// Real [AnalyticsService] backed by Firebase Analytics. Only constructed in
/// the real-services build, AFTER `Firebase.initializeApp()` has run (see
/// `main.dart`). Call sites are unchanged — they just call [log].
class FirebaseAnalyticsService implements AnalyticsService {
  final FirebaseAnalytics _fa = FirebaseAnalytics.instance;

  @override
  Future<void> init() => _fa.setAnalyticsCollectionEnabled(true);

  @override
  void log(String event, [Map<String, Object?> params = const {}]) {
    // Fire-and-forget; never let analytics throw into gameplay.
    _fa.logEvent(name: event, parameters: _sanitize(params)).catchError((_) {});
  }

  /// Firebase event parameters accept only String/num values. Coerce bools to
  /// 0/1, stringify anything else, and drop nulls.
  Map<String, Object>? _sanitize(Map<String, Object?> params) {
    if (params.isEmpty) return null;
    final out = <String, Object>{};
    params.forEach((key, value) {
      if (value == null) return;
      if (value is num || value is String) {
        out[key] = value;
      } else if (value is bool) {
        out[key] = value ? 1 : 0;
      } else {
        out[key] = value.toString();
      }
    });
    return out.isEmpty ? null : out;
  }
}
