import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/widget/eh_image.dart';

class SingleImagePage extends StatefulWidget {
  const SingleImagePage({super.key});

  @override
  State<SingleImagePage> createState() => _SingleImagePageState();
}

class _SingleImagePageState extends State<SingleImagePage> {
  late final GalleryImage galleryImage = Get.arguments as GalleryImage;

  bool isManuallyPaused = false;
  bool hasFinishedOnce = false;
  int playbackVersion = 0;
  int? gifFrameCount;

  bool get isGifPlaying => galleryImage.isGif && !isManuallyPaused && !hasFinishedOnce;

  @override
  Widget build(BuildContext context) {
    return ExtendedImageSlidePage(
      resetPageDuration: const Duration(milliseconds: 200),
      slidePageBackgroundHandler: (Offset offset, Size pageSize) =>
          UIConfig.backGroundColor(context),
      child: GestureDetector(
        onLongPress: galleryImage.isGif ? () => _showGifMenu(context) : null,
        onSecondaryTap:
            galleryImage.isGif ? () => _showGifMenu(context) : null,
        child: EHImage(
          galleryImage: galleryImage,
          enableSlideOutPage: true,
          heroTag: galleryImage,
          gifPlaybackConfig: galleryImage.isGif
              ? EHImageGifPlaybackConfig(
                  enabled: isGifPlaying,
                  playbackVersion: playbackVersion,
                  frameCount: gifFrameCount,
                  onGifFrameCountResolved: (frameCount) {
                    if (!mounted || gifFrameCount == frameCount) {
                      return;
                    }

                    setState(() {
                      gifFrameCount = frameCount;
                    });
                  },
                  onGifFirstLoopCompleted: () {
                    if (!mounted || hasFinishedOnce) {
                      return;
                    }

                    setState(() {
                      hasFinishedOnce = true;
                      isManuallyPaused = false;
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }

  void _showGifMenu(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text(
                (isGifPlaying ? 'stopGifPlayback' : 'continueGifPlayback').tr),
            onPressed: () {
              Get.back<void>();

              setState(() {
                if (isGifPlaying) {
                  isManuallyPaused = true;
                  return;
                }

                if (hasFinishedOnce) {
                  playbackVersion++;
                }
                hasFinishedOnce = false;
                isManuallyPaused = false;
              });
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Get.back<void>(),
          child: Text('cancel'.tr),
        ),
      ),
    );
  }
}
