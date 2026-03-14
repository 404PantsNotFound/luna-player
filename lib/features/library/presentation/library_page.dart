import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/download_item.dart';
import '../../../core/models/track_item.dart';
import '../../../core/services/download_service.dart';
import '../../../core/services/likes_service.dart';
import '../../../core/services/playlist_service.dart';
import '../../../core/services/queue_service.dart';
import '../../../core/services/stream_resolver.dart';
import '../../player/application/player_service.dart';
import '../../player/presentation/youtube_player_page.dart';
import '../../playlists/presentation/playlist_detail_page.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  Future<void> _openTrack(
    BuildContext context,
    TrackItem track,
    List<TrackItem> fullList,
  ) async {
    final resolver = context.read<StreamResolver>();
    final player = context.read<PlayerService>();
    final queue = context.read<QueueService>();

    final index = fullList.indexOf(track);
    queue.setQueue(fullList, index >= 0 ? index : 0);

    try {
      final resolved = await resolver.resolveAudioStream(track.videoId);
      await player.setUrl(
          resolved.url.toString(), autoPlay: true, track: track);
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => YoutubePlayerPage(track: track)),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Playback failed: $e')));
    }
  }

  Future<void> _openDownloadedTrack(
    BuildContext context,
    DownloadItem item,
    List<DownloadItem> allDownloads,
  ) async {
    final player = context.read<PlayerService>();
    final queue = context.read<QueueService>();

    final trackList = allDownloads
        .map((d) => TrackItem(
              id: d.videoId,
              videoId: d.videoId,
              title: d.title,
              artist: d.artist,
              thumbnail: d.thumbnailUrl,
            ))
        .toList();

    final index = allDownloads.indexOf(item);
    queue.setQueue(trackList, index >= 0 ? index : 0);

    final track = TrackItem(
      id: item.videoId,
      videoId: item.videoId,
      title: item.title,
      artist: item.artist,
      thumbnail: item.thumbnailUrl,
    );

    try {
      await player.setUrl('file://${item.localAudioPath}',
          autoPlay: true, track: track);
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => YoutubePlayerPage(track: track)),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Playback failed: $e')));
    }
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
          onSubmitted: (_) => _createPlaylist(context, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _createPlaylist(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createPlaylist(BuildContext context, String name) async {
    Navigator.pop(context);
    await context.read<PlaylistService>().createPlaylist(name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Library')),
      body: Consumer3<LikesService, DownloadService, PlaylistService>(
        builder: (context, likes, downloader, playlists, _) {
          final likedList = likes.likedSongs.toList();
          final downloadList = downloader.downloads;
          final playlistList = playlists.playlists;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ─── Liked Songs ───
              _SectionHeader(
                icon: Icons.favorite,
                iconColor: const Color(0xFF1DB954),
                title: 'Liked Songs',
                subtitle: '${likedList.length} songs',
              ),
              const SizedBox(height: 12),
              if (likedList.isEmpty)
                _EmptyHint(text: 'Songs you like will appear here')
              else
                _TrackList(
                  tracks: likedList,
                  onTap: (track) => _openTrack(context, track, likedList),
                  trailing: (track) => IconButton(
                    icon: const Icon(Icons.favorite,
                        color: Color(0xFF1DB954)),
                    onPressed: () => likes.toggleLike(track),
                  ),
                ),

              const Divider(height: 32),

              // ─── Downloaded ───
              _SectionHeader(
                icon: Icons.download_done,
                iconColor: Colors.blue,
                title: 'Downloaded',
                subtitle: '${downloadList.length} songs',
              ),
              const SizedBox(height: 12),
              if (downloadList.isEmpty)
                _EmptyHint(text: 'Downloaded songs play without internet')
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: downloadList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = downloadList[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildDownloadThumbnail(item),
                      ),
                      title: Text(item.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${item.artist} • ${item.fileSizeFormatted}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () =>
                            _confirmDeleteDownload(context, item, downloader),
                      ),
                      onTap: () =>
                          _openDownloadedTrack(context, item, downloadList),
                    );
                  },
                ),

              const Divider(height: 32),

              // ─── Playlists ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SectionHeader(
                    icon: Icons.queue_music,
                    iconColor: Colors.orange,
                    title: 'Playlists',
                    subtitle: '${playlistList.length} playlist${playlistList.length == 1 ? '' : 's'}',
                  ),
                  IconButton(
                    onPressed: () => _showCreatePlaylistDialog(context),
                    icon: const Icon(Icons.add_circle_outline,
                        color: Color(0xFF1DB954)),
                    tooltip: 'New playlist',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (playlistList.isEmpty)
                _EmptyHint(text: 'Create a playlist to organise your music')
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: playlistList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final playlist = playlistList[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: playlist.thumbnailUrl != null
                            ? Image.network(
                                playlist.thumbnailUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _playlistPlaceholder(),
                              )
                            : _playlistPlaceholder(),
                      ),
                      title: Text(playlist.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${playlist.songCount} song${playlist.songCount == 1 ? '' : 's'}',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'delete') {
                            await playlists
                                .deletePlaylist(playlist.id);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete',
                                style:
                                    TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PlaylistDetailPage(playlist: playlist),
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDownloadThumbnail(DownloadItem item) {
    final localFile = File(item.localThumbnailPath);
    return FutureBuilder<bool>(
      future: localFile.exists(),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return Image.file(localFile,
              width: 56, height: 56, fit: BoxFit.cover);
        }
        if (item.thumbnailUrl.isNotEmpty) {
          return Image.network(item.thumbnailUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder());
        }
        return _placeholder();
      },
    );
  }

  void _confirmDeleteDownload(
    BuildContext context,
    DownloadItem item,
    DownloadService downloader,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove download?'),
        content: Text('Delete "${item.title}" from your downloads?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              downloader.deleteDownload(item.videoId);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 56,
        height: 56,
        color: Colors.grey.shade800,
        child: const Icon(Icons.music_note),
      );

  Widget _playlistPlaceholder() => Container(
        width: 56,
        height: 56,
        color: Colors.grey.shade800,
        child: const Icon(Icons.queue_music),
      );
}

// ─── Reusable widgets ───

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            Text(subtitle,
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

class _TrackList extends StatelessWidget {
  const _TrackList({
    required this.tracks,
    required this.onTap,
    required this.trailing,
  });

  final List<TrackItem> tracks;
  final void Function(TrackItem) onTap;
  final Widget Function(TrackItem) trailing;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tracks.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final track = tracks[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: track.thumbnail.isNotEmpty
                ? Image.network(track.thumbnail,
                    width: 56, height: 56, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder())
                : _placeholder(),
          ),
          title: Text(track.title,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(track.artist,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: trailing(track),
          onTap: () => onTap(track),
        );
      },
    );
  }

  Widget _placeholder() => Container(
        width: 56,
        height: 56,
        color: Colors.grey.shade800,
        child: const Icon(Icons.music_note),
      );
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(text,
          style:
              TextStyle(color: Colors.grey.shade600, fontSize: 13)),
    );
  }
}