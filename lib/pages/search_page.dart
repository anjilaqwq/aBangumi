import 'package:flutter/material.dart';

import '../api/bangumi_api.dart';
import '../models/models.dart';
import '../widgets/common/common.dart';
import '../widgets/subject_card.dart';
import '../widgets/subject_type_selector.dart';
import 'subject_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  int _type = 2; // 默认动画
  int _requestGeneration = 0;
  bool _loading = false;
  String _keyword = '';
  List<Subject> _results = [];
  String? _error;

  Future<void> _submitSearch() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;

    await _search(keyword, type: _type, commitKeyword: true);
  }

  Future<void> _search(
    String keyword, {
    required int type,
    bool commitKeyword = false,
    bool clearResults = true,
  }) async {
    final generation = ++_requestGeneration;
    setState(() {
      _loading = true;
      _error = null;
      if (clearResults) _results = [];
      if (commitKeyword) _keyword = keyword;
    });

    try {
      final page = await BangumiApi.searchSubjects(keyword, type: type);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _loading = false;
        _results = page.items;
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _refresh() {
    final keyword = _keyword;
    final type = _type;
    if (keyword.isEmpty) return Future<void>.value();
    return _search(keyword, type: type, clearResults: false);
  }

  void _onTypeChanged(int type) {
    if (type == _type) return;

    final keyword = _keyword;
    setState(() => _type = type);
    if (keyword.isNotEmpty) {
      _search(keyword, type: type);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submitSearch(),
              decoration: InputDecoration(
                hintText: '搜索条目…',
                prefixIcon: Icon(Icons.search, color: colors.onSurfaceVariant),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: '搜索',
                  onPressed: _submitSearch,
                ),
                filled: true,
                fillColor: colors.surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colors.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colors.onSurface),
                ),
              ),
            ),
          ),
          SubjectTypeSelector(selected: _type, onChanged: _onTypeChanged),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _results.isEmpty) {
      return const LoadingState(message: '正在搜索…');
    }
    if (_error != null) {
      return ErrorState(message: '搜索失败：$_error', onRetry: _refresh);
    }
    if (_keyword.isEmpty) {
      return const EmptyState(message: '输入关键词开始搜索', icon: Icons.search);
    }
    if (_results.isEmpty) {
      return _refreshableState(
        const EmptyState(message: '没有找到相关条目', icon: Icons.search_off),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final subject = _results[index];
          return SubjectCard(
            subject: subject,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SubjectDetailPage(subjectId: subject.id),
              ),
            ),
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
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: constraints.maxHeight, child: state)],
        ),
      ),
    );
  }
}
