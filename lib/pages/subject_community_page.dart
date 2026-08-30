import 'package:flutter/material.dart';

import '../api/bangumi_private_api.dart';
import '../models/models.dart';
import '../models/private_api_models.dart';
import '../navigation/routes.dart';
import '../widgets/common/common.dart';

class SubjectCommunityPage extends StatelessWidget {
  final int subjectId;
  final int subjectType;
  final int initialTab;

  const SubjectCommunityPage({
    super.key,
    required this.subjectId,
    required this.subjectType,
    this.initialTab = 0,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab.clamp(0, 2),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('社区'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '讨论'),
              Tab(text: '长评'),
              Tab(text: '吐槽'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PagedList<P1SubjectTopic>(
              loader: (offset) => BangumiPrivateApi.subjectTopics(
                subjectId,
                limit: 20,
                offset: offset,
              ),
              itemBuilder: (context, item) => _TopicListTile(
                topic: item,
                onTap: () => AppRoutes.pushSubjectTopic(context, item.id),
              ),
              emptyMessage: '暂无讨论',
            ),
            _PagedList<P1SubjectReview>(
              loader: (offset) => BangumiPrivateApi.subjectReviews(
                subjectId,
                limit: 20,
                offset: offset,
              ),
              itemBuilder: (context, item) => _ReviewListTile(
                review: item,
                onTap: () => AppRoutes.openBlog(context, item.blogId),
              ),
              emptyMessage: '暂无长评',
            ),
            _PagedList<P1SubjectComment>(
              loader: (offset) => BangumiPrivateApi.subjectComments(
                subjectId,
                limit: 20,
                offset: offset,
              ),
              itemBuilder: (context, item) =>
                  _CommentListTile(comment: item, subjectType: subjectType),
              emptyMessage: '暂无吐槽',
            ),
          ],
        ),
      ),
    );
  }
}

typedef _PageLoader<T> = Future<PageData<T>> Function(int offset);
typedef _PageItemBuilder<T> = Widget Function(BuildContext context, T item);

class _PagedList<T> extends StatefulWidget {
  final _PageLoader<T> loader;
  final _PageItemBuilder<T> itemBuilder;
  final String emptyMessage;

  const _PagedList({
    required this.loader,
    required this.itemBuilder,
    required this.emptyMessage,
  });

  @override
  State<_PagedList<T>> createState() => _PagedListState<T>();
}

class _PagedListState<T> extends State<_PagedList<T>> {
  final ScrollController _controller = ScrollController();
  final List<T> _items = [];
  int _total = 0;
  bool _loading = false;
  Object? _error;

  bool get _hasMore => _items.length < _total;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_controller.position.extentAfter < 320) _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (!reset && _items.isNotEmpty && !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.loader(reset ? 0 : _items.length);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.items);
        _total = page.total;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const LoadingState(message: '正在读取社区内容');
    }
    if (_error != null && _items.isEmpty) {
      return ErrorState(
        message: '加载失败：$_error',
        onRetry: () => _load(reset: true),
      );
    }
    if (_items.isEmpty) return EmptyState(message: widget.emptyMessage);
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          if (index < _items.length) {
            return widget.itemBuilder(context, _items[index]);
          }
          if (_error != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('加载更多失败，点击重试'),
                ),
              ),
            );
          }
          return PagingFooter(
            loading: _loading,
            hasMore: _hasMore,
            total: _total,
          );
        },
      ),
    );
  }
}

class _TopicListTile extends StatelessWidget {
  final P1SubjectTopic topic;
  final VoidCallback onTap;

  const _TopicListTile({required this.topic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _CommunityCard(
      icon: Icons.forum_outlined,
      title: topic.title,
      meta: [
        if (topic.creator != null) topic.creator!.displayName,
        '${topic.replyCount} 回复',
        _formatDate(topic.updatedAt),
      ].join(' · '),
      onTap: onTap,
    );
  }
}

class _ReviewListTile extends StatelessWidget {
  final P1SubjectReview review;
  final VoidCallback onTap;

  const _ReviewListTile({required this.review, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _CommunityCard(
      icon: Icons.article_outlined,
      title: review.title,
      body: review.summary,
      meta: [
        review.user.displayName,
        '${review.replyCount} 回复',
        _formatDate(review.updatedAt),
      ].join(' · '),
      onTap: onTap,
    );
  }
}

class _CommentListTile extends StatelessWidget {
  final P1SubjectComment comment;
  final int subjectType;

  const _CommentListTile({required this.comment, required this.subjectType});

  @override
  Widget build(BuildContext context) {
    return _CommunityCard(
      icon: Icons.chat_bubble_outline,
      title: comment.user.displayName,
      body: comment.comment,
      badge: collectionTypeLabel(
        comment.collectionType,
        subjectType: subjectType,
      ),
      meta: [
        if (comment.rate > 0) '${comment.rate} 分',
        _formatDate(comment.updatedAt),
      ].join(' · '),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String meta;
  final String? badge;
  final VoidCallback? onTap;

  const _CommunityCard({
    required this.icon,
    required this.title,
    required this.meta,
    this.body,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title, style: textTheme.titleSmall),
                        ),
                        if (badge != null) TagChip(label: badge!),
                      ],
                    ),
                    if (body != null && body!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        body!.trim(),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      meta,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(int seconds) {
  if (seconds <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  ).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}
