import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/track_item.dart';
import '../../../core/services/download_service.dart';
import '../../../core/services/likes_service.dart';
import '../../../core/services/queue_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/stream_resolver.dart';
import '../application/player_service.dart';
import '../../playlists/presentation/add_to_playlist_sheet.dart';
import '../../settings/presentation/settings_page.dart';
import 'queue_page.dart';

class YoutubePlayerPage extends StatefulWidget {
  const YoutubePlayerPage({super.key, required this.track});

  final TrackItem track;

  @override
  State<YoutubePlayerPage> createState() => _YoutubePlayerPageState();
}

class _YoutubePlayerPageState extends State<YoutubePlayerPage> {
  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _skipNext() {
    final queue = context.read<QueueService>();
    final resolver = context.read<StreamResolver>();
    final player = context.read<PlayerService>();

    final next = queue.skipNext();
    if (next == null) return;

    resolver.resolveAudioStream(next.videoId).then((resolved) {
      if (!mounted) return;
      player.setUrl(resolved.url.toString(), autoPlay: true, track: next);
    }).catchError((e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Skip failed: $e')),
      );
    });
  }

  void _skipPrevious() {
    final queue = context.read<QueueService>();
    final resolver = context.read<StreamResolver>();
    final player = context.read<PlayerService>();

    final prev = queue.skipPrevious();
    if (prev == null) return;

    resolver.resolveAudioStream(prev.videoId).then((resolved) {
      if (!mounted) return;
      player.setUrl(resolved.url.toString(), autoPlay: true, track: prev);
    }).catchError((e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Skip failed: $e')),
      );
    });
  }

  void _handleDownload(TrackItem track) {
    final downloader = context.read<DownloadService>();
    final player = context.read<PlayerService>();
    final settings = context.read<SettingsService>();

    if (downloader.isDownloaded(track.videoId)) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Remove download?'),
          content: Text('Delete "${track.title}" from your downloads?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                downloader.deleteDownload(track.videoId);
              },
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      return;
    }

    if (!settings.hasDefaultQuality) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Choose download quality'),
          content: const Text(
              'Set your preferred download quality in Settings first.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()));
              },
              child: const Text('Go to Settings'),
            ),
          ],
        ),
      );
      return;
    }

    final currentUrl = player.currentUrl;
    if (currentUrl != null &&
        player.currentTrack?.videoId == track.videoId) {
      downloader.downloadFromUrl(track, currentUrl);
    } else {
      downloader.downloadTrack(track);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading "${track.title}"...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Now Playing',
          style: TextStyle(fontSize: 14, letterSpacing: 1.5),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QueuePage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer3<PlayerService, LikesService, DownloadService>(
          builder: (context, player, likes, downloader, _) {
            final track = player.currentTrack ?? widget.track;
            final totalMs = player.duration.inMilliseconds;
            final maxMs = totalMs <= 0 ? 1 : totalMs;
            final posMs = player.position.inMilliseconds.clamp(0, maxMs);
            final liked = likes.isLiked(track.videoId);
            final downloaded = downloader.isDownloaded(track.videoId);
            final isDownloading =
                downloader.statusOf(track.videoId) == DownloadStatus.downloading;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Album art
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: track.thumbnail.isNotEmpty
                          ? Image.network(
                              track.thumbnail,
                              key: ValueKey(track.videoId),
                              width: double.infinity,
                              height: 280,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _artPlaceholder(),
                            )
                          : _artPlaceholder(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Title + artist + action buttons
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Like
                      IconButton(
                        onPressed: () => likes.toggleLike(track),
                        icon: Icon(
                          liked ? Icons.favorite : Icons.favorite_border,
                          color: liked
                              ? const Color(0xFF1DB954)
                              : Colors.grey.shade400,
                          size: 24,
                        ),
                      ),
                      // Add to playlist
                      IconButton(
                        onPressed: () =>
                            AddToPlaylistSheet.show(context, track),
                        icon: Icon(Icons.playlist_add,
                            color: Colors.grey.shade400, size: 24),
                      ),
                      // Download
                      isDownloading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF1DB954),
                                ),
                              ),
                            )
                          : IconButton(
                              onPressed: () => _handleDownload(track),
                              icon: Icon(
                                downloaded
                                    ? Icons.download_done
                                    : Icons.download_outlined,
                                color: downloaded
                                    ? const Color(0xFF1DB954)
                                    : Colors.grey.shade400,
                                size: 24,
                              ),
                            ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (player.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        player.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),

                  // Seek bar
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14),
                      activeTrackColor: const Color(0xFF1DB954),
                      inactiveTrackColor: Colors.grey.shade800,
                      thumbColor: Colors.white,
                      overlayColor: Colors.white24,
                    ),
                    child: Slider(
                      value: posMs.toDouble(),
                      max: maxMs.toDouble(),
                      onChanged: (value) =>
                          player.seek(Duration(milliseconds: value.toInt())),
                    ),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(player.position),
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 12)),
                      Text(_fmt(player.duration),
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 12)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Controls
                  Consumer<QueueService>(
                    builder: (context, queue, _) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Shuffle
                          IconButton(
                            iconSize: 26,
                            onPressed: queue.toggleShuffle,
                            icon: Icon(
                              Icons.shuffle,
                              color: queue.shuffleOn
                                  ? const Color(0xFF1DB954)
                                  : Colors.grey.shade600,
                            ),
                          ),
                          // Skip previous
                          IconButton(
                            iconSize: 34,
                            onPressed: _skipPrevious,
                            icon: Icon(Icons.skip_previous,
                                color: Colors.grey.shade400),
                          ),
                          // Play/pause
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              iconSize: 34,
                              onPressed: player.togglePlayPause,
                              icon: Icon(
                                player.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          // Skip next
                          IconButton(
                            iconSize: 34,
                            onPressed: _skipNext,
                            icon: Icon(Icons.skip_next,
                                color: Colors.grey.shade400),
                          ),
                          // Repeat one
                          IconButton(
                            iconSize: 26,
                            onPressed: queue.toggleRepeatOne,
                            icon: Icon(
                              Icons.repeat_one,
                              color: queue.repeatMode == QueueRepeatMode.one
                                  ? const Color(0xFF1DB954)
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _artPlaceholder() {
    return Container(
      width: double.infinity,
      height: 280,
      color: const Color(0xFF282828),
      child: const Icon(Icons.music_note, size: 80, color: Colors.white38),
    );
  }
}