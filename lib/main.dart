import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'controllers/download_controller.dart';
import 'controllers/library_controller.dart';
import 'controllers/player_controller.dart';
import 'controllers/playlist_controller.dart';
import 'screens/navigation_holder.dart';
import 'services/audio_handler.dart';
import 'services/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize the native audio playback service
    final audioHandler = await initAudioService();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LibraryController()),
          ChangeNotifierProvider(create: (_) => DownloadController()),
          Provider<MyAudioHandler>.value(value: audioHandler as MyAudioHandler),
          ChangeNotifierProvider(create: (_) => PlayerController(audioHandler: audioHandler as MyAudioHandler)),
          ChangeNotifierProvider(create: (_) => PlaylistController()),
        ],
        child: MyApp(audioHandler: audioHandler as MyAudioHandler),
      ),
    );

    // Initialize AdMob SDK in the background after startup to avoid blocking splash screen
    MobileAds.instance.initialize().then((_) {
      AdService().loadInterstitialAd();
    }).catchError((error) {
      if (kDebugMode) print('AdMob initialization error: $error');
    });
  } catch (e, stackTrace) {
    if (kDebugMode) print('CRITICAL STARTUP ERROR: $e\n$stackTrace');
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xff0b1326),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Color(0xffffb2b7), size: 80),
                  const SizedBox(height: 24),
                  const Text(
                    'حدث خطأ غير متوقع أثناء تشغيل التطبيق',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xffffb2b7),
                      fontFamily: 'Inter',
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'يرجى تصوير هذه الشاشة وإرسالها للمطور لحل المشكلة:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xffdae2fd),
                      fontFamily: 'Inter',
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xff171f33),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xff444e66)),
                    ),
                    child: SelectableText(
                      'Error: $e\n\nStackTrace:\n$stackTrace',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xffdae2fd),
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
  }
}

class MyApp extends StatelessWidget {
  final MyAudioHandler audioHandler;

  const MyApp({
    super.key,
    required this.audioHandler,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rahel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff0b1326),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xffd0bcff),
          secondary: Color(0xff89ceff),
          tertiary: Color(0xffffb2b7),
          surface: Color(0xff171f33),
          background: Color(0xff0b1326),
          onPrimary: Color(0xff3c0091),
          onSecondary: Color(0xff00344d),
          onBackground: Color(0xffdae2fd),
          onSurface: Color(0xffdae2fd),
        ),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff0b1326),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xffd0bcff)),
          titleTextStyle: TextStyle(
            color: Color(0xffd0bcff),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xff0b1326),
          selectedItemColor: Color(0xffd0bcff),
          unselectedItemColor: Color(0xffcbc3d7),
          elevation: 8,
        ),
      ),
      home: NavigationHolder(audioHandler: audioHandler),
    );
  }
}
