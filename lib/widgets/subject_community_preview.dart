import 'package:flutter/material.dart';

import '../api/bangumi_private_api.dart';
import '../models/models.dart';
import '../models/private_api_models.dart';
import '../navigation/routes.dart';
import 'common/common.dart';

class SubjectCommunityPreview extends StatefulWidget {
  final int subjectId;
  final int subjectType;

  const SubjectCommunityPreview({
    super.key,
    required this.subjectId,
    required this.subjectType,
  });

  @override
  State<SubjectCommunityPreview> createState() =>
      _SubjectCommunityPreviewState();
}

class _SubjectCommunityPreviewState extends State<SubjectCommunityPreview> {
  late Future<P1SubjectCommunity> _future;

  @override
  void initState() {
    super.initState();
    _future = BangumiPrivateApi.subjectCommunity(widget.subjectId);
  }

  void _reload() {
    setState(() {
      _future = BangumiPrivateApi.subjectCommunity(widget.subjectId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<P1SubjectCommunity>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(20, 22, 20, 12),
            child: LinearProgressIndicator(minHeight: 1),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('社区内容暂时不可用'),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        if (data.topics.items.isEmpty &&
            data.reviews.items.isEmpty &&
            data.comments.items.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: '社区'),
            if (data.topics.items.isNotEmpty)
              _CommunityGroup(
                icon: Icons.forum_outlined,
                title: '讨论',
                total: data.topics.total,
                onMore: () => _openCommunity(0),
                children: [
                  for (final topic in data.topics.items) _topic(context, topic),
                ],
              ),
            if (data.reviews.items.isNotEmpty)
              _CommunityGroup(
                icon: Icons.article_outlined,
                title: '长评',
                total: data.reviews.total,
                onMore: () => _openCommunity(1),
                children: [
                  for (final review in data.reviews.items)
                    _review(context, review),
                ],
              ),
            if (data.comments.items.isNotEmpty)
              _CommunityGroup(
                icon: Icons.chat_bubble_outline,
                title: '吐槽',
                total: data.comments.total,
                onMore: () => _openCommunity(2),
                children: [
                  for (final comment in data.comments.items)
                    _comment(context, comment),
                ],
              ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  void _openCommunity(int tab) {
    AppRoutes.pushSubjectCommunity(
      context,
      subjectId: widget.subjectId,
      subjectType: widget.subjectType,
      initialTab: tab,
    );
  }

  Widget _topic(BuildContext context, P1SubjectTopic topic) {
    return _CommunityTile(
      onTap: () => AppRoutes.pushSubjectTopic(context, topic.id),
      title: topic.title,
      meta: [
        if (topic.creator != null) topic.creator!.displayName,
        '${topic.replyCount} 回复',
        _date(topic.updatedAt),
      ].join(' · '),
      trailing: Icons.chevron_right,
    );
  }

  Widget _review(BuildContext context, P1SubjectReview review) {
    return _CommunityTile(
      onTap: () => AppRoutes.openBlog(context, review.blogId),
      title: review.title,
      body: review.summary,
      meta: [
        review.user.displayName,
        '${review.replyCount} 回复',
        _date(review.updatedAt),
      ].join(' · '),
      trailing: Icons.open_in_new,
    );
  }

  Widget _comment(BuildContext context, P1SubjectComment comment) {
    final label = collectionTypeLabel(
      comment.collectionType,
      subjectType: widget.subjectType,
    );
    return _CommunityTile(
      title: comment.user.displayName,
      body: comment.comment,
      badge: label,
      meta: [
        if (comment.rate > 0) '${comment.rate} 分',
        _date(comment.updatedAt),
      ].join(' · '),
    );
  }

  String _date(int seconds) {
    if (seconds <= 0) return '';
    final value = DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    ).toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }
}

class _CommunityGroup extends StatelessWidget {
  final IconData icon;
  final String title;
  final int total;
  final VoidCallback onMore;
  final List<Widget> children;

  const _CommunityGroup({
    required this.icon,
    required this.title,
    required this.total,
    required this.onMore,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            color: colors.surfaceContainerHighest,
            child: Row(
              children: [
                Container(width: 3, height: 20, color: colors.primary),
                const SizedBox(width: 9),
                Icon(icon, size: 19, color: colors.primary),
                const SizedBox(width: 8),
                Text(title, style: textTheme.titleSmall),
                const SizedBox(width: 7),
                Text(
                  '$total',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onMore,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('查看更多'),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _CommunityTile extends StatelessWidget {
  final String title;
  final String? body;
  final String meta;
  final VoidCallback? onTap;
  final IconData? trailing;
  final String? badge;

  const _CommunityTile({
    required this.title,
    required this.meta,
    this.body,
    this.onTap,
    this.trailing,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            TagChip(label: badge!),
                          ],
                        ],
                      ),
                      if (body != null && body!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          body!.trim(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  Icon(trailing, size: 16, color: colors.onSurfaceVariant),
                ],
              ],
            ),
          ),
        ),
        const HairlineDivider(),
      ],
    );
  }
}
