import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/playlist.dart';

class PlaylistController extends ChangeNotifier {
  Database? _db;
  List<Playlist> _playlists = [];
  bool _isLoading = true;

  List<Playlist> get playlists => _playlists;
  bool get isLoading => _isLoading;

  PlaylistController() {
    _initDb();
  }

  Future<void> _initDb() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'rahel_playlists.db');
      
      _db = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE playlists (
              id TEXT PRIMARY KEY,
              name TEXT,
              itemIds TEXT,
              createdAt TEXT
            )
          ''');
        },
      );
      await loadPlaylists();
    } catch (e) {
      if (kDebugMode) print('Error initializing playlists database: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPlaylists() async {
    if (_db == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> maps = await _db!.query('playlists', orderBy: 'createdAt DESC');
      _playlists = maps.map((map) => Playlist.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) print('Error loading playlists: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createPlaylist(String name) async {
    if (_db == null || name.trim().isEmpty) return;

    final newPlaylist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      itemIds: [],
      createdAt: DateTime.now(),
    );

    try {
      await _db!.insert(
        'playlists',
        newPlaylist.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await loadPlaylists();
    } catch (e) {
      if (kDebugMode) print('Error creating playlist: $e');
    }
  }

  Future<void> renamePlaylist(String id, String newName) async {
    if (_db == null || newName.trim().isEmpty) return;

    try {
      await _db!.update(
        'playlists',
        {'name': newName.trim()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await loadPlaylists();
    } catch (e) {
      if (kDebugMode) print('Error renaming playlist: $e');
    }
  }

  Future<void> deletePlaylist(String id) async {
    if (_db == null) return;

    try {
      await _db!.delete(
        'playlists',
        where: 'id = ?',
        whereArgs: [id],
      );
      await loadPlaylists();
    } catch (e) {
      if (kDebugMode) print('Error deleting playlist: $e');
    }
  }

  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    if (_db == null) return;

    try {
      final idx = _playlists.indexWhere((p) => p.id == playlistId);
      if (idx == -1) return;

      final playlist = _playlists[idx];
      if (playlist.itemIds.contains(trackId)) return; // Already exists

      final updatedIds = List<String>.from(playlist.itemIds)..add(trackId);
      await _db!.update(
        'playlists',
        {'itemIds': updatedIds.join(',')},
        where: 'id = ?',
        whereArgs: [playlistId],
      );
      await loadPlaylists();
    } catch (e) {
      if (kDebugMode) print('Error adding track to playlist: $e');
    }
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    if (_db == null) return;

    try {
      final idx = _playlists.indexWhere((p) => p.id == playlistId);
      if (idx == -1) return;

      final playlist = _playlists[idx];
      final updatedIds = List<String>.from(playlist.itemIds)..remove(trackId);
      await _db!.update(
        'playlists',
        {'itemIds': updatedIds.join(',')},
        where: 'id = ?',
        whereArgs: [playlistId],
      );
      await loadPlaylists();
    } catch (e) {
      if (kDebugMode) print('Error removing track from playlist: $e');
    }
  }

  Future<void> updatePlaylistTracks(String playlistId, List<String> newItemIds) async {
    if (_db == null) return;

    try {
      await _db!.update(
        'playlists',
        {'itemIds': newItemIds.join(',')},
        where: 'id = ?',
        whereArgs: [playlistId],
      );
      await loadPlaylists();
    } catch (e) {
      if (kDebugMode) print('Error updating playlist tracks: $e');
    }
  }
}
