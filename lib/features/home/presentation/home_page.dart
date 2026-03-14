import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/track_item.dart';
import '../../../core/services/queue_service.dart';
import '../../../core/services/stream_resolver.dart';
import '../../../core/services/youtube_data_api.dart';
import '../../player/application/player_service.dart';
import '../../player/presentation/youtube_player_page.dart';
import '../../search/presentation/search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<TrackItem> _trending = [];
  bool _isLoadingTrending = true;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    try {
      final api = context.read<YoutubeDataApi>();
      final results = await api.searchTracks('top hits 2025');
      if (!mounted) return;
      setState(() {
        _trending = results;
        _isLoadingTrending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingTrending = false);
    }
  }

  Future<void> _openTrack(TrackItem track, List<TrackItem> sourceList) async {
    final resolver = context.read<StreamResolver>();
    final player = context.read<PlayerService>();
    final queue = context.read<QueueService>();

    // ✅ Always set the queue before playing
    final index = sourceList.indexOf(track);
    queue.setQueue(sourceList, index >= 0 ? index : 0);

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
        MaterialPageRoute(
          builder: (_) => YoutubePlayerPage(track: track),
        ),
        (route) => route.isFirst, // keep only the shell
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Playback failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Luna Music')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick search bar
          GestureDetector(
            onTap: () {
              SearchTabNotifier.of(context)?.switchToSearch();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey.shade500),
                  const SizedBox(width: 12),
                  Text(
                    'What do you want to listen to?',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Recently played
          Consumer<PlayerService>(
            builder: (context, player, _) {
              if (player.recentlyPlayed.isEmpty) return const SizedBox.shrink();
              final recentList = player.recentlyPlayed.toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recently Played',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: recentList.length,
                      itemBuilder: (context, index) {
                        final track = recentList[index];
                        return _TrackCard(
                          track: track,
                          onTap: () => _openTrack(track, recentList),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              );
            },
          ),

          // Trending
          const Text(
            'Trending',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (_isLoadingTrending)
            const Center(child: CircularProgressIndicator())
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _trending.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final track = _trending[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: track.thumbnail.isNotEmpty
                        ? Image.network(
                            track.thumbnail,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                  title: Text(track.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(track.artist,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _openTrack(track, _trending),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 56,
      height: 56,
      color: Colors.grey.shade800,
      child: const Icon(Icons.music_note),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.track, required this.onTap});

  final TrackItem track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: track.thumbnail.isNotEmpty
                  ? Image.network(
                      track.thumbnail,
                      width: 110,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 110,
                        height: 90,
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.music_note),
                      ),
                    )
                  : Container(
                      width: 110,
                      height: 90,
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.music_note),
                    ),
            ),
            const SizedBox(height: 6),
            Text(track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
            Text(track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

class SearchTabNotifier extends InheritedWidget {
  const SearchTabNotifier({
    super.key,
    required this.switchToSearch,
    required super.child,
  });

  final VoidCallback switchToSearch;

  static SearchTabNotifier? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SearchTabNotifier>();
  }

  @override
  bool updateShouldNotify(SearchTabNotifier oldWidget) => false;
}