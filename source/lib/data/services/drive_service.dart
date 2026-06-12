import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// A custom HTTP client that automatically adds Google Auth headers to every request.
class GoogleHttpClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleHttpClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class DriveService {
  final AuthService _auth;
  // Track last write time per file to prevent stale background fetches from overwriting fresh data
  final Map<String, DateTime> _lastWriteTimes = {};

  DriveService(this._auth);

  /// Helper to get an authenticated Drive API instance.
  Future<drive.DriveApi?> _getDriveApi() async {
    final user = _auth.user;
    if (user == null) return null;

    final headers = await user.authHeaders;
    final client = GoogleHttpClient(headers);
    return drive.DriveApi(client);
  }

  Future<String?> readFile(String fileName, {bool forceRefresh = false}) async {
    final user = _auth.user;
    if (user == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'drive_cache_${user.id}_$fileName';
    
    // Return cached value immediately for instant UI if available, UNLESS forceRefresh is requested
    final cached = prefs.getString(cacheKey);
    if (cached != null && !forceRefresh) {
      // Trigger background fetch to keep it fresh, but record when we started
      final startTime = DateTime.now();
      _fetchFromDrive(fileName, prefs, cacheKey, startTime: startTime);
      return cached;
    }
    
    // No cache or forceRefresh? Wait for the actual drive fetch
    return await _fetchFromDrive(fileName, prefs, cacheKey);
  }

  Future<String?> _fetchFromDrive(String fileName, SharedPreferences prefs, String cacheKey, {DateTime? startTime}) async {
    final api = await _getDriveApi();
    if (api == null) {
      debugPrint('DriveService: Could not get Drive API (User might not be authenticated)');
      return null;
    }

    try {
      debugPrint('DriveService: Listing files for $fileName in appDataFolder...');
      final fileList = await api.files.list(
        q: "name = '$fileName' and 'appDataFolder' in parents",
        spaces: 'appDataFolder',
        $fields: 'files(id, name)',
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        debugPrint('DriveService: $fileName not found in appDataFolder.');
        return null;
      }

      final fileId = fileList.files!.first.id!;
      debugPrint('DriveService: Found file $fileId. Downloading...');
      final media = await api.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      
      final List<int> data = [];
      await for (var chunk in media.stream) {
        data.addAll(chunk);
      }
      
      final content = utf8.decode(data);
      debugPrint('DriveService: Successfully downloaded ${data.length} bytes.');
      
      // SAFETY CHECK: If a write happened AFTER we started this fetch, DO NOT overwrite the cache.
      if (startTime != null) {
        final lastWrite = _lastWriteTimes[fileName];
        if (lastWrite != null && lastWrite.isAfter(startTime)) {
          debugPrint('DriveService: Skipping cache update for $fileName because a newer write exists.');
          return content;
        }
      }
      
      await prefs.setString(cacheKey, content);
      return content;
    } catch (e) {
      debugPrint('DriveService: Error reading from Drive: $e');
      return null;
    }
  }

  Future<void> writeFile(String fileName, String content) async {
    final user = _auth.user;
    if (user == null) return;

    // 1. Update local cache first
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'drive_cache_${user.id}_$fileName';
    await prefs.setString(cacheKey, content);
    _lastWriteTimes[fileName] = DateTime.now();

    // 2. Update Drive
    final api = await _getDriveApi();
    if (api == null) return;

    try {
      debugPrint('DriveService: Writing $fileName to Drive...');
      final fileList = await api.files.list(
        q: "name = '$fileName' and 'appDataFolder' in parents",
        spaces: 'appDataFolder',
        $fields: 'files(id, name)',
      );

      final bytes = utf8.encode(content);
      final media = drive.Media(
        Stream.value(bytes),
        bytes.length,
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final fileId = fileList.files!.first.id!;
        debugPrint('DriveService: Updating existing file $fileId...');
        await api.files.update(drive.File(), fileId, uploadMedia: media);
        debugPrint('DriveService: Successfully updated $fileName.');
      } else {
        debugPrint('DriveService: Creating new file $fileName...');
        final driveFile = drive.File()
          ..name = fileName
          ..parents = ['appDataFolder'];
        await api.files.create(driveFile, uploadMedia: media);
        debugPrint('DriveService: Successfully created $fileName.');
      }
    } catch (e) {
      debugPrint('DriveService: Error writing to Drive: $e');
    }
  }

  /// Deletes all files in the App Data folder.
  /// This is used for a full profile wipe.
  Future<void> deleteAllFiles() async {
    // Clear local cache for THIS user
    final user = _auth.user;
    final prefs = await SharedPreferences.getInstance();
    if (user != null) {
      final prefix = 'drive_cache_${user.id}_';
      final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
      for (var k in keys) await prefs.remove(k);
    }
    await prefs.remove('cached_holdings');

    final api = await _getDriveApi();
    if (api == null) return;

    try {
      final fileList = await api.files.list(
        q: "'appDataFolder' in parents",
        spaces: 'appDataFolder',
        $fields: 'files(id, name)',
      );

      if (fileList.files != null) {
        for (var file in fileList.files!) {
          if (file.id != null) {
            print('Deleting file: ${file.name} (${file.id})');
            await api.files.delete(file.id!);
          }
        }
      }
    } catch (e) {
      print('Error during Drive cleanup: $e');
    }
  }
}
