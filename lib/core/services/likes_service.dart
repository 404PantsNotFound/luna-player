import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/track_item.dart';

class LikesService extends ChangeNotifier {
  final List<TrackItem> _likedSongs = [];

  List<TrackItem> get likedSongs => List.unmodifiable(_likedSongs);

  Future<void> init() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'liked_songs',
      orderBy: 'likedAt DESC',
    );

    _likedSongs.clear();
    _likedSongs.addAll(rows.map((row) => TrackItem(
          id: row['videoId'] as String,
          videoId: row['videoId'] as String,
          title: row['title'] as String,
          artist: row['artist'] as String,
          thumbnail: row['thumbnail'] as String,
        )));

    notifyListeners();
  }

  bool isLiked(String videoId) {
    return _likedSongs.any((t) => t.videoId == videoId);
  }

  Future<void> toggleLike(TrackItem track) async {
    if (isLiked(track.videoId)) {
      await _unlike(track.videoId);
    } else {
      await _like(track);
    }
  }

  Future<void> _like(TrackItem track) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('liked_songs', {
      'videoId': track.videoId,
      'title': track.title,
      'artist': track.artist,
      'thumbnail': track.thumbnail,
      'likedAt': DateTime.now().millisecondsSinceEpoch,
    });
    _likedSongs.insert(0, track);
    notifyListeners();
  }

  Future<void> _unlike(String videoId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'liked_songs',
      where: 'videoId = ?',
      whereArgs: [videoId],
    );
    _likedSongs.removeWhere((t) => t.videoId == videoId);
    notifyListeners();
  }
}