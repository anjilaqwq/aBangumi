import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'page_header.dart';

/// 封面图：等比例覆盖 + 细线描边 + 克制圆角，无阴影无渐变。
class CoverImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final double borderRadius;
  final Widget? placeholder;

  const CoverImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius = 4,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = placeholder ?? _placeholder(context);
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.outlineVariant,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: imageUrl.isEmpty
          ? fallback
          : Image.network(
              imageUrl,
              width: width,
              height: height,
              fit: fit,
              alignment: alignment,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 24,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 信息框中的单行键值。
class InfoEntry {
  final String key;
  final String value;

  const InfoEntry(this.key, this.value);
}

/// 信息框：键值行，细线描边、无阴影，日式极简。
class InfoBox extends StatelessWidget {
  final List<InfoEntry> entries;
  final double keyWidth;
  final EdgeInsetsGeometry padding;

  const InfoBox({
    super.key,
    required this.entries,
    this.keyWidth = 76,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: keyWidth,
                  child: Text(entries[i].key, style: textTheme.bodySmall),
                ),
                Expanded(
                  child: Text(entries[i].value, style: textTheme.bodyMedium),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 极简标签：细线描边、无阴影、小圆角；可选点击与选中态。
class TagChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  const TagChip({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colors = theme.colorScheme;
    final text = Text(
      label,
      style: (selected ? textTheme.labelMedium : textTheme.bodySmall)?.copyWith(
        color: selected ? colors.primary : colors.onSurfaceVariant,
      ),
    );
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: text,
    );
    final decoration = BoxDecoration(
      color: selected ? colors.primaryContainer : colors.surface,
      borderRadius: BorderRadius.circular(3),
      border: Border.all(
        color: selected ? colors.primary : colors.outlineVariant,
      ),
    );

    if (onTap == null) {
      return Container(decoration: decoration, child: content);
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(decoration: decoration, child: content),
    );
  }
}

/// 详情页头：封面 + 文本（标题/副标题/元信息），无渐变无阴影。
///
/// 适合条目/角色/人物详情页顶部：左侧封面、右侧标题与副标题，
/// 下方可选元信息标签，底部以细线收束。
class DetailHero extends StatelessWidget {
  final String coverUrl;
  final String title;
  final String? subtitle;
  final List<Widget> meta;
  final Widget? trailing;
  final double coverWidth;
  final double coverHeight;
  final AlignmentGeometry coverAlignment;
  final EdgeInsetsGeometry padding;
  final bool showDivider;

  const DetailHero({
    super.key,
    required this.coverUrl,
    required this.title,
    this.subtitle,
    this.meta = const [],
    this.trailing,
    this.coverWidth = 96,
    this.coverHeight = 132,
    this.coverAlignment = Alignment.center,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoverImage(
                imageUrl: coverUrl,
                width: coverWidth,
                height: coverHeight,
                alignment: coverAlignment,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.headlineSmall),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                    if (trailing != null) ...[
                      const SizedBox(height: 8),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: meta),
          ],
          if (showDivider) ...[
            const SizedBox(height: 16),
            const HairlineDivider(),
          ],
        ],
      ),
    );
  }
}
