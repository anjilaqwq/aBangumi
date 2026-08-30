import 'package:flutter/material.dart';

import '../api/bangumi_private_api.dart';
import '../models/models.dart';
import '../models/private_api_models.dart';
import '../navigation/routes.dart';
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

  bool get _hasMoreTopics => _topics.length < _topicsTotal;

  @override
  void initState() {
    super.initState();
    _subjects = BangumiPrivateApi.trendingSubjects(type: _type);
    _scrollController.addListener(_onScroll);
    _loadTopics(reset: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 420) _loadTopics();
  }

  Future<void> _loadTopics({bool reset = false}) async {
    if (_topicsLoading) return;
    if (!reset && _topics.isNotEmpty && !_hasMoreTopics) return;
    setState(() {
      _topicsLoading = true;
      _topicsError = null;
    });
    try {
      final page = await BangumiPrivateApi.trendingSubjectTopics(
        limit: 12,
        offset: reset ? 0 : _topics.length,
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
    final subjects = BangumiPrivateApi.trendingSubjects(type: _type);
    setState(() => _subjects = subjects);
    await Future.wait<dynamic>([subjects, _loadTopics(reset: true)]);
  }

  void _changeType(int type) {
    setState(() {
      _type = type;
      _subjects = BangumiPrivateApi.trendingSubjects(type: type);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('发现')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
              child: Text(
                '热门条目与正在发生的讨论',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SectionHeader(
              title: '热门条目',
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
            ),
            SubjectTypeSelector(selected: _type, onChanged: _changeType),
            const SizedBox(height: 12),
            _trendingSubjects(),
            const SizedBox(height: 20),
            const HairlineDivider(),
            const SectionHeader(
              title: '热门讨论',
              padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
            ),
            _trendingTopics(),
          ],
        ),
      ),
    );
  }

  Widget _trendingSubjects() {
    return SizedBox(
      height: 244,
      child: FutureBuilder<PageData<P1TrendingSubject>>(
        future: _subjects,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingState(message: '正在读取热门条目');
          }
          if (snapshot.hasError) {
            return _CompactError(
              message: '热门条目暂时不可用',
              onRetry: () => _changeType(_type),
            );
          }
          final items = snapshot.data?.items ?? const [];
          if (items.isEmpty) {
            return const EmptyState(message: '暂无热门条目');
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = items[index];
              return _TrendingSubjectCard(
                item: item,
                onTap: () => AppRoutes.pushSubject(context, item.subject.id),
              );
            },
          );
        },
      ),
    );
  }

  Widget _trendingTopics() {
    if (_topicsLoading && _topics.isEmpty) {
      return const LoadingState(message: '正在读取热门讨论');
    }
    if (_topicsError != null && _topics.isEmpty) {
      return _CompactError(
        message: '热门讨论暂时不可用',
        onRetry: () => _loadTopics(reset: true),
      );
    }
    if (_topics.isEmpty) return const EmptyState(message: '暂无热门讨论');
    return Column(
      children: [
        for (final item in _topics)
          _TopicTile(
            topic: item,
            onTap: () => AppRoutes.pushSubjectTopic(context, item.id),
            onSubjectTap: item.subject == null
                ? null
                : () => AppRoutes.pushSubject(context, item.subject!.id),
          ),
        if (_topicsError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: TextButton.icon(
              onPressed: _loadTopics,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('加载更多失败，点击重试'),
            ),
          )
        else
          PagingFooter(
            loading: _topicsLoading,
            hasMore: _hasMoreTopics,
            total: _topicsTotal,
          ),
      ],
    );
  }
}

class _TrendingSubjectCard extends StatelessWidget {
  final P1TrendingSubject item;
  final VoidCallback onTap;

  const _TrendingSubjectCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final subject = item.subject;
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 122,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverImage(
              imageUrl: subject.cover,
              width: 122,
              height: 166,
              borderRadius: 2,
            ),
            const SizedBox(height: 8),
            Text(
              subject.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '热度 ${item.activityCount}',
              maxLines: 1,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  final P1SubjectTopic topic;
  final VoidCallback onTap;
  final VoidCallback? onSubjectTap;

  const _TopicTile({
    required this.topic,
    required this.onTap,
    this.onSubjectTap,
  });

  @override
  Widget build(BuildContext context) {
    final subject = topic.subject;
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subject != null) ...[
                  GestureDetector(
                    onTap: onSubjectTap,
                    child: CoverImage(
                      imageUrl: subject.cover,
                      width: 48,
                      height: 66,
                      borderRadius: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall,
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
                      Text(
                        [
                          if (topic.creator != null) topic.creator!.displayName,
                          '${topic.replyCount} 回复',
                          _formatTimestamp(topic.updatedAt),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
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
        const HairlineDivider(),
      ],
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
