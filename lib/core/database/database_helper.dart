import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'luna_music.db');

    return openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE liked_songs (
            videoId TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            thumbnail TEXT NOT NULL,
            likedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE recently_played (
            videoId TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            thumbnail TEXT NOT NULL,
            playedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE downloads (
            videoId TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            thumbnailUrl TEXT NOT NULL,
            localAudioPath TEXT NOT NULL,
            localThumbnailPath TEXT NOT NULL,
            quality TEXT NOT NULL,
            fileSize INTEGER NOT NULL,
            downloadedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE search_history (
            query TEXT PRIMARY KEY,
            searchedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE playlists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            createdAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE playlist_songs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            playlistId INTEGER NOT NULL,
            videoId TEXT NOT NULL,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            thumbnail TEXT NOT NULL,
            addedAt INTEGER NOT NULL,
            FOREIGN KEY (playlistId) REFERENCES playlists(id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS recently_played (
              videoId TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              artist TEXT NOT NULL,
              thumbnail TEXT NOT NULL,
              playedAt INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS downloads (
              videoId TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              artist TEXT NOT NULL,
              thumbnailUrl TEXT NOT NULL,
              localAudioPath TEXT NOT NULL,
              localThumbnailPath TEXT NOT NULL,
              quality TEXT NOT NULL,
              fileSize INTEGER NOT NULL,
              downloadedAt INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS search_history (
              query TEXT PRIMARY KEY,
              searchedAt INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS playlists (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              createdAt INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS playlist_songs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              playlistId INTEGER NOT NULL,
              videoId TEXT NOT NULL,
              title TEXT NOT NULL,
              artist TEXT NOT NULL,
              thumbnail TEXT NOT NULL,
              addedAt INTEGER NOT NULL,
              FOREIGN KEY (playlistId) REFERENCES playlists(id) ON DELETE CASCADE
            )
          ''');
        }
      },
    );
  }
}