import 'package:flutter/material.dart';

import '../api/bangumi_api.dart';
import '../models/models.dart';
import '../widgets/common/common.dart';
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
  int _nextOffset = 0;
  int _requestGeneration = 0;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _loadMoreError;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void didUpdateWidget(covariant TagPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag == widget.tag) return;

    if (_scroll.hasClients) _scroll.jumpTo(0);
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

  Future<void> _load({bool clearItems = true}) async {
    final generation = ++_requestGeneration;
    final tag = widget.tag;

    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _loadMoreError = null;
      if (clearItems) {
        _items = [];
        _total = 0;
        _nextOffset = 0;
        _hasMore = false;
      }
    });

    try {
      final page = await BangumiApi.searchSubjects(
        '',
        tags: [tag],
        limit: _pageSize,
        offset: 0,
      );
      if (!_isCurrentRequest(generation, tag)) return;

      final items = _uniqueSubjects(page.items);
      setState(() {
        _items = items;
        _total = page.total;
        _nextOffset = page.items.length;
        _hasMore = page.items.isNotEmpty && _nextOffset < _total;
        _loading = false;
      });
    } catch (error) {
      if (!_isCurrentRequest(generation, tag)) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _refresh() => _load(clearItems: false);

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;

    final generation = _requestGeneration;
    final tag = widget.tag;
    final offset = _nextOffset;
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });

    try {
      final page = await BangumiApi.searchSubjects(
        '',
        tags: [tag],
        limit: _pageSize,
        offset: offset,
      );
      if (!_isCurrentRequest(generation, tag)) return;

      final existingIds = _items.map((subject) => subject.id).toSet();
      final newItems = page.items
          .where((subject) => existingIds.add(subject.id))
          .toList();
      final nextOffset = offset + page.items.length;
      setState(() {
        _items = [..._items, ...newItems];
        _total = page.total;
        _nextOffset = nextOffset;
        _hasMore = page.items.isNotEmpty && nextOffset < _total;
        _loadingMore = false;
      });
    } catch (error) {
      if (!_isCurrentRequest(generation, tag)) return;
      setState(() {
        _loadingMore = false;
        _loadMoreError = error.toString();
      });
    }
  }

  bool _isCurrentRequest(int generation, String tag) {
    return mounted && generation == _requestGeneration && tag == widget.tag;
  }

  List<Subject> _uniqueSubjects(Iterable<Subject> subjects) {
    final ids = <int>{};
    return subjects.where((subject) => ids.add(subject.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('#${widget.tag}')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const LoadingState(message: '正在加载标签条目…');
    }
    if (_error != null) {
      return ErrorState(message: '加载失败：$_error', onRetry: _load);
    }
    if (_items.isEmpty) {
      return _refreshableState(
        const EmptyState(
          message: '这个标签下还没有条目',
          icon: Icons.local_offer_outlined,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          if (index < _items.length) {
            final subject = _items[index];
            return SubjectCard(
              subject: subject,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubjectDetailPage(subjectId: subject.id),
                ),
              ),
            );
          }
          if (_loadMoreError != null) {
            return ErrorState(
              message: '加载更多失败：$_loadMoreError',
              onRetry: _loadMore,
            );
          }
          return PagingFooter(
            loading: _loadingMore,
            hasMore: _hasMore,
            total: _total,
          );
        },
      ),
    );
  }

  Widget _refreshableState(Widget state) {
    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: constraints.maxHeight, child: state)],
        ),
      ),
    );
  }
}
