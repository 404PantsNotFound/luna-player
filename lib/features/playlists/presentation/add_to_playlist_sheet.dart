import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/track_item.dart';
import '../../../core/services/playlist_service.dart';

class AddToPlaylistSheet extends StatefulWidget {
  const AddToPlaylistSheet({super.key, required this.track});

  final TrackItem track;

  static Future<void> show(BuildContext context, TrackItem track) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddToPlaylistSheet(track: track),
    );
  }

  @override
  State<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<AddToPlaylistSheet> {
  void _showCreateDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'Playlist name'),
          onSubmitted: (_) => _create(controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _create(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _create(String name) async {
    Navigator.pop(context); // close dialog
    final service = context.read<PlaylistService>();
    final playlist = await service.createPlaylist(name);
    if (playlist == null) return;

    final added = await service.addSong(playlist.id, widget.track);
    if (!mounted) return;
    Navigator.pop(context); // close sheet

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added
            ? 'Added to "${playlist.name}"'
            : 'Already in "${playlist.name}"'),
      ),
    );
  }

  Future<void> _addToExisting(int playlistId, String playlistName) async {
    final added = await context
        .read<PlaylistService>()
        .addSong(playlistId, widget.track);

    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added
            ? 'Added to "$playlistName"'
            : 'Already in "$playlistName"'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistService>(
      builder: (context, service, _) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    const Text(
                      'Add to playlist',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              // Song info
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: widget.track.thumbnail.isNotEmpty
                          ? Image.network(
                              widget.track.thumbnail,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 40,
                              height: 40,
                              color: Colors.grey.shade800,
                              child: const Icon(Icons.music_note,
                                  size: 20),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500),
                          ),
                          Text(
                            widget.track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Create new playlist
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
                title: const Text('Create new playlist'),
                onTap: _showCreateDialog,
              ),

              // Existing playlists
              if (service.playlists.isNotEmpty) ...[
                const Divider(height: 1),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: service.playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = service.playlists[index];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: playlist.thumbnailUrl != null
                              ? Image.network(
                                  playlist.thumbnailUrl!,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _thumbPlaceholder(),
                                )
                              : _thumbPlaceholder(),
                        ),
                        title: Text(playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${playlist.songCount} song${playlist.songCount == 1 ? '' : 's'}',
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12),
                        ),
                        onTap: () =>
                            _addToExisting(playlist.id, playlist.name),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 44,
      height: 44,
      color: Colors.grey.shade800,
      child: const Icon(Icons.queue_music, size: 20),
    );
  }
}