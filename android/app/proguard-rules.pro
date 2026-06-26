# Custom ProGuard rules for Rahel application

# Keep Google Mobile Ads SDK classes
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }

# Keep FFmpeg Kit classes
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-keep class com.arthenica.ffmpegkit.** { *; }

# Keep Audio Service and Just Audio classes
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.just_waveform.** { *; }

# Keep SQLite (Sqflite) classes
-keep class com.tekartik.sqflite.** { *; }
