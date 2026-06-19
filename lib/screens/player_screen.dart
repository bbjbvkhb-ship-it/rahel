import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
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
  // Format duration to mm:ss
  String _formatDuration(Duration duration) {
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.audioHandler.player;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0b1326),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'مشغل الموسيقى',
            style: TextStyle(color: Color(0xffdae2fd), fontSize: 16, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: StreamBuilder<MediaItem?>(
              stream: widget.audioHandler.mediaItem,
              builder: (context, snapshot) {
                final mediaItem = snapshot.data;
                if (mediaItem == null) {
                  return _buildNoTrackState();
                }
                return Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Cover Art
                    _buildCoverArt(mediaItem),

                    // Song Info
                    Column(
                      children: [
                        Text(
                          mediaItem.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xffdae2fd),
                            fontSize: 22,
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
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),

                    // Progress Seekbar
                    _buildProgressBar(player),

                    // Playback Controls
                    _buildPlaybackControls(player),

                    // Volume Control
                    _buildVolumeSlider(player),
                  ],
                );
              },
            ),
          ),
        ),
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
      width: MediaQuery.of(context).size.width * 0.75,
      height: MediaQuery.of(context).size.width * 0.75,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffd0bcff).withOpacity(0.12),
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
                    activeTrackColor: const Color(0xffd0bcff),
                    inactiveTrackColor: Colors.white10,
                    thumbColor: const Color(0xffd0bcff),
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
                color: shuffleEnabled ? const Color(0xffd0bcff) : Colors.white24,
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
                child: const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xffd0bcff)),
                ),
              );
            } else if (playing != true) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xffd0bcff),
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
                decoration: const BoxDecoration(
                  color: Color(0xffd0bcff),
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
              iconColor = const Color(0xffd0bcff);
              icon = Icons.repeat_one;
            } else if (loopMode == LoopMode.all) {
              iconColor = const Color(0xffd0bcff);
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
