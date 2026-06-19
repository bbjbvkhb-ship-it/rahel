import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/media_item.dart';

class LibraryController extends ChangeNotifier {
  List<LocalMediaItem> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'audio', 'video'
  String? _selectedAlbum;

  List<LocalMediaItem> get items => _items;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedFilter => _selectedFilter;
  String? get selectedAlbum => _selectedAlbum;

  LibraryController() {
    loadLibrary();
  }

  // Get dynamic documents directory
  Future<Directory> get _localDir async {
    return await getApplicationDocumentsDirectory();
  }

  // Get full absolute path for a relative path
  Future<String> getAbsolutePath(String relativePath) async {
    final dir = await _localDir;
    return p.join(dir.path, relativePath);
  }

  // Get full absolute file for a media item
  Future<File> getMediaFile(LocalMediaItem item) async {
    final absolutePath = await getAbsolutePath(item.filePath);
    return File(absolutePath);
  }

  // Get full absolute thumbnail for a media item
  Future<File> getThumbnailFile(LocalMediaItem item) async {
    final absolutePath = await getAbsolutePath(item.thumbnailPath);
    return File(absolutePath);
  }

  // List of all albums
  List<String> get albums {
    final setOfAlbums = <String>{};
    for (var item in _items) {
      if (item.album != null && item.album!.trim().isNotEmpty) {
        setOfAlbums.add(item.album!);
      }
    }
    return setOfAlbums.toList()..sort();
  }

  // Filtered items list
  List<LocalMediaItem> get filteredItems {
    return _items.where((item) {
      // Filter by type
      if (_selectedFilter == 'audio' && !item.isAudio) return false;
      if (_selectedFilter == 'video' && item.isAudio) return false;

      // Filter by album
      if (_selectedAlbum != null && item.album != _selectedAlbum) return false;

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesTitle = item.title.toLowerCase().contains(query);
        final matchesArtist = item.artist.toLowerCase().contains(query);
        final matchesAlbum = (item.album ?? '').toLowerCase().contains(query);
        return matchesTitle || matchesArtist || matchesAlbum;
      }

      return true;
    }).toList()
      ..sort((a, b) => b.addedDate.compareTo(a.addedDate)); // Newest first
  }

  // Setters for filters
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  void setSelectedAlbum(String? album) {
    _selectedAlbum = album;
    notifyListeners();
  }

  // Load library metadata
  Future<void> loadLibrary() async {
    _isLoading = true;
    notifyListeners();

    try {
      final dir = await _localDir;
      final file = File(p.join(dir.path, 'library_metadata.json'));

      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        _items = jsonList.map((j) => LocalMediaItem.fromJson(j as Map<String, dynamic>)).toList();
      } else {
        _items = [];
      }
    } catch (e) {
      if (kDebugMode) print('Error loading library: $e');
      _items = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save library metadata
  Future<void> saveLibrary() async {
    try {
      final dir = await _localDir;
      final file = File(p.join(dir.path, 'library_metadata.json'));
      final jsonList = _items.map((item) => item.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      if (kDebugMode) print('Error saving library: $e');
    }
  }

  // Add item
  Future<void> addItem(LocalMediaItem item) async {
    // Remove duplicates if any
    _items.removeWhere((i) => i.id == item.id);
    _items.add(item);
    await saveLibrary();
    notifyListeners();
  }

  // Delete item
  Future<void> deleteItem(LocalMediaItem item) async {
    _items.removeWhere((i) => i.id == item.id);
    await saveLibrary();
    notifyListeners();

    // Delete files asynchronously from disk
    try {
      final mediaFile = await getMediaFile(item);
      if (await mediaFile.exists()) {
        await mediaFile.delete();
      }
      final thumbFile = await getThumbnailFile(item);
      if (await thumbFile.exists() && !item.thumbnailPath.startsWith('assets/')) {
        await thumbFile.delete();
      }
    } catch (e) {
      if (kDebugMode) print('Error deleting media files: $e');
    }
  }

  // Rename item title and/or artist
  Future<void> updateItemMetadata(String id, {required String title, required String artist, String? album}) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index != -1) {
      final oldItem = _items[index];
      _items[index] = LocalMediaItem(
        id: oldItem.id,
        title: title,
        artist: artist,
        durationSeconds: oldItem.durationSeconds,
        filePath: oldItem.filePath,
        thumbnailPath: oldItem.thumbnailPath,
        isAudio: oldItem.isAudio,
        addedDate: oldItem.addedDate,
        album: album,
      );
      await saveLibrary();
      notifyListeners();
    }
  }
}
