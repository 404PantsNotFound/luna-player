import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DownloadQuality {
  low,
  medium,
  high;

  String get label {
    switch (this) {
      case DownloadQuality.low:
        return 'Low (~48 kbps)';
      case DownloadQuality.medium:
        return 'Medium (~128 kbps)';
      case DownloadQuality.high:
        return 'High (best available)';
    }
  }

  String get key => name;
}

class SettingsService extends ChangeNotifier {
  DownloadQuality _downloadQuality = DownloadQuality.high;
  bool _initialized = false;
  bool _backgroundPlayback = true;
  bool _playWhenClosed = false; // ✅ default OFF

  DownloadQuality get downloadQuality => _downloadQuality;
  bool get hasDefaultQuality => _initialized;
  bool get backgroundPlayback => _backgroundPlayback;
  bool get playWhenClosed => _playWhenClosed;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getString('download_quality');
    if (saved != null) {
      _downloadQuality = DownloadQuality.values.firstWhere(
        (q) => q.key == saved,
        orElse: () => DownloadQuality.high,
      );
      _initialized = true;
    } else {
      _initialized = false;
    }

    _backgroundPlayback = prefs.getBool('background_playback') ?? true;
    _playWhenClosed = prefs.getBool('play_when_closed') ?? false;
    notifyListeners();
  }

  Future<void> setDownloadQuality(DownloadQuality quality) async {
    _downloadQuality = quality;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('download_quality', quality.key);
    notifyListeners();
  }

  Future<void> setBackgroundPlayback(bool value) async {
    _backgroundPlayback = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_playback', value);
    notifyListeners();
  }

  Future<void> setPlayWhenClosed(bool value) async {
    _playWhenClosed = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('play_when_closed', value);
    notifyListeners();
  }
}