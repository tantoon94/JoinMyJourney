import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';

class FirestoreUtils {
  static const int _maxRetries = 3;
  static const Duration _initialDelay = Duration(seconds: 1);
  static const Duration _maxDelay = Duration(seconds: 10);

  static Future<T> withRetry<T>({
    required Future<T> Function() operation,
    int maxRetries = _maxRetries,
    Duration initialDelay = _initialDelay,
    Duration maxDelay = _maxDelay,
  }) async {
    int attempts = 0;
    Duration delay = initialDelay;
    final random = Random();

    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts > maxRetries || !_isRetryableError(e)) {
          rethrow;
        }

        // Add jitter to prevent thundering herd
        final jitter = random.nextDouble() * 0.1;
        await Future.delayed(delay * (1 + jitter));
        
        // Exponential backoff with max delay
        delay = Duration(
          milliseconds: min(
            delay.inMilliseconds * 2,
            maxDelay.inMilliseconds,
          ),
        );
      }
    }
  }

  static bool _isRetryableError(dynamic error) {
    if (error is FirebaseException) {
      return error.code == 'cloud_firestore/unavailable' ||
             error.code == 'cloud_firestore/deadline-exceeded' ||
             error.code == 'cloud_firestore/resource-exhausted' ||
             error.code == 'cloud_firestore/internal';
    }
    return false;
  }
} 