import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../controllers/library_controller.dart';
import '../controllers/download_controller.dart';
import '../controllers/playlist_controller.dart';
import '../models/media_item.dart';
import '../services/audio_handler.dart';

class LibraryScreen extends StatefulWidget {
  final MyAudioHandler audioHandler;
  final Function(int) onNavigateToPlayer;

  const LibraryScreen({
    super.key,
    required this.audioHandler,
    required this.onNavigateToPlayer,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      Provider.of<LibraryController>(context, listen: false)
          .setSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Format seconds to mm:ss
  String _formatDuration(int seconds) {
    if (seconds <= 0) return '--:--';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // Play track and configure audio service
  // Play track and configure audio service
  void _playTrack(LocalMediaItem item, LibraryController libraryController) async {
    if (!item.isAudio) {
      _showVideoPlayOptions(item, libraryController);
      return;
    }
    _playAudioTrackOnly(item, libraryController);
  }

  void _showVideoPlayOptions(LocalMediaItem item, LibraryController libraryController) async {
    final absPath = await libraryController.getAbsolutePath(item.filePath);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff171f33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xffdae2fd),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'خيارات تشغيل ملف الفيديو (MP4)',
                style: TextStyle(color: Color(0xffcbc3d7), fontSize: 12),
              ),
              const Divider(color: Colors.white10, height: 24),
              ListTile(
                leading: const Icon(Icons.movie, color: Color(0xff89ceff)),
                title: const Text('تشغيل كفيديو (في مشغل الجهاز)', style: TextStyle(color: Color(0xffdae2fd), fontSize: 14)),
                subtitle: const Text('لمشاهدة المقطع بالصوت والصورة بملء الشاشة', style: TextStyle(color: Colors.white24, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await OpenFilex.open(absPath);
                  if (result.type != ResultType.done && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تعذر فتح الفيديو تلقائياً: ${result.message}', textDirection: TextDirection.rtl),
                        backgroundColor: const Color(0xffffb2b7),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.music_note, color: Color(0xffd0bcff)),
                title: const Text('تشغيل كصوت فقط (في الخلفية)', style: TextStyle(color: Color(0xffdae2fd), fontSize: 14)),
                subtitle: const Text('للاستماع للمقطع والتحكم به خارج التطبيق', style: TextStyle(color: Colors.white24, fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  _playAudioTrackOnly(item, libraryController);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _playAudioTrackOnly(LocalMediaItem item, LibraryController libraryController) async {
    final absPath = await libraryController.getAbsolutePath(item.filePath);
    final isFileExists = await File(absPath).exists();
    if (!isFileExists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الملف غير موجود على الجهاز. قد يكون تم حذفه من مدير الملفات.', textDirection: TextDirection.rtl),
            backgroundColor: Color(0xffffb2b7),
          ),
        );
      }
      return;
    }

    // Build the queue of all playable items in the current filtered list
    final filteredPlayable = libraryController.filteredItems;
    final queueItems = <MediaItem>[];
    final queuePaths = <String>[];
    int initialIndex = 0;

    for (int i = 0; i < filteredPlayable.length; i++) {
      final t = filteredPlayable[i];
      final path = await libraryController.getAbsolutePath(t.filePath);
      if (t.id == item.id) {
        initialIndex = queueItems.length;
      }
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

    await widget.audioHandler.playQueue(queueItems, initialIndex, queuePaths);
    widget.onNavigateToPlayer(3); // Go to player tab (index 3 now)
  }

  Future<void> _convertVideoToAudio(LocalMediaItem item, LibraryController libraryController) async {
    if (item.isAudio) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xff171f33),
          title: const Text('تحويل الفيديو إلى صوت', style: TextStyle(color: Color(0xffdae2fd))),
          content: Text('هل تريد استخراج الصوت من "${item.title}" وحفظه كملف MP3؟', style: const TextStyle(color: Color(0xffcbc3d7))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: Color(0xffcbc3d7))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تحويل', style: TextStyle(color: Color(0xffd0bcff), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          color: Color(0xff171f33),
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xffd0bcff)),
                SizedBox(height: 16),
                Text('جاري تحويل الفيديو إلى صوت...', style: TextStyle(color: Color(0xffdae2fd))),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final videoPath = await libraryController.getAbsolutePath(item.filePath);
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(appDir.path, 'downloads'));
      
      final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
      final audioPath = p.join(downloadsDir.path, '$uniqueId.mp3');

      final ffmpegCmd = '-y -i "$videoPath" -b:a 320k -vn "$audioPath"';
      final session = await FFmpegKit.execute(ffmpegCmd);
      final returnCode = await session.getReturnCode();

      if (mounted) Navigator.pop(context); // Dismiss loading

      if (ReturnCode.isSuccess(returnCode)) {
        final audioItem = LocalMediaItem(
          id: uniqueId,
          title: '${item.title} (صوت)',
          artist: item.artist,
          durationSeconds: item.durationSeconds,
          filePath: p.join('downloads', '$uniqueId.mp3'),
          thumbnailPath: item.thumbnailPath,
          isAudio: true,
          addedDate: DateTime.now(),
          album: item.album,
        );

        await libraryController.addItem(audioItem);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحويل الفيديو إلى صوت بنجاح وتمت إضافته للمكتبة!', textDirection: TextDirection.rtl),
              backgroundColor: Color(0xffd0bcff),
            ),
          );
        }
      } else {
        throw Exception('فشل تحويل الملف بواسطة FFmpeg');
      }
    } catch (e) {
      if (mounted) {
        // Try dismissing loading if it is still shown
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء التحويل: $e', textDirection: TextDirection.rtl),
            backgroundColor: const Color(0xffffb2b7),
          ),
        );
      }
    }
  }

  void _showAddToPlaylistDialog(BuildContext context, LocalMediaItem item) {
    showDialog(
      context: context,
      builder: (context) {
        final playlistController = Provider.of<PlaylistController>(context);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xff171f33),
            title: const Text('إضافة إلى قائمة تشغيل', style: TextStyle(color: Color(0xffdae2fd))),
            content: playlistController.playlists.isEmpty
                ? const Text('لا توجد قوائم تشغيل حالية. يرجى إنشاء قائمة تشغيل أولاً.', style: TextStyle(color: Color(0xffcbc3d7)))
                : SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: playlistController.playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = playlistController.playlists[index];
                        final alreadyAdded = playlist.itemIds.contains(item.id);
                        return ListTile(
                          title: Text(playlist.name, style: const TextStyle(color: Color(0xffdae2fd))),
                          subtitle: Text('${playlist.itemIds.length} مسار صوتی', style: const TextStyle(color: Color(0xffcbc3d7), fontSize: 11)),
                          trailing: alreadyAdded
                              ? const Icon(Icons.check_circle, color: Color(0xffd0bcff))
                              : const Icon(Icons.add_circle_outline, color: Color(0xffcbc3d7)),
                          onTap: alreadyAdded
                              ? null
                              : () {
                                  playlistController.addTrackToPlaylist(playlist.id, item.id);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('تمت إضافة "${item.title}" إلى قائمة "${playlist.name}"', textDirection: TextDirection.rtl),
                                      backgroundColor: const Color(0xffd0bcff),
                                    ),
                                  );
                                },
                        );
                      },
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء', style: TextStyle(color: Color(0xffcbc3d7))),
              ),
            ],
          ),
        );
      },
    );
  }

  void _shareMediaFile(LocalMediaItem item, LibraryController libraryController) async {
    try {
      final absPath = await libraryController.getAbsolutePath(item.filePath);
      final fileExists = await File(absPath).exists();
      if (!fileExists) {
        throw Exception('الملف غير موجود على الجهاز');
      }

      await Share.shareXFiles([XFile(absPath)], text: item.title);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل مشاركة الملف: $e', textDirection: TextDirection.rtl),
            backgroundColor: const Color(0xffffb2b7),
          ),
        );
      }
    }
  }

  // Show action sheet for item
  void _showActionSheet(BuildContext context, LocalMediaItem item, LibraryController libraryController) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff171f33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xffdae2fd),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                item.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xffcbc3d7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const Divider(color: Colors.white10, height: 24),
              ListTile(
                leading: const Icon(Icons.play_arrow, color: Color(0xffd0bcff)),
                title: const Text('تشغيل', style: TextStyle(color: Color(0xffdae2fd))),
                onTap: () {
                  Navigator.pop(context);
                  _playTrack(item, libraryController);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xff89ceff)),
                title: const Text('تعديل الاسم والمعلومات', style: TextStyle(color: Color(0xffdae2fd))),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(context, item, libraryController);
                },
              ),
              ListTile(
                leading: const Icon(Icons.album, color: Color(0xffd0bcff)),
                title: const Text('إضافة إلى ألبوم', style: TextStyle(color: Color(0xffdae2fd))),
                onTap: () {
                  Navigator.pop(context);
                  _showAlbumDialog(context, item, libraryController);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add, color: Color(0xffd0bcff)),
                title: const Text('إضافة إلى قائمة تشغيل', style: TextStyle(color: Color(0xffdae2fd))),
                onTap: () {
                  Navigator.pop(context);
                  _showAddToPlaylistDialog(context, item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Color(0xff89ceff)),
                title: const Text('مشاركة الملف', style: TextStyle(color: Color(0xffdae2fd))),
                onTap: () {
                  Navigator.pop(context);
                  _shareMediaFile(item, libraryController);
                },
              ),
              if (!item.isAudio)
                ListTile(
                  leading: const Icon(Icons.music_note, color: Color(0xffffb2b7)),
                  title: const Text('تحويل إلى ملف صوتي MP3', style: TextStyle(color: Color(0xffdae2fd))),
                  onTap: () {
                    Navigator.pop(context);
                    _convertVideoToAudio(item, libraryController);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Color(0xffffb2b7)),
                title: const Text('حذف نهائي', style: TextStyle(color: Color(0xffffb2b7))),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmDialog(context, item, libraryController);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Rename item
  void _showRenameDialog(BuildContext context, LocalMediaItem item, LibraryController libraryController) {
    final titleController = TextEditingController(text: item.title);
    final artistController = TextEditingController(text: item.artist);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff171f33),
          title: const Text('تعديل المعلومات', textDirection: TextDirection.rtl, style: TextStyle(color: Color(0xffdae2fd))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Color(0xffdae2fd)),
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  labelStyle: TextStyle(color: Color(0xffcbc3d7)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xffd0bcff))),
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: artistController,
                style: const TextStyle(color: Color(0xffdae2fd)),
                decoration: const InputDecoration(
                  labelText: 'الفنان / القناة',
                  labelStyle: TextStyle(color: Color(0xffcbc3d7)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xffd0bcff))),
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Color(0xffcbc3d7))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffd0bcff)),
              onPressed: () {
                if (titleController.text.trim().isNotEmpty) {
                  libraryController.updateItemMetadata(
                    item.id,
                    title: titleController.text.trim(),
                    artist: artistController.text.trim(),
                    album: item.album,
                  );
                }
                Navigator.pop(context);
              },
              child: const Text('حفظ', style: TextStyle(color: Color(0xff0b1326))),
            ),
          ],
        );
      },
    );
  }

  // Set Album and Year
  void _showAlbumDialog(BuildContext context, LocalMediaItem item, LibraryController libraryController) {
    final albumController = TextEditingController(text: item.album ?? '');
    final yearController = TextEditingController(text: item.year ?? libraryController.albumYears[item.album] ?? '');
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xff171f33),
              title: const Text('إضافة للألبوم والتحكم بالعام', textDirection: TextDirection.rtl, style: TextStyle(color: Color(0xffdae2fd))),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('اسم الألبوم:', style: TextStyle(color: Color(0xffcbc3d7), fontSize: 12), textDirection: TextDirection.rtl),
                    const SizedBox(height: 4),
                    TextField(
                      controller: albumController,
                      style: const TextStyle(color: Color(0xffdae2fd)),
                      decoration: const InputDecoration(
                        hintText: 'اسم الألبوم...',
                        hintStyle: TextStyle(color: Colors.white24),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xffd0bcff))),
                      ),
                      textDirection: TextDirection.rtl,
                      onChanged: (val) {
                        final existingYear = libraryController.albumYears[val.trim()];
                        if (existingYear != null) {
                          yearController.text = existingYear;
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('العام / السنة:', style: TextStyle(color: Color(0xffcbc3d7), fontSize: 12), textDirection: TextDirection.rtl),
                    const SizedBox(height: 4),
                    TextField(
                      controller: yearController,
                      style: const TextStyle(color: Color(0xffdae2fd)),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'مثال: 2026...',
                        hintStyle: TextStyle(color: Colors.white24),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xffd0bcff))),
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 16),
                    // Show existing albums list
                    if (libraryController.albums.isNotEmpty) ...[
                      const Text('الألبومات الحالية (انقر للاختيار):', style: TextStyle(color: Color(0xffcbc3d7), fontSize: 12), textDirection: TextDirection.rtl),
                      const SizedBox(height: 6),
                      Container(
                        height: 100,
                        width: double.maxFinite,
                        decoration: BoxDecoration(
                          color: const Color(0xff0b1326).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: libraryController.albums.length,
                          itemBuilder: (context, idx) {
                            final albumName = libraryController.albums[idx];
                            final albumYear = libraryController.albumYears[albumName];
                            final displayText = albumYear != null ? '$albumName ($albumYear)' : albumName;
                            
                            return ListTile(
                              dense: true,
                              title: Text(displayText, style: const TextStyle(color: Color(0xffdae2fd), fontSize: 12)),
                              onTap: () {
                                setState(() {
                                  albumController.text = albumName;
                                  if (albumYear != null) {
                                    yearController.text = albumYear;
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(color: Color(0xffcbc3d7))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffd0bcff)),
                  onPressed: () {
                    libraryController.updateItemMetadata(
                      item.id,
                      title: item.title,
                      artist: item.artist,
                      album: albumController.text.trim().isEmpty ? null : albumController.text.trim(),
                      year: yearController.text.trim().isEmpty ? null : yearController.text.trim(),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('تطبيق', style: TextStyle(color: Color(0xff0b1326))),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Confirm delete
  void _showDeleteConfirmDialog(BuildContext context, LocalMediaItem item, LibraryController libraryController) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff171f33),
          title: const Text('تأكيد الحذف', textDirection: TextDirection.rtl, style: TextStyle(color: Color(0xffffb2b7))),
          content: const Text(
            'هل أنت متأكد من رغبتك في حذف هذا الملف نهائياً من ذاكرة الجهاز؟ لا يمكن التراجع عن هذا الإجراء.',
            textDirection: TextDirection.rtl,
            style: TextStyle(color: Color(0xffdae2fd)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Color(0xffcbc3d7))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffffb2b7)),
              onPressed: () {
                libraryController.deleteItem(item);
                Navigator.pop(context);
              },
              child: const Text('حذف', style: TextStyle(color: Color(0xff0b1326))),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryController = Provider.of<LibraryController>(context);
    final downloadController = Provider.of<DownloadController>(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0b1326),
        appBar: AppBar(
          backgroundColor: const Color(0xff0b1326),
          elevation: 0,
          title: const Text(
            'مكتبتي',
            style: TextStyle(
              color: Color(0xffd0bcff),
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xffd0bcff)),
              onPressed: () => libraryController.loadLibrary(),
            )
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Active download indicator banner
              if (downloadController.status != DownloadStatus.idle &&
                  downloadController.status != DownloadStatus.completed)
                _buildActiveDownloadBanner(downloadController),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xff171f33),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Color(0xffdae2fd), fontSize: 15),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: Color(0xffcbc3d7)),
                      hintText: 'البحث في مكتبتك...',
                      hintStyle: const TextStyle(color: Color(0xffcbc3d7), fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Color(0xffcbc3d7)),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                    ),
                  ),
                ),
              ),

              // Filter Tabs (All / Audio / Video)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xff131b2e),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton('الكل', 'all', libraryController),
                      _buildTabButton('صوتيات', 'audio', libraryController),
                      _buildTabButton('فيديوهات', 'video', libraryController),
                    ],
                  ),
                ),
              ),

              // Albums horizontal list if any
              if (libraryController.albums.isNotEmpty)
                _buildAlbumsHorizontalList(libraryController),

              // Tracks List
              Expanded(
                child: libraryController.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xffd0bcff)),
                        ),
                      )
                    : libraryController.filteredItems.isEmpty
                        ? _buildEmptyState(libraryController)
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: libraryController.filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = libraryController.filteredItems[index];
                              return _buildTrackCard(context, item, libraryController);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveDownloadBanner(DownloadController download) {
    String statusText = '';
    Color statusColor = const Color(0xff89ceff);

    switch (download.status) {
      case DownloadStatus.queued:
        statusText = 'في قائمة الانتظار: ${download.currentTitle}';
        statusColor = const Color(0xffcbc3d7);
        break;
      case DownloadStatus.analyzing:
        statusText = 'جاري تحليل الرابط...';
        break;
      case DownloadStatus.downloading:
        final pct = download.progress > 0 ? '(${(download.progress * 100).toStringAsFixed(0)}%)' : '';
        statusText = 'جاري تحميل: ${download.currentTitle} $pct';
        break;
      case DownloadStatus.converting:
        statusText = 'جاري تحويل ومعالجة الملف...';
        statusColor = const Color(0xffd0bcff);
        break;
      case DownloadStatus.failed:
        statusText = 'فشل التحميل: ${download.errorMessage}';
        statusColor = const Color(0xffffb2b7);
        break;
      default:
        break;
    }

    return Container(
      width: double.infinity,
      color: statusColor.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                ),
              ),
              if (download.status == DownloadStatus.downloading ||
                  download.status == DownloadStatus.converting ||
                  download.status == DownloadStatus.analyzing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xffd0bcff)),
                  ),
                ),
            ],
          ),
          if (download.status == DownloadStatus.downloading ||
              download.status == DownloadStatus.converting) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (download.status == DownloadStatus.downloading && download.progress > 0)
                    ? download.progress
                    : null,
                minHeight: 4,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, String filterVal, LibraryController controller) {
    final isActive = controller.selectedFilter == filterVal;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.setSelectedFilter(filterVal),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xff1e293b).withOpacity(0.6) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? const Color(0xffd0bcff) : const Color(0xffcbc3d7),
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumsHorizontalList(LibraryController controller) {
    final selectedAlbum = controller.selectedAlbum;
    
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (selectedAlbum != null)
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.delete_sweep, color: Color(0xfffb7185), size: 22),
                tooltip: 'حذف الألبوم المختار',
                onPressed: () => _showDeleteAlbumDialog(context, selectedAlbum, controller),
              ),
            ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: controller.albums.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isAllSelected = controller.selectedAlbum == null;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: const Text('كل الألبومات'),
                      selected: isAllSelected,
                      selectedColor: const Color(0xffd0bcff).withOpacity(0.2),
                      backgroundColor: const Color(0xff171f33),
                      labelStyle: TextStyle(
                        color: isAllSelected ? const Color(0xffd0bcff) : const Color(0xffcbc3d7),
                        fontSize: 12,
                      ),
                      onSelected: (_) => controller.setSelectedAlbum(null),
                    ),
                  );
                }
                final album = controller.albums[index - 1];
                final isSelected = controller.selectedAlbum == album;
                
                final albumYear = controller.albumYears[album];
                final chipLabel = albumYear != null ? '$album • $albumYear' : album;

                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(chipLabel),
                    selected: isSelected,
                    selectedColor: const Color(0xffd0bcff).withOpacity(0.2),
                    backgroundColor: const Color(0xff171f33),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xffd0bcff) : const Color(0xffcbc3d7),
                      fontSize: 12,
                    ),
                    onSelected: (_) => controller.setSelectedAlbum(album),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAlbumDialog(BuildContext context, String albumName, LibraryController controller) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xff171f33),
          title: Text('حذف ألبوم "$albumName"', style: const TextStyle(color: Color(0xffdae2fd))),
          content: const Text(
            'اختر الإجراء الذي ترغب في اتخاذه:\n\n'
            '1. إزالة الألبوم فقط: سيتم حذف تصنيف الألبوم من الأغاني مع إبقائها في مكتبتك.\n'
            '2. حذف الألبوم والأغاني: سيتم حذف الألبوم وحذف جميع الأغاني التابعة له نهائياً من الجهاز.',
            style: TextStyle(color: Color(0xffcbc3d7), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Color(0xffcbc3d7))),
            ),
            TextButton(
              onPressed: () {
                controller.deleteAlbum(albumName);
                Navigator.pop(context);
              },
              child: const Text('إزالة الألبوم فقط', style: TextStyle(color: Color(0xffcbc3d7))),
            ),
            TextButton(
              onPressed: () {
                controller.deleteAlbumWithSongs(albumName);
                Navigator.pop(context);
              },
              child: const Text('حذف الألبوم والأغاني', style: TextStyle(color: Color(0xfffb7185), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(LibraryController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              controller.searchQuery.isNotEmpty ? Icons.search_off : Icons.library_music,
              size: 64,
              color: const Color(0xffcbc3d7).withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              controller.searchQuery.isNotEmpty
                  ? 'لم نعثر على نتائج مطابقة لـ "${controller.searchQuery}"'
                  : 'مكتبتك فارغة حالياً',
              style: const TextStyle(color: Color(0xffcbc3d7), fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              controller.searchQuery.isNotEmpty
                  ? 'تأكد من كتابة الاسم بشكل صحيح أو ابحث عن كلمة أخرى.'
                  : 'اذهب لتبويب "المتصفح" لفتح يوتيوب وتنزيل أغانيك المفضلة لتظهر هنا.',
              style: const TextStyle(color: Colors.white24, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackCard(BuildContext context, LocalMediaItem item, LibraryController libraryController) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key('track-${item.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            color: const Color(0xfffb7185).withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xfffb7185).withOpacity(0.3), width: 0.5),
          ),
          child: const Icon(Icons.delete_sweep, color: Color(0xfffb7185), size: 26),
        ),
        confirmDismiss: (direction) async {
          return await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                backgroundColor: const Color(0xff171f33),
                title: const Text('تأكيد الحذف', textDirection: TextDirection.rtl, style: TextStyle(color: Color(0xfffb7185), fontWeight: FontWeight.bold)),
                content: const Text(
                  'هل أنت متأكد من رغبتك في حذف هذا الملف نهائياً من ذاكرة الجهاز؟ لا يمكن التراجع عن هذا الإجراء.',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(color: Color(0xffdae2fd), fontSize: 14),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('إلغاء', style: TextStyle(color: Color(0xffcbc3d7))),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xfffb7185)),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('حذف', style: TextStyle(color: Color(0xff0b1326), fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          );
        },
        onDismissed: (direction) {
          libraryController.deleteItem(item);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حذف "${item.title}" نهائياً من الجهاز.', textDirection: TextDirection.rtl),
              backgroundColor: const Color(0xfffb7185),
            ),
          );
        },
        child: InkWell(
          onTap: () => _playTrack(item, libraryController),
          onLongPress: !item.isAudio ? () => _convertVideoToAudio(item, libraryController) : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xff171f33).withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.04), width: 0.5),
            ),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: item.thumbnailPath.startsWith('downloads')
                        ? FutureBuilder<String>(
                            future: libraryController.getAbsolutePath(item.thumbnailPath),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && File(snapshot.data!).existsSync()) {
                                return Image.file(
                                  File(snapshot.data!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildFallbackThumb(item.isAudio),
                                );
                              }
                              return _buildFallbackThumb(item.isAudio);
                            },
                          )
                        : _buildFallbackThumb(item.isAudio),
                  ),
                ),
                const SizedBox(width: 12),
                // Track Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xffdae2fd),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xffcbc3d7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.isAudio
                                  ? const Color(0xffd0bcff).withOpacity(0.1)
                                  : const Color(0xff89ceff).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.isAudio ? 'MP3' : 'MP4',
                              style: TextStyle(
                                color: item.isAudio ? const Color(0xffd0bcff) : const Color(0xff89ceff),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (item.album != null) ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.year != null ? '💿 ${item.album} (${item.year})' : '💿 ${item.album}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white24, fontSize: 10),
                              ),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            _formatDuration(item.durationSeconds),
                            style: const TextStyle(color: Colors.white30, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action Button
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Color(0xffcbc3d7)),
                  onPressed: () => _showActionSheet(context, item, libraryController),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackThumb(bool isAudio) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff2d3449), Color(0xff0b1326)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          isAudio ? Icons.music_note : Icons.videocam,
          color: const Color(0xffd0bcff),
          size: 24,
        ),
      ),
    );
  }
}
