import 'package:flutter/material.dart';

import '../api/bangumi_private_api.dart';
import '../models/private_api_models.dart';
import '../navigation/routes.dart';
import '../widgets/common/common.dart';

class SubjectTopicPage extends StatefulWidget {
  final int topicId;

  const SubjectTopicPage({super.key, required this.topicId});

  @override
  State<SubjectTopicPage> createState() => _SubjectTopicPageState();
}

class _SubjectTopicPageState extends State<SubjectTopicPage> {
  late Future<P1SubjectTopic> _future;

  @override
  void initState() {
    super.initState();
    _future = BangumiPrivateApi.subjectTopic(widget.topicId);
  }

  Future<void> _reload() async {
    final future = BangumiPrivateApi.subjectTopic(widget.topicId);
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('讨论'),
        actions: [
          IconButton(
            tooltip: '在网页中打开',
            onPressed: () =>
                AppRoutes.openSubjectTopic(context, widget.topicId),
            icon: const Icon(Icons.open_in_new, size: 20),
          ),
        ],
      ),
      body: FutureBuilder<P1SubjectTopic>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingState(message: '正在读取讨论');
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return ErrorState(
              message: '讨论加载失败：${snapshot.error}',
              onRetry: _reload,
            );
          }
          return _content(snapshot.data!);
        },
      ),
    );
  }

  Widget _content(P1SubjectTopic topic) {
    final subject = topic.subject;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          PageHeader(
            title: topic.title,
            subtitle: [
              if (subject != null) subject.title,
              '${topic.replyCount} 回复',
              _formatDate(topic.updatedAt),
            ].join(' · '),
            trailing: subject == null
                ? null
                : TextButton(
                    onPressed: () => AppRoutes.pushSubject(context, subject.id),
                    child: const Text('查看条目'),
                  ),
          ),
          if (topic.replies.isEmpty)
            const EmptyState(message: '讨论暂无可显示内容')
          else
            for (var index = 0; index < topic.replies.length; index++)
              _ReplyCard(
                reply: topic.replies[index],
                floor: index == 0 ? '主楼' : '#$index',
                mainPost: index == 0,
              ),
        ],
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  final P1Reply reply;
  final String floor;
  final bool mainPost;
  final bool nested;

  const _ReplyCard({
    required this.reply,
    required this.floor,
    this.mainPost = false,
    this.nested = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final creator = reply.creator;
    return Container(
      margin: EdgeInsets.fromLTRB(nested ? 42 : 20, 10, 20, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: mainPost ? colors.primaryContainer : colors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: mainPost ? colors.primary : colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (creator != null) ...[
                ClipOval(
                  child: CoverImage(
                    imageUrl: creator.avatar,
                    width: 30,
                    height: 30,
                    borderRadius: 15,
                    alignment: Alignment.topCenter,
                  ),
                ),
                const SizedBox(width: 9),
              ],
              Expanded(
                child: Text(
                  creator?.displayName ?? '匿名用户',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
              ),
              Text(
                floor,
                style: textTheme.labelMedium?.copyWith(
                  color: mainPost ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            reply.content.trim(),
            style: textTheme.bodyMedium?.copyWith(height: 1.65),
          ),
          const SizedBox(height: 10),
          Text(
            _formatDateTime(reply.createdAt),
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          if (reply.replies.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (var index = 0; index < reply.replies.length; index++)
              _ReplyCard(
                reply: reply.replies[index],
                floor: '回复 ${index + 1}',
                nested: true,
              ),
          ],
        ],
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

String _formatDateTime(int seconds) {
  if (seconds <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  ).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}';
}
