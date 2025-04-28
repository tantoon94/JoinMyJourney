import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/journey.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShadowingPage extends StatefulWidget {
  final String journeyId;
  final String creatorId;

  const ShadowingPage({
    super.key,
    required this.journeyId,
    required this.creatorId,
  });

  @override
  State<ShadowingPage> createState() => _ShadowingPageState();
}

class _ShadowingPageState extends State<ShadowingPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  GoogleMapController? _mapController;
  Map<String, dynamic>? _journeyData;
  List<LatLng> _route = [];
  List<Stop> _stops = [];
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  List<bool> _completedStops = [];

  @override
  void initState() {
    super.initState();
    _loadJourneyData();
  }

  Future<void> _loadJourneyData() async {
    final journeyDoc = await _db.collection('journeys')
        .doc(widget.journeyId)
        .get();
    if (!journeyDoc.exists) return;

    setState(() {
      _journeyData = journeyDoc.data();
    });

    // Get route points from subcollection
    final routeDoc = await _db.collection('journeys')
        .doc(widget.journeyId)
        .collection('route')
        .doc('points')
        .get();
    
    if (routeDoc.exists) {
      final routeData = routeDoc.data()!;
      setState(() {
        _route = (routeData['points'] as List<dynamic>? ?? [])
            .map((point) => LatLng(point['lat'], point['lng']))
            .toList();
      });
    }

    // Get stops from subcollection
    final stopsSnapshot = await _db.collection('journeys')
        .doc(widget.journeyId)
        .collection('stops')
        .orderBy('order')
        .get();
    
    setState(() {
      _stops = stopsSnapshot.docs
          .map((doc) => Stop.fromMap(doc.data()))
          .toList();
      _completedStops = List.filled(_stops.length, false);
    });

    _updateMapFeatures();
  }

  void _updateMapFeatures() {
    if (_stops.isEmpty) return;

    // Create markers
    final markers = _stops.asMap().entries.map((entry) {
      final index = entry.key;
      final stop = entry.value;
      return Marker(
        markerId: MarkerId('stop_$index'),
        position: stop.location,
        infoWindow: InfoWindow(title: stop.name, snippet: stop.description),
      );
    }).toSet();

    // Create polyline from route
    final polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _route,
        color: Colors.amber,
        width: 3,
      ),
    };

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });

    // Animate camera to show all stops
    if (_mapController != null && _route.isNotEmpty) {
      final bounds = _calculateBounds(_route);
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    }
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;

    for (final point in points) {
      minLat = minLat == null ? point.latitude : min(minLat, point.latitude);
      maxLat = maxLat == null ? point.latitude : max(maxLat, point.latitude);
      minLng = minLng == null ? point.longitude : min(minLng, point.longitude);
      maxLng = maxLng == null ? point.longitude : max(maxLng, point.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  Future<void> _shadowJourney() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check if already shadowing
      final existingShadow = await _db.collection('shadows')
          .where('userId', isEqualTo: user.uid)
          .where('journeyId', isEqualTo: widget.journeyId)
          .where('status', isEqualTo: 'active')
          .get();

      if (existingShadow.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are already shadowing this journey')),
        );
        return;
      }

      // Add shadow record
      await _db.collection('shadows').add({
        'userId': user.uid,
        'journeyId': widget.journeyId,
        'creatorId': widget.creatorId,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'completedStops': List.filled(_stops.length, false),
        'currentStop': 0,
      });

      // Update journey shadowers count
      await _db.collection('journeys').doc(widget.journeyId)
          .update({'shadowers': FieldValue.increment(1)});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are now shadowing this journey!')),
      );
    } catch (e) {
      print('Error shadowing journey: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error shadowing journey: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A2A2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _journeyData?['title'] ?? 'Loading...',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(51.5074, -0.1278), // London
                    zoom: 13,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _updateMapFeatures();
                  },
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  mapType: MapType.normal,
                ),
                if (_journeyData == null)
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _journeyData?['location'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${_journeyData?['likes'] ?? 0} ',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const Icon(Icons.favorite, color: Colors.white, size: 18),
                      const Spacer(),
                      const Icon(Icons.local_fire_department, color: Colors.white, size: 18),
                      const SizedBox(width: 4),
                      const Icon(Icons.attach_money, color: Colors.white, size: 18),
                      const SizedBox(width: 4),
                      const Icon(Icons.people, color: Colors.white, size: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _stops.length,
                      itemBuilder: (context, index) {
                        final stop = _stops[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(right: 4.0),
                              child: Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                            ),
                            Checkbox(
                              value: _completedStops[index],
                              onChanged: (val) {
                                setState(() {
                                  _completedStops[index] = val ?? false;
                                });
                              },
                              activeColor: Colors.amber,
                            ),
                            Expanded(
                              child: Text(
                                '${index + 1}. ${stop.name}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  decoration: _completedStops[index]
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          // TODO: Implement directions
                        },
                        icon: const Icon(Icons.pin_drop, color: Colors.black),
                        label: const Text('Get Directions', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          // TODO: Implement share
                        },
                        icon: const Icon(Icons.share, color: Colors.black),
                        label: const Text('Share', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.directions_walk),
                      label: const Text('Shadow this journey'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: _shadowJourney,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double min(double a, double b) => a < b ? a : b;
double max(double a, double b) => a > b ? a : b; 