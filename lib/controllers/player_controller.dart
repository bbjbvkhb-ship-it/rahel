import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/audio_handler.dart';

class PlayerController extends ChangeNotifier {
  final MyAudioHandler audioHandler;
  Timer? _timer;
  Duration? _remainingTime;

  PlayerController({required this.audioHandler});

  Duration? get remainingTime => _remainingTime;
  bool get isTimerActive => _timer != null;

  void startSleepTimer(Duration duration) {
    cancelSleepTimer();
    _remainingTime = duration;
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime == null) {
        cancelSleepTimer();
        return;
      }
      
      final newTime = _remainingTime! - const Duration(seconds: 1);
      if (newTime.inSeconds <= 0) {
        _remainingTime = Duration.zero;
        audioHandler.pause();
        cancelSleepTimer();
      } else {
        _remainingTime = newTime;
        notifyListeners();
      }
    });
  }

  void cancelSleepTimer() {
    _timer?.cancel();
    _timer = null;
    _remainingTime = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
