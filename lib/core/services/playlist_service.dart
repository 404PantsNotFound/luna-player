import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/playlist.dart';
import '../models/track_item.dart';

class PlaylistService extends ChangeNotifier {
  final List<Playlist> _playlists = [];

  List<Playlist> get playlists => List.unmodifiable(_playlists);

  Future<void> init() async {
    await _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Load playlists with song count and first thumbnail
      final rows = await db.rawQuery('''
        SELECT
          p.id,
          p.name,
          p.createdAt,
          COUNT(ps.id) as songCount,
          (SELECT ps2.thumbnail FROM playlist_songs ps2
           WHERE ps2.playlistId = p.id
           ORDER BY ps2.addedAt DESC LIMIT 1) as thumbnailUrl
        FROM playlists p
        LEFT JOIN playlist_songs ps ON ps.playlistId = p.id
        GROUP BY p.id
        ORDER BY p.createdAt DESC
      ''');

      _playlists.clear();
      _playlists.addAll(rows.map((r) => Playlist.fromMap(r)));
      notifyListeners();
    } catch (e) {
      debugPrint('[PlaylistService] Failed to load: $e');
    }
  }

  Future<Playlist?> createPlaylist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final id = await db.insert('playlists', {
        'name': trimmed,
        'createdAt': now,
      });

      final playlist = Playlist(
        id: id,
        name: trimmed,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      );

      _playlists.insert(0, playlist);
      notifyListeners();
      return playlist;
    } catch (e) {
      debugPrint('[PlaylistService] Failed to create: $e');
      return null;
    }
  }

  Future<void> deletePlaylist(int playlistId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('playlists',
          where: 'id = ?', whereArgs: [playlistId]);
      await db.delete('playlist_songs',
          where: 'playlistId = ?', whereArgs: [playlistId]);

      _playlists.removeWhere((p) => p.id == playlistId);
      notifyListeners();
    } catch (e) {
      debugPrint('[PlaylistService] Failed to delete: $e');
    }
  }

  Future<void> renamePlaylist(int playlistId, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;

    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'playlists',
        {'name': trimmed},
        where: 'id = ?',
        whereArgs: [playlistId],
      );

      final index = _playlists.indexWhere((p) => p.id == playlistId);
      if (index >= 0) {
        _playlists[index] = Playlist(
          id: _playlists[index].id,
          name: trimmed,
          createdAt: _playlists[index].createdAt,
          songCount: _playlists[index].songCount,
          thumbnailUrl: _playlists[index].thumbnailUrl,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[PlaylistService] Failed to rename: $e');
    }
  }

  Future<bool> addSong(int playlistId, TrackItem track) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Check if song already in playlist
      final existing = await db.query(
        'playlist_songs',
        where: 'playlistId = ? AND videoId = ?',
        whereArgs: [playlistId, track.videoId],
      );

      if (existing.isNotEmpty) return false; // already in playlist

      await db.insert('playlist_songs', {
        'playlistId': playlistId,
        'videoId': track.videoId,
        'title': track.title,
        'artist': track.artist,
        'thumbnail': track.thumbnail,
        'addedAt': DateTime.now().millisecondsSinceEpoch,
      });

      await _loadPlaylists(); // refresh counts
      return true;
    } catch (e) {
      debugPrint('[PlaylistService] Failed to add song: $e');
      return false;
    }
  }

  Future<void> removeSong(int playlistId, String videoId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'playlist_songs',
        where: 'playlistId = ? AND videoId = ?',
        whereArgs: [playlistId, videoId],
      );
      await _loadPlaylists();
    } catch (e) {
      debugPrint('[PlaylistService] Failed to remove song: $e');
    }
  }

  Future<List<TrackItem>> getPlaylistSongs(int playlistId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'playlist_songs',
        where: 'playlistId = ?',
        whereArgs: [playlistId],
        orderBy: 'addedAt ASC',
      );

      return rows
          .map((r) => TrackItem(
                id: r['videoId'] as String,
                videoId: r['videoId'] as String,
                title: r['title'] as String,
                artist: r['artist'] as String,
                thumbnail: r['thumbnail'] as String,
              ))
          .toList();
    } catch (e) {
      debugPrint('[PlaylistService] Failed to get songs: $e');
      return [];
    }
  }

  bool isSongInPlaylist(int playlistId, String videoId) {
    // This is a sync check — for UI use only
    // For accurate check use getPlaylistSongs
    return false;
  }
}