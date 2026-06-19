class LocalMediaItem {
  final String id;
  final String title;
  final String artist;
  final int durationSeconds;
  final String filePath;
  final String thumbnailPath;
  final bool isAudio;
  final DateTime addedDate;
  final String? album;

  LocalMediaItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.durationSeconds,
    required this.filePath,
    required this.thumbnailPath,
    required this.isAudio,
    required this.addedDate,
    this.album,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'durationSeconds': durationSeconds,
      'filePath': filePath,
      'thumbnailPath': thumbnailPath,
      'isAudio': isAudio,
      'addedDate': addedDate.toIso8601String(),
      'album': album,
    };
  }

  factory LocalMediaItem.fromJson(Map<String, dynamic> json) {
    return LocalMediaItem(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      durationSeconds: json['durationSeconds'] as int,
      filePath: json['filePath'] as String,
      thumbnailPath: json['thumbnailPath'] as String,
      isAudio: json['isAudio'] as bool,
      addedDate: DateTime.parse(json['addedDate'] as String),
      album: json['album'] as String?,
    );
  }
}
