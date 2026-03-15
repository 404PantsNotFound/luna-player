import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/track_item.dart';
import '../../../core/services/likes_service.dart';
import '../../../core/services/queue_service.dart';
import '../../../core/services/stream_resolver.dart';
import '../../../core/services/youtube_data_api.dart';
import '../../player/application/player_service.dart';
import '../../player/presentation/youtube_player_page.dart';
import '../../search/presentation/search_page.dart';

import '../../settings/presentation/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<TrackItem> _curated = [];
  bool _isLoading = true;
  String _sectionTitle = 'Top Charts';

  @override
  void initState() {
    super.initState();
    // ✅ Load after first frame so UI renders immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurated();
    });
  }

  Future<void> _loadCurated() async {
    final api = context.read<YoutubeDataApi>();
    final player = context.read<PlayerService>();
    final likes = context.read<LikesService>();

    // Gather seed artists from recently played + liked songs
    final recentArtists = player.recentlyPlayed
        .map((t) => t.artist)
        .where((a) => a.isNotEmpty)
        .toList();

    final likedArtists = likes.likedSongs
        .map((t) => t.artist)
        .where((a) => a.isNotEmpty)
        .toList();

    // Combine and deduplicate
    final allArtists = {...recentArtists, ...likedArtists}.toList();

    String query;
    if (allArtists.isEmpty) {
      // First time user — show top charts
      query = 'top hits 2025';
      _sectionTitle = 'Top Charts';
    } else {
      // Pick a random artist from their history
      allArtists.shuffle();
      final seedArtist = allArtists.first;
      query = '$seedArtist mix';
      _sectionTitle = 'Based on your taste';
    }

    try {
      final results = await api.searchTracks(query);
      if (!mounted) return;
      setState(() {
        _curated = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openTrack(TrackItem track, int index) async {
    final resolver = context.read<StreamResolver>();
    final player = context.read<PlayerService>();
    final queue = context.read<QueueService>();

    queue.setQueue(_curated, index);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Luna'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadCurated();
            },
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick search bar
          GestureDetector(
            onTap: () => SearchTabNotifier.of(context)?.switchToSearch(),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
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
              if (player.recentlyPlayed.isEmpty) {
                return const SizedBox.shrink();
              }
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
                          onTap: () => _openTrack(track, index),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              );
            },
          ),

          // Curated section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _sectionTitle,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_curated.isEmpty)
            Text('Nothing to show',
                style: TextStyle(color: Colors.grey.shade600))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _curated.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final track = _curated[index];
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
                  onTap: () => _openTrack(track, index),
                );
              },
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
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500)),
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
    return context
        .dependOnInheritedWidgetOfExactType<SearchTabNotifier>();
  }

  @override
  bool updateShouldNotify(SearchTabNotifier oldWidget) => false;
}