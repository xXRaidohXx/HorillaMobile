class StopwatchManager {
  static final StopwatchManager _instance = StopwatchManager._internal();

  factory StopwatchManager() {
    return _instance;
  }

  StopwatchManager._internal();

  Stopwatch _stopwatch = Stopwatch();
  Duration _initialElapsedTime = Duration.zero;
  Duration _savedElapsedTime = Duration.zero;

  Stopwatch get stopwatch => _stopwatch;

  void startStopwatch({Duration initialTime = Duration.zero}) {
    if (!_stopwatch.isRunning) {
      if (_savedElapsedTime != Duration.zero) {
        _initialElapsedTime = _savedElapsedTime;
        _savedElapsedTime = Duration.zero;
      } else {
        _initialElapsedTime = initialTime;
      }
      _stopwatch.reset();
      _stopwatch.start();
    } else {
    }
  }

  void stopStopwatch() {
    _stopwatch.stop();
    _savedElapsedTime = _stopwatch.elapsed + _initialElapsedTime;
  }

  void resetStopwatch() {
    _stopwatch.reset();
    _initialElapsedTime = Duration.zero;
    _savedElapsedTime = Duration.zero;
  }

  Duration get elapsed {
    return _stopwatch.elapsed + _initialElapsedTime;
  }
}
