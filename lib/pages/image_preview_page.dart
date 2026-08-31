import 'package:flutter/material.dart';

import '../network/bangumi_resource.dart';

class ImagePreviewPage extends StatelessWidget {
  final String imageUrl;
  final String title;
  final Object? heroTag;

  const ImagePreviewPage({
    super.key,
    required this.imageUrl,
    required this.title,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final pixelRatio = media.devicePixelRatio.clamp(1.0, 2.0);
    final provider = ResizeImage(
      bangumiNetworkImage(imageUrl),
      width: (media.size.width * pixelRatio).round().clamp(1, 1600),
      height: (media.size.height * pixelRatio).round().clamp(1, 2400),
      policy: ResizeImagePolicy.fit,
    );

    Widget image = SizedBox.expand(
      child: Image(
        image: provider,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, color: Colors.white70),
              SizedBox(height: 10),
              Text('图片暂时无法显示', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
    if (heroTag != null) image = Hero(tag: heroTag!, child: image);

    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111318),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        top: false,
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          boundaryMargin: const EdgeInsets.all(80),
          child: image,
        ),
      ),
    );
  }
}
