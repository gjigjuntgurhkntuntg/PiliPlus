import 'dart:async';

class CompletedGate {
  const CompletedGate._();

  // media_kit may emit completed slightly before the published UI position
  // catches up. Treat only the near tail as a valid completed candidate.
  static const Duration maxRemaining = Duration(milliseconds: 1200);
  // Below this threshold the playback is close enough to publish completed.
  static const Duration readyRemaining = Duration(milliseconds: 100);
  // Extra settle time lets final position listeners run before next-item logic.
  static const Duration buffer = Duration(milliseconds: 200);

  static Duration? remaining({
    required Duration total,
    required Duration position,
    Duration maxAllowed = maxRemaining,
  }) {
    if (total <= Duration.zero) {
      return null;
    }
    final remaining = total - position;
    if (remaining > maxAllowed) {
      return null;
    }
    return remaining <= Duration.zero ? Duration.zero : remaining;
  }

  static bool isReady(Duration remaining) => remaining <= readyRemaining;

  // Use the larger remaining time when raw player state and published UI state
  // disagree, so the gate errs toward finishing late instead of early.
  static Duration? longer(Duration? a, Duration? b) {
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    return a >= b ? a : b;
  }

  static Duration tailPlaybackWait(
    Duration remaining, {
    required double playbackRate,
  }) {
    final rate = playbackRate > 0 ? playbackRate : 1.0;
    final playbackMs = remaining.inMilliseconds / rate;
    return Duration(milliseconds: playbackMs.ceil());
  }

  // For pause-state suppression we also include the settle buffer; completed
  // publication itself schedules the buffer separately after syncing position.
  static Duration tailWait(
    Duration remaining, {
    required double playbackRate,
  }) => tailPlaybackWait(remaining, playbackRate: playbackRate) + buffer;
}

class CompletedGateScheduler {
  Timer? _timer;
  int _token = 0;

  bool cancel() {
    final hadPending = _timer != null;
    _token += 1;
    _timer?.cancel();
    _timer = null;
    return hadPending;
  }

  void schedule(Duration delay, void Function() onFire) {
    // Token invalidation prevents an older tail timer from firing after seek,
    // manual pause, media switch, or a newer completed candidate.
    final token = ++_token;
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (token != _token) {
        return;
      }
      _timer = null;
      onFire();
    });
  }
}
