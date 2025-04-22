import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class JourneyMapPage extends StatefulWidget {
  const JourneyMapPage({super.key});

  @override
  State<JourneyMapPage> createState() => _JourneyMapPageState();
}

class _JourneyMapPageState extends State<JourneyMapPage> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = [];
  bool _isTracking = false;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _journeyId;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    final status = await Geolocator.checkPermission();
    if (status == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      if (result == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required')),
        );
        return;
      }
    }
    if (status == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission is permanently denied')),
      );
      return;
    }
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _updateCamera();
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _updateCamera() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        ),
      );
    }
  }

  void _startTracking() async {
    setState(() {
      _isTracking = true;
      _routePoints = [];
      _polylines = {};
      _startTime = DateTime.now();
    });

    // Create new journey document
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    // Get user data
    final userDoc = await _db.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User data not found')),
      );
      return;
    }

    final userData = userDoc.data();
    if (userData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User data is null')),
      );
      return;
    }

    final username = userData['username'] as String?;
    if (username == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username not found')),
      );
      return;
    }

    // Create journey document
    final journeyData = {
      'title': 'Tracked Journey',
      'description': 'Journey tracked in real-time',
      'creatorId': user.uid,
      'creatorName': username,
      'creatorPhotoUrl': userData['photoUrl'] ?? '',
      'category': 'Missions',
      'recommendedPeople': 1,
      'estimatedCost': 0.0,
      'durationInHours': 0.0,
      'steps': [],
      'waypoints': [],
      'trackPoints': [],
      'createdAt': FieldValue.serverTimestamp(),
      'likes': 0,
      'isPublic': true,
    };

    // Save journey using batch write
    final batch = _db.batch();
    
    // Add to main journeys collection
    final journeyRef = _db.collection('journeys').doc();
    batch.set(journeyRef, journeyData);
    
    // Add to user's journeys subcollection
    final userJourneyRef = _db
        .collection('users')
        .doc(user.uid)
        .collection('journeys')
        .doc(journeyRef.id);
    batch.set(userJourneyRef, {
      'journeyId': journeyRef.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Update user's journey count
    batch.update(
      _db.collection('users').doc(user.uid),
      {'journeyCount': FieldValue.increment(1)},
    );

    await batch.commit();
    _journeyId = journeyRef.id;

    // Start location updates
    _positionStream = Geolocator.getPositionStream().listen((position) {
      setState(() {
        _currentPosition = position;
        final point = LatLng(position.latitude, position.longitude);
        _routePoints.add(point);
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: _routePoints,
            color: Colors.blue,
            width: 5,
          ),
        };
      });

      // Update track points in Firestore
      if (_journeyId != null) {
        _db.collection('journeys').doc(_journeyId).update({
          'trackPoints': _routePoints.map((point) => {
            'latitude': point.latitude,
            'longitude': point.longitude,
          }).toList(),
        });
      }
    });
  }

  Future<void> _stopTracking() async {
    _positionStream?.cancel();
    setState(() {
      _isTracking = false;
    });

    // Update journey with final data
    if (_journeyId != null) {
      final distance = _calculateDistance();
      final duration = _startTime != null
          ? DateTime.now().difference(_startTime!).inHours.toDouble()
          : 0.0;

      await _db.collection('journeys').doc(_journeyId).update({
        'title': 'Tracked Journey (${distance.toStringAsFixed(1)} km)',
        'durationInHours': duration,
        'trackPoints': _routePoints.map((point) => {
          'latitude': point.latitude,
          'longitude': point.longitude,
        }).toList(),
      });
    }
  }

  double _calculateDistance() {
    if (_routePoints.length < 2) return 0;
    double totalDistance = 0;
    for (int i = 0; i < _routePoints.length - 1; i++) {
      totalDistance += Geolocator.distanceBetween(
        _routePoints[i].latitude,
        _routePoints[i].longitude,
        _routePoints[i + 1].latitude,
        _routePoints[i + 1].longitude,
      );
    }
    return totalDistance / 1000; // Convert to kilometers
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Journey'),
        actions: [
          IconButton(
            icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
            onPressed: _isTracking ? _stopTracking : _startTracking,
          ),
        ],
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ),
                zoom: 15,
              ),
              onMapCreated: (controller) => _mapController = controller,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              polylines: _polylines,
              markers: _routePoints.isNotEmpty
                  ? {
                      Marker(
                        markerId: const MarkerId('start'),
                        position: _routePoints.first,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueGreen,
                        ),
                      ),
                      Marker(
                        markerId: const MarkerId('end'),
                        position: _routePoints.last,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed,
                        ),
                      ),
                    }
                  : {},
            ),
    );
  }
} 