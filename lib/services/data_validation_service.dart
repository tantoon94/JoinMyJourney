import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DataValidationService {
  static String? validateUserData(Map<String, dynamic> data) {
    if (data['displayName'] == null || data['displayName'].toString().isEmpty) {
      return 'Display name is required';
    }
    if (data['email'] == null || data['email'].toString().isEmpty) {
      return 'Email is required';
    }
    if (data['userType'] == null ||
        !['regular', 'researcher'].contains(data['userType'])) {
      return 'Invalid user type';
    }
    return null;
  }

  static String? validateJourneyData(Map<String, dynamic> data) {
    if (data['title'] == null || data['title'].toString().isEmpty) {
      return 'Title is required';
    }
    if (data['description'] == null || data['description'].toString().isEmpty) {
      return 'Description is required';
    }
    if (data['creatorId'] == null || data['creatorId'].toString().isEmpty) {
      return 'Creator ID is required';
    }
    if (data['category'] == null || data['category'].toString().isEmpty) {
      return 'Category is required';
    }
    if (data['difficulty'] != null &&
        (data['difficulty'] < 1 || data['difficulty'] > 5)) {
      return 'Difficulty must be between 1 and 5';
    }
    if (data['cost'] != null && (data['cost'] < 1 || data['cost'] > 5)) {
      return 'Cost must be between 1 and 5';
    }
    if (data['recommendedPeople'] != null && data['recommendedPeople'] < 1) {
      return 'Recommended people must be at least 1';
    }
    if (data['durationInHours'] != null && data['durationInHours'] < 0) {
      return 'Duration must be positive';
    }
    return null;
  }

  static String? validateStopData(Map<String, dynamic> data) {
    if (data['name'] == null || data['name'].toString().isEmpty) {
      return 'Stop name is required';
    }
    if (data['description'] == null || data['description'].toString().isEmpty) {
      return 'Stop description is required';
    }
    if (data['location'] == null || data['location'] is! Map) {
      return 'Valid location is required';
    }
    if (data['order'] == null || data['order'] < 0) {
      return 'Valid order is required';
    }
    if (data['journeyId'] == null || data['journeyId'].toString().isEmpty) {
      return 'Journey ID is required';
    }
    return null;
  }

  static String? validateRoutePoints(List<LatLng> points) {
    if (points.isEmpty) {
      return 'At least one route point is required';
    }
    for (var point in points) {
      if (point.latitude < -90 || point.latitude > 90) {
        return 'Invalid latitude value';
      }
      if (point.longitude < -180 || point.longitude > 180) {
        return 'Invalid longitude value';
      }
    }
    return null;
  }

  static Map<String, dynamic> sanitizeUserData(Map<String, dynamic> data) {
    return {
      'displayName': data['displayName']?.toString().trim(),
      'email': data['email']?.toString().trim().toLowerCase(),
      'userType': data['userType']?.toString().toLowerCase(),
      'photoURL': data['photoURL']?.toString(),
      'bio': data['bio']?.toString().trim(),
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, dynamic> sanitizeJourneyData(Map<String, dynamic> data) {
    return {
      'title': data['title']?.toString().trim(),
      'description': data['description']?.toString().trim(),
      'creatorId': data['creatorId']?.toString(),
      'creatorName': data['creatorName']?.toString().trim(),
      'creatorPhotoUrl': data['creatorPhotoUrl']?.toString(),
      'category': data['category']?.toString().trim(),
      'difficulty': data['difficulty']?.clamp(1, 5),
      'cost': data['cost']?.clamp(1, 5),
      'recommendedPeople': data['recommendedPeople']?.clamp(1, 100),
      'durationInHours': data['durationInHours']?.clamp(0, 24),
      'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'likes': data['likes']?.clamp(0, double.infinity) ?? 0,
      'shadowers': data['shadowers']?.clamp(0, double.infinity) ?? 0,
      'totalStops': data['totalStops']?.clamp(0, double.infinity) ?? 0,
    };
  }

  static Map<String, dynamic> sanitizeStopData(Map<String, dynamic> data) {
    return {
      'name': data['name']?.toString().trim(),
      'description': data['description']?.toString().trim(),
      'location': data['location'],
      'order': data['order']?.clamp(0, double.infinity),
      'journeyId': data['journeyId']?.toString(),
      'creatorId': data['creatorId']?.toString(),
      'markerId': data['markerId']?.toString(),
      'isActive': data['isActive'] ?? true,
      'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'imageUrl': data['imageUrl']?.toString(),
    };
  }
}
