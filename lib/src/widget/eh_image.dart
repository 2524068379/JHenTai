import 'package:animate_do/animate_do.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'dart:io' as io;
import 'dart:math' as math;

import '../service/gallery_download_service.dart';

typedef LoadingProgressWidgetBuilder = Widget Function(double);
typedef FailedWidgetBuilder = Widget Function(ExtendedImageState state);
typedef DownloadingWidgetBuilder = Widget Function();
typedef PausedWidgetBuilder = Widget Function();
typedef LoadingWidgetBuilder = Widget Function();
typedef CompletedWidgetBuilder = Widget? Function(ExtendedImageState state);

class EHImage extends StatelessWidget {
  final GalleryImage galleryImage;
  final bool autoLayout;
  final double? containerHeight;
  final double? containerWidth;
  final Color? containerColor;
  final BoxFit fit;
  final bool enableSlideOutPage;
  final BorderRadius borderRadius;
  final Object? heroTag;
  final bool clearMemoryCacheWhenDispose;
  final List<BoxShadow>? shadows;
  final bool forceFadeIn;
  final int? maxBytes;

  final LoadingProgressWidgetBuilder? loadingProgressWidgetBuilder;
  final FailedWidgetBuilder? failedWidgetBuilder;
  final DownloadingWidgetBuilder? downloadingWidgetBuilder;
  final PausedWidgetBuilder? pausedWidgetBuilder;
  final LoadingWidgetBuilder? loadingWidgetBuilder;
  final CompletedWidgetBuilder? completedWidgetBuilder;

  const EHImage({
    super.key,
    required this.galleryImage,
    this.autoLayout = false,
    this.containerHeight,
    this.containerWidth,
    this.containerColor,
    this.fit = BoxFit.contain,
    this.enableSlideOutPage = false,
    this.borderRadius = BorderRadius.zero,
    this.heroTag,
    this.clearMemoryCacheWhenDispose = false,
    this.shadows,
    this.forceFadeIn = false,
    this.maxBytes,
    this.loadingProgressWidgetBuilder,
    this.failedWidgetBuilder,
    this.downloadingWidgetBuilder,
    this.pausedWidgetBuilder,
    this.loadingWidgetBuilder,
    this.completedWidgetBuilder,
  });

  const EHImage.autoLayout({
    super.key,
    required this.galleryImage,
    this.autoLayout = true,
    this.containerHeight,
    this.containerWidth,
    this.containerColor,
    this.fit = BoxFit.contain,
    this.enableSlideOutPage = false,
    this.borderRadius = BorderRadius.zero,
    this.heroTag,
    this.clearMemoryCacheWhenDispose = false,
    this.shadows,
    this.forceFadeIn = false,
    this.maxBytes,
    this.loadingProgressWidgetBuilder,
    this.failedWidgetBuilder,
    this.downloadingWidgetBuilder,
    this.pausedWidgetBuilder,
    this.loadingWidgetBuilder,
    this.completedWidgetBuilder,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = advancedSetting.inNoImageMode.isTrue
        ? const SizedBox()
        : galleryImage.path == null
            ? buildNetworkImage(context)
            : buildFileImage(context);

    if (galleryImage.isGif) {
      child = RepaintBoundary(child: child);
    }

    if (heroTag != null && styleSetting.isInMobileLayout) {
      child = Hero(tag: heroTag!, child: child);
    }

    if (autoLayout) {
      return LayoutBuilder(
        builder: (_, constraints) => Container(
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          decoration:
              BoxDecoration(color: containerColor, borderRadius: borderRadius),
          child: child,
        ),
      );
    }

    return Container(
      height: containerHeight,
      width: containerWidth,
      decoration:
          BoxDecoration(color: containerColor, borderRadius: borderRadius),
      child: child,
    );
  }

  Widget buildNetworkImage(BuildContext context) {
    final Size? decodeCacheSize = _computeDecodeCacheSize(context);

    return ExtendedImage.network(
      _replaceEXUrl(galleryImage.url),
      fit: fit,
      height: containerHeight,
      width: containerWidth,
      cacheWidth: decodeCacheSize?.width.toInt(),
      cacheHeight: decodeCacheSize?.height.toInt(),
      handleLoadingProgress: loadingProgressWidgetBuilder != null,
      printError: kDebugMode,
      enableSlideOutPage: enableSlideOutPage,
      clearMemoryCacheWhenDispose: clearMemoryCacheWhenDispose,
      loadStateChanged: (ExtendedImageState state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return loadingProgressWidgetBuilder != null
                ? loadingProgressWidgetBuilder!.call(_computeLoadingProgress(
                    state.loadingProgress, state.extendedImageInfo))
                : Center(child: UIConfig.loadingAnimation(context));
          case LoadState.failed:
            return failedWidgetBuilder?.call(state) ??
                Center(
                  child: GestureDetector(
                      onTap: state.reLoadImage,
                      child: const Icon(Icons.sentiment_very_dissatisfied)),
                );
          case LoadState.completed:
            state.returnLoadStateChangedWidget = true;

            Widget child = completedWidgetBuilder?.call(state) ??
                _buildExtendedRawImage(state);

            if (borderRadius != BorderRadius.zero) {
              child = ClipRRect(borderRadius: borderRadius, child: child);
            }

            if (state.slidePageState != null) {
              child = ExtendedImageSlidePageHandler(
                  extendedImageSlidePageState: state.slidePageState,
                  child: child);
            }

            child = Center(
              child: Container(
                decoration: BoxDecoration(
                    boxShadow: shadows, borderRadius: borderRadius),
                child: child,
              ),
            );

            return _shouldFadeIn(state)
                ? WidgetExtension(child).fadeIn()
                : child;
        }
      },
      maxBytes: _effectiveMaxBytes,
      filterQuality:
          galleryImage.isGif ? FilterQuality.low : FilterQuality.medium,
    );
  }

  Widget buildFileImage(BuildContext context) {
    if (galleryImage.downloadStatus == DownloadStatus.paused) {
      return pausedWidgetBuilder?.call() ??
          const Center(child: CircularProgressIndicator());
    }

    if (galleryImage.downloadStatus == DownloadStatus.downloading) {
      return downloadingWidgetBuilder?.call() ??
          const Center(child: CircularProgressIndicator());
    }

    final Size? decodeCacheSize = _computeDecodeCacheSize(context);

    return ExtendedImage.file(
      io.File(GalleryDownloadService
          .computeImageDownloadAbsolutePathFromRelativePath(
              galleryImage.path!)),
      fit: fit,
      height: containerHeight,
      width: containerWidth,
      cacheWidth: decodeCacheSize?.width.toInt(),
      cacheHeight: decodeCacheSize?.height.toInt(),
      enableLoadState: loadingWidgetBuilder != null ||
          failedWidgetBuilder != null ||
          completedWidgetBuilder != null,
      enableSlideOutPage: enableSlideOutPage,
      borderRadius: borderRadius,
      shape: BoxShape.rectangle,
      clearMemoryCacheWhenDispose: clearMemoryCacheWhenDispose,
      loadStateChanged: (ExtendedImageState state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return loadingWidgetBuilder != null
                ? loadingWidgetBuilder!.call()
                : Center(child: UIConfig.loadingAnimation(context));
          case LoadState.failed:
            return failedWidgetBuilder?.call(state) ??
                Center(
                  child: GestureDetector(
                      onTap: state.reLoadImage,
                      child: const Icon(Icons.sentiment_very_dissatisfied)),
                );
          case LoadState.completed:
            state.returnLoadStateChangedWidget = true;

            Widget child = completedWidgetBuilder?.call(state) ??
                _buildExtendedRawImage(state);

            if (borderRadius != BorderRadius.zero) {
              child = ClipRRect(borderRadius: borderRadius, child: child);
            }

            if (state.slidePageState != null) {
              child = ExtendedImageSlidePageHandler(
                  extendedImageSlidePageState: state.slidePageState,
                  child: child);
            }

            child = Center(
              child: Container(
                decoration: BoxDecoration(
                    boxShadow: shadows, borderRadius: borderRadius),
                child: child,
              ),
            );

            return _shouldFadeIn(state) ? FadeIn(child: child) : child;
        }
      },
      maxBytes: _effectiveMaxBytes,
      filterQuality:
          galleryImage.isGif ? FilterQuality.low : FilterQuality.medium,
    );
  }

  double _computeLoadingProgress(
      ImageChunkEvent? loadingProgress, ImageInfo? extendedImageInfo) {
    if (loadingProgress == null) {
      return 0.01;
    }

    int cur = loadingProgress.cumulativeBytesLoaded;
    int? total = extendedImageInfo?.sizeBytes;
    int? compressed = loadingProgress.expectedTotalBytes;
    return cur / (compressed ?? total ?? cur * 100);
  }

  /// replace image host: exhentai.org -> ehgt.org
  String _replaceEXUrl(String url) {
    Uri rawUri = Uri.parse(url);
    String host = rawUri.host;
    if (host != 's.exhentai.org') {
      return url;
    }

    Uri newUri = rawUri.replace(host: 'ehgt.org');
    return newUri.toString();
  }

  Widget _buildExtendedRawImage(ExtendedImageState state) {
    FittedSizes fittedSizes = applyBoxFit(
      fit,
      Size(state.extendedImageInfo!.image.width.toDouble(),
          state.extendedImageInfo!.image.height.toDouble()),
      Size(containerWidth ?? double.infinity,
          containerHeight ?? double.infinity),
    );

    return ExtendedRawImage(
      image: state.extendedImageInfo?.image,
      height: fittedSizes.destination.height == 0
          ? null
          : fittedSizes.destination.height,
      width: fittedSizes.destination.width == 0
          ? null
          : fittedSizes.destination.width,
      scale: state.extendedImageInfo?.scale ?? 1.0,
      fit: fit,
      filterQuality:
          galleryImage.isGif ? FilterQuality.low : FilterQuality.medium,
    );
  }

  int? get _effectiveMaxBytes => galleryImage.isGif ? null : maxBytes;

  bool _shouldFadeIn(ExtendedImageState state) {
    if ((state.frameNumber ?? 0) > 0) {
      return false;
    }

    return forceFadeIn || !state.wasSynchronouslyLoaded;
  }

  Size? _computeDecodeCacheSize(BuildContext context) {
    if (!galleryImage.isGif ||
        galleryImage.width == null ||
        galleryImage.height == null) {
      return null;
    }

    final double sourceWidth = galleryImage.width!;
    final double sourceHeight = galleryImage.height!;
    final double widthConstraint =
        _finitePositive(containerWidth) ?? sourceWidth;
    final double heightConstraint =
        _finitePositive(containerHeight) ?? sourceHeight;

    if (widthConstraint <= 0 || heightConstraint <= 0) {
      return null;
    }

    final FittedSizes fittedSizes = applyBoxFit(
      fit,
      Size(sourceWidth, sourceHeight),
      Size(widthConstraint, heightConstraint),
    );

    final double pixelRatio =
        MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final double targetWidth = math.min(
      sourceWidth,
      fittedSizes.destination.width * pixelRatio,
    );
    final double targetHeight = math.min(
      sourceHeight,
      fittedSizes.destination.height * pixelRatio,
    );

    if (!targetWidth.isFinite ||
        !targetHeight.isFinite ||
        targetWidth <= 0 ||
        targetHeight <= 0) {
      return null;
    }

    return Size(targetWidth.ceilToDouble(), targetHeight.ceilToDouble());
  }

  double? _finitePositive(double? value) {
    if (value == null || !value.isFinite || value <= 0) {
      return null;
    }

    return value;
  }
}
