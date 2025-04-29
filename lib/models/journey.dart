import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';

class Journey {
  final String id;
  final String title;
  final String description;
  final String location;
  final String creatorId;
  final String creatorName;
  final String? creatorPhotoUrl;
  final String category;
  final int difficulty;
  final int cost;
  final int recommendedPeople;
  final double durationInHours;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int likes;
  final int shadowers;
  final int totalStops;
  final Map<String, dynamic>? mapThumbnailData;
  final List<LatLng> route;
  final List<Stop> stops;
  final String status;
  final String visibility;
  final String lastModifiedBy;
  final int version;

  Journey({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.creatorId,
    required this.creatorName,
    this.creatorPhotoUrl,
    required this.category,
    required this.difficulty,
    required this.cost,
    required this.recommendedPeople,
    required this.durationInHours,
    required this.createdAt,
    required this.updatedAt,
    required this.likes,
    required this.shadowers,
    required this.totalStops,
    this.mapThumbnailData,
    required this.route,
    required this.stops,
    required this.status,
    required this.visibility,
    required this.lastModifiedBy,
    required this.version,
  });

  factory Journey.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Journey(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? 'Anonymous',
      creatorPhotoUrl: data['creatorPhotoUrl'],
      category: data['category'] ?? 'Adventures',
      difficulty: data['difficulty'] ?? 1,
      cost: data['cost'] ?? 1,
      recommendedPeople: data['recommendedPeople'] ?? 2,
      durationInHours: (data['durationInHours'] ?? 1.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      likes: data['likes'] ?? 0,
      shadowers: data['shadowers'] ?? 0,
      totalStops: data['totalStops'] ?? 0,
      mapThumbnailData: data['mapThumbnailData'],
      route: (data['route'] as List<dynamic>? ?? [])
          .map((point) => LatLng(
                point['lat'] as double,
                point['lng'] as double,
              ))
          .toList(),
      stops: (data['stops'] as List<dynamic>? ?? [])
          .map((stop) => Stop.fromMap(stop as Map<String, dynamic>))
          .toList(),
      status: data['status'] ?? 'active',
      visibility: data['visibility'] ?? 'public',
      lastModifiedBy: data['lastModifiedBy'] ?? '',
      version: data['version'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'creatorPhotoUrl': creatorPhotoUrl,
      'category': category,
      'difficulty': difficulty,
      'cost': cost,
      'recommendedPeople': recommendedPeople,
      'durationInHours': durationInHours,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'likes': likes,
      'shadowers': shadowers,
      'totalStops': totalStops,
      'mapThumbnailData': mapThumbnailData,
      'route': route
          .map((point) => {
                'latitude': point.latitude,
                'longitude': point.longitude,
              })
          .toList(),
      'stops': stops.map((stop) => stop.toMap()).toList(),
      'status': status,
      'visibility': visibility,
      'lastModifiedBy': lastModifiedBy,
      'version': version,
    };
  }

  Journey copyWith({
    String? id,
    String? title,
    String? description,
    String? location,
    String? creatorId,
    String? creatorName,
    String? creatorPhotoUrl,
    String? category,
    int? difficulty,
    int? cost,
    int? recommendedPeople,
    double? durationInHours,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likes,
    int? shadowers,
    int? totalStops,
    Map<String, dynamic>? mapThumbnailData,
    List<LatLng>? route,
    List<Stop>? stops,
    String? status,
    String? visibility,
    String? lastModifiedBy,
    int? version,
  }) {
    return Journey(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      creatorPhotoUrl: creatorPhotoUrl ?? this.creatorPhotoUrl,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      cost: cost ?? this.cost,
      recommendedPeople: recommendedPeople ?? this.recommendedPeople,
      durationInHours: durationInHours ?? this.durationInHours,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likes: likes ?? this.likes,
      shadowers: shadowers ?? this.shadowers,
      totalStops: totalStops ?? this.totalStops,
      mapThumbnailData: mapThumbnailData ?? this.mapThumbnailData,
      route: route ?? this.route,
      stops: stops ?? this.stops,
      status: status ?? this.status,
      visibility: visibility ?? this.visibility,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      version: version ?? this.version,
    );
  }
}

class Stop {
  final String id;
  final String name;
  final String description;
  final LatLng location;
  final int order;
  final String? notes;
  final Map<String, dynamic>? imageData;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final int version;

  Stop({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.order,
    this.notes,
    this.imageData,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.version,
  });

  factory Stop.fromMap(Map<String, dynamic> map) {
    double lat = 0.0;
    double lng = 0.0;
    try {
      final loc = map['location'] ?? {};
      lat = (loc['latitude'] as num?)?.toDouble() ?? 0.0;
      lng = (loc['longitude'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      print(
          'Warning: Stop.fromMap could not parse latitude/longitude from: \\${map['location']}. Error: \\$e');
    }
    return Stop(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      location: LatLng(lat, lng),
      order: map['order'] ?? 0,
      notes: map['notes'],
      imageData: map['imageData'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      status: map['status'] ?? 'active',
      version: map['version'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'location': {
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
      'order': order,
      'notes': notes,
      'imageData': imageData,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'status': status,
      'version': version,
    };
  }
}

class JourneyNote {
  final String id;
  final String text;
  final LatLng position;
  final Color color;
  final String? imagePath;

  JourneyNote({
    required this.id,
    required this.text,
    required this.position,
    this.color = Colors.blue,
    this.imagePath,
  });

  factory JourneyNote.fromMap(Map<String, dynamic> map) {
    final GeoPoint position = map['position'] as GeoPoint;
    return JourneyNote(
      id: map['id'] as String,
      text: map['text'] as String,
      position: LatLng(position.latitude, position.longitude),
      color: Color(map['color'] as int),
      imagePath: map['imagePath'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'position': GeoPoint(position.latitude, position.longitude),
      'color': color.value,
      'imagePath': imagePath,
    };
  }
}
