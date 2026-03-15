import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/services/audio_handler.dart';
import 'core/services/download_service.dart';
import 'core/services/likes_service.dart';
import 'core/services/playlist_service.dart';
import 'core/services/queue_service.dart';
import 'core/services/search_history_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/stream_resolver.dart';
import 'core/services/update_service.dart';
import 'core/services/youtube_data_api.dart';
import 'features/player/application/player_service.dart';
import 'main_shell.dart';

late LunaAudioHandler _audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsService = await _initSettings();

  _audioHandler = await AudioService.init(
    builder: () => LunaAudioHandler(settingsService),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.luna.music.channel.audio',
      androidNotificationChannelName: 'Luna Music',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
    ),
  );

  final results = await Future.wait([
    _initLikes(),
    _initSearchHistory(),
    _initPlaylists(),
  ]);

  final likesService = results[0] as LikesService;
  final searchHistoryService = results[1] as SearchHistoryService;
  final playlistService = results[2] as PlaylistService;

  final downloadService = DownloadService(settingsService);
  await downloadService.init();

  // ✅ Init update service — checks version and sets showPatchNotes
  final updateService = UpdateService();
  await updateService.init();
  updateService.checkForUpdate(); // fire and forget

  runApp(LunaMusicApp(
    audioHandler: _audioHandler,
    likesService: likesService,
    settingsService: settingsService,
    downloadService: downloadService,
    searchHistoryService: searchHistoryService,
    playlistService: playlistService,
    updateService: updateService,
  ));
}

Future<LikesService> _initLikes() async {
  final s = LikesService();
  await s.init();
  return s;
}

Future<SettingsService> _initSettings() async {
  final s = SettingsService();
  await s.init();
  return s;
}

Future<SearchHistoryService> _initSearchHistory() async {
  final s = SearchHistoryService();
  await s.init();
  return s;
}

Future<PlaylistService> _initPlaylists() async {
  final s = PlaylistService();
  await s.init();
  return s;
}

class LunaMusicApp extends StatelessWidget {
  const LunaMusicApp({
    super.key,
    required this.audioHandler,
    required this.likesService,
    required this.settingsService,
    required this.downloadService,
    required this.searchHistoryService,
    required this.playlistService,
    required this.updateService,
  });

  final LunaAudioHandler audioHandler;
  final LikesService likesService;
  final SettingsService settingsService;
  final DownloadService downloadService;
  final SearchHistoryService searchHistoryService;
  final PlaylistService playlistService;
  final UpdateService updateService;

  @override
  Widget build(BuildContext context) {
    final api = YoutubeDataApi();
    final queueService = QueueService(api);

    return MultiProvider(
      providers: [
        Provider<YoutubeDataApi>(
          create: (_) => api,
          dispose: (_, a) => a.dispose(),
        ),
        Provider<StreamResolver>(
          create: (_) => StreamResolver(),
          dispose: (_, r) => r.dispose(),
        ),
        Provider<UpdateService>.value(value: updateService),
        ChangeNotifierProvider<PlayerService>(
          create: (_) => PlayerService(audioHandler),
        ),
        ChangeNotifierProvider<QueueService>.value(value: queueService),
        ChangeNotifierProvider<LikesService>.value(value: likesService),
        ChangeNotifierProvider<SettingsService>.value(value: settingsService),
        ChangeNotifierProvider<DownloadService>.value(value: downloadService),
        ChangeNotifierProvider<SearchHistoryService>.value(
            value: searchHistoryService),
        ChangeNotifierProvider<PlaylistService>.value(value: playlistService),
      ],
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Luna',
          theme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            colorSchemeSeed: Colors.deepPurple,
          ),
          home: QueuePlayerBridge(child: const MainShell()),
        );
      },
    );
  }
}

class QueuePlayerBridge extends StatefulWidget {
  const QueuePlayerBridge({super.key, required this.child});
  final Widget child;

  @override
  State<QueuePlayerBridge> createState() => _QueuePlayerBridgeState();
}

class _QueuePlayerBridgeState extends State<QueuePlayerBridge> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = context.read<PlayerService>();
      final queue = context.read<QueueService>();
      final resolver = context.read<StreamResolver>();

      player.onSongComplete = () async {
        final next = queue.getNextForAutoAdvance();
        if (next == null) return;
        try {
          final resolved = await resolver.resolveAudioStream(next.videoId);
          await player.setUrl(
            resolved.url.toString(),
            autoPlay: true,
            track: next,
          );
        } catch (e) {
          debugPrint('[QueuePlayerBridge] Auto-advance failed: $e');
        }
      };

      // ✅ Show patch notes first, then check for updates
      Future.delayed(const Duration(milliseconds: 800), () {
        _showDialogs();
      });
    });
  }

  void _showDialogs() async {
    final updateService = context.read<UpdateService>();

    // ✅ Show patch notes if first launch after update
    if (updateService.showPatchNotes && mounted) {
      await _showPatchNotes(updateService);
    }

    // ✅ Then show update available dialog if needed
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    if (updateService.updateAvailable) {
      _showUpdateDialog(updateService);
    }
  }

  Future<void> _showPatchNotes(UpdateService updateService) async {
    final notes = updateService.getPatchNotes();
    final version = updateService.currentVersion;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.rocket_launch,
                        color: Color(0xFF1DB954), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "What's New",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Luna v$version',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(color: Colors.white12),
              const SizedBox(height: 12),

              // Patch notes list
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: notes.map((note) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          note,
                          style: TextStyle(
                            color: Colors.grey.shade300,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUpdateDialog(UpdateService updateService) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Color(0xFF1DB954)),
            const SizedBox(width: 12),
            const Text('Update Available',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Luna v${updateService.latestVersion} is available.\nWould you like to update now?',
          style: TextStyle(color: Colors.grey.shade400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Later',
                style: TextStyle(color: Colors.grey.shade500)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openDownload(updateService.downloadUrl!);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Update',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openDownload(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}