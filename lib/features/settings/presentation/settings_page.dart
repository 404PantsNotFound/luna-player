import 'package:flutter/material.dart';
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
              // Playback section
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

              // Downloads section
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
                              height: 1, color: Colors.grey.shade800),
                      ],
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // About section
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
                child: const ListTile(
                  title: Text('Luna'),
                  subtitle: Text('Version 1.0.0'),
                  trailing:
                      Icon(Icons.music_note, color: Color(0xFF1DB954)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}