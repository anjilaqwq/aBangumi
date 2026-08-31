import 'package:flutter/material.dart';

import '../models/models.dart';
import 'common/common.dart';

/// Dense editorial subject card used by rankings, calendar and search.
class SubjectCard extends StatelessWidget {
  final Subject subject;
  final VoidCallback? onTap;
  final int? rank;
  final bool dense;

  const SubjectCard({
    super.key,
    required this.subject,
    this.onTap,
    this.rank,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 8 : 10),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dense ? 14 : 16),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(dense ? 8 : 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rank != null) ...[
                  _RankBadge(rank: rank!, dense: dense),
                  SizedBox(width: dense ? 7 : 9),
                ],
                CoverImage(
                  imageUrl: subject.cover,
                  width: dense ? 60 : 68,
                  height: dense ? 84 : 96,
                  borderRadius: dense ? 9 : 10,
                ),
                SizedBox(width: dense ? 9 : 12),
                Expanded(
                  child: SizedBox(
                    height: dense ? 84 : 104,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                subject.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            if (subject.score > 0) ...[
                              const SizedBox(width: 8),
                              _ScoreBadge(score: subject.score),
                            ],
                          ],
                        ),
                        SizedBox(height: dense ? 3 : 5),
                        Text(
                          _metaText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        if (subject.tags.isNotEmpty)
                          Text(
                            subject.tags
                                .take(3)
                                .map((tag) => '#$tag')
                                .join('  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.secondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        SizedBox(height: dense ? 3 : 5),
                        Wrap(
                          spacing: 12,
                          runSpacing: 2,
                          children: [
                            _Engagement(
                              icon: Icons.star_outline_rounded,
                              value: subject.ratingTotal,
                              suffix: '人评分',
                            ),
                            if (subject.collectionDoing > 0) ...[
                              _Engagement(
                                icon: Icons.people_alt_outlined,
                                value: subject.collectionDoing,
                                suffix: '人在看',
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
}

class _RankBadge extends StatelessWidget {
  final int rank;
  final bool dense;

  const _RankBadge({required this.rank, required this.dense});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final featured = rank <= 3;
    return Container(
      width: dense ? 31 : 35,
      height: dense ? 31 : 35,
      decoration: BoxDecoration(
        color: featured ? colors.primary : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(dense ? 9 : 11),
      ),
      child: Center(
        child: Text(
          rank.toString().padLeft(2, '0'),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: featured ? colors.onPrimary : colors.onSurfaceVariant,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final double score;

  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        score.toStringAsFixed(1),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Engagement extends StatelessWidget {
  final IconData icon;
  final int value;
  final String suffix;

  const _Engagement({
    required this.icon,
    required this.value,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          value > 0 ? '$value $suffix' : '暂无$suffix',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
