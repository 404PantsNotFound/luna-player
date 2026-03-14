import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../database/database_helper.dart';
import '../models/download_item.dart';
import '../models/track_item.dart';
import 'settings_service.dart';

enum DownloadStatus { idle, downloading, done, failed }

class DownloadService extends ChangeNotifier {
  final SettingsService _settings;
  final YoutubeExplode _yt = YoutubeExplode();
  final Dio _dio = Dio();

  DownloadService(this._settings);

  final List<DownloadItem> _downloads = [];
  final Map<String, DownloadStatus> _statusMap = {};
  final Map<String, double> _progressMap = {};

  List<DownloadItem> get downloads => List.unmodifiable(_downloads);

  DownloadStatus statusOf(String videoId) =>
      _statusMap[videoId] ?? DownloadStatus.idle;

  double progressOf(String videoId) => _progressMap[videoId] ?? 0.0;

  bool isDownloaded(String videoId) =>
      _downloads.any((d) => d.videoId == videoId);

  Future<void> init() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('downloads', orderBy: 'downloadedAt DESC');
      _downloads.clear();
      _downloads.addAll(rows.map((r) => DownloadItem.fromMap(r)));
      notifyListeners();
      debugPrint('[DownloadService] Loaded ${_downloads.length} downloads');
    } catch (e) {
      debugPrint('[DownloadService] Failed to load downloads: $e');
    }
  }

  // ✅ Fast path — reuses the stream URL already resolved for playback
  Future<void> downloadFromUrl(TrackItem track, String streamUrl) async {
    if (isDownloaded(track.videoId)) return;
    if (_statusMap[track.videoId] == DownloadStatus.downloading) return;

    _statusMap[track.videoId] = DownloadStatus.downloading;
    _progressMap[track.videoId] = 0.0;
    notifyListeners();

    try {
      final dir = await _getDownloadsDir();
      final audioPath = p.join(dir.path, '${track.videoId}.webm');
      final thumbPath = p.join(dir.path, '${track.videoId}_thumb.jpg');

      await _dio.download(
        streamUrl,
        audioPath,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
            'Referer': 'https://www.youtube.com/',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 5),
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _progressMap[track.videoId] = received / total;
            notifyListeners();
          }
        },
      );

      // Download thumbnail
      if (track.thumbnail.isNotEmpty) {
        try {
          await _dio.download(track.thumbnail, thumbPath,
              options: Options(
                  receiveTimeout: const Duration(seconds: 15)));
        } catch (_) {}
      }

      final audioFile = File(audioPath);
      final fileSize = await audioFile.length();

      if (fileSize > 50 * 1024 * 1024) {
        await audioFile.delete();
        throw Exception('File too large — likely a mix/album stream');
      }

      final quality = _settings.downloadQuality.key;
      final item = DownloadItem(
        videoId: track.videoId,
        title: track.title,
        artist: track.artist,
        thumbnailUrl: track.thumbnail,
        localAudioPath: audioPath,
        localThumbnailPath: thumbPath,
        quality: quality,
        fileSize: fileSize,
        downloadedAt: DateTime.now(),
      );

      final db = await DatabaseHelper.instance.database;
      await db.insert('downloads', item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

      _downloads.insert(0, item);
      _statusMap[track.videoId] = DownloadStatus.done;
      _progressMap.remove(track.videoId);

      debugPrint('[DownloadService] ✅ Downloaded: ${track.title} '
          '(${item.fileSizeFormatted})');
    } catch (e, st) {
      _statusMap[track.videoId] = DownloadStatus.failed;
      _progressMap.remove(track.videoId);
      debugPrint('[DownloadService] Failed: $e\n$st');
    }

    notifyListeners();
  }

  // Fallback — resolves its own URL (slower, only used if no URL available)
  Future<void> downloadTrack(
    TrackItem track, {
    DownloadQuality? quality,
    void Function()? onQualityNotSet,
  }) async {
    if (isDownloaded(track.videoId)) return;
    if (_statusMap[track.videoId] == DownloadStatus.downloading) return;

    if (!_settings.hasDefaultQuality && quality == null) {
      onQualityNotSet?.call();
      return;
    }

    final effectiveQuality = quality ?? _settings.downloadQuality;

    _statusMap[track.videoId] = DownloadStatus.downloading;
    _progressMap[track.videoId] = 0.0;
    notifyListeners();

    try {
      final manifest = await _yt.videos.streams.getManifest(
        track.videoId,
        ytClients: [YoutubeApiClient.androidVr],
      );

      final audioStreams = manifest.audioOnly.toList()
        ..sort((a, b) =>
            b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));

      if (audioStreams.isEmpty) throw Exception('No audio streams found');

      final validStreams = audioStreams.where((s) {
        final approxDuration =
            s.size.totalBytes / (s.bitrate.bitsPerSecond / 8);
        return approxDuration < 900;
      }).toList();

      final streamsToUse =
          validStreams.isNotEmpty ? validStreams : audioStreams;

      AudioOnlyStreamInfo selectedStream;
      switch (effectiveQuality) {
        case DownloadQuality.low:
          selectedStream = streamsToUse.last;
          break;
        case DownloadQuality.medium:
          selectedStream = streamsToUse[streamsToUse.length ~/ 2];
          break;
        case DownloadQuality.high:
          selectedStream = streamsToUse.first;
          break;
      }

      await downloadFromUrl(track, selectedStream.url.toString());
    } catch (e, st) {
      _statusMap[track.videoId] = DownloadStatus.failed;
      _progressMap.remove(track.videoId);
      debugPrint('[DownloadService] Failed: $e\n$st');
      notifyListeners();
    }
  }

  Future<void> deleteDownload(String videoId) async {
    final item = _downloads.firstWhere(
      (d) => d.videoId == videoId,
      orElse: () => throw Exception('Not found'),
    );

    try {
      final audioFile = File(item.localAudioPath);
      final thumbFile = File(item.localThumbnailPath);
      if (await audioFile.exists()) await audioFile.delete();
      if (await thumbFile.exists()) await thumbFile.delete();

      final db = await DatabaseHelper.instance.database;
      await db.delete('downloads',
          where: 'videoId = ?', whereArgs: [videoId]);

      _downloads.removeWhere((d) => d.videoId == videoId);
      _statusMap.remove(videoId);
      notifyListeners();
    } catch (e) {
      debugPrint('[DownloadService] Delete failed: $e');
    }
  }

  Future<Directory> _getDownloadsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'luna_downloads'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @override
  void dispose() {
    _yt.close();
    _dio.close();
    super.dispose();
  }
}