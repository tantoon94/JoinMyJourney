import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/image_handler.dart';

class MapThumbnailService {
  static const String _apiKey = 'AIzaSyBleoptuqG4muN960mY7UWdTUljJi_Fycc';
  static const String _cachePrefix = 'map_thumbnail_';
  static const Duration _cacheDuration = Duration(days: 7);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  
  // Rate limiting
  static final _requestTimes = <String, DateTime>{};
  static const _minRequestInterval = Duration(milliseconds: 200);

  // Cache management
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith(_cachePrefix)) {
        await prefs.remove(key);
      }
    }
  }

  static Future<Map<String, dynamic>?> getCachedThumbnail(String journeyId) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_cachePrefix$journeyId';
    final cachedString = prefs.getString(cacheKey);
    
    if (cachedString == null) return null;
    
    final cacheData = jsonDecode(cachedString) as Map<String, dynamic>;
    final timestamp = DateTime.parse(cacheData['timestamp']);
    
    if (DateTime.now().difference(timestamp) > _cacheDuration) {
      await prefs.remove(cacheKey);
      return null;
    }
    
    return cacheData;
  }

  static Future<void> cacheThumbnail(String journeyId, Map<String, dynamic> thumbnailData) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_cachePrefix$journeyId';
    final cacheData = {
      ...thumbnailData,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString(cacheKey, jsonEncode(cacheData));
  }

  // Rate limiting
  static bool _canMakeRequest(String key) {
    final lastRequest = _requestTimes[key];
    if (lastRequest == null) return true;
    
    final timeSinceLastRequest = DateTime.now().difference(lastRequest);
    return timeSinceLastRequest >= _minRequestInterval;
  }

  static void _updateRequestTime(String key) {
    _requestTimes[key] = DateTime.now();
  }

  // Main thumbnail generation method
  static Future<Map<String, dynamic>?> generateThumbnail({
    required LatLng center,
    required List<LatLng> stops,
    required List<LatLng> route,
    required String journeyId,
  }) async {
    // Check cache first
    final cachedThumbnail = await getCachedThumbnail(journeyId);
    if (cachedThumbnail != null) {
      print('Using cached thumbnail for journey $journeyId');
      return cachedThumbnail;
    }

    // Rate limiting
    if (!_canMakeRequest(journeyId)) {
      print('Rate limit exceeded for journey $journeyId');
      return null;
    }
    _updateRequestTime(journeyId);

    // Prepare markers and path
    final markers = stops.asMap().entries.map((entry) {
      final stop = entry.value;
      return 'markers=color:amber%7C${stop.latitude},${stop.longitude}';
    }).join('&');

    final path = route.map((point) => '${point.latitude},${point.longitude}').join('|');

    // Construct URL
    final staticMapUrl = 'https://maps.googleapis.com/maps/api/staticmap'
        '?center=${center.latitude},${center.longitude}'
        '&zoom=13'
        '&size=800x400'
        '&scale=2'
        '&maptype=roadmap'
        '&$markers'
        '&path=color:0xFFFFA500%7Cweight:3%7C$path'
        '&key=$_apiKey';

    // Retry logic
    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        print('Attempting to generate thumbnail (attempt $attempt)');
        final response = await http.get(Uri.parse(staticMapUrl)).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Downloading static map timed out');
          },
        );

        if (response.statusCode == 200) {
          // Compress the image
          final compressedBytes = await ImageHandler.compressAndResizeImage(
            response.bodyBytes,
            maxWidth: 800,
            maxHeight: 400,
            quality: 85,
          );

          if (compressedBytes == null) {
            throw Exception('Failed to compress static map');
          }

          // Create thumbnail data
          final thumbnailData = {
            'data': base64Encode(compressedBytes),
            'type': 'image/jpeg',
            'size': compressedBytes.length,
            'timestamp': DateTime.now().toIso8601String(),
            'name': 'map_thumbnail.jpg',
            'dimensions': {
              'width': 800,
              'height': 400,
            },
          };

          // Cache the thumbnail
          await cacheThumbnail(journeyId, thumbnailData);
          return thumbnailData;
        } else if (response.statusCode == 403) {
          throw Exception('API key error: ${response.body}');
        } else {
          throw Exception('Failed to download static map: ${response.statusCode}');
        }
      } catch (e) {
        print('Error generating thumbnail (attempt $attempt): $e');
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay);
        } else {
          rethrow;
        }
      }
    }

    return null;
  }

  // Fallback method using a simple map preview
  static Future<Map<String, dynamic>?> generateFallbackThumbnail({
    required List<LatLng> stops,
    required String journeyId,
  }) async {
    try {
      // Create a simple colored background
      final image = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x03, 0x20, 0x00, 0x00, 0x01, 0x90,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x4B, 0x0D, 0x24, 0x80, 0x00, 0x00, 0x00,
        0x01, 0x73, 0x52, 0x47, 0x42, 0x00, 0xAE, 0xCE, 0x1C, 0xE9, 0x00, 0x00,
        0x00, 0x04, 0x67, 0x41, 0x4D, 0x41, 0x00, 0x00, 0xB1, 0x8F, 0x0B, 0xFC,
        0x61, 0x05, 0x00, 0x00, 0x00, 0x09, 0x70, 0x48, 0x59, 0x73, 0x00, 0x00,
        0x0E, 0xC3, 0x00, 0x00, 0x0E, 0xC3, 0x01, 0xC7, 0x6F, 0xA8, 0x64, 0x00,
        0x00, 0x00, 0x19, 0x74, 0x45, 0x58, 0x74, 0x53, 0x6F, 0x66, 0x74, 0x77,
        0x61, 0x72, 0x65, 0x00, 0x41, 0x64, 0x6F, 0x62, 0x65, 0x20, 0x49, 0x6D,
        0x61, 0x67, 0x65, 0x52, 0x65, 0x61, 0x64, 0x79, 0x71, 0xC9, 0x65, 0x3C,
        0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00,
        0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00,
        0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
      ]);

      final thumbnailData = {
        'data': base64Encode(image),
        'type': 'image/png',
        'size': image.length,
        'timestamp': DateTime.now().toIso8601String(),
        'name': 'fallback_thumbnail.png',
        'dimensions': {
          'width': 800,
          'height': 400,
        },
        'isFallback': true,
      };

      await cacheThumbnail(journeyId, thumbnailData);
      return thumbnailData;
    } catch (e) {
      print('Error generating fallback thumbnail: $e');
      return null;
    }
  }
} 