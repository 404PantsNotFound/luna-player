import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/track_item.dart';

class YoutubeDataApi {
  final YoutubeExplode _yt = YoutubeExplode();

  void _log(String message) {
    debugPrint('[YoutubeDataApi] $message');
  }

  Future<List<TrackItem>> searchTracks(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      _log('Searching for: $trimmed');

      final searchList = await _yt.search.search(trimmed);
      final tracks = <TrackItem>[];

      // ✅ Log what types we're actually getting
      for (final result in searchList) {
        _log('Result type: ${result.runtimeType} — ${result}');
        break; // just log the first one
      }

      for (final result in searchList) {
        // ✅ Try dynamic access instead of type checking
        try {
          final dynamic r = result;
          final String? videoId = r.id?.value as String?;
          final String? title = r.title as String?;
          final String? author = r.author as String?;
          final Duration? duration = r.duration as Duration?;

          if (videoId == null || videoId.isEmpty) continue;
          if (title == null || title.isEmpty) continue;

          // Skip long videos
          if (duration != null && duration.inMinutes > 15) continue;

          final thumbnail =
              'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

          tracks.add(TrackItem(
            id: videoId,
            videoId: videoId,
            title: title,
            artist: author ?? 'Unknown',
            thumbnail: thumbnail,
            duration: duration,
          ));

          if (tracks.length >= 20) break;
        } catch (e) {
          _log('Skipping result: $e');
          continue;
        }
      }

      _log('Found ${tracks.length} tracks');
      return tracks;
    } catch (e, st) {
      _log('Search failed: $e');
      debugPrint('$st');
      return [];
    }
  }

  void dispose() {
    _yt.close();
  }
}