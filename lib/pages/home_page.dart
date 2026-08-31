import 'package:flutter/material.dart';

import '../api/bangumi_api.dart';
import '../models/models.dart';
import '../navigation/routes.dart';
import '../widgets/common/common.dart';
import '../widgets/subject_card.dart';
import '../widgets/subject_type_selector.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _pageSize = 20;
  static const _maxRetainedItems = 120;
  final ScrollController _scrollController = ScrollController();
  final List<Subject> _subjects = [];
  int _type = 2;
  int _total = 0;
  int _nextOffset = 0;
  int _rankBase = 0;
  bool _loading = false;
  Object? _error;

  bool get _hasMore => _nextOffset < _total;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 520) _load();
  }

  Future<void> _load({bool reset = false, bool forceRefresh = false}) async {
    if (_loading) return;
    if (!reset && _subjects.isNotEmpty && !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await BangumiApi.topSubjects(
        type: _type,
        limit: _pageSize,
        offset: reset ? 0 : _nextOffset,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _subjects.clear();
          _nextOffset = 0;
          _rankBase = 0;
        }
        final known = _subjects.map((item) => item.id).toSet();
        _subjects.addAll(page.items.where((item) => known.add(item.id)));
        _nextOffset = page.items.isEmpty
            ? page.total
            : _nextOffset + page.items.length;
        if (_subjects.length > _maxRetainedItems) {
          final excess = _subjects.length - _maxRetainedItems;
          _subjects.removeRange(0, excess);
          _rankBase += excess;
        }
        _total = page.total;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() => _load(reset: true, forceRefresh: true);

  void _onTypeChanged(int type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _subjects.clear();
      _total = 0;
      _nextOffset = 0;
      _rankBase = 0;
      _error = null;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BANGUMI  排行'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'RANKING',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          key: PageStorageKey('ranking-$_type'),
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _RankingHero(typeLabel: subjectTypeLabel(_type)),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TypeSelectorHeader(
                child: SubjectTypeSelector(
                  selected: _type,
                  onChanged: _onTypeChanged,
                ),
              ),
            ),
            ..._bodySlivers(),
          ],
        ),
      ),
    );
  }

  List<Widget> _bodySlivers() {
    if (_loading && _subjects.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: LoadingState(message: '正在整理榜单'),
        ),
      ];
    }
    if (_error != null && _subjects.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(
            message: '榜单暂时不可用：$_error',
            onRetry: () => _load(reset: true, forceRefresh: true),
          ),
        ),
      ];
    }
    if (_subjects.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(message: '暂无排行数据'),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            Widget cardAt(BuildContext context, int index) {
              final subject = _subjects[index];
              return SubjectCard(
                subject: subject,
                rank: _rankBase + index + 1,
                onTap: () => AppRoutes.pushSubject(context, subject.id),
              );
            }

            if (constraints.crossAxisExtent < 760) {
              return SliverList.builder(
                itemCount: _subjects.length,
                itemBuilder: cardAt,
              );
            }
            return SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 560,
                mainAxisExtent: 126,
                crossAxisSpacing: 12,
              ),
              itemCount: _subjects.length,
              itemBuilder: cardAt,
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('续载失败，点击重试'),
                  ),
                ),
              )
            : PagingFooter(loading: _loading, hasMore: _hasMore, total: _total),
      ),
    ];
  }
}

class _TypeSelectorHeader extends SliverPersistentHeaderDelegate {
  final Widget child;

  const _TypeSelectorHeader({required this.child});

  @override
  double get minExtent => 52;

  @override
  double get maxExtent => 52;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: overlapsContent
            ? Border(bottom: BorderSide(color: colors.outlineVariant))
            : null,
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _TypeSelectorHeader oldDelegate) =>
      oldDelegate.child != child;
}

class _RankingHero extends StatelessWidget {
  final String typeLabel;

  const _RankingHero({required this.typeLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final foreground = dark ? colors.onSurface : colors.surface;
    final background = dark ? colors.surfaceContainerHighest : colors.onSurface;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 7, color: colors.primary),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'TOP  $typeLabel',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.workspace_premium_rounded,
                          color: colors.primary,
                          size: 26,
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Text(
                      '$typeLabel排行榜',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
