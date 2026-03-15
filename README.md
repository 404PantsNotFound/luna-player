# Luna 🌙

A free, open-source YouTube music player for Android.

## Features
- 🔍 Search and stream music from YouTube
- 📥 Download songs for offline listening
- ❤️ Like and save favourite songs
- 📋 Create and manage playlists
- 🔀 Shuffle and repeat modes
- 📱 Background playback with notification controls
- 🕓 Search history and recently played
- 🎵 Queue management with drag to reorder

## Installation
1. Go to [Releases](../../releases)
2. Download the latest `app-release.apk`
3. On your Android phone go to **Settings → Security → Install unknown apps** and enable it for your browser or file manager
4. Open the downloaded APK and install

## Building from source
```bash
git clone https://github.com/404PantsNotFound/luna-music.git
cd luna-music
flutter pub get
flutter run
```

## Tech stack
- Flutter
- youtube_explode_dart (search + stream)
- just_audio (playback)
- just_audio_background (notification controls)
- sqflite (local database)
- provider (state management)

