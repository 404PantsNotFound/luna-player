class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    this.songCount = 0,
    this.thumbnailUrl,
  });

  final int id;
  final String name;
  final DateTime createdAt;
  final int songCount;
  final String? thumbnailUrl;

  factory Playlist.fromMap(Map<String, dynamic> map) => Playlist(
        id: map['id'] as int,
        name: map['name'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            map['createdAt'] as int),
        songCount: map['songCount'] as int? ?? 0,
        thumbnailUrl: map['thumbnailUrl'] as String?,
      );
}