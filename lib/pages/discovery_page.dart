import 'package:flutter/material.dart';

import '../api/bangumi_private_api.dart';
import '../models/models.dart';
import '../models/private_api_models.dart';
import '../navigation/routes.dart';
import '../store/auth_store.dart';
import '../widgets/common/common.dart';
import '../widgets/subject_type_selector.dart';

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  final ScrollController _scrollController = ScrollController();
  int _type = 2;
  late Future<PageData<P1TrendingSubject>> _subjects;
  final List<P1SubjectTopic> _topics = [];
  int _topicsTotal = 0;
  bool _topicsLoading = false;
  Object? _topicsError;
  String? _authToken;

  bool get _hasMoreTopics => _topics.length < _topicsTotal;

  @override
  void initState() {
    super.initState();
    _authToken = AuthStore.instance.token.value;
    _subjects = BangumiPrivateApi.trendingSubjects(
      type: _type,
      token: _authToken,
    );
    AuthStore.instance.token.addListener(_onAuthChanged);
    _scrollController.addListener(_onScroll);
    _loadTopics(reset: true);
  }

  @override
  void dispose() {
    AuthStore.instance.token.removeListener(_onAuthChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    final token = AuthStore.instance.token.value;
    if (token == _authToken) return;
    _authToken = token;
    setState(() {
      _subjects = BangumiPrivateApi.trendingSubjects(type: _type, token: token);
      _topics.clear();
      _topicsTotal = 0;
      _topicsError = null;
    });
    _loadTopics(reset: true);
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 420) _loadTopics();
  }

  Future<void> _loadTopics({
    bool reset = false,
    bool forceRefresh = false,
  }) async {
    if (_topicsLoading) return;
    if (!reset && _topics.isNotEmpty && !_hasMoreTopics) return;
    setState(() {
      _topicsLoading = true;
      _topicsError = null;
    });
    try {
      final page = await BangumiPrivateApi.trendingSubjectTopics(
        token: _authToken,
        limit: 12,
        offset: reset ? 0 : _topics.length,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _topics.clear();
        _topics.addAll(page.items);
        _topicsTotal = page.total;
      });
    } catch (error) {
      if (mounted) setState(() => _topicsError = error);
    } finally {
      if (mounted) setState(() => _topicsLoading = false);
    }
  }

  Future<void> _reload() async {
    final subjects = BangumiPrivateApi.trendingSubjects(
      type: _type,
      token: _authToken,
      forceRefresh: true,
    );
    setState(() => _subjects = subjects);
    await Future.wait<dynamic>([
      subjects,
      _loadTopics(reset: true, forceRefresh: true),
    ]);
  }

  void _changeType(int type) {
    setState(() {
      _type = type;
      _subjects = BangumiPrivateApi.trendingSubjects(
        type: type,
        token: _authToken,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('发现')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: '发现热潮',
                eyebrow: 'DISCOVER / NOW',
                icon: Icons.local_fire_department_rounded,
                subtitle: '热门条目与正在发生的用户讨论',
                showDivider: false,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              ),
            ),
            const SliverToBoxAdapter(
              child: SectionHeader(
                title: '热门条目',
                padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              ),
            ),
            SliverToBoxAdapter(
              child: SubjectTypeSelector(
                selected: _type,
                onChanged: _changeType,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverToBoxAdapter(child: _trendingSubjects()),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            const SliverToBoxAdapter(
              child: SectionHeader(
                title: '热门讨论',
                count: '用户动态',
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              ),
            ),
            ..._topicSlivers(),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }

  List<Widget> _topicSlivers() {
    if (_topicsLoading && _topics.isEmpty) {
      return const [
        SliverToBoxAdapter(child: LoadingState(message: '正在读取热门讨论')),
      ];
    }
    if (_topicsError != null && _topics.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _CompactError(
            message: '热门讨论暂时不可用',
            onRetry: () => _loadTopics(reset: true),
          ),
        ),
      ];
    }
    if (_topics.isEmpty) {
      return const [SliverToBoxAdapter(child: EmptyState(message: '暂无热门讨论'))];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.crossAxisExtent >= 680;
            final delegate = SliverChildBuilderDelegate((context, index) {
              final item = _topics[index];
              return _TopicTile(
                topic: item,
                dense: wide,
                onTap: () => AppRoutes.pushSubjectTopic(context, item.id),
                onSubjectTap: item.subject == null
                    ? null
                    : () => AppRoutes.pushSubject(context, item.subject!.id),
              );
            }, childCount: _topics.length);
            if (!wide) return SliverList(delegate: delegate);
            return SliverGrid(
              delegate: delegate,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 136,
                crossAxisSpacing: 10,
                mainAxisSpacing: 8,
              ),
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: _topicsError != null
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _loadTopics,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('加载更多失败，点击重试'),
                  ),
                ),
              )
            : PagingFooter(
                loading: _topicsLoading,
                hasMore: _hasMoreTopics,
                total: _topicsTotal,
              ),
      ),
    ];
  }

  Widget _trendingSubjects() {
    return FutureBuilder<PageData<P1TrendingSubject>>(
      future: _subjects,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 180,
            child: LoadingState(message: '正在读取热门条目'),
          );
        }
        if (snapshot.hasError) {
          return SizedBox(
            height: 120,
            child: _CompactError(
              message: '热门条目暂时不可用',
              onRetry: () => _changeType(_type),
            ),
          );
        }
        final items = snapshot.data?.items ?? const [];
        if (items.isEmpty) {
          return const SizedBox(
            height: 120,
            child: EmptyState(message: '暂无热门条目'),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 680;
            if (!wide) {
              return SizedBox(
                height: 244,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _TrendingSubjectCard(
                      item: item,
                      onTap: () =>
                          AppRoutes.pushSubject(context, item.subject.id),
                    );
                  },
                ),
              );
            }
            final tileWidth = ((constraints.maxWidth - 38) / 2).clamp(
              360.0,
              540.0,
            );
            return SizedBox(
              height: 224,
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: tileWidth,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _TrendingSubjectCard(
                    item: item,
                    dense: true,
                    onTap: () =>
                        AppRoutes.pushSubject(context, item.subject.id),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _TrendingSubjectCard extends StatelessWidget {
  final P1TrendingSubject item;
  final VoidCallback onTap;
  final bool dense;

  const _TrendingSubjectCard({
    required this.item,
    required this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final subject = item.subject;
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    if (dense) {
      return Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                CoverImage(
                  imageUrl: subject.cover,
                  width: 62,
                  height: 88,
                  borderRadius: 9,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subject.typeLabel,
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 14,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${item.activityCount} 动态',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          if (subject.score > 0)
                            Text(
                              subject.score.toStringAsFixed(1),
                              style: textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: 136,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoverImage(
                  imageUrl: subject.cover,
                  width: 120,
                  height: 146,
                  borderRadius: 10,
                ),
                const SizedBox(height: 8),
                Text(
                  subject.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 14,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${item.activityCount}',
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (subject.score > 0)
                      Text(
                        subject.score.toStringAsFixed(1),
                        style: textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  final P1SubjectTopic topic;
  final VoidCallback onTap;
  final VoidCallback? onSubjectTap;
  final bool dense;

  const _TopicTile({
    required this.topic,
    required this.onTap,
    this.onSubjectTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final subject = topic.subject;
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final creator = topic.creator;
    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 0 : 10),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dense ? 14 : 15),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(dense ? 10 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subject != null) ...[
                  GestureDetector(
                    onTap: onSubjectTap,
                    child: CoverImage(
                      imageUrl: subject.cover,
                      width: dense ? 44 : 48,
                      height: dense ? 62 : 66,
                      borderRadius: 9,
                    ),
                  ),
                  SizedBox(width: dense ? 9 : 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subject != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          subject.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (creator != null) ...[
                            ClipOval(
                              child: CoverImage(
                                imageUrl: creator.avatar,
                                width: 22,
                                height: 22,
                                borderRadius: 11,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${creator.displayName}  @${creator.username}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Icon(
                            Icons.forum_outlined,
                            size: 14,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${topic.replyCount}',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(topic.updatedAt),
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CompactError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh, size: 18),
        label: Text(message),
      ),
    );
  }
}

String _formatTimestamp(int seconds) {
  if (seconds <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  ).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}
