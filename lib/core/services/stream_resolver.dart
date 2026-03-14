import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class ResolvedAudioStream {
  ResolvedAudioStream({
    required this.videoId,
    required this.url,
    this.streamInfo,
  });

  final String videoId;
  final Uri url;
  final dynamic streamInfo;
}

class StreamResolver {
  StreamResolver() : _yt = YoutubeExplode();

  final YoutubeExplode _yt;

  // Remember the last client that worked to skip failed attempts
  YoutubeApiClient? _lastWorkingClient;

  void _log(String message) {
    debugPrint('[StreamResolver] $message');
  }

  Future<ResolvedAudioStream> resolveAudioStream(String videoId) async {
    _log('Resolving stream for videoId=$videoId');

    // Put last working client first to avoid wasting time on failing ones
    final allClients = [
      YoutubeApiClient.androidVr,
      YoutubeApiClient.ios,
      YoutubeApiClient.mweb,
    ];

    final orderedClients = _lastWorkingClient != null
        ? [
            _lastWorkingClient!,
            ...allClients.where((c) => c != _lastWorkingClient),
          ]
        : allClients;

    for (final client in orderedClients) {
      try {
        final manifest = await _yt.videos.streams.getManifest(
          videoId,
          ytClients: [client],
        );

        final audioOnly = manifest.audioOnly.toList();
        if (audioOnly.isEmpty) continue;

        audioOnly.sort((a, b) =>
            b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));

        final best = audioOnly.first;
        _lastWorkingClient = client;

        _log(
          'Resolved: container=${best.container.name}, '
          'bitrate=${best.bitrate.bitsPerSecond}',
        );

        return ResolvedAudioStream(
          videoId: videoId,
          url: best.url,
          streamInfo: best,
        );
      } catch (e) {
        _log('Client $client failed: $e — trying next...');
        continue;
      }
    }

    throw Exception('All clients failed for $videoId');
  }

  void dispose() {
    _yt.close();
  }
}