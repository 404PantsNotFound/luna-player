import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'core/services/download_service.dart';
import 'core/services/likes_service.dart';
import 'core/services/playlist_service.dart';
import 'core/services/queue_service.dart';
import 'core/services/search_history_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/stream_resolver.dart';
import 'core/services/youtube_data_api.dart';
import 'features/player/application/player_service.dart';
import 'main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.luna.music.channel.audio',
    androidNotificationChannelName: 'Luna Music',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );

  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  final likesService = LikesService();
  await likesService.init();

  final settingsService = SettingsService();
  await settingsService.init();

  final downloadService = DownloadService(settingsService);
  await downloadService.init();

  final searchHistoryService = SearchHistoryService();
  await searchHistoryService.init();

  final playlistService = PlaylistService();
  await playlistService.init();

  runApp(LunaMusicApp(
    likesService: likesService,
    settingsService: settingsService,
    downloadService: downloadService,
    searchHistoryService: searchHistoryService,
    playlistService: playlistService,
  ));
}

class LunaMusicApp extends StatelessWidget {
  const LunaMusicApp({
    super.key,
    required this.likesService,
    required this.settingsService,
    required this.downloadService,
    required this.searchHistoryService,
    required this.playlistService,
  });

  final LikesService likesService;
  final SettingsService settingsService;
  final DownloadService downloadService;
  final SearchHistoryService searchHistoryService;
  final PlaylistService playlistService;

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
        ChangeNotifierProvider<PlayerService>(
          create: (_) => PlayerService(),
        ),
        ChangeNotifierProvider<QueueService>.value(value: queueService),
        ChangeNotifierProvider<LikesService>.value(value: likesService),
        ChangeNotifierProvider<SettingsService>.value(value: settingsService),
        ChangeNotifierProvider<DownloadService>.value(value: downloadService),
        ChangeNotifierProvider<SearchHistoryService>.value(
            value: searchHistoryService),
        ChangeNotifierProvider<PlaylistService>.value(value: playlistService),
      ],
      // ✅ builder gives QueuePlayerBridge access to all providers above
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
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}