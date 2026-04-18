import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/pages/read/read_gif_playback_controller.dart';

void main() {
  group('ReadGifPlaybackController', () {
    test('auto selects the current gif candidate', () {
      final ReadGifPlaybackController controller = ReadGifPlaybackController();

      controller.syncAutoCandidate(3, isGifCandidate: true);

      expect(controller.activeGifIndex, 3);
      expect(controller.isGifPlaying(3), isTrue);
    });

    test('switching pages pauses the old gif and activates the new gif', () {
      final ReadGifPlaybackController controller = ReadGifPlaybackController();

      controller.syncAutoCandidate(1, isGifCandidate: true);
      controller.syncAutoCandidate(4, isGifCandidate: true);

      expect(controller.activeGifIndex, 4);
      expect(controller.isGifPlaying(1), isFalse);
      expect(controller.isGifPlaying(4), isTrue);
    });

    test('manually paused gif does not auto resume when revisited', () {
      final ReadGifPlaybackController controller = ReadGifPlaybackController();

      controller.syncAutoCandidate(2, isGifCandidate: true);
      controller.pause(2);
      controller.syncAutoCandidate(5, isGifCandidate: true);
      controller.syncAutoCandidate(2, isGifCandidate: true);

      expect(controller.activeGifIndex, isNull);
      expect(controller.manuallyPausedGifIndexes, contains(2));
    });

    test('first loop completion blocks later auto playback until resumed', () {
      final ReadGifPlaybackController controller = ReadGifPlaybackController();

      controller.syncAutoCandidate(6, isGifCandidate: true);
      controller.markFirstLoopCompleted(6);
      controller.syncAutoCandidate(6, isGifCandidate: true);

      expect(controller.activeGifIndex, isNull);
      expect(controller.finishedOnceGifIndexes, contains(6));
    });

    test('manual resume takes over current gif and restarts after completion', () {
      final ReadGifPlaybackController controller = ReadGifPlaybackController();

      controller.syncAutoCandidate(1, isGifCandidate: true);
      controller.syncAutoCandidate(2, isGifCandidate: true);

      expect(controller.activeGifIndex, 2);

      controller.resume(1);
      expect(controller.activeGifIndex, 1);
      expect(controller.isGifPlaying(2), isFalse);
      expect(controller.playbackVersionOf(1), 0);

      controller.markFirstLoopCompleted(1);
      controller.resume(1);
      expect(controller.activeGifIndex, 1);
      expect(controller.playbackVersionOf(1), 1);
    });
  });
}
