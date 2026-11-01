import 'dart:async';

class VolumeController {
  static final VolumeController _instance = VolumeController._internal();
  static VolumeController get instance => _instance;
  factory VolumeController() => _instance;
  VolumeController._internal();

  final _controller = StreamController<double>.broadcast();
  double _volume = 1.0;
  bool showSystemUI = true;

  bool get isShowSystemUI => showSystemUI;

  Future<double> getVolume() async {
    return _volume;
  }

  Future<void> setVolume(double volume, {bool showSystemUI = true}) async {
    _volume = volume.clamp(0.0, 1.0);
    this.showSystemUI = showSystemUI;
    _controller.add(_volume);
  }

  void addListener(void Function(double) listener, {bool fetchInitialVolume = true}) {
    _controller.stream.listen(listener);
    if (fetchInitialVolume) {
      listener(_volume);
    }
  }

  StreamSubscription<double> listener({required void Function(double) onVolumeChanged}) {
    return _controller.stream.listen(onVolumeChanged);
  }

  void removeListener() {}

  Future<double> maxVolume() async => 1.0;
}
