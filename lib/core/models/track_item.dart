class TrackItem {
  TrackItem({
    required this.id,
    required this.videoId,
    required this.title,
    required this.artist,
    required this.thumbnail,
    this.duration,
    this.isLocal = false,
    this.localFilePath,
  });

  final String id;
  final String videoId;
  final String title;
  final String artist;
  final String thumbnail;
  final Duration? duration;
  final bool isLocal;
  final String? localFilePath;
}