class ReadGifPlaybackController {
  int? activeGifIndex;

  final Set<int> manuallyPausedGifIndexes = <int>{};
  final Set<int> finishedOnceGifIndexes = <int>{};
  final Map<int, int> gifFrameCountCache = <int, int>{};

  final Map<int, int> _playbackVersions = <int, int>{};

  bool isGifPlaying(int index) {
    return activeGifIndex == index;
  }

  bool isGifAutoPlayable(int index) {
    return !manuallyPausedGifIndexes.contains(index) &&
        !finishedOnceGifIndexes.contains(index);
  }

  int playbackVersionOf(int index) {
    return _playbackVersions[index] ?? 0;
  }

  int? frameCountOf(int index) {
    return gifFrameCountCache[index];
  }

  void cacheFrameCount(int index, int frameCount) {
    gifFrameCountCache[index] = frameCount;
  }

  Set<int> syncAutoCandidate(int? candidateIndex, {required bool isGifCandidate}) {
    final int? previousActiveGifIndex = activeGifIndex;
    final int? nextActiveGifIndex;

    if (candidateIndex == null ||
        !isGifCandidate ||
        !isGifAutoPlayable(candidateIndex)) {
      nextActiveGifIndex = null;
    } else {
      nextActiveGifIndex = candidateIndex;
    }

    activeGifIndex = nextActiveGifIndex;

    return _affectedIndexes(previousActiveGifIndex, nextActiveGifIndex);
  }

  Set<int> pause(int index) {
    final int? previousActiveGifIndex = activeGifIndex;

    manuallyPausedGifIndexes.add(index);
    if (activeGifIndex == index) {
      activeGifIndex = null;
    }

    return _affectedIndexes(previousActiveGifIndex, activeGifIndex, index);
  }

  Set<int> resume(int index) {
    final int? previousActiveGifIndex = activeGifIndex;
    final bool shouldRestart = finishedOnceGifIndexes.remove(index);

    manuallyPausedGifIndexes.remove(index);
    if (shouldRestart) {
      _playbackVersions[index] = playbackVersionOf(index) + 1;
    }
    activeGifIndex = index;

    return _affectedIndexes(previousActiveGifIndex, activeGifIndex, index);
  }

  Set<int> markFirstLoopCompleted(int index) {
    final int? previousActiveGifIndex = activeGifIndex;

    finishedOnceGifIndexes.add(index);
    manuallyPausedGifIndexes.remove(index);
    if (activeGifIndex == index) {
      activeGifIndex = null;
    }

    return _affectedIndexes(previousActiveGifIndex, activeGifIndex, index);
  }

  Set<int> _affectedIndexes(int? previousActiveGifIndex, int? nextActiveGifIndex,
      [int? currentIndex]) {
    return <int>{
      if (previousActiveGifIndex != null) previousActiveGifIndex,
      if (nextActiveGifIndex != null) nextActiveGifIndex,
      if (currentIndex != null) currentIndex,
    };
  }
}
