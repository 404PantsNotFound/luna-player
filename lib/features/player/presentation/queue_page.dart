import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/track_item.dart';
import '../../../core/services/queue_service.dart';
import '../../../core/services/stream_resolver.dart';
import '../application/player_service.dart';

class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  Future<void> _playFromQueue(
      BuildContext context, TrackItem track, int index) async {
    final queue = context.read<QueueService>();
    final resolver = context.read<StreamResolver>();
    final player = context.read<PlayerService>();

    if (queue.locked) return;

    // Set index then play
    queue.reorder(queue.currentIndex, queue.currentIndex); // no-op to trigger notify
    // Actually jump to index
    final diff = index - queue.currentIndex;
    if (diff == 0) return;

    // Move currentIndex to tapped song
    for (var i = 0; i < diff.abs(); i++) {
      if (diff > 0) {
        queue.skipNext();
      } else {
        queue.skipPrevious();
      }
    }

    final next = queue.currentTrack;
    if (next == null) return;

    try {
      final resolved = await resolver.resolveAudioStream(next.videoId);
      if (!context.mounted) return;
      await player.setUrl(resolved.url.toString(),
          autoPlay: true, track: next);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('Queue'),
        centerTitle: true,
        actions: [
          // ✅ Lock button
          Consumer<QueueService>(
            builder: (context, queue, _) => IconButton(
              onPressed: queue.toggleLock,
              tooltip: queue.locked ? 'Unlock queue' : 'Lock queue',
              icon: Icon(
                queue.locked ? Icons.lock : Icons.lock_open,
                color: queue.locked
                    ? const Color(0xFF1DB954)
                    : Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
      body: Consumer<QueueService>(
        builder: (context, queue, _) {
          if (queue.queue.isEmpty) {
            return Center(
              child: Text(
                'Queue is empty',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lock banner
              if (queue.locked)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  color: const Color(0xFF1DB954).withOpacity(0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.lock,
                          size: 14, color: Color(0xFF1DB954)),
                      const SizedBox(width: 8),
                      Text(
                        'Queue is locked — no changes allowed',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

              // Now playing header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Now Playing',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ),

              // Current song
              if (queue.currentTrack != null)
                _QueueTile(
                  track: queue.currentTrack!,
                  isCurrent: true,
                  isLocked: queue.locked,
                  onTap: () {},
                  onDelete: null,
                ),

              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Next Up',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ),

              // ✅ Reorderable list
              Expanded(
                child: ReorderableListView.builder(
                  onReorder: queue.locked
                      ? (_, __) {} // no-op when locked
                      : (oldIndex, newIndex) {
                          // Offset because current song is shown separately
                          final adjustedOld =
                              oldIndex + queue.currentIndex + 1;
                          final adjustedNew =
                              newIndex + queue.currentIndex + 1;
                          queue.reorder(adjustedOld, adjustedNew);
                        },
                  itemCount: queue.queue.length - queue.currentIndex - 1,
                  itemBuilder: (context, index) {
                    final actualIndex = queue.currentIndex + 1 + index;
                    if (actualIndex >= queue.queue.length) {
                      return const SizedBox.shrink(key: ValueKey('empty'));
                    }
                    final track = queue.queue[actualIndex];
                    return _QueueTile(
                      key: ValueKey(track.videoId + actualIndex.toString()),
                      track: track,
                      isCurrent: false,
                      isLocked: queue.locked,
                      onTap: () =>
                          _playFromQueue(context, track, actualIndex),
                      onDelete: queue.locked
                          ? null
                          : () => queue.removeAt(actualIndex),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    super.key,
    required this.track,
    required this.isCurrent,
    required this.isLocked,
    required this.onTap,
    required this.onDelete,
  });

  final TrackItem track;
  final bool isCurrent;
  final bool isLocked;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: isCurrent
          ? const Color(0xFF1DB954).withOpacity(0.08)
          : Colors.transparent,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: track.thumbnail.isNotEmpty
            ? Image.network(
                track.thumbnail,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent ? const Color(0xFF1DB954) : Colors.white,
          fontWeight:
              isCurrent ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
      ),
      trailing: isCurrent
          ? const Icon(Icons.equalizer, color: Color(0xFF1DB954), size: 20)
          : isLocked
              ? Icon(Icons.drag_handle, color: Colors.grey.shade700, size: 20)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.close,
                          color: Colors.grey.shade600, size: 18),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.drag_handle,
                        color: Colors.grey.shade600, size: 20),
                  ],
                ),
      onTap: isCurrent ? null : onTap,
    );
  }

  Widget _placeholder() {
    return Container(
      width: 48,
      height: 48,
      color: Colors.grey.shade800,
      child: const Icon(Icons.music_note, size: 20),
    );
  }
}