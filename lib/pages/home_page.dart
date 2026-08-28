import 'package:flutter/material.dart';

import '../api/bangumi_api.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../widgets/common/common.dart';
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

  Future<void> _reload() async {
    final future = BangumiApi.topSubjects(type: _type);
    setState(() => _future = future);
    await future;
  }

  void _onTypeChanged(int type) {
    setState(() {
      _type = type;
      _future = BangumiApi.topSubjects(type: type);
    });
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = subjectTypeLabel(_type);
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('排行榜')),
      body: Column(
        children: [
          PageHeader(
            title: '$typeLabel排行榜',
            subtitle: 'Bangumi 高评分条目',
            showDivider: false,
          ),
          SubjectTypeSelector(selected: _type, onChanged: _onTypeChanged),
          Expanded(
            child: FutureBuilder<List<Subject>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingState(message: '正在整理榜单');
                }
                if (snapshot.hasError) {
                  return ErrorState(
                    message: '加载失败：${snapshot.error}',
                    onRetry: _reload,
                  );
                }

                final subjects = snapshot.data ?? const [];
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: subjects.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 96),
                            EmptyState(message: '暂无排行数据'),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(top: 10, bottom: 24),
                          itemCount: subjects.length,
                          itemBuilder: (context, index) {
                            final subject = subjects[index];
                            return SubjectCard(
                              subject: subject,
                              rank: index + 1,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SubjectDetailPage(subjectId: subject.id),
                                ),
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
}
