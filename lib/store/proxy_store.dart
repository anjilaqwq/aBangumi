import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Application-level proxy policy. VPN/Xray may already own system traffic;
/// this is only the Dart HttpClient fallback.
enum ProxyMode { off, automatic, manual }

enum ProxyProtocol { http, socks5 }

class ProxySettings {
  final ProxyMode mode;
  final String host;
  final int port;
  final ProxyProtocol protocol;

  const ProxySettings({
    this.mode = ProxyMode.off,
    this.host = '',
    this.port = 0,
    this.protocol = ProxyProtocol.http,
  });

  String get findProxy {
    final scheme = protocol == ProxyProtocol.socks5 ? 'SOCKS5' : 'PROXY';
    return '$scheme $host:$port';
  }

  bool get hasManualProxy =>
      host.trim().isNotEmpty && port > 0 && port <= 65535;
}

class ProxyStore extends ChangeNotifier {
  ProxyStore._();
  static final instance = ProxyStore._();

  static const _channel = MethodChannel('abgm/proxy');
  static const _modeKey = 'proxy.mode';
  static const _hostKey = 'proxy.host';
  static const _portKey = 'proxy.port';
  static const _protocolKey = 'proxy.protocol';

  ProxySettings _settings = const ProxySettings();
  String? _systemProxy;
  SharedPreferences? _prefs;

  ProxySettings get settings => _settings;
  String? get systemProxy => _systemProxy;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final mode = ProxyMode.values.firstWhere(
      (e) => e.name == _prefs!.getString(_modeKey),
      orElse: () => ProxyMode.off,
    );
    final protocol = ProxyProtocol.values.firstWhere(
      (e) => e.name == _prefs!.getString(_protocolKey),
      orElse: () => ProxyProtocol.http,
    );
    _settings = ProxySettings(
      mode: mode,
      host: _prefs!.getString(_hostKey) ?? '',
      port: _prefs!.getInt(_portKey) ?? 0,
      protocol: protocol,
    );
    await refreshSystemProxy();
  }

  Future<void> refreshSystemProxy() async {
    try {
      final value = await _channel.invokeMethod<String>('getProxy');
      _systemProxy = value != null && value.isNotEmpty && value != 'DIRECT'
          ? value
          : null;
    } on MissingPluginException {
      _systemProxy = null;
    } on PlatformException {
      _systemProxy = null;
    }
    notifyListeners();
  }

  Future<void> save(ProxySettings value) async {
    if (value.mode == ProxyMode.manual && !value.hasManualProxy) {
      throw const FormatException('请输入有效的代理地址和端口');
    }
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, value.mode.name);
    await prefs.setString(_hostKey, value.host.trim());
    await prefs.setInt(_portKey, value.port);
    await prefs.setString(_protocolKey, value.protocol.name);
    _settings = value.copyWith(host: value.host.trim());
    notifyListeners();
  }

  String? proxyFor(Uri uri) {
    // OAuth BFF and all non-Bangumi hosts must never be intercepted.
    final host = uri.host.toLowerCase();
    if (!(host == 'bgm.tv' || host.endsWith('.bgm.tv'))) return null;
    switch (_settings.mode) {
      case ProxyMode.off:
        return null;
      case ProxyMode.manual:
        return _settings.hasManualProxy ? _settings.findProxy : null;
      case ProxyMode.automatic:
        return _systemProxy;
    }
  }

  Future<void> testConnection() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse('https://api.bgm.tv/'));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 500) {
        throw HttpException('HTTP ${response.statusCode}');
      }
    } finally {
      client.close(force: true);
    }
  }
}

extension on ProxySettings {
  ProxySettings copyWith({
    ProxyMode? mode,
    String? host,
    int? port,
    ProxyProtocol? protocol,
  }) => ProxySettings(
    mode: mode ?? this.mode,
    host: host ?? this.host,
    port: port ?? this.port,
    protocol: protocol ?? this.protocol,
  );
}
