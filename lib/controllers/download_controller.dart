import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/media_item.dart';
import 'library_controller.dart';

enum DownloadStatus { idle, analyzing, downloading, converting, completed, failed }

class DownloadController extends ChangeNotifier {
  DownloadStatus _status = DownloadStatus.idle;
  double _progress = 0.0;
  String _currentTitle = '';
  String _errorMessage = '';
  String _downloadSize = '';

  DownloadStatus get status => _status;
  double get progress => _progress;
  String get currentTitle => _currentTitle;
  String get errorMessage => _errorMessage;
  String get downloadSize => _downloadSize;

  final _yt = YoutubeExplode();

  void reset() {
    _status = DownloadStatus.idle;
    _progress = 0.0;
    _currentTitle = '';
    _errorMessage = '';
    _downloadSize = '';
    notifyListeners();
  }

  Future<void> startDownload(
    String url,
    bool isAudio,
    LibraryController libraryController,
  ) async {
    if (url.trim().isEmpty) {
      _errorMessage = 'الرجاء إدخال رابط صحيح';
      _status = DownloadStatus.failed;
      notifyListeners();
      return;
    }

    _status = DownloadStatus.analyzing;
    _progress = 0.0;
    _currentTitle = 'جاري تحليل الرابط...';
    _errorMessage = '';
    _downloadSize = '';
    notifyListeners();

    try {
      // Check if it is a YouTube URL
      final cleanUrl = url.trim();
      final isYouTube = cleanUrl.contains('youtube.com') || cleanUrl.contains('youtu.be');

      if (!isYouTube) {
        // Simple direct HTTP download fallback
        await _downloadDirectFile(cleanUrl, isAudio, libraryController);
        return;
      }

      // Parse YouTube Video
      Video video;
      try {
        video = await _yt.videos.get(VideoId(cleanUrl));
      } catch (e) {
        // Try parsing video ID from url queries manually if VideoId class failed
        final idStr = VideoId.parseVideoId(cleanUrl) ?? '';
        if (idStr.isEmpty) throw Exception('عذرًا، لم نتمكن من التعرف على معرف الفيديو من هذا الرابط');
        video = await _yt.videos.get(VideoId(idStr));
      }

      _currentTitle = video.title;
      notifyListeners();

      // Get streams
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);
      
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(appDir.path, 'downloads'));
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final cleanVideoTitle = _sanitizeFileName(video.title);
      final uniqueId = video.id.value;

      // Download Thumbnail
      String relThumbnailPath = 'assets/default_thumb.png';
      try {
        final thumbUrl = video.thumbnails.highResUrl;
        final thumbResponse = await http.get(Uri.parse(thumbUrl));
        if (thumbResponse.statusCode == 200) {
          final thumbFile = File(p.join(downloadsDir.path, '$uniqueId.jpg'));
          await thumbFile.writeAsBytes(thumbResponse.bodyBytes);
          relThumbnailPath = p.join('downloads', '$uniqueId.jpg');
        }
      } catch (e) {
        if (kDebugMode) print('Failed to download thumbnail: $e');
      }

      if (isAudio) {
        // Audio conversion path: Get audio-only stream and convert to mp3 via FFmpeg
        final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
        _downloadSize = '${(audioStreamInfo.size.megaBytes).toStringAsFixed(1)} MB';
        
        final tempAudioPath = p.join(downloadsDir.path, '${uniqueId}_temp.webm');
        final outputAudioPath = p.join(downloadsDir.path, '$uniqueId.mp3');

        // Download stream to temp file
        _status = DownloadStatus.downloading;
        notifyListeners();

        final tempFile = File(tempAudioPath);
        final fileStream = tempFile.openWrite();
        final stream = _yt.videos.streamsClient.get(audioStreamInfo);

        double bytesDownloaded = 0.0;
        final totalBytes = audioStreamInfo.size.bytes;

        await for (final data in stream) {
          fileStream.add(data);
          bytesDownloaded += data.length;
          _progress = bytesDownloaded / totalBytes;
          notifyListeners();
        }
        await fileStream.close();

        // Convert to MP3 using ffmpeg_kit
        _status = DownloadStatus.converting;
        _progress = 0.0;
        notifyListeners();

        // Overwrite output if already exists
        final finalMp3File = File(outputAudioPath);
        if (await finalMp3File.exists()) {
          await finalMp3File.delete();
        }

        // Execute FFmpeg: convert to mp3 320k
        final ffmpegCmd = '-y -i "$tempAudioPath" -b:a 320k -vn "$outputAudioPath"';
        final session = await FFmpegKit.execute(ffmpegCmd);
        final returnCode = await session.getReturnCode();

        // Clean up temp audio stream file
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        if (ReturnCode.isSuccess(returnCode)) {
          // Add to Library
          final mediaItem = LocalMediaItem(
            id: uniqueId,
            title: video.title,
            artist: video.author,
            durationSeconds: video.duration?.inSeconds ?? 0,
            filePath: p.join('downloads', '$uniqueId.mp3'),
            thumbnailPath: relThumbnailPath,
            isAudio: true,
            addedDate: DateTime.now(),
          );
          await libraryController.addItem(mediaItem);
          _status = DownloadStatus.completed;
          _progress = 1.0;
          notifyListeners();
        } else {
          final failStackTrace = await session.getFailStackTrace();
          throw Exception('فشل تحويل الملف الصوتي: $failStackTrace');
        }
      } else {
        // Video path: Download video with highest quality (muxed or video+audio combined)
        // For simplicity and quick execution, download a muxed stream (video + audio)
        final videoStreamInfo = manifest.muxed.withHighestVideoQuality();
        _downloadSize = '${(videoStreamInfo.size.megaBytes).toStringAsFixed(1)} MB';

        final outputVideoPath = p.join(downloadsDir.path, '$uniqueId.mp4');

        _status = DownloadStatus.downloading;
        notifyListeners();

        final finalFile = File(outputVideoPath);
        if (await finalFile.exists()) {
          await finalFile.delete();
        }

        final fileStream = finalFile.openWrite();
        final stream = _yt.videos.streamsClient.get(videoStreamInfo);

        double bytesDownloaded = 0.0;
        final totalBytes = videoStreamInfo.size.bytes;

        await for (final data in stream) {
          fileStream.add(data);
          bytesDownloaded += data.length;
          _progress = bytesDownloaded / totalBytes;
          notifyListeners();
        }
        await fileStream.close();

        // Add to Library
        final mediaItem = LocalMediaItem(
          id: uniqueId,
          title: video.title,
          artist: video.author,
          durationSeconds: video.duration?.inSeconds ?? 0,
          filePath: p.join('downloads', '$uniqueId.mp4'),
          thumbnailPath: relThumbnailPath,
          isAudio: false,
          addedDate: DateTime.now(),
        );
        await libraryController.addItem(mediaItem);
        _status = DownloadStatus.completed;
        _progress = 1.0;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Download error: $e');
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      _status = DownloadStatus.failed;
      notifyListeners();
    }
  }

  // Direct HTTP file download fallback
  Future<void> _downloadDirectFile(
    String url,
    bool isAudio,
    LibraryController libraryController,
  ) async {
    try {
      final uri = Uri.parse(url);
      final filename = p.basename(uri.path);
      final extension = p.extension(uri.path);
      
      final title = filename.isNotEmpty ? filename.split('.').first : 'ملف خارجي';
      _currentTitle = title;
      notifyListeners();

      final response = await http.head(uri);
      int totalBytes = 0;
      if (response.headers.containsKey('content-length')) {
        totalBytes = int.tryParse(response.headers['content-length'] ?? '0') ?? 0;
      }
      _downloadSize = totalBytes > 0 ? '${(totalBytes / 1024 / 1024).toStringAsFixed(1)} MB' : 'غير معروف';

      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(appDir.path, 'downloads'));
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
      final finalExtension = extension.isNotEmpty ? extension : (isAudio ? '.mp3' : '.mp4');
      final outputFilePath = p.join(downloadsDir.path, '$uniqueId$finalExtension');

      _status = DownloadStatus.downloading;
      notifyListeners();

      final client = http.Client();
      final request = http.Request('GET', uri);
      final responseStream = await client.send(request);

      if (responseStream.statusCode != 200) {
        throw Exception('فشل الاتصال بالملف الخارجي: رمز الحالة ${responseStream.statusCode}');
      }

      final file = File(outputFilePath);
      final fileSink = file.openWrite();
      
      int bytesDownloaded = 0;
      await for (final chunk in responseStream.stream) {
        fileSink.add(chunk);
        bytesDownloaded += chunk.length;
        if (totalBytes > 0) {
          _progress = bytesDownloaded / totalBytes;
        } else {
          _progress = -1.0; // Indeterminate
        }
        notifyListeners();
      }
      await fileSink.close();
      client.close();

      // Add to Library
      final mediaItem = LocalMediaItem(
        id: uniqueId,
        title: title,
        artist: uri.host,
        durationSeconds: 0,
        filePath: p.join('downloads', '$uniqueId$finalExtension'),
        thumbnailPath: 'assets/default_thumb.png', // Fallback
        isAudio: isAudio,
        addedDate: DateTime.now(),
      );

      await libraryController.addItem(mediaItem);
      _status = DownloadStatus.completed;
      _progress = 1.0;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Direct download error: $e');
      _errorMessage = 'فشل تنزيل الرابط المباشر: $e';
      _status = DownloadStatus.failed;
      notifyListeners();
    }
  }

  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(' ', '_')
        .substring(0, name.length > 50 ? 50 : name.length);
  }

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }
}
