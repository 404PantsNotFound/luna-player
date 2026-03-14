import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/track_item.dart';
import 'youtube_data_api.dart';

import 'youtube_data_api.dart';

enum QueueRepeatMode { none, one }

class QueueService extends ChangeNotifier {
  final YoutubeDataApi _api;

  QueueService(this._api);

  final List<TrackItem> _queue = [];
  final List<TrackItem> _originalQueue = [];
  int _currentIndex = -1;
  bool _isFetchingMore = false;

  bool _shuffleOn = false;
  QueueRepeatMode _repeatMode = QueueRepeatMode.none;
  bool _locked = false; // ✅ lock state

  List<TrackItem> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  bool get hasPrevious => _currentIndex > 0;
  int get queueLength => _queue.length;
  bool get shuffleOn => _shuffleOn;
  QueueRepeatMode get repeatMode => _repeatMode;
  bool get locked => _locked;

  TrackItem? get currentTrack =>
      _currentIndex >= 0 && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;

  void setQueue(List<TrackItem> tracks, int startIndex) {
    if (_locked) return; // ✅ ignore if locked
    _queue.clear();
    _originalQueue.clear();
    _queue.addAll(tracks);
    _originalQueue.addAll(tracks);
    _currentIndex = startIndex;
    debugPrint('[QueueService] Queue set: ${_queue.length} tracks, starting at $startIndex');
    notifyListeners();
    _fetchMoreIfNeeded();
  }

  void toggleLock() {
    _locked = !_locked;
    debugPrint('[QueueService] Locked: $_locked');
    notifyListeners();
  }

  // ✅ Reorder — drag from oldIndex to newIndex
  void reorder(int oldIndex, int newIndex) {
    if (_locked) return;

    // Adjust for ReorderableListView behaviour
    if (newIndex > oldIndex) newIndex--;

    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);

    // Keep currentIndex pointing to the same song
    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }

    notifyListeners();
  }

  // ✅ Remove a song from queue
  void removeAt(int index) {
    if (_locked) return;
    if (index < 0 || index >= _queue.length) return;

    _queue.removeAt(index);

    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex && _currentIndex >= _queue.length) {
      _currentIndex = _queue.length - 1;
    }

    notifyListeners();
  }

  void toggleShuffle() {
    if (_locked) return;
    _shuffleOn = !_shuffleOn;

    if (_shuffleOn) {
      final current = currentTrack;
      final remaining = _queue
          .where((t) => t.videoId != current?.videoId)
          .toList()
        ..shuffle(Random());

      _queue.clear();
      if (current != null) {
        _queue.add(current);
        _currentIndex = 0;
      }
      _queue.addAll(remaining);
    } else {
      final current = currentTrack;
      _queue.clear();
      _queue.addAll(_originalQueue);
      _currentIndex = current != null
          ? _queue.indexWhere((t) => t.videoId == current.videoId)
          : 0;
      if (_currentIndex < 0) _currentIndex = 0;
    }

    debugPrint('[QueueService] Shuffle: $_shuffleOn');
    notifyListeners();
  }

  void toggleRepeatOne() {
    _repeatMode =
        _repeatMode == QueueRepeatMode.one ? QueueRepeatMode.none : QueueRepeatMode.one;
    debugPrint('[QueueService] Repeat: $_repeatMode');
    notifyListeners();
  }

  TrackItem? skipNext() {
    if (_locked) return null; // ✅ block if locked
    if (_queue.isEmpty) return null;

    if (_repeatMode == QueueRepeatMode.one) {
      return _queue[_currentIndex];
    }

    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
    } else {
      _currentIndex = 0;
    }

    final track = _queue[_currentIndex];
    debugPrint('[QueueService] skipNext → index=$_currentIndex title=${track.title}');
    notifyListeners();
    _fetchMoreIfNeeded();
    return track;
  }

  TrackItem? skipPrevious() {
    if (_locked) return null; // ✅ block if locked
    if (_queue.isEmpty) return null;

    if (_currentIndex > 0) {
      _currentIndex--;
    }

    final track = _queue[_currentIndex];
    debugPrint('[QueueService] skipPrevious → index=$_currentIndex title=${track.title}');
    notifyListeners();
    return track;
  }

  TrackItem? getNextForAutoAdvance() {
    if (_locked) return null; // ✅ block auto-advance if locked
    if (_queue.isEmpty) return null;

    if (_repeatMode == QueueRepeatMode.one) {
      return _queue[_currentIndex];
    }

    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
    } else {
      _currentIndex = 0;
    }

    notifyListeners();
    _fetchMoreIfNeeded();
    return _queue[_currentIndex];
  }

  Future<void> advanceToNext() async {
    if (_locked) return;
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      notifyListeners();
      _fetchMoreIfNeeded();
    } else {
      await _fetchMoreAndAdvance();
    }
  }

  Future<void> _fetchMoreIfNeeded() async {
    if (_locked) return;
    final songsAhead = _queue.length - _currentIndex - 1;
    if (songsAhead < 3 && !_isFetchingMore) {
      await _fetchMore();
    }
  }

  Future<void> _fetchMoreAndAdvance() async {
    await _fetchMore();
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      notifyListeners();
    }
  }

  Future<void> _fetchMore() async {
    if (_locked || _isFetchingMore || _queue.isEmpty) return;
    _isFetchingMore = true;

    try {
      final current = currentTrack;
      if (current == null) return;

      final query = '${current.artist} music';
      final more = await _api.searchTracks(query);

      final existing = _queue.map((t) => t.videoId).toSet();
      final fresh =
          more.where((t) => !existing.contains(t.videoId)).toList();

      if (fresh.isNotEmpty) {
        _queue.addAll(fresh);
        _originalQueue.addAll(fresh);

        if (_shuffleOn) {
          final newTracks = _queue.sublist(_currentIndex + 1)
            ..shuffle(Random());
          _queue.replaceRange(
              _currentIndex + 1, _queue.length, newTracks);
        }

        notifyListeners();
        debugPrint('[QueueService] Added ${fresh.length} more, total=${_queue.length}');
      }
    } catch (e) {
      debugPrint('[QueueService] Fetch more failed: $e');
    } finally {
      _isFetchingMore = false;
    }
  }
}