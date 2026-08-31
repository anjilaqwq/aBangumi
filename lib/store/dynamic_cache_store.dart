import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight stale-while-offline cache for anonymous page data.
///
/// Authenticated responses are intentionally excluded by API callers. Values
/// are mirrored in memory for fast tab switches and persisted so the first
/// frame after a cold start can still use recent data.
class DynamicCacheStore {
  DynamicCacheStore._();

  static final instance = DynamicCacheStore._();

  static const _prefix = 'dynamic-cache.v1.';
  static const _maxMemoryEntries = 28;
  static const _maxDiskEntries = 48;
  static const _maxDiskAge = Duration(days: 7);
  final Map<String, _CacheRecord> _memory = {};
  final Map<String, Future<dynamic>> _inFlight = {};
  SharedPreferences? _preferences;
  bool _diskPruned = false;

  Future<dynamic> loadJson({
    required String key,
    required Future<dynamic> Function() loader,
    Duration maxAge = const Duration(minutes: 10),
    bool forceRefresh = false,
  }) async {
    final cacheKey = _cacheKey(key);
    final cached = await _read(cacheKey);
    if (!forceRefresh && cached != null && cached.isFresh(maxAge)) {
      return cached.value;
    }

    final running = _inFlight[cacheKey];
    if (running != null) return running;

    final request = () async {
      try {
        final value = await loader();
        await _write(cacheKey, value);
        return value;
      } catch (_) {
        if (cached != null) return cached.value;
        rethrow;
      } finally {
        _inFlight.remove(cacheKey);
      }
    }();
    _inFlight[cacheKey] = request;
    return request;
  }

  Future<void> remove(String key) async {
    final cacheKey = _cacheKey(key);
    _memory.remove(cacheKey);
    final preferences = _preferences ??= await SharedPreferences.getInstance();
    await preferences.remove(cacheKey);
  }

  Future<_CacheRecord?> _read(String cacheKey) async {
    final memory = _memory[cacheKey];
    if (memory != null) {
      _memory
        ..remove(cacheKey)
        ..[cacheKey] = memory;
      return memory;
    }

    final preferences = await _prefs();
    final raw = preferences.getString(cacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      final record = _CacheRecord(
        savedAt: DateTime.fromMillisecondsSinceEpoch(
          (envelope['savedAt'] as num).toInt(),
        ),
        value: envelope['value'],
      );
      _remember(cacheKey, record);
      return record;
    } on Object {
      await preferences.remove(cacheKey);
      return null;
    }
  }

  Future<void> _write(String cacheKey, dynamic value) async {
    final record = _CacheRecord(savedAt: DateTime.now(), value: value);
    _remember(cacheKey, record);
    final preferences = await _prefs();
    await preferences.setString(
      cacheKey,
      jsonEncode({
        'savedAt': record.savedAt.millisecondsSinceEpoch,
        'value': value,
      }),
    );
  }

  String _cacheKey(String key) => '$_prefix${sha256.convert(utf8.encode(key))}';

  void _remember(String key, _CacheRecord record) {
    _memory
      ..remove(key)
      ..[key] = record;
    while (_memory.length > _maxMemoryEntries) {
      _memory.remove(_memory.keys.first);
    }
  }

  Future<SharedPreferences> _prefs() async {
    final preferences = _preferences ??= await SharedPreferences.getInstance();
    if (!_diskPruned) {
      _diskPruned = true;
      await _pruneDisk(preferences);
    }
    return preferences;
  }

  Future<void> _pruneDisk(SharedPreferences preferences) async {
    final entries = <MapEntry<String, DateTime>>[];
    final now = DateTime.now();
    for (final key in preferences.getKeys().where(
      (key) => key.startsWith(_prefix),
    )) {
      try {
        final raw = preferences.getString(key);
        final envelope = jsonDecode(raw!) as Map<String, dynamic>;
        final savedAt = DateTime.fromMillisecondsSinceEpoch(
          (envelope['savedAt'] as num).toInt(),
        );
        if (now.difference(savedAt) > _maxDiskAge) {
          await preferences.remove(key);
        } else {
          entries.add(MapEntry(key, savedAt));
        }
      } on Object {
        await preferences.remove(key);
      }
    }
    entries.sort((a, b) => b.value.compareTo(a.value));
    for (final entry in entries.skip(_maxDiskEntries)) {
      await preferences.remove(entry.key);
    }
  }
}

class _CacheRecord {
  final DateTime savedAt;
  final dynamic value;

  const _CacheRecord({required this.savedAt, required this.value});

  bool isFresh(Duration maxAge) => DateTime.now().difference(savedAt) <= maxAge;
}
