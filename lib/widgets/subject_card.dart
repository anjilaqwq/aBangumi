import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import 'common/common.dart';

/// 条目卡片：无边框、无阴影的编辑部列表行，底部以细线分隔。
///
/// 保留 [subject] / [onTap] 契约，新增可选 [rank] 用于排行榜编号。
class SubjectCard extends StatelessWidget {
  final Subject subject;
  final VoidCallback? onTap;

  /// 排行榜序号（可选），显示于封面左侧。
  final int? rank;

  const SubjectCard({super.key, required this.subject, this.onTap, this.rank});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rankValue = rank;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rankValue != null) ...[
                  SizedBox(width: 30, child: _rankText(context, rankValue)),
                  const SizedBox(width: 12),
                ],
                CoverImage(
                  imageUrl: subject.cover,
                  width: 56,
                  height: 78,
                  borderRadius: 2,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall,
                      ),
                      if (subject.originalTitle.isNotEmpty &&
                          subject.originalTitle != subject.title) ...[
                        const SizedBox(height: 4),
                        Text(
                          subject.originalTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        _metaText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.subtle),
                      ),
                      if (subject.tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          subject.tags.take(3).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall
                              ?.copyWith(color: AppColors.subtle),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _score(context, subject.score),
              ],
            ),
            const SizedBox(height: 14),
            const HairlineDivider(),
          ],
        ),
      ),
    );
  }

  String get _metaText {
    final parts = <String>[
      subject.typeLabel,
      if (subject.platform.isNotEmpty) subject.platform,
      if (subject.date.isNotEmpty) subject.date,
    ];
    return parts.join(' · ');
  }

  Widget _rankText(BuildContext context, int rank) {
    final textTheme = Theme.of(context).textTheme;
    return Text(
      rank < 10 ? '0$rank' : '$rank',
      style: textTheme.titleMedium?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _score(BuildContext context, double score) {
    final textTheme = Theme.of(context).textTheme;
    if (score <= 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          score.toStringAsFixed(1),
          style: textTheme.titleMedium?.copyWith(
            color: AppColors.vermilion,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '评分',
          style: textTheme.bodySmall?.copyWith(color: AppColors.subtle),
        ),
      ],
    );
  }
}
