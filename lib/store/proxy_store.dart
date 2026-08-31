import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Application-level proxy policy. VPN/Xray may already own system traffic;
/// this is only the Dart HttpClient fallback.
enum ProxyMode { off, automatic, manual }

enum ProxyProtocol { http }

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

  String get findProxy => 'PROXY $host:$port';

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
    // Network probing can take seconds on a fresh emulator or offline device.
    // Keep it out of the first-frame path; listeners receive the result later.
    unawaited(refreshSystemProxy());
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
    _systemProxy ??= await _discoverLocalHttpProxy();
    notifyListeners();
  }

  Future<String?> _discoverLocalHttpProxy() async {
    const ports = [2080, 2081, 7890, 10809, 1080, 8080];
    for (final port in ports) {
      Socket? socket;
      try {
        socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: const Duration(milliseconds: 350),
        );
      } on Object {
        continue;
      } finally {
        socket?.destroy();
      }

      final proxy = 'PROXY 127.0.0.1:$port';
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 4)
        ..findProxy = (_) => proxy;
      try {
        final request = await client.getUrl(
          Uri.parse('https://api.bgm.tv/calendar'),
        );
        final response = await request.close();
        await response.drain<void>();
        if (response.statusCode >= 200 && response.statusCode < 400) {
          return proxy;
        }
      } on Object {
        // 端口可能是纯 SOCKS 或其他本地服务，继续检查下一个端口。
      } finally {
        client.close(force: true);
      }
    }
    return null;
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

  Future<void> testConnection([ProxySettings? candidate]) async {
    final target = candidate ?? _settings;
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    client.findProxy = (_) {
      switch (target.mode) {
        case ProxyMode.off:
          return 'DIRECT';
        case ProxyMode.automatic:
          return _systemProxy ?? 'DIRECT';
        case ProxyMode.manual:
          return target.hasManualProxy ? target.findProxy : 'DIRECT';
      }
    };
    try {
      final request = await client.getUrl(
        Uri.parse('https://api.bgm.tv/calendar'),
      );
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 400) {
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
