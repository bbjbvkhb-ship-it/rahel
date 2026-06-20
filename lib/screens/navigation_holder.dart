import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import '../services/audio_handler.dart';
import 'library_screen.dart';
import 'playlist_screen.dart';
import 'browser_screen.dart';
import 'player_screen.dart';
import 'downloads_screen.dart';
import 'settings_screen.dart';

class NavigationHolder extends StatefulWidget {
  final MyAudioHandler audioHandler;

  const NavigationHolder({
    super.key,
    required this.audioHandler,
  });

  @override
  State<NavigationHolder> createState() => _NavigationHolderState();
}

class _NavigationHolderState extends State<NavigationHolder> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      LibraryScreen(
        audioHandler: widget.audioHandler,
        onNavigateToPlayer: (_) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerScreen(audioHandler: widget.audioHandler),
            ),
          );
        },
      ),
      PlaylistScreen(
        audioHandler: widget.audioHandler,
        onNavigateToPlayer: (_) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerScreen(audioHandler: widget.audioHandler),
            ),
          );
        },
      ),
      BrowserScreen(
        onNavigateToTab: (idx) {
          setState(() {
            _currentIndex = idx;
          });
        },
      ),
      const DownloadsScreen(),
      SettingsScreen(
        onNavigateToBrowserUrl: (idx, url) {
          setState(() {
            _currentIndex = idx;
          });
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0b1326),
      body: Stack(
        children: [
          // Screen contents
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // Floating Mini-Player positioned just above the bottom navigation bar
          Positioned(
            left: 12,
            right: 12,
            bottom: kBottomNavigationBarHeight + 20,
            child: _buildMiniPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildMiniPlayer() {
    return StreamBuilder<MediaItem?>(
      stream: widget.audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return const SizedBox.shrink();

        return StreamBuilder<PlaybackState>(
          stream: widget.audioHandler.playbackState,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final playing = state?.playing ?? false;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlayerScreen(audioHandler: widget.audioHandler),
                  ),
                );
              },
              child: Dismissible(
                key: const Key('mini-player-dismiss'),
                direction: DismissDirection.down,
                onDismissed: (_) {
                  widget.audioHandler.stop();
                },
                child: Container(
                  height: 58,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xff1e293b).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 42,
                          height: 42,
                          color: const Color(0xff0b1326),
                          child: mediaItem.artUri != null &&
                                  mediaItem.artUri!.scheme == 'file' &&
                                  File(mediaItem.artUri!.toFilePath()).existsSync()
                              ? Image.file(
                                  File(mediaItem.artUri!.toFilePath()),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildMiniFallbackCover(),
                                )
                              : _buildMiniFallbackCover(),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Track details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              mediaItem.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xffdae2fd),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              playing ? 'جاري التشغيل...' : 'مؤقت',
                              style: const TextStyle(
                                color: Color(0xffcbc3d7),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Player Mini Controls (Skip Prev, Play/Pause, Skip Next)
                      Row(
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.skip_next, color: Color(0xffdae2fd), size: 22), // Mirrored RTL next
                            onPressed: () => widget.audioHandler.skipToPrevious(),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              playing ? Icons.pause : Icons.play_arrow,
                              color: const Color(0xffd0bcff),
                              size: 26,
                            ),
                            onPressed: () {
                              if (playing) {
                                widget.audioHandler.pause();
                              } else {
                                widget.audioHandler.play();
                              }
                            },
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.skip_previous, color: Color(0xffdae2fd), size: 22), // Mirrored RTL prev
                            onPressed: () => widget.audioHandler.skipToNext(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMiniFallbackCover() {
    return const Center(
      child: Icon(Icons.music_note, color: Color(0xffd0bcff), size: 20),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff0b1326),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 0.5,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xff0b1326),
        selectedItemColor: const Color(0xffd0bcff),
        unselectedItemColor: const Color(0xffcbc3d7).withOpacity(0.6),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music_outlined),
            activeIcon: Icon(Icons.library_music),
            label: 'المكتبة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.playlist_play_outlined),
            activeIcon: Icon(Icons.playlist_play),
            label: 'قوائم التشغيل',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'المتصفح',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.download_for_offline_outlined),
            activeIcon: Icon(Icons.download_for_offline),
            label: 'التنزيلات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}
