import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../network/bangumi_resource.dart';

/// Markdown-aware post body with compatibility for common Bangumi markup.
class PostContent extends StatelessWidget {
  final String content;
  final bool selectable;

  const PostContent({super.key, required this.content, this.selectable = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return MarkdownBody(
      data: normalizePostMarkup(content),
      selectable: selectable,
      softLineBreak: true,
      onTapLink: (_, href, __) {
        final uri = href == null ? null : Uri.tryParse(href);
        if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      imageBuilder: (uri, title, alt) {
        if (uri.scheme != 'http' && uri.scheme != 'https') {
          return Text(alt ?? '图片');
        }
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          constraints: const BoxConstraints(maxHeight: 420),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Image.network(
            resolveBangumiResourceUrl(uri.toString()),
            headers: bangumiResourceHeaders,
            fit: BoxFit.contain,
            cacheWidth: 900,
            errorBuilder: (_, __, ___) => Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_outlined, size: 18),
                  const SizedBox(width: 7),
                  Flexible(child: Text(alt ?? '图片暂时无法显示')),
                ],
              ),
            ),
          ),
        );
      },
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyMedium?.copyWith(height: 1.72),
        h1: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        h2: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        h3: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        blockquote: theme.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
          height: 1.65,
        ),
        blockquoteDecoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          border: Border(left: BorderSide(color: colors.primary, width: 4)),
          borderRadius: BorderRadius.circular(8),
        ),
        code: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: colors.onSurface,
          backgroundColor: colors.surfaceContainerHighest,
        ),
        codeblockDecoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outlineVariant),
        ),
        a: theme.textTheme.bodyMedium?.copyWith(
          color: colors.primary,
          decoration: TextDecoration.underline,
          decorationColor: colors.primary,
        ),
      ),
    );
  }
}

String normalizePostMarkup(String source) {
  var value = source.replaceAll('\r\n', '\n');
  value = value.replaceAllMapped(
    RegExp(r'\[img\](https?://[^\[]+)\[/img\]', caseSensitive: false),
    (match) => '![](${match.group(1)!.trim()})',
  );
  value = value.replaceAllMapped(
    RegExp(
      r'\[url=(https?://[^\]]+)\]([\s\S]*?)\[/url\]',
      caseSensitive: false,
    ),
    (match) => '[${match.group(2)}](${match.group(1)})',
  );
  value = value.replaceAllMapped(
    RegExp(r'\(bgm38\)', caseSensitive: false),
    (_) => '![bgm38](https://bgm.tv/img/smiles/tv/15.gif)',
  );
  value = value.replaceAllMapped(
    RegExp(r'\(musume_(\d{2})\)', caseSensitive: false),
    (match) =>
        '![musume_${match.group(1)}](https://lain.bgm.tv/img/smiles/musume/musume_${match.group(1)}.gif)',
  );
  return value;
}
