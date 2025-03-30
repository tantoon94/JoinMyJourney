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
    });

    // Create new journey document
    final user = _auth.currentUser;
    if (user != null) {
      final journeyRef = await _db.collection('journeys').add({
        'userId': user.uid,
        'startTime': FieldValue.serverTimestamp(),
        'route': [],
      });
      _journeyId = journeyRef.id;
    }

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

      // Update route in Firestore
      if (_journeyId != null) {
        _db.collection('journeys').doc(_journeyId).update({
          'route': _routePoints.map((point) => {
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

    // Update journey end time
    if (_journeyId != null) {
      await _db.collection('journeys').doc(_journeyId).update({
        'endTime': FieldValue.serverTimestamp(),
        'distance': _calculateDistance(),
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