import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/library_controller.dart';

class SettingsScreen extends StatefulWidget {
  final Function(int, String) onNavigateToBrowserUrl;

  const SettingsScreen({
    super.key,
    required this.onNavigateToBrowserUrl,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _downloadQuality = '320kbps';
  double _totalSizeMb = 0.0;
  bool _isCalculating = true;

  @override
  void initState() {
    super.initState();
    _calculateStorageUsage();
  }

  // Calculate actual storage size of downloads folder
  Future<void> _calculateStorageUsage() async {
    setState(() {
      _isCalculating = true;
    });

    try {
      final libraryController = Provider.of<LibraryController>(context, listen: false);
      double sizeBytes = 0;
      for (final item in libraryController.items) {
        final file = await libraryController.getMediaFile(item);
        if (await file.exists()) {
          sizeBytes += await file.length();
        }
        final thumb = await libraryController.getThumbnailFile(item);
        if (await thumb.exists() && !item.thumbnailPath.startsWith('assets/')) {
          sizeBytes += await thumb.length();
        }
      }

      setState(() {
        _totalSizeMb = sizeBytes / (1024 * 1024);
        _isCalculating = false;
      });
    } catch (e) {
      setState(() {
        _totalSizeMb = 0.0;
        _isCalculating = false;
      });
    }
  }

  // Support click handler: opens Whatsapp
  void _openWhatsAppSupport() {
    // Standard WhatsApp chat link
    const whatsappUrl = 'https://wa.me/9647700000000'; // Mock/Standard support number
    widget.onNavigateToBrowserUrl(1, whatsappUrl); // Navigate to browser tab and load WhatsApp
  }

  @override
  Widget build(BuildContext context) {
    final libraryController = Provider.of<LibraryController>(context);

    // Calculate percentage based on 1000MB limit for visual feedback
    final double maxMockStorageMb = 1000.0;
    final double pct = (_totalSizeMb / maxMockStorageMb).clamp(0.0, 1.0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0b1326),
        appBar: AppBar(
          backgroundColor: const Color(0xff0b1326),
          elevation: 0,
          title: const Text(
            'الإعدادات',
            style: TextStyle(
              color: Color(0xffd0bcff),
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xffcbc3d7)),
              onPressed: _calculateStorageUsage,
            )
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xff171f33).withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xffd0bcff).withOpacity(0.1),
                          border: Border.all(color: const Color(0xffd0bcff), width: 1.5),
                        ),
                        child: const Center(
                          child: Icon(Icons.person, color: Color(0xffd0bcff), size: 32),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'أحمد محمد',
                              style: TextStyle(
                                color: Color(0xffdae2fd),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'عضو مميز (Premium)',
                              style: TextStyle(
                                color: const Color(0xffcbc3d7).withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.verified, color: Color(0xffd0bcff), size: 24),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Storage Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xff171f33).withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'المساحة المستهلكة',
                            style: TextStyle(color: Color(0xffcbc3d7), fontSize: 13),
                          ),
                          Text(
                            _isCalculating
                                ? 'جاري الحساب...'
                                : '${(_totalSizeMb).toStringAsFixed(1)} ميجابايت',
                            style: const TextStyle(color: Color(0xffd0bcff), fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _isCalculating ? null : pct,
                          minHeight: 6,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xffd0bcff)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isCalculating
                            ? 'جاري فحص الملفات المحملة...'
                            : 'تم تحميل ${libraryController.items.length} ملفات.',
                        style: const TextStyle(color: Colors.white24, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Settings Group 1: Downloads
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    'التحميل والتحويل',
                    style: TextStyle(color: Color(0xffcbc3d7), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xff171f33).withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.5),
                  ),
                  child: Column(
                    children: [
                      // Quality Setting Dialog
                      ListTile(
                        leading: const Icon(Icons.high_quality, color: Color(0xffd0bcff)),
                        title: const Text('جودة التحويل الصوتي', style: TextStyle(color: Color(0xffdae2fd), fontSize: 14)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_downloadQuality, style: const TextStyle(color: Color(0xffcbc3d7), fontSize: 13)),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_back_ios, color: Colors.white24, size: 14), // RTL back arrow is chevron
                          ],
                        ),
                        onTap: _showQualityPicker,
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      // Mock App Theme Settings
                      ListTile(
                        leading: const Icon(Icons.dark_mode, color: Color(0xff89ceff)),
                        title: const Text('مظهر التطبيق', style: TextStyle(color: Color(0xffdae2fd), fontSize: 14)),
                        trailing: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('داكن', style: TextStyle(color: Color(0xffcbc3d7), fontSize: 13)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_back_ios, color: Colors.white24, size: 14),
                          ],
                        ),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('الوضع الداكن مفعل افتراضياً لتوفير طاقة البطارية وسلاسة العرض', textDirection: TextDirection.rtl),
                              backgroundColor: Color(0xff171f33),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Settings Group 2: Support
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    'الدعم والمساعدة',
                    style: TextStyle(color: Color(0xffcbc3d7), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xff171f33).withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.5),
                  ),
                  child: Column(
                    children: [
                      // WhatsApp Technical Support
                      ListTile(
                        leading: const Icon(Icons.support_agent, color: Color(0xffffb2b7)),
                        title: const Text('الدعم الفني عبر الواتساب', style: TextStyle(color: Color(0xffdae2fd), fontSize: 14)),
                        trailing: const Icon(Icons.arrow_back_ios, color: Colors.white24, size: 14),
                        onTap: _openWhatsAppSupport,
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      // Technical info
                      ListTile(
                        leading: const Icon(Icons.info_outline, color: Color(0xffcbc3d7)),
                        title: const Text('حول محرك Rahel المحلي', style: TextStyle(color: Color(0xffdae2fd), fontSize: 14)),
                        trailing: const Icon(Icons.arrow_back_ios, color: Colors.white24, size: 14),
                        onTap: _showAboutEngineDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Version Info Text
                const Center(
                  child: Column(
                    children: [
                      Text(
                        'تطبيق راحة الأصلي (Rahel Native)',
                        style: TextStyle(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'الإصدار 1.0.0 (Build 1)',
                        style: TextStyle(color: Colors.white10, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQualityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff171f33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'اختر جودة تحويل الصوت',
                style: TextStyle(color: Color(0xffdae2fd), fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              RadioListTile<String>(
                title: const Text('جودة فائقة (320kbps) - موصى به', style: TextStyle(color: Color(0xffdae2fd))),
                value: '320kbps',
                groupValue: _downloadQuality,
                activeColor: const Color(0xffd0bcff),
                onChanged: (val) {
                  setState(() => _downloadQuality = val!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<String>(
                title: const Text('جودة عالية (192kbps)', style: TextStyle(color: Color(0xffdae2fd))),
                value: '192kbps',
                groupValue: _downloadQuality,
                activeColor: const Color(0xffd0bcff),
                onChanged: (val) {
                  setState(() => _downloadQuality = val!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<String>(
                title: const Text('جودة متوسطة (128kbps)', style: TextStyle(color: Color(0xffdae2fd))),
                value: '128kbps',
                groupValue: _downloadQuality,
                activeColor: const Color(0xffd0bcff),
                onChanged: (val) {
                  setState(() => _downloadQuality = val!);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAboutEngineDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff171f33),
          title: const Text('محرك Rahel الذاتي', textDirection: TextDirection.rtl, style: TextStyle(color: Color(0xffd0bcff))),
          content: const Text(
            'هذا التطبيق مبرمج بالكامل بلغة Dart و إطار العمل Flutter.\n\n'
            'يتميز بالاستقلالية الكاملة 100%:\n'
            '• يعتمد على مكتبة youtube_explode لاستخلاص الملفات مباشرة من خوادم يوتيوب.\n'
            '• يستخدم محرك FFmpeg Kit الأصلي المدمج بالهاتف لمعالجة مسارات الصوت وتحويلها إلى MP3 بجودة 320kbps.\n'
            '• تشغيل الصوت بالخلفية وربطه بأزرار شاشة القفل يتم بنظام الـ AudioService الرسمي للأجهزة.\n\n'
            'لا حاجة بعد اليوم لتشغيل أي خوادم بايثون خارجية أو أجهزة كمبيوتر للتحميل.',
            textDirection: TextDirection.rtl,
            style: TextStyle(color: Color(0xffdae2fd), fontSize: 13, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffd0bcff)),
              onPressed: () => Navigator.pop(context),
              child: const Text('فهمت', style: TextStyle(color: Color(0xff0b1326))),
            )
          ],
        );
      },
    );
  }
}
