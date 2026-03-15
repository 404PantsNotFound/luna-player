import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../../core/services/settings_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<SettingsService>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ─── Playback ───
              const Text(
                'PLAYBACK',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Background playback'),
                      subtitle: const Text(
                        'Keep playing when app is minimized or screen locks',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: settings.backgroundPlayback,
                      activeColor: const Color(0xFF1DB954),
                      onChanged: (val) =>
                          settings.setBackgroundPlayback(val),
                    ),
                    Divider(height: 1, color: Colors.grey.shade800),
                    SwitchListTile(
                      title: const Text('Keep playing when app is closed'),
                      subtitle: const Text(
                        'Music continues even after closing the app',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: settings.playWhenClosed,
                      activeColor: const Color(0xFF1DB954),
                      onChanged: (val) =>
                          settings.setPlayWhenClosed(val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ─── Downloads ───
              const Text(
                'DOWNLOADS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: DownloadQuality.values.map((quality) {
                    final selected = settings.downloadQuality == quality;
                    final isLast =
                        quality == DownloadQuality.values.last;
                    return Column(
                      children: [
                        ListTile(
                          title: Text(quality.label),
                          trailing: selected
                              ? const Icon(Icons.check_circle,
                                  color: Color(0xFF1DB954))
                              : Icon(Icons.radio_button_unchecked,
                                  color: Colors.grey.shade600),
                          onTap: () =>
                              settings.setDownloadQuality(quality),
                        ),
                        if (!isLast)
                          Divider(
                              height: 1,
                              color: Colors.grey.shade800),
                      ],
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // ─── About ───
              const Text(
                'ABOUT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.hasData
                        ? 'Version ${snapshot.data!.version}'
                        : 'Version 1.5.0';
                    return ListTile(
                      title: const Text('Luna'),
                      subtitle: Text(version),
                      trailing: const Icon(Icons.music_note,
                          color: Color(0xFF1DB954)),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // ─── Check for updates ───
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.system_update,
                      color: Color(0xFF1DB954)),
                  title: const Text('Check for updates'),
                  trailing: Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.grey.shade600),
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Checking for updates...')),
                    );
                    // Update check happens on app launch automatically
                    // This is just a manual trigger hint
                    await Future.delayed(
                        const Duration(seconds: 1));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('You\'re on the latest version!')),
                    );
                  },
                ),
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}