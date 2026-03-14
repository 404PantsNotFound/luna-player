import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/playlist.dart';
import '../../../core/models/track_item.dart';
import '../../../core/services/playlist_service.dart';
import '../../../core/services/queue_service.dart';
import '../../../core/services/stream_resolver.dart';
import '../../player/application/player_service.dart';
import '../../player/presentation/youtube_player_page.dart';

class PlaylistDetailPage extends StatefulWidget {
  const PlaylistDetailPage({super.key, required this.playlist});

  final Playlist playlist;

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  List<TrackItem> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    final songs = await context
        .read<PlaylistService>()
        .getPlaylistSongs(widget.playlist.id);
    if (!mounted) return;
    setState(() {
      _songs = songs;
      _isLoading = false;
    });
  }

  Future<void> _openTrack(TrackItem track, int index) async {
    final resolver = context.read<StreamResolver>();
    final player = context.read<PlayerService>();
    final queue = context.read<QueueService>();

    queue.setQueue(_songs, index);

    try {
      final resolved = await resolver.resolveAudioStream(track.videoId);
      await player.setUrl(
        resolved.url.toString(),
        autoPlay: true,
        track: track,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => YoutubePlayerPage(track: track)),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Playback failed: $e')),
      );
    }
  }

  void _playAll() {
    if (_songs.isEmpty) return;
    _openTrack(_songs.first, 0);
  }

  void _showRenameDialog() {
    final controller =
        TextEditingController(text: widget.playlist.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context
                  .read<PlaylistService>()
                  .renamePlaylist(widget.playlist.id, controller.text);
              Navigator.pop(context);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: Text(
            'Delete "${widget.playlist.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context
                  .read<PlaylistService>()
                  .deletePlaylist(widget.playlist.id);
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // go back to library
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          // ✅ Collapsible header with playlist art
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: const Color(0xFF121212),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'rename') _showRenameDialog();
                  if (value == 'delete') _confirmDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'rename', child: Text('Rename')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.playlist.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              background: widget.playlist.thumbnailUrl != null
                  ? Image.network(
                      widget.playlist.thumbnailUrl!,
                      fit: BoxFit.cover,
                      colorBlendMode: BlendMode.darken,
                      color: Colors.black.withOpacity(0.4),
                      errorBuilder: (_, __, ___) => _artPlaceholder(),
                    )
                  : _artPlaceholder(),
            ),
          ),

          // Song count + play button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_songs.length} song${_songs.length == 1 ? '' : 's'}',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 13),
                  ),
                  if (_songs.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _playAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Play all'),
                    ),
                ],
              ),
            ),
          ),

          // Songs list
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _songs.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.queue_music,
                                size: 64,
                                color: Colors.grey.shade700),
                            const SizedBox(height: 16),
                            Text(
                              'No songs yet',
                              style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add songs from search or the player',
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final track = _songs[index];
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: track.thumbnail.isNotEmpty
                                  ? Image.network(
                                      track.thumbnail,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _placeholder(),
                                    )
                                  : _placeholder(),
                            ),
                            title: Text(track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Text(track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.grey.shade500)),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'remove') {
                                  await context
                                      .read<PlaylistService>()
                                      .removeSong(
                                          widget.playlist.id,
                                          track.videoId);
                                  await _loadSongs();
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Remove from playlist',
                                      style: TextStyle(
                                          color: Colors.redAccent)),
                                ),
                              ],
                            ),
                            onTap: () => _openTrack(track, index),
                          );
                        },
                        childCount: _songs.length,
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _artPlaceholder() {
    return Container(
      color: const Color(0xFF282828),
      child: const Icon(Icons.queue_music,
          size: 80, color: Colors.white24),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 50,
      height: 50,
      color: Colors.grey.shade800,
      child: const Icon(Icons.music_note, size: 20),
    );
  }
}