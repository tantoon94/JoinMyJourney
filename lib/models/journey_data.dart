import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'journey.dart' as journey;

class JourneyData {
  final String? title;
  final String? description;
  final List<LatLng> routePoints;
  final List<journey.Stop> stops;
  final DateTime startTime;
  final DateTime? endTime;

  JourneyData({
    this.title,
    this.description,
    required this.routePoints,
    required this.stops,
    required this.startTime,
    this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'routePoints': routePoints.map((point) => {
        'latitude': point.latitude,
        'longitude': point.longitude,
      }).toList(),
      'stops': stops.map((stop) => stop.toMap()).toList(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
    };
  }

  factory JourneyData.fromMap(Map<String, dynamic> map) {
    return JourneyData(
      title: map['title'] as String?,
      description: map['description'] as String?,
      routePoints: (map['routePoints'] as List).map((point) => LatLng(
        point['latitude'] as double,
        point['longitude'] as double,
      )).toList(),
      stops: (map['stops'] as List).map((stop) => journey.Stop.fromMap(stop)).toList(),
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime'] as String) : null,
    );
  }
} 