import 'package:flutter/material.dart';

import '../api/bangumi_api.dart';
import '../models/models.dart';
import '../navigation/routes.dart';
import '../widgets/common/common.dart';
import '../widgets/subject_card.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late Future<List<CalendarDay>> _future;
  int _selectedWeekday = DateTime.now().weekday;

  @override
  void initState() {
    super.initState();
    _future = BangumiApi.calendar();
  }

  Future<void> _reload() async {
    final future = BangumiApi.calendar(forceRefresh: true);
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<CalendarDay>>(
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
            if (days.isEmpty) return _emptySchedule();
            final selected = days.firstWhere(
              (day) => day.weekdayId == _selectedWeekday,
              orElse: () => days.first,
            );
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0.025, 0),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: _schedule(days, selected),
            );
          },
        ),
      ),
    );
  }

  Widget _schedule(List<CalendarDay> days, CalendarDay selected) {
    return RefreshIndicator(
      key: ValueKey(_selectedWeekday),
      onRefresh: _reload,
      child: CustomScrollView(
        key: PageStorageKey('calendar-$_selectedWeekday'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            title: const Text('每日放送'),
            actions: [
              IconButton(
                onPressed: _reload,
                tooltip: '刷新日程',
                icon: const Icon(Icons.refresh_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(child: _dayOverview(selected)),
          SliverToBoxAdapter(child: _weekdaySelector(days)),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: '${_dayLabel(selected)}更新',
              count: '${selected.items.length} 部',
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            ),
          ),
          if (selected.items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(message: '本日暂无放送条目'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.crossAxisExtent >= 680;
                  final delegate = SliverChildBuilderDelegate((context, index) {
                    final subject = selected.items[index];
                    return SubjectCard(
                      subject: subject,
                      dense: wide,
                      onTap: () => AppRoutes.pushSubject(context, subject.id),
                    );
                  }, childCount: selected.items.length);
                  if (!wide) return SliverList(delegate: delegate);
                  return SliverGrid(
                    delegate: delegate,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 108,
                          crossAxisSpacing: 10,
                        ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayOverview(CalendarDay day) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final today = day.weekdayId == DateTime.now().weekday;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, wide ? 5 : 8, 16, wide ? 8 : 12),
      child: Container(
        padding: EdgeInsets.all(wide ? 12 : 18),
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(wide ? 16 : 20),
          border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: wide ? 44 : 52,
              height: wide ? 44 : 52,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(wide ? 14 : 17),
              ),
              child: Icon(
                Icons.live_tv_rounded,
                color: colors.onPrimary,
                size: wide ? 23 : 27,
              ),
            ),
            SizedBox(width: wide ? 12 : 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _dayLabel(day),
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (today) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '今天',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    day.items.isEmpty
                        ? '今天暂时没有记录到更新'
                        : '${day.items.length} 部作品将在这一天更新',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.calendar_today_rounded, color: colors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _weekdaySelector(List<CalendarDay> days) {
    _WeekdayTile tileFor(CalendarDay day, {double? width}) => _WeekdayTile(
      width: width,
      label: _shortDayLabel(day),
      count: day.items.length,
      selected: day.weekdayId == _selectedWeekday,
      today: day.weekdayId == DateTime.now().weekday,
      onTap: () {
        if (_selectedWeekday == day.weekdayId) return;
        setState(() => _selectedWeekday = day.weekdayId);
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 680) {
          return SizedBox(
            height: 62,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  for (var index = 0; index < days.length; index++) ...[
                    if (index > 0) const SizedBox(width: 6),
                    Expanded(child: tileFor(days[index], width: null)),
                  ],
                ],
              ),
            ),
          );
        }
        return SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 5),
            itemBuilder: (context, index) => tileFor(days[index], width: 42),
          ),
        );
      },
    );
  }

  Widget _emptySchedule() {
    return RefreshIndicator(
      onRefresh: _reload,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: const [
          SliverAppBar(floating: true, title: Text('每日放送')),
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(message: '暂无放送数据'),
          ),
        ],
      ),
    );
  }

  String _dayLabel(CalendarDay day) =>
      day.cn.isEmpty ? '星期${day.weekdayId}' : day.cn;

  String _shortDayLabel(CalendarDay day) {
    final value = _dayLabel(day).replaceFirst('星期', '');
    return value.isEmpty ? '${day.weekdayId}' : value;
  }
}

class _WeekdayTile extends StatelessWidget {
  final double? width;
  final String label;
  final int count;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  const _WeekdayTile({
    this.width = 42,
    required this.label,
    required this.count,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
      decoration: BoxDecoration(
        color: selected ? colors.primary : colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? colors.primary : colors.outlineVariant,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: textTheme.titleSmall?.copyWith(
                      color: selected ? colors.onPrimary : colors.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (today) ...[
                    const SizedBox(width: 3),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: selected ? colors.onPrimary : colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '$count',
                style: textTheme.labelSmall?.copyWith(
                  color: selected
                      ? colors.onPrimary.withValues(alpha: 0.82)
                      : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
