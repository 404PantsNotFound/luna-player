class DownloadItem {
  const DownloadItem({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.localAudioPath,
    required this.localThumbnailPath,
    required this.quality,
    required this.fileSize,
    required this.downloadedAt,
  });

  final String videoId;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final String localAudioPath;
  final String localThumbnailPath;
  final String quality;
  final int fileSize;
  final DateTime downloadedAt;

  String get fileSizeFormatted {
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory DownloadItem.fromMap(Map<String, dynamic> map) => DownloadItem(
        videoId: map['videoId'] as String,
        title: map['title'] as String,
        artist: map['artist'] as String,
        thumbnailUrl: map['thumbnailUrl'] as String,
        localAudioPath: map['localAudioPath'] as String,
        localThumbnailPath: map['localThumbnailPath'] as String,
        quality: map['quality'] as String,
        fileSize: map['fileSize'] as int,
        downloadedAt: DateTime.fromMillisecondsSinceEpoch(
            map['downloadedAt'] as int),
      );

  Map<String, dynamic> toMap() => {
        'videoId': videoId,
        'title': title,
        'artist': artist,
        'thumbnailUrl': thumbnailUrl,
        'localAudioPath': localAudioPath,
        'localThumbnailPath': localThumbnailPath,
        'quality': quality,
        'fileSize': fileSize,
        'downloadedAt': downloadedAt.millisecondsSinceEpoch,
      };
}