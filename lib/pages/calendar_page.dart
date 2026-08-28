import 'package:flutter/material.dart';

import '../api/bangumi_api.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../widgets/common/common.dart';
import '../widgets/subject_card.dart';
import 'subject_detail_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late Future<List<CalendarDay>> _future;
  int _selectedWeekday = DateTime.now().weekday; // 1=周一 ... 7=周日

  @override
  void initState() {
    super.initState();
    _future = BangumiApi.calendar();
  }

  Future<void> _reload() async {
    final future = BangumiApi.calendar();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('每日放送')),
      body: FutureBuilder<List<CalendarDay>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingState(message: '正在读取放送日程');
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: '加载失败：${snapshot.error}',
              onRetry: _reload,
            );
          }

          final days = snapshot.data ?? const [];
          if (days.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  PageHeader(title: '放送日程', subtitle: '按星期浏览每日更新'),
                  SizedBox(height: 72),
                  EmptyState(message: '暂无放送数据'),
                ],
              ),
            );
          }

          final selected = days.firstWhere(
            (day) => day.weekdayId == _selectedWeekday,
            orElse: () => days.first,
          );
          return Column(
            children: [
              const PageHeader(
                title: '放送日程',
                subtitle: '按星期浏览每日更新',
                showDivider: false,
              ),
              _weekdaySelector(days),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _reload,
                  child: selected.items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 96),
                            EmptyState(message: '本日暂无放送条目'),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(top: 10, bottom: 24),
                          itemCount: selected.items.length,
                          itemBuilder: (context, index) {
                            final subject = selected.items[index];
                            return SubjectCard(
                              subject: subject,
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _weekdaySelector(List<CalendarDay> days) {
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final day = days[index];
              final label = day.cn.isEmpty
                  ? '周${day.weekdayId}'
                  : day.cn.replaceFirst('星期', '周');
              return TagChip(
                label: label,
                selected: day.weekdayId == _selectedWeekday,
                onTap: () => setState(() => _selectedWeekday = day.weekdayId),
              );
            },
          ),
        ),
        const HairlineDivider(),
      ],
    );
  }
}
