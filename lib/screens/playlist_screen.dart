import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/playlist_controller.dart';
import '../controllers/library_controller.dart';
import '../models/playlist.dart';
import '../models/media_item.dart';
import '../services/audio_handler.dart';

class PlaylistScreen extends StatefulWidget {
  final MyAudioHandler audioHandler;
  final Function(int) onNavigateToPlayer;

  const PlaylistScreen({
    super.key,
    required this.audioHandler,
    required this.onNavigateToPlayer,
  });

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final TextEditingController _playlistNameController = TextEditingController();

  void _showCreatePlaylistDialog() {
    _playlistNameController.clear();
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xff171f33),
          title: const Text('إنشاء قائمة تشغيل جديدة', style: TextStyle(color: Color(0xffdae2fd))),
          content: TextField(
            controller: _playlistNameController,
            autofocus: true,
            style: const TextStyle(color: Color(0xffdae2fd)),
            decoration: const InputDecoration(
              labelText: 'اسم قائمة التشغيل',
              labelStyle: TextStyle(color: Color(0xffcbc3d7)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xffd0bcff))),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xffd0bcff))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Color(0xffcbc3d7))),
            ),
            TextButton(
              onPressed: () {
                final name = _playlistNameController.text.trim();
                if (name.isNotEmpty) {
                  Provider.of<PlaylistController>(context, listen: false).createPlaylist(name);
                  Navigator.pop(context);
                }
              },
              child: const Text('إنشاء', style: TextStyle(color: Color(0xffd0bcff), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenamePlaylistDialog(Playlist playlist) {
    _playlistNameController.text = playlist.name;
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xff171f33),
          title: const Text('إعادة تسمية قائمة التشغيل', style: TextStyle(color: Color(0xffdae2fd))),
          content: TextField(
            controller: _playlistNameController,
            autofocus: true,
            style: const TextStyle(color: Color(0xffdae2fd)),
            decoration: const InputDecoration(
              labelText: 'الاسم الجديد',
              labelStyle: TextStyle(color: Color(0xffcbc3d7)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xffd0bcff))),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xffd0bcff))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Color(0xffcbc3d7))),
            ),
            TextButton(
              onPressed: () {
                final name = _playlistNameController.text.trim();
                if (name.isNotEmpty) {
                  Provider.of<PlaylistController>(context, listen: false).renamePlaylist(playlist.id, name);
                  Navigator.pop(context);
                }
              },
              child: const Text('حفظ', style: TextStyle(color: Color(0xffd0bcff), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _openPlaylistDetails(Playlist playlist) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlaylistDetailsScreen(
          playlistId: playlist.id,
          audioHandler: widget.audioHandler,
          onNavigateToPlayer: widget.onNavigateToPlayer,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _playlistNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playlistController = Provider.of<PlaylistController>(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0b1326),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('قوائم التشغيل'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.add, size: 28),
              onPressed: _showCreatePlaylistDialog,
            ),
          ],
        ),
        body: playlistController.isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xffd0bcff)))
            : playlistController.playlists.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: playlistController.playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlistController.playlists[index];
                      return _buildPlaylistCard(playlist);
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xff171f33),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: const Icon(Icons.playlist_play, color: Color(0xffd0bcff), size: 64),
            ),
            const SizedBox(height: 24),
            const Text(
              'قوائم التشغيل فارغة',
              style: TextStyle(color: Color(0xffdae2fd), fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'أنشئ قوائم تشغيل مخصصة ونظم موسيقاك المفضلة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xffcbc3d7), fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreatePlaylistDialog,
              icon: const Icon(Icons.add, color: Color(0xff0b1326)),
              label: const Text('إنشاء قائمة تشغيل', style: TextStyle(color: Color(0xff0b1326), fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffd0bcff),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistCard(Playlist playlist) {
    final libraryController = Provider.of<LibraryController>(context, listen: false);

    // Get the first track image if available
    String? playlistImage;
    if (playlist.itemIds.isNotEmpty) {
      final firstItemId = playlist.itemIds.first;
      final matchedItem = libraryController.items.firstWhere(
        (i) => i.id == firstItemId,
        orElse: () => LocalMediaItem(
          id: '',
          title: '',
          artist: '',
          durationSeconds: 0,
          filePath: '',
          thumbnailPath: '',
          isAudio: true,
          addedDate: DateTime.now(),
        ),
      );
      if (matchedItem.id.isNotEmpty && matchedItem.thumbnailPath.startsWith('downloads')) {
        playlistImage = matchedItem.thumbnailPath;
      }
    }

    return Card(
      color: const Color(0xff171f33),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.03)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xff0b1326),
            borderRadius: BorderRadius.circular(10),
          ),
          child: playlistImage != null
              ? FutureBuilder<File>(
                  future: libraryController.getThumbnailFile(
                    LocalMediaItem(
                      id: '',
                      title: '',
                      artist: '',
                      durationSeconds: 0,
                      filePath: '',
                      thumbnailPath: playlistImage,
                      isAudio: true,
                      addedDate: DateTime.now(),
                    ),
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.existsSync()) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(snapshot.data!, fit: BoxFit.cover),
                      );
                    }
                    return const Icon(Icons.playlist_play, color: Color(0xffd0bcff));
                  },
                )
              : const Icon(Icons.playlist_play, color: Color(0xffd0bcff)),
        ),
        title: Text(
          playlist.name,
          style: const TextStyle(color: Color(0xffdae2fd), fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          '${playlist.itemIds.length} مسار صوتی',
          style: const TextStyle(color: Color(0xffcbc3d7), fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xffcbc3d7), size: 20),
              onPressed: () => _showRenamePlaylistDialog(playlist),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xfffb7185), size: 20),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: AlertDialog(
                      backgroundColor: const Color(0xff171f33),
                      title: const Text('حذف قائمة التشغيل', style: TextStyle(color: Color(0xffdae2fd))),
                      content: Text('هل أنت متأكد من رغبتك في حذف "${playlist.name}"؟ لن يتم حذف الملفات الصوتية الأصلية.', style: const TextStyle(color: Color(0xffcbc3d7))),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('إلغاء', style: TextStyle(color: Color(0xffcbc3d7))),
                        ),
                        TextButton(
                          onPressed: () {
                            Provider.of<PlaylistController>(context, listen: false).deletePlaylist(playlist.id);
                            Navigator.pop(context);
                          },
                          child: const Text('حذف', style: TextStyle(color: Color(0xfffb7185), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        onTap: () => _openPlaylistDetails(playlist),
      ),
    );
  }
}

class PlaylistDetailsScreen extends StatefulWidget {
  final String playlistId;
  final MyAudioHandler audioHandler;
  final Function(int) onNavigateToPlayer;

  const PlaylistDetailsScreen({
    super.key,
    required this.playlistId,
    required this.audioHandler,
    required this.onNavigateToPlayer,
  });

  @override
  State<PlaylistDetailsScreen> createState() => _PlaylistDetailsScreenState();
}

class _PlaylistDetailsScreenState extends State<PlaylistDetailsScreen> {
  // Format seconds to mm:ss
  String _formatDuration(int seconds) {
    if (seconds <= 0) return '--:--';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _playPlaylist(List<LocalMediaItem> tracks, int startIndex) async {
    final libraryController = Provider.of<LibraryController>(context, listen: false);
    final queueItems = <MediaItem>[];
    final queuePaths = <String>[];

    for (int i = 0; i < tracks.length; i++) {
      final t = tracks[i];
      final path = await libraryController.getAbsolutePath(t.filePath);
      
      queueItems.add(MediaItem(
        id: t.id,
        title: t.title,
        artist: t.artist,
        duration: Duration(seconds: t.durationSeconds),
        artUri: t.thumbnailPath.startsWith('downloads')
            ? Uri.file(await libraryController.getAbsolutePath(t.thumbnailPath))
            : null,
        extras: {'filePath': path, 'isAudio': t.isAudio},
      ));
      queuePaths.add(path);
    }

    if (queueItems.isNotEmpty) {
      await widget.audioHandler.playQueue(queueItems, startIndex, queuePaths);
      widget.onNavigateToPlayer(2); // Go to player tab
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlistController = Provider.of<PlaylistController>(context);
    final libraryController = Provider.of<LibraryController>(context);

    final playlistIndex = playlistController.playlists.indexWhere((p) => p.id == widget.playlistId);
    if (playlistIndex == -1) {
      return const Scaffold(
        body: Center(child: Text('قائمة التشغيل غير موجودة', style: TextStyle(color: Colors.white))),
      );
    }

    final playlist = playlistController.playlists[playlistIndex];

    // Find full LocalMediaItem instances for ids in playlist
    final List<LocalMediaItem> tracks = [];
    for (var trackId in playlist.itemIds) {
      final idx = libraryController.items.indexWhere((i) => i.id == trackId);
      if (idx != -1) {
        tracks.add(libraryController.items[idx]);
      }
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0b1326),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(playlist.name),
          centerTitle: true,
          actions: [
            if (tracks.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.play_circle_fill, size: 28, color: Color(0xffd0bcff)),
                onPressed: () => _playPlaylist(tracks, 0),
              )
          ],
        ),
        body: tracks.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.queue_music, color: Colors.white24, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'لا توجد مسارات في هذه القائمة',
                        style: TextStyle(color: Color(0xffcbc3d7), fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'انتقل إلى علامة التبويب "المكتبة" واضغط طويلاً أو اضغط على الخيارات لإضافة مسارات صوتية.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white24, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${tracks.length} مسار صوتی',
                          style: const TextStyle(color: Color(0xffcbc3d7), fontSize: 13),
                        ),
                        const Text(
                          'اسحب لإعادة الترتيب',
                          style: TextStyle(color: Colors.white24, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      itemCount: tracks.length,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final item = tracks.removeAt(oldIndex);
                        tracks.insert(newIndex, item);
                        final updatedIds = tracks.map((t) => t.id).toList();
                        playlistController.updatePlaylistTracks(playlist.id, updatedIds);
                      },
                      itemBuilder: (context, index) {
                        final track = tracks[index];
                        return Card(
                          key: Key(track.id),
                          color: const Color(0xff171f33),
                          elevation: 0,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.white.withOpacity(0.02)),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xff0b1326),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: track.thumbnailPath.startsWith('downloads')
                                  ? FutureBuilder<File>(
                                      future: libraryController.getThumbnailFile(track),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData && snapshot.data!.existsSync()) {
                                          return ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.file(snapshot.data!, fit: BoxFit.cover),
                                          );
                                        }
                                        return const Icon(Icons.music_note, color: Color(0xffd0bcff));
                                      },
                                    )
                                  : const Icon(Icons.music_note, color: Color(0xffd0bcff)),
                            ),
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xffdae2fd), fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${track.artist} • ${_formatDuration(track.durationSeconds)}',
                              style: const TextStyle(color: Color(0xffcbc3d7), fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Color(0xfffb7185), size: 20),
                                  onPressed: () {
                                    playlistController.removeTrackFromPlaylist(playlist.id, track.id);
                                  },
                                ),
                                const Icon(Icons.drag_handle, color: Colors.white24),
                              ],
                            ),
                            onTap: () => _playPlaylist(tracks, index),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
