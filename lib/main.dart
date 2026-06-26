import 'package:flutter/material.dart';
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
  });
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
