import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../controllers/download_controller.dart';
import '../controllers/library_controller.dart';
import '../widgets/smart_download_sheet.dart';

class BrowserScreen extends StatefulWidget {
  final Function(int) onNavigateToTab;

  const BrowserScreen({
    super.key,
    required this.onNavigateToTab,
  });

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  final TextEditingController _urlController = TextEditingController();
  InAppWebViewController? _webViewController;
  bool _showBrowser = false;
  bool _isLoading = false;
  double _loadProgress = 0.0;
  String _currentUrl = '';
  bool _showDownloadFloatingBar = false;

  final List<Map<String, dynamic>> _quickLinks = [
    {
      'name': 'YouTube',
      'url': 'https://m.youtube.com',
      'color': const Color(0xffff0000),
      'icon': Icons.play_circle_fill,
    },
    {
      'name': 'SoundCloud',
      'url': 'https://m.soundcloud.com',
      'color': const Color(0xffff5500),
      'icon': Icons.cloud,
    },
    {
      'name': 'Instagram',
      'url': 'https://www.instagram.com',
      'color': const Color(0xffe1306c),
      'icon': Icons.camera_alt,
    },
    {
      'name': 'X / Twitter',
      'url': 'https://x.com',
      'color': const Color(0xff111111),
      'icon': Icons.close,
    },
    {
      'name': 'Facebook',
      'url': 'https://m.facebook.com',
      'color': const Color(0xff1877f2),
      'icon': Icons.facebook,
    },
    {
      'name': 'TikTok',
      'url': 'https://www.tiktok.com',
      'color': const Color(0xff00f2fe),
      'icon': Icons.music_note,
    },
    {
      'name': 'Vimeo',
      'url': 'https://vimeo.com',
      'color': const Color(0xff1ab7ea),
      'icon': Icons.videocam,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboardForYouTube();
    });
  }

  Future<void> _checkClipboardForYouTube() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null) {
        final text = data.text!.trim();
        final isYouTube = text.contains('youtube.com') || text.contains('youtu.be');
        if (isYouTube && text != _currentUrl) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم العثور على رابط يوتيوب في الحافظة:\n$text', textDirection: TextDirection.rtl),
              backgroundColor: const Color(0xff171f33),
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: 'فتح وتنزيل',
                textColor: const Color(0xffd0bcff),
                onPressed: () {
                  _urlController.text = text;
                  _loadUrl(text);
                  _showSmartDownloadSheet(text);
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error checking clipboard: $e');
    }
  }

  void _showSmartDownloadSheet(String url) {
    if (url.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SmartDownloadSheet(url: url),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // Load URL
  void _loadUrl(String url) {
    if (url.trim().isEmpty) return;

    var targetUrl = url.trim();
    if (!targetUrl.startsWith('http://') && !targetUrl.startsWith('https://')) {
      // Check if it looks like a query or a website domain
      if (targetUrl.contains('.') && !targetUrl.contains(' ')) {
        targetUrl = 'https://$targetUrl';
      } else {
        // Search google
        targetUrl = 'https://www.google.com/search?q=${Uri.encodeComponent(targetUrl)}';
      }
    }

    setState(() {
      _showBrowser = true;
      _currentUrl = targetUrl;
    });

    if (_webViewController != null) {
      _webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(targetUrl)));
    }
  }

  // Paste from clipboard
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      setState(() {
        _urlController.text = data.text!;
      });
      _loadUrl(data.text!);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الحافظة فارغة حالياً', textDirection: TextDirection.rtl),
            backgroundColor: Color(0xff171f33),
          ),
        );
      }
    }
  }

  // Check if current URL is downloadable (YouTube Video)
  void _checkDownloadAvailability(String url) {
    final isYoutubeVideo = url.contains('youtube.com/watch') ||
        url.contains('youtu.be/') ||
        url.contains('youtube.com/shorts/');
    setState(() {
      _showDownloadFloatingBar = isYoutubeVideo;
    });
  }

  // Trigger download in DownloadController (Redirected to Smart Download Sheet)
  void _triggerDownload(bool isAudio) {
    _showSmartDownloadSheet(_currentUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0b1326),
        appBar: AppBar(
          backgroundColor: const Color(0xff0b1326),
          elevation: 0,
          title: const Text(
            'المتصفح الذكي',
            style: TextStyle(
              color: Color(0xffd0bcff),
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          leading: _showBrowser
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xffd0bcff)),
                  onPressed: () {
                    setState(() {
                      _showBrowser = false;
                      _urlController.clear();
                      _currentUrl = '';
                      _showDownloadFloatingBar = false;
                    });
                  },
                )
              : null,
          actions: _showBrowser
              ? [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xffcbc3d7)),
                    onPressed: () {
                      _webViewController?.reload();
                    },
                  )
                ]
              : null,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Loading Progress Bar
              if (_isLoading && _showBrowser)
                LinearProgressIndicator(
                  value: _loadProgress,
                  minHeight: 3,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xffd0bcff)),
                ),

              // Address and search input bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xff171f33),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _showBrowser ? const Color(0xffd0bcff).withOpacity(0.3) : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      const Icon(Icons.lock_outline, color: Color(0xffcbc3d7), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          style: const TextStyle(color: Color(0xffdae2fd), fontSize: 14),
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            hintText: 'أدخل الرابط أو ابحث هنا...',
                            hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onSubmitted: (val) => _loadUrl(val),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.paste, color: Color(0xff89ceff), size: 20),
                        tooltip: 'لصق الرابط',
                        onPressed: _pasteFromClipboard,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 6, right: 2),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xffd0bcff),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _loadUrl(_urlController.text),
                          child: const Text(
                            'اذهب',
                            style: TextStyle(color: Color(0xff0b1326), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Main viewport
              Expanded(
                child: _showBrowser
                    ? Stack(
                        children: [
                          InAppWebView(
                            initialUrlRequest: URLRequest(url: WebUri(_currentUrl)),
                            initialSettings: InAppWebViewSettings(
                              mediaPlaybackRequiresUserGesture: false,
                              allowsInlineMediaPlayback: true,
                              javaScriptEnabled: true,
                              javaScriptCanOpenWindowsAutomatically: true,
                              allowsBackForwardNavigationGestures: true,
                              sharedCookiesEnabled: true,
                              isFraudulentWebsiteWarningEnabled: false,
                              userAgent:
                                  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
                                  'AppleWebKit/605.1.15 (KHTML, like Gecko) '
                                  'Version/17.0 Mobile/15E148 Safari/604.1',
                            ),
                            onWebViewCreated: (controller) {
                              _webViewController = controller;
                            },
                            shouldOverrideUrlLoading: (controller, navigationAction) async {
                              // Allow all navigation
                              return NavigationActionPolicy.ALLOW;
                            },
                            onUpdateVisitedHistory: (controller, url, isReload) {
                              // Catches YouTube SPA navigation (no full page reload)
                              if (url != null) {
                                setState(() {
                                  _currentUrl = url.toString();
                                  _urlController.text = _currentUrl;
                                });
                                _checkDownloadAvailability(_currentUrl);
                              }
                            },
                            onLoadStart: (controller, url) {
                              if (url != null) {
                                setState(() {
                                  _isLoading = true;
                                  _currentUrl = url.toString();
                                  _urlController.text = _currentUrl;
                                });
                                _checkDownloadAvailability(_currentUrl);
                              }
                            },
                            onLoadStop: (controller, url) async {
                              if (url != null) {
                                setState(() {
                                  _isLoading = false;
                                  _currentUrl = url.toString();
                                  _urlController.text = _currentUrl;
                                });
                                _checkDownloadAvailability(_currentUrl);
                              }
                            },
                            onProgressChanged: (controller, progress) {
                              setState(() {
                                _loadProgress = progress / 100;
                              });
                            },
                          ),
                          
                          // Web navigation controls overlay (Bottom-left/right)
                          Positioned(
                            bottom: _showDownloadFloatingBar ? 90 : 16,
                            left: 16,
                            right: 16,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Navigation Back/Forward
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xff171f33).withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white10, width: 0.5),
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.arrow_back_ios, color: Color(0xffcbc3d7), size: 18),
                                        onPressed: () async {
                                          if (await _webViewController?.canGoBack() ?? false) {
                                            _webViewController?.goBack();
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.arrow_forward_ios, color: Color(0xffcbc3d7), size: 18),
                                        onPressed: () async {
                                          if (await _webViewController?.canGoForward() ?? false) {
                                            _webViewController?.goForward();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                // Home shortcut to return dashboard
                                FloatingActionButton.small(
                                  backgroundColor: const Color(0xff171f33).withOpacity(0.9),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: const BorderSide(color: Colors.white10, width: 0.5),
                                  ),
                                  child: const Icon(Icons.home, color: Color(0xffd0bcff)),
                                  onPressed: () {
                                    setState(() {
                                      _showBrowser = false;
                                      _urlController.clear();
                                      _currentUrl = '';
                                      _showDownloadFloatingBar = false;
                                    });
                                  },
                                )
                              ],
                            ),
                          ),

                          // Floating Download Action Bar
                          if (_showDownloadFloatingBar)
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xff171f33).withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xffd0bcff).withOpacity(0.3), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xffd0bcff).withOpacity(0.15),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.offline_pin, color: Color(0xffd0bcff)),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'تم اكتشاف فيديو يوتيوب!',
                                        style: TextStyle(color: Color(0xffdae2fd), fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xffd0bcff),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      icon: const Icon(Icons.download_done, size: 16, color: Color(0xff0b1326)),
                                      label: const Text('تنزيل متميز', style: TextStyle(color: Color(0xff0b1326), fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: () => _showSmartDownloadSheet(_currentUrl),
                                    )
                                  ],
                                ),
                              ),
                            ),
                        ],
                      )
                    : _buildDashboard(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            'روابط سريعة',
            style: TextStyle(
              color: Color(0xffdae2fd),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Grid layout for quick links
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: _quickLinks.length,
            itemBuilder: (context, index) {
              final link = _quickLinks[index];
              return InkWell(
                onTap: () => _loadUrl(link['url']),
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xff171f33),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                      ),
                      child: Center(
                        child: Icon(
                          link['icon'],
                          color: link['color'],
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      link['name'],
                      style: const TextStyle(
                        color: Color(0xffcbc3d7),
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          // Helpful Instructions Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xff171f33).withOpacity(0.4),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.04), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xffd0bcff).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.offline_pin_outlined, color: Color(0xffd0bcff), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'التحميل المباشر والمستقل',
                      style: TextStyle(
                        color: Color(0xffdae2fd),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '1. افتح يوتيوب أو أي موقع تواصل اجتماعي من الروابط أعلاه.\n'
                  '2. تصفح المقطع الذي تود تنزيله.\n'
                  '3. ستلاحظ ظهور لوحة تحميل ذكية بالأسفل فوراً.\n'
                  '4. اضغط على "صوت MP3" أو "فيديو MP4" ليقوم التطبيق بالتحميل والتحويل محلياً على جهازك 100% دون خوادم خارجية.',
                  style: TextStyle(
                    color: Color(0xffcbc3d7),
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
