import 'package:flutter/material.dart';

import '../api/bangumi_api.dart';
import '../models/models.dart';
import '../widgets/subject_card.dart';
import '../widgets/subject_type_selector.dart';
import 'subject_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _type = 2; // 默认动画
  late Future<List<Subject>> _future;

  @override
  void initState() {
    super.initState();
    _future = BangumiApi.topSubjects(type: _type);
  }

  void _reload() {
    setState(() {
      _future = BangumiApi.topSubjects(type: _type);
    });
  }

  void _onTypeChanged(int t) {
    setState(() {
      _type = t;
      _future = BangumiApi.topSubjects(type: t);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bangumi ${subjectTypeLabel(_type)}排行榜')),
      body: Column(
        children: [
          SubjectTypeSelector(selected: _type, onChanged: _onTypeChanged),
          Expanded(
            child: FutureBuilder<List<Subject>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _errorView(snap.error.toString());
                }
                final list = snap.data ?? const [];
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final s = list[i];
                      return SubjectCard(
                        subject: s,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  SubjectDetailPage(subjectId: s.id)),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('加载失败：$msg', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _reload, child: const Text('重试')),
            ],
          ),
        ),
      );
}
