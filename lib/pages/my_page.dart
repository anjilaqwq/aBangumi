import 'package:flutter/material.dart';

import '../api/bangumi_api.dart';
import '../models/models.dart';
import '../store/auth_store.dart';
import 'subject_detail_page.dart';

class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ValueListenableBuilder<String?>(
        valueListenable: AuthStore.instance.token,
        builder: (context, token, _) {
          if (token == null || token.isEmpty) return const _LoginView();
          return const _ProfileView();
        },
      ),
    );
  }
}

// ---------------- 登录 ----------------

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthStore.instance.login(_controller.text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '登录失败：$e';
        });
      }
      return;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle_outlined,
                size: 72, color: Color(0xFFF09199)),
            const SizedBox(height: 16),
            const Text('登录 Bangumi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '在 bgm.tv 设置页生成访问令牌后粘贴到下方',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: '访问令牌 (Access Token)',
                hintText: '粘贴你的 token',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('登录'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 个人资料 + 收藏（分页 + 筛选） ----------------

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  static const _pageSize = 50;
  final ScrollController _scroll = ScrollController();

  int _collectionType = 0; // 0 = 全部（收藏类型）
  int _subjectType = 0; // 0 = 全部（条目类型）
  List<Collection> _items = [];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  User? get _user => AuthStore.instance.user.value;
  String? get _token => AuthStore.instance.token.value;

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    final token = _token;
    final user = _user;
    if (token == null || user == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await BangumiApi.userCollections(
        token,
        user.username,
        collectionType: _collectionType == 0 ? null : _collectionType,
        subjectType: _subjectType == 0 ? null : _subjectType,
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _total = page.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore) return;
    if (_items.length >= _total) return;
    final token = _token;
    final user = _user;
    if (token == null || user == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await BangumiApi.userCollections(
        token,
        user.username,
        collectionType: _collectionType == 0 ? null : _collectionType,
        subjectType: _subjectType == 0 ? null : _subjectType,
        limit: _pageSize,
        offset: _items.length,
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...page.items];
        _total = page.total;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _selectCollectionType(int t) {
    if (_collectionType == t) return;
    setState(() => _collectionType = t);
    _load();
  }

  void _selectSubjectType(int t) {
    if (_subjectType == t) return;
    setState(() => _subjectType = t);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        _header(user),
        _chipRow('条目类型', [
          _chipOption('全部', _subjectType == 0, () => _selectSubjectType(0)),
          ...kSubjectTypes.map((e) =>
              _chipOption(e.value, _subjectType == e.key, () => _selectSubjectType(e.key))),
        ]),
        _chipRow('收藏状态', [
          _chipOption('全部', _collectionType == 0, () => _selectCollectionType(0)),
          ...kCollectionTypes.map((e) => _chipOption(
              e.value, _collectionType == e.key, () => _selectCollectionType(e.key))),
        ]),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _chipRow(String title, List<Widget> chips) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 0),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(title,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ),
          Expanded(
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: chips,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipOption(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: ChoiceChip(
        label: Text(label),
        labelStyle: const TextStyle(fontSize: 12),
        selected: selected,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _header(User u) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundImage:
                u.avatarLarge.isNotEmpty ? NetworkImage(u.avatarLarge) : null,
            child: u.avatarLarge.isEmpty ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(u.displayName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text('@${u.username}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
                if (u.sign.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(u.sign,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.grey),
            tooltip: '退出登录',
            onPressed: () => AuthStore.instance.logout(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('加载失败：$_error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
          child: Text('这里空空如也', style: TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i < _items.length) return _collectionTile(_items[i]);
          if (_loadingMore) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          if (_items.length >= _total) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  '已加载全部 $_total 条',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ),
            );
          }
          return const SizedBox(height: 40);
        },
      ),
    );
  }

  Widget _collectionTile(Collection c) {
    final s = c.subject;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => SubjectDetailPage(subjectId: s.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: s.cover.isNotEmpty
                    ? Image.network(
                        s.cover,
                        width: 56,
                        height: 78,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _coverPlaceholder(),
                      )
                    : _coverPlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _chip(c.typeLabel),
                        if (c.rate > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _chip('评分 ${c.rate}'),
                          ),
                        if (c.isPrivate)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.lock_outline,
                                size: 14, color: Colors.grey),
                          ),
                      ],
                    ),
                    if (c.comment.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(c.comment,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverPlaceholder() => Container(
        width: 56,
        height: 78,
        color: Colors.grey[300],
        child: const Icon(Icons.image_not_supported_outlined,
            color: Colors.grey, size: 20),
      );

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11)),
      );
}
