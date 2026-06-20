class Playlist {
  final String id;
  final String name;
  final List<String> itemIds;
  final DateTime createdAt;

  Playlist({
    required this.id,
    required this.name,
    required this.itemIds,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'itemIds': itemIds.join(','),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Playlist.fromMap(Map<String, dynamic> map) {
    final itemIdsStr = map['itemIds'] as String? ?? '';
    return Playlist(
      id: map['id'] as String,
      name: map['name'] as String,
      itemIds: itemIdsStr.isNotEmpty ? itemIdsStr.split(',') : [],
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
