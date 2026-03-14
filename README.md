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

## License
MIT License — free to use, modify and distribute.
```
```

---

## Step 4 — Create a `LICENSE` file
Create a file called `LICENSE` in your project root:
```
MIT License

Copyright (c) 2025 YOUR_NAME

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Step 5 — Create GitHub repo
1. Go to [github.com](https://github.com) → **+** → **New repository**
2. Name: `luna-music`
3. Set to **Public**
4. **Don't** tick README or anything else
5. Click **Create repository**

---

## Step 6 — Push code
Run these one by one in your project folder:
```bash
git init
git add .
git commit -m "Initial commit — Luna music player v1.0.0"
git branch -M main
git remote add origin https://github.com/404PantsNotFound/luna-music.git
git push -u origin main
```

---

## Step 7 — Create a Release
1. Go to your repo on GitHub
2. Click **Releases** on the right → **Create a new release**
3. Click **Choose a tag** → type `v1.0.0` → **Create new tag**
4. Title: `Luna v1.0.0`
5. Description:
