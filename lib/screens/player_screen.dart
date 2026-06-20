import 'dart:io';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';
import '../controllers/player_controller.dart';
import '../services/audio_handler.dart';

class PlayerScreen extends StatefulWidget {
  final MyAudioHandler audioHandler;

  const PlayerScreen({
    super.key,
    required this.audioHandler,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  Color _backgroundColor = const Color(0xff0b1326);
  Color _accentColor = const Color(0xffd0bcff);
  String? _lastExtractedId;

  // Format duration to mm:ss
  String _formatDuration(Duration duration) {
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatTimerDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _updatePalette(MediaItem mediaItem) async {
    if (_lastExtractedId == mediaItem.id) return;
    _lastExtractedId = mediaItem.id;

    final artUri = mediaItem.artUri;
    if (artUri != null && artUri.scheme == 'file') {
      final file = File(artUri.toFilePath());
      if (await file.exists()) {
        try {
          final palette = await PaletteGenerator.fromImageProvider(
            FileImage(file),
            maximumColorCount: 16,
          );
          if (mounted) {
            setState(() {
              _backgroundColor = palette.darkMutedColor?.color ?? palette.dominantColor?.color ?? const Color(0xff0b1326);
              _accentColor = palette.lightVibrantColor?.color ?? palette.dominantColor?.color ?? const Color(0xffd0bcff);
            });
          }
          return;
        } catch (e) {
          if (kDebugMode) print('Error extracting palette: $e');
        }
      }
    }

    if (mounted) {
      setState(() {
        _backgroundColor = const Color(0xff0b1326);
        _accentColor = const Color(0xffd0bcff);
      });
    }
  }

  void _showSleepTimerSheet(BuildContext context, PlayerController playerController) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff171f33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'مؤقت النوم',
                style: TextStyle(color: Color(0xffdae2fd), fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'سيتم إيقاف تشغيل الموسيقى تلقائياً بعد مرور الوقت المحدد.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xffcbc3d7), fontSize: 13),
              ),
              const Divider(color: Colors.white10, height: 24),
              if (playerController.isTimerActive) ...[
                ListTile(
                  leading: const Icon(Icons.timer_off, color: Color(0xfffb7185)),
                  title: const Text('إيقاف المؤقت الحالي', style: TextStyle(color: Color(0xfffb7185))),
                  subtitle: Text(
                    'الوقت المتبقي: ${_formatTimerDuration(playerController.remainingTime ?? Duration.zero)}',
                    style: const TextStyle(color: Color(0xffcbc3d7)),
                  ),
                  onTap: () {
                    playerController.cancelSleepTimer();
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [5, 10, 15, 30, 45, 60].map((minutes) {
                  return InkWell(
                    onTap: () {
                      playerController.startSleepTimer(Duration(minutes: minutes));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم ضبط مؤقت النوم بعد $minutes دقيقة', textDirection: TextDirection.rtl),
                          backgroundColor: const Color(0xffd0bcff),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 80,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xff0b1326),
                        border: Border.all(color: const Color(0xffd0bcff).withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer, color: Color(0xffd0bcff), size: 20),
                          const SizedBox(height: 6),
                          Text(
                            '$minutes دقيقة',
                            style: const TextStyle(color: Color(0xffdae2fd), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showQueueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff171f33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<List<MediaItem>>(
          stream: widget.audioHandler.queue,
          builder: (context, queueSnapshot) {
            final queue = queueSnapshot.data ?? [];
            return StreamBuilder<MediaItem?>(
              stream: widget.audioHandler.mediaItem,
              builder: (context, mediaSnapshot) {
                final currentItem = mediaSnapshot.data;
                return Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'قائمة التشغيل الحالية',
                        style: TextStyle(color: Color(0xffdae2fd), fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (queue.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text('لا توجد عناصر في قائمة التشغيل', style: TextStyle(color: Color(0xffcbc3d7))),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: queue.length,
                            itemBuilder: (context, index) {
                              final item = queue[index];
                              final isCurrent = currentItem?.id == item.id;
                              return ListTile(
                                leading: Icon(
                                  isCurrent ? Icons.play_circle_fill : Icons.music_note,
                                  color: isCurrent ? const Color(0xffd0bcff) : const Color(0xffcbc3d7),
                                ),
                                title: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isCurrent ? const Color(0xffd0bcff) : const Color(0xffdae2fd),
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Text(
                                  item.artist ?? 'غير معروف',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xffcbc3d7), fontSize: 11),
                                ),
                                onTap: () {
                                  widget.audioHandler.player.seek(Duration.zero, index: index);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBlurBackground(MediaItem? mediaItem) {
    final artUri = mediaItem?.artUri;
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: _backgroundColor,
        ),
        child: artUri != null && artUri.scheme == 'file' && File(artUri.toFilePath()).existsSync()
            ? ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 45.0, sigmaY: 45.0),
                child: Image.file(
                  File(artUri.toFilePath()),
                  fit: BoxFit.cover,
                  color: Colors.black.withOpacity(0.3),
                  colorBlendMode: BlendMode.dstATop,
                ),
              )
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xff171f33), Color(0xff0b1326)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.audioHandler.player;
    final playerController = Provider.of<PlayerController>(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: StreamBuilder<MediaItem?>(
        stream: widget.audioHandler.mediaItem,
        builder: (context, snapshot) {
          final mediaItem = snapshot.data;
          if (mediaItem != null) {
            _updatePalette(mediaItem);
          }

          return Scaffold(
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text(
                'مشغل الموسيقى',
                style: TextStyle(color: Color(0xffdae2fd), fontSize: 16, fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              leading: IconButton(
                icon: Icon(
                  playerController.isTimerActive ? Icons.timer : Icons.timer_outlined,
                  color: playerController.isTimerActive ? const Color(0xffd0bcff) : const Color(0xffcbc3d7),
                ),
                onPressed: () => _showSleepTimerSheet(context, playerController),
              ),
              actions: [
                if (playerController.isTimerActive)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        _formatTimerDuration(playerController.remainingTime ?? Duration.zero),
                        style: const TextStyle(color: Color(0xffd0bcff), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.queue_music, color: Color(0xffcbc3d7)),
                  onPressed: () => _showQueueSheet(context),
                )
              ],
            ),
            body: Stack(
              children: [
                _buildBlurBackground(mediaItem),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: mediaItem == null
                        ? _buildNoTrackState()
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Cover Art
                              _buildCoverArt(mediaItem),

                              // Song Info & Visualizer
                              Column(
                                children: [
                                  Text(
                                    mediaItem.title,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xffdae2fd),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    mediaItem.artist ?? 'غير معروف',
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xffcbc3d7),
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  StreamBuilder<bool>(
                                    stream: player.playingStream,
                                    builder: (context, snapshot) {
                                      final isPlaying = snapshot.data ?? false;
                                      return AnimatedVisualizer(
                                        isPlaying: isPlaying,
                                        color: _accentColor,
                                      );
                                    },
                                  )
                                ],
                              ),

                              // Progress Seekbar
                              _buildProgressBar(player),

                              // Playback Controls
                              _buildPlaybackControls(player),

                              // Volume Control
                              _buildVolumeSlider(player),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoTrackState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff171f33), Color(0xff0b1326)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
            ),
            child: const Center(
              child: Icon(Icons.music_note_sharp, color: Color(0xffd0bcff), size: 64),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'لا يوجد ملف قيد التشغيل',
            style: TextStyle(color: Color(0xffcbc3d7), fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'اذهب للمكتبة لتشغيل المسار الصوتي المفضل لديك.',
            style: TextStyle(color: Colors.white24, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCoverArt(MediaItem mediaItem) {
    final artUri = mediaItem.artUri;
    return Container(
      width: MediaQuery.of(context).size.width * 0.70,
      height: MediaQuery.of(context).size.width * 0.70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: 2,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: artUri != null && artUri.scheme == 'file' && File(artUri.toFilePath()).existsSync()
            ? Image.file(
                File(artUri.toFilePath()),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallbackCover(),
              )
            : _buildFallbackCover(),
      ),
    );
  }

  Widget _buildFallbackCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff222a3d), Color(0xff131b2e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.music_note, color: Color(0xffd0bcff), size: 80),
      ),
    );
  }

  Widget _buildProgressBar(AudioPlayer player) {
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (context, snapshot) {
        final duration = snapshot.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, snapshot) {
            var position = snapshot.data ?? Duration.zero;
            if (position > duration) {
              position = duration;
            }
            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: _accentColor,
                    inactiveTrackColor: Colors.white10,
                    thumbColor: _accentColor,
                  ),
                  child: Slider(
                    value: position.inMilliseconds.toDouble(),
                    min: 0.0,
                    max: duration.inMilliseconds.toDouble(),
                    onChanged: (value) {
                      player.seek(Duration(milliseconds: value.round()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: const TextStyle(color: Color(0xffcbc3d7), fontSize: 11),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: const TextStyle(color: Colors.white24, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPlaybackControls(AudioPlayer player) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Shuffle Button
        StreamBuilder<bool>(
          stream: player.shuffleModeEnabledStream,
          builder: (context, snapshot) {
            final shuffleEnabled = snapshot.data ?? false;
            return IconButton(
              icon: Icon(
                Icons.shuffle,
                color: shuffleEnabled ? _accentColor : Colors.white24,
              ),
              onPressed: () async {
                await widget.audioHandler.setShuffleMode(
                  shuffleEnabled ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all,
                );
              },
            );
          },
        ),

        // Skip Previous
        IconButton(
          iconSize: 32,
          icon: const Icon(Icons.skip_next, color: Color(0xffdae2fd)), // Mirrored RTL
          onPressed: () {
            widget.audioHandler.skipToPrevious();
          },
        ),

        // Play/Pause
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final processingState = playerState?.processingState;
            final playing = playerState?.playing;

            if (processingState == ProcessingState.loading ||
                processingState == ProcessingState.buffering) {
              return Container(
                margin: const EdgeInsets.all(8),
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                ),
              );
            } else if (playing != true) {
              return Container(
                decoration: BoxDecoration(
                  color: _accentColor,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  iconSize: 42,
                  icon: const Icon(Icons.play_arrow, color: Color(0xff0b1326)),
                  onPressed: widget.audioHandler.play,
                ),
              );
            } else {
              return Container(
                decoration: BoxDecoration(
                  color: _accentColor,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  iconSize: 42,
                  icon: const Icon(Icons.pause, color: Color(0xff0b1326)),
                  onPressed: widget.audioHandler.pause,
                ),
              );
            }
          },
        ),

        // Skip Next
        IconButton(
          iconSize: 32,
          icon: const Icon(Icons.skip_previous, color: Color(0xffdae2fd)), // Mirrored RTL
          onPressed: () {
            widget.audioHandler.skipToNext();
          },
        ),

        // Repeat Button
        StreamBuilder<LoopMode>(
          stream: player.loopModeStream,
          builder: (context, snapshot) {
            final loopMode = snapshot.data ?? LoopMode.off;
            Color iconColor = Colors.white24;
            IconData icon = Icons.repeat;

            if (loopMode == LoopMode.one) {
              iconColor = _accentColor;
              icon = Icons.repeat_one;
            } else if (loopMode == LoopMode.all) {
              iconColor = _accentColor;
            }

            return IconButton(
              icon: Icon(icon, color: iconColor),
              onPressed: () async {
                AudioServiceRepeatMode newMode;
                if (loopMode == LoopMode.off) {
                  newMode = AudioServiceRepeatMode.all;
                } else if (loopMode == LoopMode.all) {
                  newMode = AudioServiceRepeatMode.one;
                } else {
                  newMode = AudioServiceRepeatMode.none;
                }
                await widget.audioHandler.setRepeatMode(newMode);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildVolumeSlider(AudioPlayer player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.volume_mute, color: Colors.white24, size: 16),
          Expanded(
            child: StreamBuilder<double>(
              stream: player.volumeStream,
              builder: (context, snapshot) {
                final volume = snapshot.data ?? 1.0;
                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                    activeTrackColor: Colors.white24,
                    inactiveTrackColor: Colors.white10,
                    thumbColor: Colors.white24,
                  ),
                  child: Slider(
                    value: volume,
                    onChanged: (val) {
                      player.setVolume(val);
                    },
                  ),
                );
              },
            ),
          ),
          const Icon(Icons.volume_up, color: Colors.white24, size: 16),
        ],
      ),
    );
  }
}

class AnimatedVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;

  const AnimatedVisualizer({
    super.key,
    required this.isPlaying,
    required this.color,
  });

  @override
  State<AnimatedVisualizer> createState() => _AnimatedVisualizerState();
}

class _AnimatedVisualizerState extends State<AnimatedVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _multipliers = [1.2, 0.8, 1.5, 0.9, 1.3, 0.7, 1.1, 1.4, 0.6, 1.0];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(10, (index) {
            double value = _controller.value;
            double height = 5 + (value * 25 * _multipliers[index]);
            if (!widget.isPlaying) {
              height = 4.0;
            }
            return Container(
              width: 3.5,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.7),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
