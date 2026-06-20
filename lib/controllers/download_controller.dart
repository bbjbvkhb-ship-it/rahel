import 'dart:convert';
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

enum DownloadStatus { idle, queued, analyzing, downloading, converting, completed, failed }

class DownloadTask {
  final String id;
  final String url;
  String title;
  final bool isAudio;
  final String quality;
  DownloadStatus status;
  double progress;
  String size;
  String errorMessage;
  DateTime dateAdded;

  DownloadTask({
    required this.id,
    required this.url,
    required this.title,
    required this.isAudio,
    required this.quality,
    this.status = DownloadStatus.idle,
    this.progress = 0.0,
    this.size = '',
    this.errorMessage = '',
    DateTime? dateAdded,
  }) : dateAdded = dateAdded ?? DateTime.now();

  void update({
    DownloadStatus? status,
    double? progress,
    String? size,
    String? errorMessage,
    String? title,
  }) {
    if (status != null) this.status = status;
    if (progress != null) this.progress = progress;
    if (size != null) this.size = size;
    if (errorMessage != null) this.errorMessage = errorMessage;
    if (title != null) this.title = title;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'isAudio': isAudio,
      'quality': quality,
      'status': status.name,
      'progress': progress,
      'size': size,
      'errorMessage': errorMessage,
      'dateAdded': dateAdded.toIso8601String(),
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] as String,
      url: json['url'] as String,
      title: json['title'] as String,
      isAudio: json['isAudio'] as bool,
      quality: json['quality'] as String,
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.completed,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 1.0,
      size: json['size'] as String? ?? '',
      errorMessage: json['errorMessage'] as String? ?? '',
      dateAdded: DateTime.parse(json['dateAdded'] as String),
    );
  }
}

class DownloadController extends ChangeNotifier {
  List<DownloadTask> _tasks = []; // Active and queued tasks
  List<DownloadTask> _history = []; // Completed and failed tasks
  
  // Single active task variables (for backward compatibility with old widgets)
  DownloadStatus _status = DownloadStatus.idle;
  double _progress = 0.0;
  String _currentTitle = '';
  String _errorMessage = '';
  String _downloadSize = '';

  List<DownloadTask> get tasks => _tasks;
  List<DownloadTask> get history => _history;

  DownloadStatus get status => _status;
  double get progress => _progress;
  String get currentTitle => _currentTitle;
  String get errorMessage => _errorMessage;
  String get downloadSize => _downloadSize;

  final _yt = YoutubeExplode();

  DownloadController() {
    _loadHistory();
  }

  void reset() {
    _status = DownloadStatus.idle;
    _progress = 0.0;
    _currentTitle = '';
    _errorMessage = '';
    _downloadSize = '';
    notifyListeners();
  }

  // Load download history from JSON
  Future<void> _loadHistory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File(p.join(appDir.path, 'download_history.json'));
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        _history = jsonList.map((j) => DownloadTask.fromJson(j as Map<String, dynamic>)).toList();
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Error loading download history: $e');
    }
  }

  // Save download history to JSON
  Future<void> _saveHistory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File(p.join(appDir.path, 'download_history.json'));
      final jsonList = _history.map((t) => t.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      if (kDebugMode) print('Error saving download history: $e');
    }
  }

  // Clear download history
  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }

  // Add a new download task to the queue
  Future<void> queueDownload(
    String url,
    bool isAudio,
    String quality,
    LibraryController libraryController,
  ) async {
    if (url.trim().isEmpty) return;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final task = DownloadTask(
      id: id,
      url: url.trim(),
      title: 'جاري جلب معلومات الفيديو...',
      isAudio: isAudio,
      quality: quality,
      status: DownloadStatus.queued,
    );

    _tasks.add(task);
    
    // Update backward compatibility fields
    _status = DownloadStatus.queued;
    _currentTitle = task.title;
    notifyListeners();

    _processQueue(libraryController);
  }

  // Process the queue and execute up to 3 concurrent downloads
  Future<void> _processQueue(LibraryController libraryController) async {
    final activeCount = _tasks.where((t) => 
      t.status == DownloadStatus.analyzing || 
      t.status == DownloadStatus.downloading || 
      t.status == DownloadStatus.converting
    ).length;

    if (activeCount >= 3) return; // Max 3 concurrent downloads

    final nextIndex = _tasks.indexWhere((t) => t.status == DownloadStatus.queued);
    if (nextIndex == -1) return;

    final task = _tasks[nextIndex];
    task.status = DownloadStatus.analyzing;
    notifyListeners();

    // Start downloading the task in the background
    _executeDownload(task, libraryController);
    
    // Check if we can run another one
    _processQueue(libraryController);
  }

  // Actual download execution
  Future<void> _executeDownload(DownloadTask task, LibraryController libraryController) async {
    try {
      final cleanUrl = task.url;
      final isYouTube = cleanUrl.contains('youtube.com') || cleanUrl.contains('youtu.be');

      if (!isYouTube) {
        await _downloadDirectFile(task, libraryController);
        return;
      }

      // 1. Analyze video details
      Video video;
      try {
        video = await _yt.videos.get(VideoId(cleanUrl));
      } catch (e) {
        final idStr = VideoId.parseVideoId(cleanUrl) ?? '';
        if (idStr.isEmpty) throw Exception('لم نتمكن من التعرف على هذا الرابط');
        video = await _yt.videos.get(VideoId(idStr));
      }

      task.update(status: DownloadStatus.analyzing, title: video.title);
      
      // Update compatibility fields
      _currentTitle = video.title;
      _status = DownloadStatus.analyzing;
      notifyListeners();

      // Get manifest
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(appDir.path, 'downloads'));
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final uniqueId = video.id.value;

      // 2. Download Thumbnail
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

      if (task.isAudio) {
        // Audio conversion path: Get audio-only stream and convert to mp3
        final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
        final sizeStr = '${(audioStreamInfo.size.totalBytes / 1024 / 1024).toStringAsFixed(1)} MB';
        task.update(size: sizeStr);
        _downloadSize = sizeStr;

        final tempAudioPath = p.join(downloadsDir.path, '${uniqueId}_temp.webm');
        final outputAudioPath = p.join(downloadsDir.path, '$uniqueId.mp3');

        // Download stream to temp file
        task.update(status: DownloadStatus.downloading);
        _status = DownloadStatus.downloading;
        notifyListeners();

        final tempFile = File(tempAudioPath);
        final fileStream = tempFile.openWrite();
        final stream = _yt.videos.streamsClient.get(audioStreamInfo);

        double bytesDownloaded = 0.0;
        final totalBytes = audioStreamInfo.size.totalBytes;

        await for (final data in stream) {
          fileStream.add(data);
          bytesDownloaded += data.length;
          final prog = bytesDownloaded / totalBytes;
          task.update(progress: prog);
          _progress = prog;
          notifyListeners();
        }
        await fileStream.close();

        // Convert to MP3 using ffmpeg_kit
        task.update(status: DownloadStatus.converting, progress: 0.0);
        _status = DownloadStatus.converting;
        _progress = 0.0;
        notifyListeners();

        final finalMp3File = File(outputAudioPath);
        if (await finalMp3File.exists()) {
          await finalMp3File.delete();
        }

        // Apply quality encoding
        final bitrate = task.quality == '128k' ? '128k' : '320k';
        final ffmpegCmd = '-y -i "$tempAudioPath" -b:a $bitrate -vn "$outputAudioPath"';
        final session = await FFmpegKit.execute(ffmpegCmd);
        final returnCode = await session.getReturnCode();

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

          task.update(status: DownloadStatus.completed, progress: 1.0);
          _status = DownloadStatus.completed;
          _progress = 1.0;
          _moveToHistory(task);
        } else {
          final failStackTrace = await session.getFailStackTrace();
          throw Exception('فشل تحويل الملف الصوتي: $failStackTrace');
        }
      } else {
        // Video path (Muxing video & audio for 1080p, or download muxed stream directly for 720p)
        final outputVideoPath = p.join(downloadsDir.path, '$uniqueId.mp4');
        final finalFile = File(outputVideoPath);
        if (await finalFile.exists()) {
          await finalFile.delete();
        }

        if (task.quality == '1080p') {
          // Download 1080p video stream + highest audio stream, then merge them
          final videoOnlyStreams = manifest.videoOnly.where((s) => s.videoQuality == VideoQuality.high1080);
          final videoStream = videoOnlyStreams.isNotEmpty 
              ? videoOnlyStreams.first 
              : manifest.videoOnly.sortByVideoQuality().last;
          final audioStream = manifest.audioOnly.withHighestBitrate();

          final totalBytes = videoStream.size.totalBytes + audioStream.size.totalBytes;
          final sizeStr = '${(totalBytes / 1024 / 1024).toStringAsFixed(1)} MB';
          task.update(size: sizeStr);
          _downloadSize = sizeStr;

          task.update(status: DownloadStatus.downloading);
          _status = DownloadStatus.downloading;
          notifyListeners();

          final tempVideoPath = p.join(downloadsDir.path, '${uniqueId}_temp_video.mp4');
          final tempAudioPath = p.join(downloadsDir.path, '${uniqueId}_temp_audio.webm');

          // Download video segment
          double bytesDownloaded = 0.0;
          final tempVideoFile = File(tempVideoPath);
          final videoSink = tempVideoFile.openWrite();
          await for (final chunk in _yt.videos.streamsClient.get(videoStream)) {
            videoSink.add(chunk);
            bytesDownloaded += chunk.length;
            final prog = bytesDownloaded / totalBytes;
            task.update(progress: prog);
            _progress = prog;
            notifyListeners();
          }
          await videoSink.close();

          // Download audio segment
          final tempAudioFile = File(tempAudioPath);
          final audioSink = tempAudioFile.openWrite();
          await for (final chunk in _yt.videos.streamsClient.get(audioStream)) {
            audioSink.add(chunk);
            bytesDownloaded += chunk.length;
            final prog = bytesDownloaded / totalBytes;
            task.update(progress: prog);
            _progress = prog;
            notifyListeners();
          }
          await audioSink.close();

          // Mux video and audio via FFmpeg
          task.update(status: DownloadStatus.converting, progress: 0.0);
          _status = DownloadStatus.converting;
          _progress = 0.0;
          notifyListeners();

          final ffmpegCmd = '-y -i "$tempVideoPath" -i "$tempAudioPath" -c:v copy -c:a aac "$outputVideoPath"';
          final session = await FFmpegKit.execute(ffmpegCmd);
          final returnCode = await session.getReturnCode();

          if (await tempVideoFile.exists()) await tempVideoFile.delete();
          if (await tempAudioFile.exists()) await tempAudioFile.delete();

          if (ReturnCode.isSuccess(returnCode)) {
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

            task.update(status: DownloadStatus.completed, progress: 1.0);
            _status = DownloadStatus.completed;
            _progress = 1.0;
            _moveToHistory(task);
          } else {
            throw Exception('فشل دمج الصوت مع الفيديو بدقة 1080p');
          }
        } else {
          // Download 720p or lower muxed stream
          final videoStreams = manifest.muxed.where((s) => s.videoQuality == VideoQuality.high720);
          final videoStream = videoStreams.isNotEmpty
              ? videoStreams.first
              : (manifest.muxed.sortByVideoQuality().isNotEmpty 
                  ? manifest.muxed.sortByVideoQuality().last 
                  : manifest.muxed.first);

          final sizeStr = '${(videoStream.size.totalBytes / 1024 / 1024).toStringAsFixed(1)} MB';
          task.update(size: sizeStr);
          _downloadSize = sizeStr;

          task.update(status: DownloadStatus.downloading);
          _status = DownloadStatus.downloading;
          notifyListeners();

          final fileStream = finalFile.openWrite();
          double bytesDownloaded = 0.0;
          final totalBytes = videoStream.size.totalBytes;

          await for (final data in _yt.videos.streamsClient.get(videoStream)) {
            fileStream.add(data);
            bytesDownloaded += data.length;
            final prog = bytesDownloaded / totalBytes;
            task.update(progress: prog);
            _progress = prog;
            notifyListeners();
          }
          await fileStream.close();

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

          task.update(status: DownloadStatus.completed, progress: 1.0);
          _status = DownloadStatus.completed;
          _progress = 1.0;
          _moveToHistory(task);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Download error: $e');
      final errorMsg = e.toString().replaceAll('Exception:', '').trim();
      task.update(status: DownloadStatus.failed, errorMessage: errorMsg);
      _errorMessage = errorMsg;
      _status = DownloadStatus.failed;
      _moveToHistory(task);
    } finally {
      notifyListeners();
      // Process next in queue
      _processQueue(libraryController);
    }
  }

  // Direct HTTP file download fallback
  Future<void> _downloadDirectFile(
    DownloadTask task,
    LibraryController libraryController,
  ) async {
    try {
      final uri = Uri.parse(task.url);
      final filename = p.basename(uri.path);
      final extension = p.extension(uri.path);
      
      final title = filename.isNotEmpty ? filename.split('.').first : 'ملف خارجي';
      task.update(title: title);
      _currentTitle = title;
      notifyListeners();

      final response = await http.head(uri);
      int totalBytes = 0;
      if (response.headers.containsKey('content-length')) {
        totalBytes = int.tryParse(response.headers['content-length'] ?? '0') ?? 0;
      }
      final sizeStr = totalBytes > 0 ? '${(totalBytes / 1024 / 1024).toStringAsFixed(1)} MB' : 'غير معروف';
      task.update(size: sizeStr);
      _downloadSize = sizeStr;

      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(appDir.path, 'downloads'));
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
      final finalExtension = extension.isNotEmpty ? extension : (task.isAudio ? '.mp3' : '.mp4');
      final outputFilePath = p.join(downloadsDir.path, '$uniqueId$finalExtension');

      task.update(status: DownloadStatus.downloading);
      _status = DownloadStatus.downloading;
      notifyListeners();

      final client = http.Client();
      final request = http.Request('GET', uri);
      final responseStream = await client.send(request);

      if (responseStream.statusCode != 200) {
        throw Exception('رمز الحالة ${responseStream.statusCode}');
      }

      final file = File(outputFilePath);
      final fileSink = file.openWrite();
      
      int bytesDownloaded = 0;
      await for (final chunk in responseStream.stream) {
        fileSink.add(chunk);
        bytesDownloaded += chunk.length;
        if (totalBytes > 0) {
          final prog = bytesDownloaded / totalBytes;
          task.update(progress: prog);
          _progress = prog;
        } else {
          task.update(progress: -1.0);
          _progress = -1.0;
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
        thumbnailPath: 'assets/default_thumb.png',
        isAudio: task.isAudio,
        addedDate: DateTime.now(),
      );

      await libraryController.addItem(mediaItem);
      task.update(status: DownloadStatus.completed, progress: 1.0);
      _status = DownloadStatus.completed;
      _progress = 1.0;
      _moveToHistory(task);
    } catch (e) {
      if (kDebugMode) print('Direct download error: $e');
      final errorMsg = 'فشل تنزيل الرابط المباشر: $e';
      task.update(status: DownloadStatus.failed, errorMessage: errorMsg);
      _errorMessage = errorMsg;
      _status = DownloadStatus.failed;
      _moveToHistory(task);
    }
  }

  void _moveToHistory(DownloadTask task) {
    _tasks.removeWhere((t) => t.id == task.id);
    _history.insert(0, task); // Save to history
    _saveHistory();
  }

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }
}
