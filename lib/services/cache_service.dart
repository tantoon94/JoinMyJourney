import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CacheService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _cachePrefix = 'journey_cache_';
  static const Duration _cacheDuration = Duration(hours: 24);

  // Cache user data
  Future<void> cacheUserData(String userId, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '${_cachePrefix}user_$userId';
    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString(cacheKey, jsonEncode(cacheData));
  }

  // Get cached user data
  Future<Map<String, dynamic>?> getCachedUserData(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '${_cachePrefix}user_$userId';
    final cachedString = prefs.getString(cacheKey);

    if (cachedString == null) return null;

    final cacheData = jsonDecode(cachedString) as Map<String, dynamic>;
    final timestamp = DateTime.parse(cacheData['timestamp']);

    if (DateTime.now().difference(timestamp) > _cacheDuration) {
      await prefs.remove(cacheKey);
      return null;
    }

    return cacheData['data'] as Map<String, dynamic>;
  }

  // Cache journey data
  Future<void> cacheJourneyData(
      String journeyId, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '${_cachePrefix}journey_$journeyId';
    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString(cacheKey, jsonEncode(cacheData));
  }

  // Get cached journey data
  Future<Map<String, dynamic>?> getCachedJourneyData(String journeyId) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '${_cachePrefix}journey_$journeyId';
    final cachedString = prefs.getString(cacheKey);

    if (cachedString == null) return null;

    final cacheData = jsonDecode(cachedString) as Map<String, dynamic>;
    final timestamp = DateTime.parse(cacheData['timestamp']);

    if (DateTime.now().difference(timestamp) > _cacheDuration) {
      await prefs.remove(cacheKey);
      return null;
    }

    return cacheData['data'] as Map<String, dynamic>;
  }

  // Cache journey stops
  Future<void> cacheJourneyStops(
      String journeyId, List<Map<String, dynamic>> stops) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '${_cachePrefix}stops_$journeyId';
    final cacheData = {
      'data': stops,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString(cacheKey, jsonEncode(cacheData));
  }

  // Get cached journey stops
  Future<List<Map<String, dynamic>>?> getCachedJourneyStops(
      String journeyId) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '${_cachePrefix}stops_$journeyId';
    final cachedString = prefs.getString(cacheKey);

    if (cachedString == null) return null;

    final cacheData = jsonDecode(cachedString) as Map<String, dynamic>;
    final timestamp = DateTime.parse(cacheData['timestamp']);

    if (DateTime.now().difference(timestamp) > _cacheDuration) {
      await prefs.remove(cacheKey);
      return null;
    }

    return List<Map<String, dynamic>>.from(cacheData['data']);
  }

  // Clear all cache
  Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith(_cachePrefix)) {
        await prefs.remove(key);
      }
    }
  }

  // Clear specific cache
  Future<void> clearCache(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith('$_cachePrefix$prefix')) {
        await prefs.remove(key);
      }
    }
  }

  // Enable offline persistence
  Future<void> enableOfflinePersistence() async {
    await _db.enablePersistence(const PersistenceSettings(
      synchronizeTabs: true,
    ));
  }

  // Get data with offline support
  Future<Map<String, dynamic>?> getDataWithOfflineSupport(
    String collection,
    String docId,
  ) async {
    try {
      // Try to get from cache first
      final cachedData = await getCachedJourneyData(docId);
      if (cachedData != null) {
        return cachedData;
      }

      // If not in cache, get from Firestore
      final doc = await _db.collection(collection).doc(docId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;

      // Cache the data
      await cacheJourneyData(docId, data);

      return data;
    } catch (e) {
      print('Error getting data with offline support: $e');
      return null;
    }
  }
}
