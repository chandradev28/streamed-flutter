import 'package:flutter/material.dart';

class OptimizedNetworkImage extends StatelessWidget {
  const OptimizedNetworkImage({
    super.key,
    required this.url,
    this.fit,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.cacheWidth,
    this.cacheHeight,
    this.filterQuality = FilterQuality.medium,
    this.errorBuilder,
  });

  final String url;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final AlignmentGeometry alignment;
  final int? cacheWidth;
  final int? cacheHeight;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final double ratio = MediaQuery.devicePixelRatioOf(context);
    final int? resolvedCacheWidth =
        cacheWidth ?? (width == null ? null : (width! * ratio).round());
    final int? resolvedCacheHeight =
        cacheHeight ?? (height == null ? null : (height! * ratio).round());

    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      cacheWidth: resolvedCacheWidth,
      cacheHeight: resolvedCacheHeight,
      filterQuality: filterQuality,
      gaplessPlayback: true,
      errorBuilder: errorBuilder,
    );
  }
}
