import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/services/settings_service.dart';
import 'features/home/presentation/home_page.dart';
import 'features/library/presentation/library_page.dart';
import 'features/player/application/player_service.dart';
import 'features/player/presentation/mini_player.dart';
import 'features/search/presentation/search_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    SearchPage(),
    LibraryPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ✅ When app is fully closed (detached), stop if toggle is off
    if (state == AppLifecycleState.detached) {
      final settings = context.read<SettingsService>();
      final player = context.read<PlayerService>();

      if (!settings.playWhenClosed) {
        player.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SearchTabNotifier(
      switchToSearch: () => setState(() => _currentIndex = 1),
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) =>
                  setState(() => _currentIndex = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_outlined),
                  selectedIcon: Icon(Icons.search),
                  label: 'Search',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music),
                  label: 'Library',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}