import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:animate_do/animate_do.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';

import '../service/gallery_download_service.dart';

typedef LoadingProgressWidgetBuilder = Widget Function(double);
typedef FailedWidgetBuilder = Widget Function(ExtendedImageState state);
typedef DownloadingWidgetBuilder = Widget Function();
typedef PausedWidgetBuilder = Widget Function();
typedef LoadingWidgetBuilder = Widget Function();
typedef CompletedWidgetBuilder = Widget? Function(ExtendedImageState state);

class EHImageGifPlaybackConfig {
  const EHImageGifPlaybackConfig({
    required this.enabled,
    this.playbackVersion = 0,
    this.frameCount,
    this.onGifFrameCountResolved,
    this.onGifFirstLoopCompleted,
    this.onGifPlayRequested,
    this.onGifPauseRequested,
  });

  final bool enabled;
  final int playbackVersion;
  final int? frameCount;
  final ValueChanged<int>? onGifFrameCountResolved;
  final VoidCallback? onGifFirstLoopCompleted;
  final VoidCallback? onGifPlayRequested;
  final VoidCallback? onGifPauseRequested;
}

class EHImage extends StatefulWidget {
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
  final EHImageGifPlaybackConfig? gifPlaybackConfig;

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
    this.gifPlaybackConfig,
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
    this.gifPlaybackConfig,
    this.loadingProgressWidgetBuilder,
    this.failedWidgetBuilder,
    this.downloadingWidgetBuilder,
    this.pausedWidgetBuilder,
    this.loadingWidgetBuilder,
    this.completedWidgetBuilder,
  });

  @override
  State<EHImage> createState() => _EHImageState();
}

class _EHImageState extends State<EHImage> {
  int? _resolvedGifFrameCount;
  bool _isResolvingGifFrameCount = false;
  bool _hasLoadedControlledGifFrame = false;
  int? _completedPlaybackVersion;

  @override
  void initState() {
    super.initState();
    _resolvedGifFrameCount = widget.gifPlaybackConfig?.frameCount;
  }

  @override
  void didUpdateWidget(covariant EHImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_gifIdentity(oldWidget.galleryImage) != _gifIdentity(widget.galleryImage)) {
      _resolvedGifFrameCount = widget.gifPlaybackConfig?.frameCount;
      _hasLoadedControlledGifFrame = false;
      _completedPlaybackVersion = null;
      _isResolvingGifFrameCount = false;
      return;
    }

    if (widget.gifPlaybackConfig?.frameCount != null &&
        widget.gifPlaybackConfig?.frameCount != _resolvedGifFrameCount) {
      _resolvedGifFrameCount = widget.gifPlaybackConfig?.frameCount;
    }

    if (oldWidget.gifPlaybackConfig?.playbackVersion !=
        widget.gifPlaybackConfig?.playbackVersion) {
      _hasLoadedControlledGifFrame = false;
      _completedPlaybackVersion = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = advancedSetting.inNoImageMode.value
        ? const SizedBox()
        : widget.galleryImage.path == null
            ? buildNetworkImage(context)
            : buildFileImage(context);

    if (_useControlledGifPlayback) {
      child = KeyedSubtree(
        key: ValueKey<String>(
            '${_gifIdentity(widget.galleryImage)}::${widget.gifPlaybackConfig!.playbackVersion}'),
        child: TickerMode(
          enabled:
              widget.gifPlaybackConfig!.enabled || !_hasLoadedControlledGifFrame,
          child: child,
        ),
      );
    }

    if (widget.galleryImage.isGif) {
      child = RepaintBoundary(child: child);
    }

    if (widget.heroTag != null && styleSetting.isInMobileLayout) {
      child = Hero(tag: widget.heroTag!, child: child);
    }

    if (widget.autoLayout) {
      return LayoutBuilder(
        builder: (_, constraints) => Container(
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          decoration: BoxDecoration(
            color: widget.containerColor,
            borderRadius: widget.borderRadius,
          ),
          child: child,
        ),
      );
    }

    return Container(
      height: widget.containerHeight,
      width: widget.containerWidth,
      decoration: BoxDecoration(
        color: widget.containerColor,
        borderRadius: widget.borderRadius,
      ),
      child: child,
    );
  }

  Widget buildNetworkImage(BuildContext context) {
    final Size? decodeCacheSize = _computeDecodeCacheSize(context);

    return ExtendedImage.network(
      _replaceEXUrl(widget.galleryImage.url),
      fit: widget.fit,
      height: widget.containerHeight,
      width: widget.containerWidth,
      cacheWidth: decodeCacheSize?.width.toInt(),
      cacheHeight: decodeCacheSize?.height.toInt(),
      cacheRawData: _shouldCacheGifRawData,
      handleLoadingProgress: widget.loadingProgressWidgetBuilder != null,
      printError: kDebugMode,
      enableSlideOutPage: widget.enableSlideOutPage,
      clearMemoryCacheWhenDispose: widget.clearMemoryCacheWhenDispose,
      loadStateChanged: (ExtendedImageState state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return widget.loadingProgressWidgetBuilder != null
                ? widget.loadingProgressWidgetBuilder!.call(
                    _computeLoadingProgress(
                        state.loadingProgress, state.extendedImageInfo),
                  )
                : Center(child: UIConfig.loadingAnimation(context));
          case LoadState.failed:
            return widget.failedWidgetBuilder?.call(state) ??
                Center(
                  child: GestureDetector(
                    onTap: state.reLoadImage,
                    child: const Icon(Icons.sentiment_very_dissatisfied),
                  ),
                );
          case LoadState.completed:
            state.returnLoadStateChangedWidget = true;

            _handleGifPlaybackState(state);

            Widget child = widget.completedWidgetBuilder?.call(state) ??
                _buildExtendedRawImage(state);

            if (widget.borderRadius != BorderRadius.zero) {
              child = ClipRRect(
                borderRadius: widget.borderRadius,
                child: child,
              );
            }

            if (state.slidePageState != null) {
              child = ExtendedImageSlidePageHandler(
                extendedImageSlidePageState: state.slidePageState,
                child: child,
              );
            }

            child = Center(
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: widget.shadows,
                  borderRadius: widget.borderRadius,
                ),
                child: child,
              ),
            );

            return _shouldFadeIn(state)
                ? WidgetExtension(child).fadeIn()
                : child;
        }
      },
      maxBytes: _effectiveMaxBytes,
      filterQuality: widget.galleryImage.isGif
          ? FilterQuality.low
          : FilterQuality.medium,
    );
  }

  Widget buildFileImage(BuildContext context) {
    if (widget.galleryImage.downloadStatus == DownloadStatus.paused) {
      return widget.pausedWidgetBuilder?.call() ??
          const Center(child: CircularProgressIndicator());
    }

    if (widget.galleryImage.downloadStatus == DownloadStatus.downloading) {
      return widget.downloadingWidgetBuilder?.call() ??
          const Center(child: CircularProgressIndicator());
    }

    final Size? decodeCacheSize = _computeDecodeCacheSize(context);

    return ExtendedImage.file(
      io.File(
        GalleryDownloadService.computeImageDownloadAbsolutePathFromRelativePath(
          widget.galleryImage.path!,
        ),
      ),
      fit: widget.fit,
      height: widget.containerHeight,
      width: widget.containerWidth,
      cacheWidth: decodeCacheSize?.width.toInt(),
      cacheHeight: decodeCacheSize?.height.toInt(),
      cacheRawData: _shouldCacheGifRawData,
      enableLoadState: widget.loadingWidgetBuilder != null ||
          widget.failedWidgetBuilder != null ||
          widget.completedWidgetBuilder != null,
      enableSlideOutPage: widget.enableSlideOutPage,
      borderRadius: widget.borderRadius,
      shape: BoxShape.rectangle,
      clearMemoryCacheWhenDispose: widget.clearMemoryCacheWhenDispose,
      loadStateChanged: (ExtendedImageState state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return widget.loadingWidgetBuilder != null
                ? widget.loadingWidgetBuilder!.call()
                : Center(child: UIConfig.loadingAnimation(context));
          case LoadState.failed:
            return widget.failedWidgetBuilder?.call(state) ??
                Center(
                  child: GestureDetector(
                    onTap: state.reLoadImage,
                    child: const Icon(Icons.sentiment_very_dissatisfied),
                  ),
                );
          case LoadState.completed:
            state.returnLoadStateChangedWidget = true;

            _handleGifPlaybackState(state);

            Widget child = widget.completedWidgetBuilder?.call(state) ??
                _buildExtendedRawImage(state);

            if (widget.borderRadius != BorderRadius.zero) {
              child = ClipRRect(
                borderRadius: widget.borderRadius,
                child: child,
              );
            }

            if (state.slidePageState != null) {
              child = ExtendedImageSlidePageHandler(
                extendedImageSlidePageState: state.slidePageState,
                child: child,
              );
            }

            child = Center(
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: widget.shadows,
                  borderRadius: widget.borderRadius,
                ),
                child: child,
              ),
            );

            return _shouldFadeIn(state) ? FadeIn(child: child) : child;
        }
      },
      maxBytes: _effectiveMaxBytes,
      filterQuality: widget.galleryImage.isGif
          ? FilterQuality.low
          : FilterQuality.medium,
    );
  }

  double _computeLoadingProgress(
      ImageChunkEvent? loadingProgress, ImageInfo? extendedImageInfo) {
    if (loadingProgress == null) {
      return 0.01;
    }

    final int currentBytes = loadingProgress.cumulativeBytesLoaded;
    final int? totalBytes = extendedImageInfo?.sizeBytes;
    final int? compressedBytes = loadingProgress.expectedTotalBytes;
    return currentBytes /
        (compressedBytes ?? totalBytes ?? currentBytes * 100);
  }

  String _replaceEXUrl(String url) {
    final Uri rawUri = Uri.parse(url);
    if (rawUri.host != 's.exhentai.org') {
      return url;
    }

    return rawUri.replace(host: 'ehgt.org').toString();
  }

  Widget _buildExtendedRawImage(ExtendedImageState state) {
    final FittedSizes fittedSizes = applyBoxFit(
      widget.fit,
      Size(
        state.extendedImageInfo!.image.width.toDouble(),
        state.extendedImageInfo!.image.height.toDouble(),
      ),
      Size(
        widget.containerWidth ?? double.infinity,
        widget.containerHeight ?? double.infinity,
      ),
    );

    return ExtendedRawImage(
      image: state.extendedImageInfo?.image,
      height:
          fittedSizes.destination.height == 0 ? null : fittedSizes.destination.height,
      width:
          fittedSizes.destination.width == 0 ? null : fittedSizes.destination.width,
      scale: state.extendedImageInfo?.scale ?? 1.0,
      fit: widget.fit,
      filterQuality: widget.galleryImage.isGif
          ? FilterQuality.low
          : FilterQuality.medium,
    );
  }

  int? get _effectiveMaxBytes => widget.galleryImage.isGif ? null : widget.maxBytes;

  bool get _shouldCacheGifRawData => _useControlledGifPlayback;

  bool get _useControlledGifPlayback =>
      widget.galleryImage.isGif && widget.gifPlaybackConfig != null;

  int? get _gifFrameCount => widget.gifPlaybackConfig?.frameCount ?? _resolvedGifFrameCount;

  bool _shouldFadeIn(ExtendedImageState state) {
    if ((state.frameNumber ?? 0) > 0) {
      return false;
    }

    return widget.forceFadeIn || !state.wasSynchronouslyLoaded;
  }

  void _handleGifPlaybackState(ExtendedImageState state) {
    if (!_useControlledGifPlayback) {
      return;
    }

    if (!_hasLoadedControlledGifFrame) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _hasLoadedControlledGifFrame) {
          return;
        }

        setState(() {
          _hasLoadedControlledGifFrame = true;
        });
      });
    }

    _ensureGifFrameCount(state);

    final int? gifFrameCount = _gifFrameCount;
    if (!widget.gifPlaybackConfig!.enabled || gifFrameCount == null) {
      return;
    }

    final int frameNumber = state.frameNumber ?? 0;
    if (frameNumber + 1 < gifFrameCount) {
      return;
    }

    final int playbackVersion = widget.gifPlaybackConfig!.playbackVersion;
    if (_completedPlaybackVersion == playbackVersion) {
      return;
    }

    _completedPlaybackVersion = playbackVersion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.gifPlaybackConfig?.playbackVersion != playbackVersion) {
        return;
      }

      widget.gifPlaybackConfig?.onGifFirstLoopCompleted?.call();
    });
  }

  Future<void> _ensureGifFrameCount(ExtendedImageState state) async {
    if (!_useControlledGifPlayback ||
        _gifFrameCount != null ||
        _isResolvingGifFrameCount) {
      return;
    }

    if (state.imageProvider is! ExtendedImageProvider<dynamic>) {
      return;
    }

    _isResolvingGifFrameCount = true;

    try {
      final ExtendedImageProvider<dynamic> imageProvider =
          state.imageProvider as ExtendedImageProvider<dynamic>;
      final ui.Codec codec =
          await ui.instantiateImageCodec(imageProvider.rawImageData);
      final int frameCount = codec.frameCount;
      codec.dispose();

      if (!mounted) {
        return;
      }

      _resolvedGifFrameCount = frameCount;
      widget.gifPlaybackConfig?.onGifFrameCountResolved?.call(frameCount);
      setState(() {});
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Resolve gif frame count failed: $error');
      }
    } finally {
      _isResolvingGifFrameCount = false;
    }
  }

  Size? _computeDecodeCacheSize(BuildContext context) {
    if (!widget.galleryImage.isGif ||
        widget.galleryImage.width == null ||
        widget.galleryImage.height == null) {
      return null;
    }

    final double sourceWidth = widget.galleryImage.width!;
    final double sourceHeight = widget.galleryImage.height!;
    final double widthConstraint =
        _finitePositive(widget.containerWidth) ?? sourceWidth;
    final double heightConstraint =
        _finitePositive(widget.containerHeight) ?? sourceHeight;

    if (widthConstraint <= 0 || heightConstraint <= 0) {
      return null;
    }

    final FittedSizes fittedSizes = applyBoxFit(
      widget.fit,
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

  String _gifIdentity(GalleryImage galleryImage) {
    return galleryImage.path ?? galleryImage.url;
  }
}
