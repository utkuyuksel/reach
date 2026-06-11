import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'persisted_models.dart';
import 'storage_service.dart';

/// [StorageService] backed by `shared_preferences`. Each domain is stored as a
/// single JSON string; values are cached in memory after [init] so reads are
/// synchronous.
class PrefsStorageService implements StorageService {
  static const _kSettings = 'reach.settings.v1';
  static const _kPremium = 'reach.premium.v1';
  static const _kDaily = 'reach.daily.v1';
  static const _kZen = 'reach.zen.v1';
  static const _kWallet = 'reach.wallet.v1';
  static const _kStats = 'reach.stats.v1';
  static const _kMosaic = 'reach.mosaic.v1';

  late SharedPreferences _prefs;

  Settings _settings = const Settings();
  bool _premium = false;
  DailyRecord _daily = const DailyRecord();
  ZenRecord _zen = const ZenRecord();
  StatsRecord _stats = const StatsRecord();
  MosaicRecord _mosaic = const MosaicRecord();
  WalletRecord? _wallet;

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _settings = _readMap(_kSettings, Settings.fromMap) ?? const Settings();
    _premium = _prefs.getBool(_kPremium) ?? false;
    _daily = _readMap(_kDaily, DailyRecord.fromMap) ?? const DailyRecord();
    _zen = _readMap(_kZen, ZenRecord.fromMap) ?? const ZenRecord();
    _stats = _readMap(_kStats, StatsRecord.fromMap) ?? const StatsRecord();
    _mosaic = _readMap(_kMosaic, MosaicRecord.fromMap) ?? const MosaicRecord();
    _wallet = _readMap(_kWallet, WalletRecord.fromMap);
  }

  T? _readMap<T>(String key, T Function(Map<String, dynamic>) fromMap) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // corrupt/old data → fall back to defaults
    }
  }

  @override
  Settings loadSettings() => _settings;

  @override
  Future<void> saveSettings(Settings settings) async {
    _settings = settings;
    await _prefs.setString(_kSettings, jsonEncode(settings.toMap()));
  }

  @override
  bool loadPremium() => _premium;

  @override
  Future<void> savePremium(bool premium) async {
    _premium = premium;
    await _prefs.setBool(_kPremium, premium);
  }

  @override
  DailyRecord loadDaily() => _daily;

  @override
  Future<void> saveDaily(DailyRecord record) async {
    _daily = record;
    await _prefs.setString(_kDaily, jsonEncode(record.toMap()));
  }

  @override
  ZenRecord loadZen() => _zen;

  @override
  Future<void> saveZen(ZenRecord record) async {
    _zen = record;
    await _prefs.setString(_kZen, jsonEncode(record.toMap()));
  }

  @override
  StatsRecord loadStats() => _stats;

  @override
  Future<void> saveStats(StatsRecord record) async {
    _stats = record;
    await _prefs.setString(_kStats, jsonEncode(record.toMap()));
  }

  @override
  MosaicRecord loadMosaic() => _mosaic;

  @override
  Future<void> saveMosaic(MosaicRecord record) async {
    _mosaic = record;
    await _prefs.setString(_kMosaic, jsonEncode(record.toMap()));
  }

  @override
  WalletRecord? loadWallet() => _wallet;

  @override
  Future<void> saveWallet(WalletRecord record) async {
    _wallet = record;
    await _prefs.setString(_kWallet, jsonEncode(record.toMap()));
  }
}

/// In-memory [StorageService] for tests and quick dev runs (no disk I/O).
class InMemoryStorageService implements StorageService {
  Settings _settings = const Settings();
  bool _premium = false;
  DailyRecord _daily = const DailyRecord();
  ZenRecord _zen = const ZenRecord();
  StatsRecord _stats = const StatsRecord();
  MosaicRecord _mosaic = const MosaicRecord();
  WalletRecord? _wallet;

  @override
  Future<void> init() async {}

  @override
  Settings loadSettings() => _settings;
  @override
  Future<void> saveSettings(Settings settings) async => _settings = settings;

  @override
  bool loadPremium() => _premium;
  @override
  Future<void> savePremium(bool premium) async => _premium = premium;

  @override
  DailyRecord loadDaily() => _daily;
  @override
  Future<void> saveDaily(DailyRecord record) async => _daily = record;

  @override
  ZenRecord loadZen() => _zen;
  @override
  Future<void> saveZen(ZenRecord record) async => _zen = record;

  @override
  StatsRecord loadStats() => _stats;
  @override
  Future<void> saveStats(StatsRecord record) async => _stats = record;

  @override
  MosaicRecord loadMosaic() => _mosaic;
  @override
  Future<void> saveMosaic(MosaicRecord record) async => _mosaic = record;

  @override
  WalletRecord? loadWallet() => _wallet;
  @override
  Future<void> saveWallet(WalletRecord record) async => _wallet = record;
}
