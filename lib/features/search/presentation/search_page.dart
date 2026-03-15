import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/track_item.dart';
import '../../../core/services/likes_service.dart';
import '../../../core/services/queue_service.dart';
import '../../../core/services/search_history_service.dart';
import '../../../core/services/stream_resolver.dart';
import '../../../core/services/youtube_data_api.dart';
import '../../player/application/player_service.dart';
import '../../player/presentation/youtube_player_page.dart';
import '../../playlists/presentation/add_to_playlist_sheet.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
  bool _showHistory = false;
  List<TrackItem> _results = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _showHistory = _focusNode.hasFocus);
    });
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {}); // rebuild for suffix icon + history filter

    final query = _controller.text.trim();

    // Cancel previous timer
    _debounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    // ✅ Small 400ms debounce to avoid hammering on every keystroke
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search(query, addToHistory: false);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query, {bool addToHistory = true}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    if (addToHistory) {
      _focusNode.unfocus();
      setState(() => _showHistory = false);
      context.read<SearchHistoryService>().addSearch(trimmed);
    }

    setState(() => _isLoading = true);

    try {
      final api = context.read<YoutubeDataApi>();
      final results = await api.searchTracks(trimmed);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openTrack(TrackItem track, int index) async {
    final resolver = context.read<StreamResolver>();
    final player = context.read<PlayerService>();
    final queue = context.read<QueueService>();

    // Save to history when user actually plays a song
    context.read<SearchHistoryService>().addSearch(_controller.text.trim());

    queue.setQueue(_results, index);

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
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (q) => _search(q, addToHistory: true),
              decoration: InputDecoration(
                hintText: 'Search songs, artists...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _results = []);
                          _focusNode.requestFocus();
                        },
                      )
                    : null,
              ),
            ),
          ),

          // History dropdown
          Consumer<SearchHistoryService>(
            builder: (context, historyService, _) {
              final suggestions =
                  historyService.suggestions(_controller.text);

              if (!_showHistory || suggestions.isEmpty) {
                return const SizedBox.shrink();
              }

              return Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Recent searches',
                              style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12)),
                          TextButton(
                            onPressed: historyService.clearAll,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text('Clear all',
                                style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ...suggestions.map(
                      (query) => ListTile(
                        dense: true,
                        leading: Icon(Icons.history,
                            color: Colors.grey.shade600, size: 18),
                        title: Text(query,
                            style: const TextStyle(fontSize: 14)),
                        trailing: IconButton(
                          icon: Icon(Icons.close,
                              color: Colors.grey.shade600, size: 16),
                          onPressed: () =>
                              historyService.removeSearch(query),
                        ),
                        onTap: () {
                          _controller.text = query;
                          _search(query, addToHistory: true);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          _controller.text.isEmpty
                              ? 'Search for a song to start playing'
                              : 'No results found',
                          style:
                              TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : Consumer<LikesService>(
                        builder: (context, likes, _) {
                          return ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final track = _results[index];
                              final liked =
                                  likes.isLiked(track.videoId);

                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  child: track.thumbnail.isNotEmpty
                                      ? Image.network(
                                          track.thumbnail,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (_, __, ___) =>
                                                  _placeholder(),
                                        )
                                      : _placeholder(),
                                ),
                                title: Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () =>
                                          likes.toggleLike(track),
                                      icon: Icon(
                                        liked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: liked
                                            ? const Color(0xFF1DB954)
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          AddToPlaylistSheet.show(
                                              context, track),
                                      icon: Icon(Icons.playlist_add,
                                          color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                                onTap: () => _openTrack(track, index),
                              );
                            },
                          );
                        },
                      ),
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