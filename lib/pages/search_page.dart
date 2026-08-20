import 'package:flutter/material.dart';

import '../api/bangumi_api.dart';
import '../models/models.dart';
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
  bool _loading = false;
  String _keyword = '';
  List<Subject> _results = [];
  String? _error;

  Future<void> _search() async {
    final kw = _controller.text.trim();
    if (kw.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
      _keyword = kw;
    });
    try {
      final page = await BangumiApi.searchSubjects(kw, type: _type);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _results = page.items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onTypeChanged(int t) {
    setState(() => _type = t);
    if (_keyword.isNotEmpty) _search(); // 已搜索过则按新类型重搜
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: '搜索条目…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('搜索失败：$_error', textAlign: TextAlign.center),
        ),
      );
    }
    if (_keyword.isEmpty) {
      return const Center(
          child: Text('输入关键词开始搜索', style: TextStyle(color: Colors.grey)));
    }
    if (_results.isEmpty) {
      return const Center(
          child: Text('没有找到相关条目', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final s = _results[i];
        return SubjectCard(
          subject: s,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => SubjectDetailPage(subjectId: s.id)),
          ),
        );
      },
    );
  }
}
