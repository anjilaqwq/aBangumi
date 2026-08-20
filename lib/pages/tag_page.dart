import 'package:flutter/material.dart';

import '../api/bangumi_api.dart';
import '../models/models.dart';
import '../widgets/subject_card.dart';
import 'subject_detail_page.dart';

/// 标签页：展示带有某个标签的条目（分页加载）
class TagPage extends StatefulWidget {
  final String tag;
  const TagPage({super.key, required this.tag});

  @override
  State<TagPage> createState() => _TagPageState();
}

class _TagPageState extends State<TagPage> {
  static const _pageSize = 30;
  final ScrollController _scroll = ScrollController();
  List<Subject> _items = [];
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

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await BangumiApi.searchSubjects(
        '',
        tags: [widget.tag],
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
    if (_loading || _loadingMore || _items.length >= _total) return;
    setState(() => _loadingMore = true);
    try {
      final page = await BangumiApi.searchSubjects(
        '',
        tags: [widget.tag],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('#${widget.tag}')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
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
          child: Text('这个标签下还没有条目', style: TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i < _items.length) {
            final s = _items[i];
            return SubjectCard(
              subject: s,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SubjectDetailPage(subjectId: s.id)),
              ),
            );
          }
          // 列表底部：加载更多 / 已到底
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
}
