import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/track_item.dart';
import '../../../core/services/audio_handler.dart';

class PlayerService extends ChangeNotifier {
  final LunaAudioHandler _handler;

  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<ProcessingState>? _processingSub;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isSettingUrl = false;
  String? _currentUrl;
  String? _errorMessage;
  TrackItem? _currentTrack;
  final List<TrackItem> _recentlyPlayed = [];

  bool _isManuallyStopping = false;
  VoidCallback? onSongComplete;

  Duration get duration => _duration;
  Duration get position => _position;
  bool get isPlaying => _isPlaying;
  bool get isSettingUrl => _isSettingUrl;
  String? get currentUrl => _currentUrl;
  String? get errorMessage => _errorMessage;
  TrackItem? get currentTrack => _currentTrack;
  bool get hasTrack => _currentTrack != null;
  List<TrackItem> get recentlyPlayed => List.unmodifiable(_recentlyPlayed);

  PlayerService(this._handler) {
    _loadRecentlyPlayed();

    _durationSub = _handler.durationStream.listen((value) {
      _duration = value ?? Duration.zero;
      notifyListeners();
    });

    _positionSub = _handler.positionStream.listen((value) {
      _position = value;
      notifyListeners();
    });

    _playerStateSub = _handler.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });

    _processingSub = _handler.processingStateStream.listen((state) {
      if (state == ProcessingState.completed && !_isManuallyStopping) {
        onSongComplete?.call();
      }
      notifyListeners();
    });
  }

  Future<void> _loadRecentlyPlayed() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'recently_played',
        orderBy: 'playedAt DESC',
        limit: 20,
      );

      _recentlyPlayed.clear();
      _recentlyPlayed.addAll(rows.map((row) => TrackItem(
            id: row['videoId'] as String,
            videoId: row['videoId'] as String,
            title: row['title'] as String,
            artist: row['artist'] as String,
            thumbnail: row['thumbnail'] as String,
          )));

      notifyListeners();
    } catch (e) {
      debugPrint('[PlayerService] Failed to load recently played: $e');
    }
  }

  Future<void> _saveToRecentlyPlayed(TrackItem track) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'recently_played',
        {
          'videoId': track.videoId,
          'title': track.title,
          'artist': track.artist,
          'thumbnail': track.thumbnail,
          'playedAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await db.execute('''
        DELETE FROM recently_played
        WHERE videoId NOT IN (
          SELECT videoId FROM recently_played
          ORDER BY playedAt DESC
          LIMIT 20
        )
      ''');
    } catch (e) {
      debugPrint('[PlayerService] Failed to save recently played: $e');
    }
  }

  Future<void> setUrl(
    String url, {
    bool autoPlay = true,
    TrackItem? track,
  }) async {
    try {
      _isManuallyStopping = true;
      await _handler.stop();
      _isManuallyStopping = false;

      _isSettingUrl = true;
      _errorMessage = null;
      _currentUrl = url;

      if (track != null) {
        _currentTrack = track;
        _recentlyPlayed.removeWhere((t) => t.videoId == track.videoId);
        _recentlyPlayed.insert(0, track);
        if (_recentlyPlayed.length > 20) _recentlyPlayed.removeLast();
        _saveToRecentlyPlayed(track);
      }

      notifyListeners();

      final mediaItem = track != null
          ? MediaItem(
              id: track.videoId,
              title: track.title,
              artist: track.artist,
              artUri: track.thumbnail.isNotEmpty
                  ? Uri.parse(track.thumbnail)
                  : null,
              displayTitle: track.title,
              displaySubtitle: track.artist,
            )
          : MediaItem(
              id: url,
              title: 'Unknown',
              artist: 'Unknown',
            );

      await _handler.playFromUrl(url, mediaItem: mediaItem);
    } catch (e, st) {
      _errorMessage = 'Failed to load audio: $e';
      debugPrint(_errorMessage);
      debugPrintStack(stackTrace: st);
      notifyListeners();
    } finally {
      _isManuallyStopping = false;
      _isSettingUrl = false;
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    try {
      if (_handler.playing) {
        await _handler.pause();
      } else {
        await _handler.play();
      }
    } catch (e) {
      _errorMessage = 'Toggle failed: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _handler.seek(position);
    } catch (e) {
      _errorMessage = 'Seek failed: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  Future<void> stop() async {
    try {
      _isManuallyStopping = true;
      await _handler.stop();
      _isManuallyStopping = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[PlayerService] Stop failed: $e');
    } finally {
      _isManuallyStopping = false;
    }
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _processingSub?.cancel();
    super.dispose();
  }
}