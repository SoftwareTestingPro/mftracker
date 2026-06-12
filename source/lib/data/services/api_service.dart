import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fund_nav.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.mfapi.in/mf',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36',
      'Accept': 'application/json',
    },
  ));

  DateTime? _lastRequestTime;
  static const _minRequestInterval = Duration(milliseconds: 200);
  Future<void>? _activeRequest;
  
  // Cache to avoid redundant calls for the same fund in one session
  final Map<String, FundHistory> _historyCache = {};

  Future<T> _throttledRequest<T>(Future<T> Function() request) async {
    final previousRequest = _activeRequest;
    final completer = Completer<void>();
    _activeRequest = completer.future;
    
    if (previousRequest != null) {
      await previousRequest;
    }

    try {
      final now = DateTime.now();
      if (_lastRequestTime != null) {
        final diff = now.difference(_lastRequestTime!);
        if (diff < _minRequestInterval) {
          await Future.delayed(_minRequestInterval - diff);
        }
      }
      
      _lastRequestTime = DateTime.now();
      
      // Simple retry logic
      int retries = 0;
      while (true) {
        try {
          return await request();
        } catch (e) {
          if (retries >= 2) rethrow;
          retries++;
          await Future.delayed(Duration(seconds: retries));
        }
      }
    } finally {
      completer.complete();
    }
  }

  Future<List<Map<String, dynamic>>> searchFunds(String query) async {
    return _throttledRequest(() async {
      try {
        debugPrint('ApiService: Searching funds for query: $query');
        final response = await _dio.get('/search', queryParameters: {'q': query});
        if (response.statusCode == 200) {
          debugPrint('ApiService: Successfully searched funds. Status: ${response.statusCode}');
          return List<Map<String, dynamic>>.from(response.data);
        }
        debugPrint('ApiService: Search failed. Status: ${response.statusCode}');
      } catch (e) {
        debugPrint('ApiService: Search error: $e');
      }
      return [];
    });
  }

  Future<List<Map<String, dynamic>>> getAllFunds() async {
    return _throttledRequest(() async {
      debugPrint('ApiService: Fetching all funds');
      final response = await _dio.get('');
      if (response.statusCode == 200) {
        debugPrint('ApiService: Successfully fetched all funds. Status: ${response.statusCode}');
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    });
  }

  Future<FundHistory?> getFundHistory(String schemeCode) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'nav_history_$schemeCode';
    
    // 1. Check in-memory cache first
    if (_historyCache.containsKey(schemeCode)) {
      final cached = _historyCache[schemeCode]!;
      if (DateTime.now().difference(cached.timestamp).inHours < 4) {
        return cached;
      }
    }

    // 2. Try network with fallback to disk cache
    return _throttledRequest(() async {
      try {
        debugPrint('ApiService: Fetching history for $schemeCode...');
        final response = await _dio.get('/$schemeCode');
        
        if (response.statusCode == 200) {
          final data = response.data;
          final history = FundHistory(
            schemeCode: data['meta']['scheme_code'].toString(),
            schemeName: data['meta']['scheme_name'],
            data: (data['data'] as List).map((nav) => FundNAV(
              date: nav['date'],
              nav: double.tryParse(nav['nav'].toString()) ?? 0.0,
            )).toList(),
            timestamp: DateTime.now(),
          );
          
          // Update both caches
          _historyCache[schemeCode] = history;
          await prefs.setString(cacheKey, jsonEncode({
            'meta': data['meta'],
            'data': data['data'],
            'timestamp': history.timestamp.toIso8601String(),
          }));
          
          debugPrint('ApiService: Successfully fetched ${history.data.length} records for $schemeCode');
          return history;
        }
      } catch (e) {
        debugPrint('ApiService: Network error for $schemeCode: $e. Checking disk cache...');
      }

      // 3. Fallback to Disk Cache if network failed or returned error
      final diskCached = prefs.getString(cacheKey);
      if (diskCached != null) {
        try {
          final decoded = jsonDecode(diskCached);
          final history = FundHistory(
            schemeCode: decoded['meta']['scheme_code'].toString(),
            schemeName: decoded['meta']['scheme_name'],
            data: (decoded['data'] as List).map((nav) => FundNAV(
              date: nav['date'],
              nav: double.tryParse(nav['nav'].toString()) ?? 0.0,
            )).toList(),
            timestamp: DateTime.parse(decoded['timestamp']),
          );
          _historyCache[schemeCode] = history;
          debugPrint('ApiService: Using disk cache for $schemeCode (from ${history.timestamp})');
          return history;
        } catch (e) {
          debugPrint('ApiService: Disk cache corrupted for $schemeCode: $e');
        }
      }

      return null;
    });
  }

  Future<double> getCurrentNAV(String schemeCode) async {
    final history = await getFundHistory(schemeCode);
    if (history != null && history.data.isNotEmpty) {
      return history.data.first.nav;
    }
    return 0.0;
  }

  /// Helper to get NAV from already fetched history object (saves network calls)
  double getNAVFromHistory(FundHistory history, DateTime date) {
    if (history.data.isEmpty) return 0.0;
    final targetDate = DateTime(date.year, date.month, date.day);
    final closest = findClosestRecord(history.data, targetDate);
    return closest?.nav ?? history.data.last.nav;
  }

  Future<double> getNAVForDate(String schemeCode, DateTime date) async {
    try {
      final history = await getFundHistory(schemeCode);
      if (history == null) return 0.0;
      return getNAVFromHistory(history, date);
    } catch (e) {
      return 0.0;
    }
  }

  Map<String, double> calculatePeriodicReturns(List<FundNAV> navHistory, double currentNAV, {DateTime? earliestDate}) {
    if (navHistory.isEmpty) return {};

    // Use the latest record in history as the reference point for "today"
    // The API returns the data with the most recent NAV first.
    final parts = navHistory.first.date.split('-');
    final anchorDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    
    final holdStart = earliestDate ?? anchorDate.subtract(const Duration(days: 36500));
    final daysHeld = anchorDate.difference(holdStart).inDays;

    // Build eligible periods based on holding duration
    final Map<String, int> periods = {};
    if (daysHeld >= 1)  periods['daily'] = 1;
    if (daysHeld >= 7)  periods['weekly'] = 7;
    if (daysHeld >= 15) periods['fortnightly'] = 15;
    if (daysHeld >= 30) periods['monthly'] = 30;
    if (daysHeld >= 90)  periods['quarterly'] = 90;
    if (daysHeld >= 180) periods['halfYearly'] = 180;
    if (daysHeld >= 365) periods['yearly'] = 365;

    // Add per-calendar-year returns
    final currentYear = anchorDate.year;
    final startYear = holdStart.year;
    if (startYear < currentYear) {
      for (int year = currentYear; year >= startYear; year--) {
        final yearStart = DateTime(year, 1, 1);
        if (holdStart.isBefore(yearStart) || holdStart.year == year) {
          periods[year.toString()] = anchorDate.difference(
            holdStart.year == year && holdStart.isAfter(yearStart) ? holdStart : yearStart
          ).inDays;
        }
      }
    }

    final Map<String, double> results = {};

    for (var entry in periods.entries) {
      DateTime targetDate;
      if (int.tryParse(entry.key) != null) {
        final year = int.parse(entry.key);
        final yearStart = DateTime(year, 1, 1);
        targetDate = holdStart.year == year && holdStart.isAfter(yearStart)
            ? holdStart
            : yearStart;
      } else {
        targetDate = anchorDate.subtract(Duration(days: entry.value));
      }

      FundNAV? pastNAV = findClosestRecord(navHistory, targetDate);

      // If pastNAV is the same as the latest record for 'daily', try to find the one before it
      if (entry.key == 'daily' && pastNAV != null && pastNAV.date == navHistory.first.date && navHistory.length > 1) {
        pastNAV = navHistory[1];
      }

      if (pastNAV != null && pastNAV.nav > 0) {
        // Calculate absolute return for all periods
        results[entry.key] = ((currentNAV - pastNAV.nav) / pastNAV.nav) * 100;
      }
    }

    return results;
  }

  /// Find the NAV record closest to (and on or before) the target date.
  FundNAV? findClosestRecord(List<FundNAV> navHistory, DateTime targetDate) {
    FundNAV? closest;
    for (var navRecord in navHistory) {
      final parts = navRecord.date.split('-');
      final recordDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));

      if (recordDate.isBefore(targetDate) || recordDate.isAtSameMomentAs(targetDate)) {
        if (closest == null) {
          closest = navRecord;
        } else {
          final closestParts = closest.date.split('-');
          final closestDate = DateTime(int.parse(closestParts[2]), int.parse(closestParts[1]), int.parse(closestParts[0]));
          if (recordDate.isAfter(closestDate)) {
            closest = navRecord;
          }
        }
      }
    }
    return closest;
  }
}
