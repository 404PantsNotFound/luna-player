import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateService {
  static const String _githubRepo = '404PantsNotFound/luna-player';
  static const String _releasesUrl =
      'https://api.github.com/repos/$_githubRepo/releases/latest';

  String? latestVersion;
  String? downloadUrl;
  bool updateAvailable = false;
  bool showPatchNotes = false;
  String currentVersion = '';

  // ✅ Patch notes per version — update this every release
  static const Map<String, List<String>> _patchNotes = {
    '1.5.0': [
      '🔧 Fixed background playback — music now keeps playing when minimized',
      '🔍 Search now shows results as you type',
      '🏠 Home page now shows curated content based on your taste',
      '📋 Full playlist support — create, edit, reorder',
      '🔀 Shuffle and repeat modes',
      '📜 Queue page with drag to reorder and lock',
      '🕓 Search history with quick re-search',
      '🖼️ Higher quality album art',
      '✨ Scrolling text for long song titles',
      '🔔 Update notifications when new version is available',
    ],
    '1.0.0': [
      '🎵 Initial release of Luna',
      '🔍 Search and stream music from YouTube',
      '📥 Download songs for offline listening',
      '❤️ Like and save favourite songs',
      '🎵 Background playback with notification controls',
    ],
  };

  Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = info.version;

      final prefs = await SharedPreferences.getInstance();
      final lastSeenVersion = prefs.getString('last_seen_version') ?? '';

      // ✅ Show patch notes if this is a new version
      if (lastSeenVersion != currentVersion) {
        showPatchNotes = true;
        await prefs.setString('last_seen_version', currentVersion);
      }

      debugPrint('[UpdateService] Current: $currentVersion LastSeen: $lastSeenVersion ShowPatchNotes: $showPatchNotes');
    } catch (e) {
      debugPrint('[UpdateService] Init failed: $e');
    }
  }

  List<String> getPatchNotes() {
    return _patchNotes[currentVersion] ?? 
           _patchNotes[_patchNotes.keys.first] ?? 
           ['Bug fixes and improvements'];
  }

  Future<void> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse(_releasesUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final tagName = data['tag_name'] as String;
      latestVersion = tagName.replaceAll('v', '');

      final assets = data['assets'] as List;
      for (final asset in assets) {
        if ((asset['name'] as String).endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String;
          break;
        }
      }

      updateAvailable = _isNewer(latestVersion!, currentVersion);
      debugPrint('[UpdateService] Latest: $latestVersion Available: $updateAvailable');
    } catch (e) {
      debugPrint('[UpdateService] Check failed: $e');
    }
  }

  bool _isNewer(String latest, String current) {
    try {
      final l = latest.split('.').map(int.parse).toList();
      final c = current.split('.').map(int.parse).toList();
      while (l.length < 3) l.add(0);
      while (c.length < 3) c.add(0);
      for (int i = 0; i < 3; i++) {
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
    } catch (_) {}
    return false;
  }
}