import 'package:youtube_explode_dart/youtube_explode_dart.dart';

String? extractYoutubeVideoId(String url) {
  url = url.trim();
  if (url.isEmpty) return null;

  // Try using youtube_explode's VideoId parse method first
  try {
    final videoIdObj = VideoId(url);
    if (videoIdObj.value.length == 11) {
      return videoIdObj.value;
    }
  } catch (_) {
    // Fallback to manual regex if VideoId throws
  }

  // Pattern to find 11 character video ID
  // It handles:
  // - youtube.com/watch?v=ID
  // - youtube.com/embed/ID
  // - youtube.com/shorts/ID
  // - youtube.com/live/ID
  // - youtu.be/ID
  // - music.youtube.com/watch?v=ID
  final regExp = RegExp(
    r'^.*(youtu.be\/|v\/|u\/\w\/|embed\/|shorts\/|live\/|watch\?v=|\&v=)([^#\&\?]*).*',
    caseSensitive: false,
    multiLine: false,
  );

  final match = regExp.firstMatch(url);
  if (match != null && match.groupCount >= 2) {
    final id = match.group(2);
    if (id != null && id.length == 11) {
      return id;
    }
  }

  // Fallback RegExp to search for any 11-character ID after watch?v= or shorts/ or youtu.be/
  final watchReg = RegExp(r'[?&]v=([^&#\?]+)');
  final watchMatch = watchReg.firstMatch(url);
  if (watchMatch != null && watchMatch.group(1)?.length == 11) {
    return watchMatch.group(1);
  }

  final pathReg = RegExp(r'(shorts\/|embed\/|v\/|live\/|youtu.be\/)([^&#\?\s]+)');
  final pathMatch = pathReg.firstMatch(url);
  if (pathMatch != null && pathMatch.group(2)?.length == 11) {
    return pathMatch.group(2);
  }

  return null;
}

Future<T> retryYoutubeCall<T>(Future<T> Function() call, {int maxRetries = 3}) async {
  int attempts = 0;
  while (true) {
    attempts++;
    try {
      return await call();
    } catch (e) {
      if (attempts >= maxRetries) {
        rethrow;
      }
      // Wait before retrying (exponential backoff: 300ms, 600ms, 900ms...)
      await Future.delayed(Duration(milliseconds: 300 * attempts));
    }
  }
}

