import 'package:flutter/material.dart';

import '../store/proxy_store.dart';
import '../widgets/common/page_header.dart';

class ProxySettingsPage extends StatefulWidget {
  const ProxySettingsPage({super.key});

  @override
  State<ProxySettingsPage> createState() => _ProxySettingsPageState();
}

class _ProxySettingsPageState extends State<ProxySettingsPage> {
  late ProxyMode _mode;
  late ProxyProtocol _protocol;
  late final TextEditingController _host;
  late final TextEditingController _port;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final s = ProxyStore.instance.settings;
    _mode = s.mode;
    _protocol = s.protocol;
    _host = TextEditingController(text: s.host);
    _port = TextEditingController(text: s.port == 0 ? '' : '${s.port}');
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  String get _current {
    final s = ProxyStore.instance.settings;
    switch (s.mode) {
      case ProxyMode.off:
        return '关闭（直连）';
      case ProxyMode.automatic:
        return '自动${ProxyStore.instance.systemProxy == null ? '（未检测到系统代理）' : '（已读取系统代理）'}';
      case ProxyMode.manual:
        return '${s.protocol == ProxyProtocol.http ? 'HTTP' : 'SOCKS5'} ${s.host}:${s.port}';
    }
  }

  Future<void> _save() async {
    final port = int.tryParse(_port.text.trim()) ?? 0;
    setState(() => _saving = true);
    try {
      await ProxyStore.instance.save(
        ProxySettings(
          mode: _mode,
          host: _host.text,
          port: port,
          protocol: _protocol,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('代理设置已保存')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('FormatException: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      await ProxyStore.instance.testConnection();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('连接测试成功')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('连接测试失败，请检查代理或网络')));
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manual = _mode == ProxyMode.manual;
    return Scaffold(
      appBar: AppBar(title: const Text('代理设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          const PageHeader(title: '代理'),
          const SizedBox(height: 20),
          Text('当前设置', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Text(_current, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          SegmentedButton<ProxyMode>(
            segments: const [
              ButtonSegment(value: ProxyMode.off, label: Text('关闭')),
              ButtonSegment(value: ProxyMode.automatic, label: Text('自动')),
              ButtonSegment(value: ProxyMode.manual, label: Text('手动')),
            ],
            selected: {_mode},
            onSelectionChanged: (v) => setState(() => _mode = v.first),
          ),
          if (manual) ...[
            const SizedBox(height: 24),
            DropdownButtonFormField<ProxyProtocol>(
              initialValue: _protocol,
              decoration: const InputDecoration(labelText: '协议'),
              items: const [
                DropdownMenuItem(
                  value: ProxyProtocol.http,
                  child: Text('HTTP'),
                ),
                DropdownMenuItem(
                  value: ProxyProtocol.socks5,
                  child: Text('SOCKS5'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _protocol = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _host,
              decoration: const InputDecoration(
                labelText: '代理主机',
                hintText: '例如 10.0.2.2',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _port,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '端口',
                hintText: '例如 2080',
              ),
            ),
          ],
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _testing ? null : _test,
            icon: const Icon(Icons.network_check),
            label: Text(_testing ? '测试中…' : '测试连接'),
          ),
        ],
      ),
    );
  }
}
