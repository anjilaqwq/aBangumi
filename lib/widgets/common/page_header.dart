import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 页面标题 / 页头：衬线标题 + 大留白 + 细线分隔，日式极简。
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final bool showDivider;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 16),
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.headlineMedium),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (showDivider) ...[
            const SizedBox(height: 16),
            const HairlineDivider(),
          ],
        ],
      ),
    );
  }
}

/// 区块标题：衬线标题 + 可选数量/右侧动作，克制静谧。
class SectionHeader extends StatelessWidget {
  final String title;
  final String? count;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 12),
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(title, style: textTheme.titleMedium),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(count!, style: textTheme.bodySmall),
          ],
          const Spacer(),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: textTheme.labelMedium,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// 细分隔线：1px 暖灰细线，日式「間」的分隔。
class HairlineDivider extends StatelessWidget {
  final double indent;
  final double endIndent;
  final Color? color;

  const HairlineDivider({
    super.key,
    this.indent = 0,
    this.endIndent = 0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: indent,
      endIndent: endIndent,
      color: color ?? AppColors.line,
    );
  }
}
