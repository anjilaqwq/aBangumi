import 'package:flutter/material.dart';

import '../api/bangumi_api.dart';
import '../models/models.dart';
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

  void _reload() {
    setState(() {
      _future = BangumiApi.calendar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('每日放送')),
      body: FutureBuilder<List<CalendarDay>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('加载失败：${snap.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _reload, child: const Text('重试')),
                  ],
                ),
              ),
            );
          }
          final days = snap.data ?? const [];
          if (days.isEmpty) {
            return const Center(child: Text('暂无数据', style: TextStyle(color: Colors.grey)));
          }
          final selected = days.firstWhere(
            (d) => d.weekdayId == _selectedWeekday,
            orElse: () => days.first,
          );
          return Column(
            children: [
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  children: days.map((d) {
                    final active = d.weekdayId == _selectedWeekday;
                    final label =
                        d.cn.isEmpty ? '周${d.weekdayId}' : d.cn.replaceFirst('星期', '周');
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: active,
                        onSelected: (_) =>
                            setState(() => _selectedWeekday = d.weekdayId),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: selected.items.length,
                    itemBuilder: (context, i) {
                      final s = selected.items[i];
                      return SubjectCard(
                        subject: s,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SubjectDetailPage(subjectId: s.id)),
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
}
