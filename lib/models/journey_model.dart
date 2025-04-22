import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JourneyStop {
  final String title;
  final String description;
  final LatLng location;
  final String? imageUrl;
  bool isCompleted; // For tracking progress

  JourneyStop({
    required this.title,
    required this.description,
    required this.location,
    this.imageUrl,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'location': GeoPoint(location.latitude, location.longitude),
      'imageUrl': imageUrl,
      'isCompleted': isCompleted,
    };
  }

  static JourneyStop fromMap(Map<String, dynamic> map) {
    return JourneyStop(
      title: map['title'],
      description: map['description'],
      location: LatLng(
        map['location'].latitude,
        map['location'].longitude,
      ),
      imageUrl: map['imageUrl'],
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

class Journey {
  final String id;
  final String creatorId;
  final String title;
  final String description;
  final List<JourneyStop> stops;
  final int durationInHours;
  final int recommendedPeople;
  final double cost;
  final double rating;
  final int ratingCount;
  final List<String> likedByUsers;
  final DateTime createdAt;
  final List<LatLng> routePoints;

  Journey({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.description,
    required this.stops,
    required this.durationInHours,
    required this.recommendedPeople,
    required this.cost,
    this.rating = 0.0,
    this.ratingCount = 0,
    List<String>? likedByUsers,
    DateTime? createdAt,
    required this.routePoints,
  }) : 
    this.likedByUsers = likedByUsers ?? [],
    this.createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'creatorId': creatorId,
      'title': title,
      'description': description,
      'stops': stops.map((stop) => stop.toMap()).toList(),
      'durationInHours': durationInHours,
      'recommendedPeople': recommendedPeople,
      'cost': cost,
      'rating': rating,
      'ratingCount': ratingCount,
      'likedByUsers': likedByUsers,
      'createdAt': Timestamp.fromDate(createdAt),
      'routePoints': routePoints.map((point) => 
        GeoPoint(point.latitude, point.longitude)).toList(),
    };
  }

  static Journey fromMap(Map<String, dynamic> map, String id) {
    return Journey(
      id: id,
      creatorId: map['creatorId'],
      title: map['title'],
      description: map['description'],
      stops: (map['stops'] as List)
          .map((stop) => JourneyStop.fromMap(stop))
          .toList(),
      durationInHours: map['durationInHours'],
      recommendedPeople: map['recommendedPeople'],
      cost: map['cost'].toDouble(),
      rating: map['rating']?.toDouble() ?? 0.0,
      ratingCount: map['ratingCount'] ?? 0,
      likedByUsers: List<String>.from(map['likedByUsers'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      routePoints: (map['routePoints'] as List)
          .map((point) => LatLng(
                (point as GeoPoint).latitude,
                point.longitude,
              ))
          .toList(),
    );
  }
} 