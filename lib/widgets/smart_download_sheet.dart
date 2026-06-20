import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import '../controllers/download_controller.dart';
import '../controllers/library_controller.dart';
import '../services/youtube_helper.dart';

class SmartDownloadSheet extends StatefulWidget {
  final String url;

  const SmartDownloadSheet({
    super.key,
    required this.url,
  });

  @override
  State<SmartDownloadSheet> createState() => _SmartDownloadSheetState();
}

class _SmartDownloadSheetState extends State<SmartDownloadSheet> {
  final _yt = YoutubeExplode();
  final _previewPlayer = AudioPlayer();
  
  bool _isLoading = true;
  String _errorMessage = '';
  
  Video? _video;
  bool _isAudio = true;
  String _quality = '320k'; // Default high quality audio
  
  bool _isPreviewPlaying = false;
  bool _isPreviewLoading = false;

  @override
  void initState() {
    super.initState();
    _analyzeVideo();
  }

  Future<void> _analyzeVideo() async {
    try {
      final cleanUrl = widget.url.trim();
      final videoId = extractYoutubeVideoId(cleanUrl);
      if (videoId == null) throw Exception('لم نتمكن من التعرف على الرابط');
      
      final video = await retryYoutubeCall(() => _yt.videos.get(VideoId(videoId)));

      if (mounted) {
        setState(() {
          _video = video;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'فشل تحليل الرابط. تأكد من صحة رابط يوتيوب.';
          _isLoading = false;
        });
      }
    }
  }



  Future<void> _togglePreview() async {
    if (_video == null) return;

    if (_isPreviewPlaying) {
      await _previewPlayer.pause();
      if (mounted) {
        setState(() {
          _isPreviewPlaying = false;
        });
      }
    } else {
      setState(() {
        _isPreviewLoading = true;
      });

      try {
        if (_previewPlayer.duration == null) {
          final manifest = await retryYoutubeCall(() => _yt.videos.streamsClient.getManifest(_video!.id));
          final audioStream = manifest.audioOnly.withHighestBitrate();
          await _previewPlayer.setUrl(audioStream.url.toString());
        }

        
        _previewPlayer.play();
        _previewPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            if (mounted) {
              setState(() {
                _isPreviewPlaying = false;
              });
            }
          }
        });

        if (mounted) {
          setState(() {
            _isPreviewLoading = false;
            _isPreviewPlaying = true;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isPreviewLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل تشغيل المعاينة الصوتیة', textDirection: TextDirection.rtl),
              backgroundColor: Color(0xffffb2b7),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _yt.close();
    _previewPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '00:00';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final downloadController = Provider.of<DownloadController>(context, listen: false);
    final libraryController = Provider.of<LibraryController>(context, listen: false);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xff171f33),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _isLoading
            ? _buildLoadingState()
            : _errorMessage.isNotEmpty
                ? _buildErrorState()
                : _buildMetadataState(downloadController, libraryController),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const SizedBox(
      height: 250,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xffd0bcff)),
            SizedBox(height: 16),
            Text('جاري جلب تفاصيل الرابط وبحث الجودة...', style: TextStyle(color: Color(0xffcbc3d7))),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return SizedBox(
      height: 220,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Color(0xfffb7185), size: 48),
          const SizedBox(height: 16),
          Text(_errorMessage, style: const TextStyle(color: Color(0xffdae2fd), fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff1d2438)),
            child: const Text('إغلاق', style: TextStyle(color: Color(0xffdae2fd))),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataState(DownloadController downloadController, LibraryController libraryController) {
    final video = _video!;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Video Card Details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  video.thumbnails.mediumResUrl,
                  width: 120,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.white10, width: 120, height: 70),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xffdae2fd), fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${video.author} • ${_formatDuration(video.duration)}',
                      style: const TextStyle(color: Color(0xffcbc3d7), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Preview Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xff0b1326),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.headphones, color: Color(0xffd0bcff), size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'معاينة الملف الصوتي قبل التحميل',
                    style: TextStyle(color: Color(0xffdae2fd), fontSize: 13),
                  ),
                ),
                if (_isPreviewLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Color(0xffd0bcff), strokeWidth: 2),
                  )
                else
                  IconButton(
                    onPressed: _togglePreview,
                    icon: Icon(
                      _isPreviewPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      color: const Color(0xffd0bcff),
                      size: 28,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Format Toggle
          const Text('صيغة الملف', style: TextStyle(color: Color(0xffcbc3d7), fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('صوت (MP3)', style: TextStyle(fontSize: 13))),
                  selected: _isAudio,
                  selectedColor: const Color(0xffd0bcff).withOpacity(0.2),
                  backgroundColor: const Color(0xff0b1326),
                  labelStyle: TextStyle(color: _isAudio ? const Color(0xffd0bcff) : const Color(0xffcbc3d7)),
                  onSelected: (val) {
                    setState(() {
                      _isAudio = true;
                      _quality = '320k'; // Reset default quality
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('فيديو (MP4)', style: TextStyle(fontSize: 13))),
                  selected: !_isAudio,
                  selectedColor: const Color(0xffd0bcff).withOpacity(0.2),
                  backgroundColor: const Color(0xff0b1326),
                  labelStyle: TextStyle(color: !_isAudio ? const Color(0xffd0bcff) : const Color(0xffcbc3d7)),
                  onSelected: (val) {
                    setState(() {
                      _isAudio = false;
                      _quality = '720p'; // Reset default quality
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quality Selector
          const Text('دقة الجودة', style: TextStyle(color: Color(0xffcbc3d7), fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: _isAudio
                ? [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('عالية (320kbps)')),
                        selected: _quality == '320k',
                        selectedColor: const Color(0xff89ceff).withOpacity(0.2),
                        backgroundColor: const Color(0xff0b1326),
                        labelStyle: TextStyle(color: _quality == '320k' ? const Color(0xff89ceff) : const Color(0xffcbc3d7)),
                        onSelected: (val) => setState(() => _quality = '320k'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('قياسية (128kbps)')),
                        selected: _quality == '128k',
                        selectedColor: const Color(0xff89ceff).withOpacity(0.2),
                        backgroundColor: const Color(0xff0b1326),
                        labelStyle: TextStyle(color: _quality == '128k' ? const Color(0xff89ceff) : const Color(0xffcbc3d7)),
                        onSelected: (val) => setState(() => _quality = '128k'),
                      ),
                    ),
                  ]
                : [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('عالية جداً (1080p)')),
                        selected: _quality == '1080p',
                        selectedColor: const Color(0xffffb2b7).withOpacity(0.2),
                        backgroundColor: const Color(0xff0b1326),
                        labelStyle: TextStyle(color: _quality == '1080p' ? const Color(0xffffb2b7) : const Color(0xffcbc3d7)),
                        onSelected: (val) => setState(() => _quality = '1080p'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('عالية (720p)')),
                        selected: _quality == '720p',
                        selectedColor: const Color(0xffffb2b7).withOpacity(0.2),
                        backgroundColor: const Color(0xff0b1326),
                        labelStyle: TextStyle(color: _quality == '720p' ? const Color(0xffffb2b7) : const Color(0xffcbc3d7)),
                        onSelected: (val) => setState(() => _quality = '720p'),
                      ),
                    ),
                  ],
          ),
          const SizedBox(height: 28),

          // Download Trigger Button
          ElevatedButton.icon(
            onPressed: () {
              downloadController.queueDownload(
                widget.url,
                _isAudio,
                _quality,
                libraryController,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تمت إضافة "${video.title}" إلى قائمة التنزيلات!', textDirection: TextDirection.rtl),
                  backgroundColor: const Color(0xffd0bcff),
                ),
              );
            },
            icon: const Icon(Icons.download, color: Color(0xff0b1326)),
            label: const Text(
              'بدء التنزيل الآن',
              style: TextStyle(color: Color(0xff0b1326), fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffd0bcff),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
