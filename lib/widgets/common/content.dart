import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'page_header.dart';

/// 在平板/桌面宽屏上限制阅读区域，手机端保持占满。
class AdaptiveContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const AdaptiveContentWidth({
    super.key,
    required this.child,
    this.maxWidth = 1100,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > maxWidth
            ? maxWidth
            : constraints.maxWidth;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: child,
          ),
        );
      },
    );
  }
}

/// 根据原图和展示区域的比例，选择完整显示或轻微裁切。
///
/// 常规海报会继续铺满；明显偏长（如 1:2）或偏宽（如 2:1）的资源图
/// 会完整显示，避免只剩图片中间一小块。
BoxFit adaptiveImageFit({
  required double sourceAspectRatio,
  required double frameAspectRatio,
}) {
  if (!sourceAspectRatio.isFinite ||
      !frameAspectRatio.isFinite ||
      sourceAspectRatio <= 0 ||
      frameAspectRatio <= 0) {
    return BoxFit.cover;
  }
  final relativeAspect = sourceAspectRatio / frameAspectRatio;
  return relativeAspect >= 0.78 && relativeAspect <= 1.28
      ? BoxFit.cover
      : BoxFit.contain;
}

/// 封面图：自动适配原图比例 + 细线描边 + 克制圆角。
class CoverImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;

  /// 指定后固定使用该模式；不指定时根据原图比例自动判断。
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final double borderRadius;
  final Widget? placeholder;

  const CoverImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.borderRadius = 4,
    this.placeholder,
  });

  @override
  State<CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends State<CoverImage> {
  ImageProvider<Object>? _provider;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  Size? _sourceSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant CoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height) {
      _sourceSize = null;
      _resolveImage();
    }
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  void _resolveImage() {
    _removeImageListener();
    if (widget.imageUrl.isEmpty) {
      _provider = null;
      return;
    }
    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
    final decodeWidth = widget.width == null
        ? null
        : (widget.width! * pixelRatio).round().clamp(1, 1600);
    final decodeHeight = widget.height == null
        ? null
        : (widget.height! * pixelRatio).round().clamp(1, 2000);
    final networkImage = NetworkImage(widget.imageUrl);
    final ImageProvider<Object> provider =
        decodeWidth == null && decodeHeight == null
        ? networkImage
        : ResizeImage(
            networkImage,
            width: decodeWidth,
            height: decodeHeight,
            policy: ResizeImagePolicy.fit,
          );
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      _handleImageFrame,
      onError: (_, __) {
        // Image 组件自身的 errorBuilder 负责展示占位图。
      },
    );
    _provider = provider;
    _imageStream = stream;
    _imageListener = listener;
    stream.addListener(listener);
  }

  void _removeImageListener() {
    final stream = _imageStream;
    final listener = _imageListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageListener = null;
  }

  void _handleImageFrame(ImageInfo info, bool synchronousCall) {
    final nextSize = Size(
      info.image.width.toDouble(),
      info.image.height.toDouble(),
    );
    if (_sourceSize == nextSize) return;
    if (synchronousCall) {
      _sourceSize = nextSize;
    } else if (mounted) {
      setState(() => _sourceSize = nextSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = widget.placeholder ?? _placeholder(context);
    final sourceSize = _sourceSize;
    final hasFrameSize = widget.width != null && widget.height != null;
    final fit =
        widget.fit ??
        (sourceSize != null && hasFrameSize
            ? adaptiveImageFit(
                sourceAspectRatio: sourceSize.width / sourceSize.height,
                frameAspectRatio: widget.width! / widget.height!,
              )
            : BoxFit.cover);
    return Container(
      width: widget.width,
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: widget.imageUrl.isEmpty || _provider == null
          ? fallback
          : Image(
              image: _provider!,
              width: widget.width,
              height: widget.height,
              fit: fit,
              alignment: widget.alignment,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
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
    final textStyle =
        (selected ? textTheme.labelMedium : textTheme.bodySmall)?.copyWith(
          color: selected ? colors.primary : colors.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        ) ??
        const TextStyle();
    final text = AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      style: textStyle,
      child: Text(label),
    );
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: text,
    );

    Widget decorated() => AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? colors.primaryContainer : colors.surface,
        borderRadius: BorderRadius.circular(selected ? 10 : 7),
        border: Border.all(
          color: selected ? colors.primary : colors.outlineVariant,
        ),
      ),
      child: content,
    );

    if (onTap == null) {
      return decorated();
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: decorated(),
      ),
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
  final VoidCallback? onCoverTap;
  final Object? coverHeroTag;

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
    this.onCoverTap,
    this.coverHeroTag,
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
              _DetailCover(
                imageUrl: coverUrl,
                width: coverWidth,
                height: coverHeight,
                alignment: coverAlignment,
                onTap: onCoverTap,
                heroTag: coverHeroTag,
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

class _DetailCover extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final AlignmentGeometry alignment;
  final VoidCallback? onTap;
  final Object? heroTag;

  const _DetailCover({
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.alignment,
    this.onTap,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget image = CoverImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      alignment: alignment,
      borderRadius: 12,
    );
    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }
    if (onTap == null || imageUrl.isEmpty) return image;
    return Semantics(
      button: true,
      label: '查看完整图片',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            image,
            Positioned(
              right: 7,
              bottom: 7,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Icon(
                  Icons.open_in_full_rounded,
                  size: 15,
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
