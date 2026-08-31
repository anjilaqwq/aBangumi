import 'package:flutter/painting.dart';

import '../auth/oauth_config.dart';

const Map<String, String> bangumiResourceHeaders = {
  'User-Agent': 'aBangumi/1.1.1 (https://github.com/anjilaqwq/aBangumi)',
  'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
};

/// Routes Bangumi-hosted covers, avatars and post images through the configured
/// OA server. Other sites remain direct so post authors can embed external
/// images without turning the OA endpoint into a general-purpose proxy.
String resolveBangumiResourceUrl(String value) {
  final source = Uri.tryParse(value.trim());
  if (source == null || !source.hasAuthority) return value;
  final host = source.host.toLowerCase();
  final isBangumi = host == 'bgm.tv' || host.endsWith('.bgm.tv');
  if (!isBangumi || !OAuthConfig.isConfigured) return value;

  final secureSource = source.scheme == 'http'
      ? source.replace(scheme: 'https')
      : source;
  if (secureSource.scheme != 'https') return value;

  return Uri.parse(
    '${OAuthConfig.requireAuthBaseUrl()}${OAuthConfig.resourceProxyPath}',
  ).replace(queryParameters: {'url': secureSource.toString()}).toString();
}

NetworkImage bangumiNetworkImage(String value) => NetworkImage(
  resolveBangumiResourceUrl(value),
  headers: bangumiResourceHeaders,
);
