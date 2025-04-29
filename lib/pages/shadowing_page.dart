import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/journey.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

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
  late Future<Map<String, dynamic>> _futureJourneyData;

  @override
  void initState() {
    super.initState();
    _futureJourneyData = _loadJourneyData();
  }

  Future<Map<String, dynamic>> _loadJourneyData() async {
    final journeyDoc =
        await _db.collection('journeys').doc(widget.journeyId).get();
    if (!journeyDoc.exists) throw Exception('Journey not found');
    final journeyData = journeyDoc.data()!;
    // Get route points from subcollection
    final routeDoc =
        await journeyDoc.reference.collection('route').doc('points').get();
    List<LatLng> route = [];
    if (routeDoc.exists) {
      final routeData = routeDoc.data()!;
      route = (routeData['points'] as List<dynamic>? ?? [])
          .where((point) =>
              point['latitude'] != null && point['longitude'] != null)
          .map((point) => LatLng(
                (point['latitude'] as num).toDouble(),
                (point['longitude'] as num).toDouble(),
              ))
          .toList();
    }
    // Get stops from subcollection
    final stopsSnapshot =
        await journeyDoc.reference.collection('stops').orderBy('order').get();
    final stops =
        stopsSnapshot.docs.map((doc) => Stop.fromMap(doc.data())).toList();
    // Initialize completed stops if not already set
    if (_completedStops.length != stops.length) {
      _completedStops = List<bool>.filled(stops.length, false);
    }
    return {
      'data': journeyData,
      'route': route,
      'stops': stops,
    };
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _futureJourneyData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          print('ShadowingPage error: \\${snapshot.error}');
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('An error occurred while loading the journey.'),
                  const SizedBox(height: 8),
                  Text(snapshot.error?.toString() ?? 'Unknown error',
                      style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          );
        }
        final data = snapshot.data!['data'] as Map<String, dynamic>;
        final route = snapshot.data!['route'] as List<LatLng>;
        final stops = snapshot.data!['stops'] as List<Stop>;
        // Ensure _stops and _route are up to date for map features and completion logic
        if (_stops != stops || _route != route) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _stops = stops;
              _route = route;
              _updateMapFeatures();
            });
          });
        }
        // Defensive: ensure _completedStops is correct length
        if (_completedStops.length != stops.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _completedStops = List<bool>.filled(stops.length, false);
            });
          });
        }
        final allCompleted =
            _completedStops.isNotEmpty && _completedStops.every((c) => c);
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
              data['title'] ?? 'Loading...',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Always show the interactive map with route and markers
              SizedBox(
                height: 200,
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: route.isNotEmpty
                          ? CameraPosition(target: route[0], zoom: 13)
                          : const CameraPosition(
                              target: LatLng(51.5074, -0.1278), zoom: 13),
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
                  ],
                ),
              ),
              // Journey Info
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['location'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${data['likes'] ?? 0} ',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const Icon(Icons.favorite,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 16),
                        const Icon(Icons.local_fire_department,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 4),
                        const Icon(Icons.attach_money,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 4),
                        const Icon(Icons.people, color: Colors.white, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
              // Checklist of Stops
              Expanded(
                child: stops.isEmpty
                    ? const Center(
                        child: Text('No stops found for this journey',
                            style: TextStyle(color: Colors.white)))
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ListView.builder(
                          itemCount: stops.length,
                          itemBuilder: (context, index) {
                            final stop = stops[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[850],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding:
                                        EdgeInsets.only(right: 4.0, top: 4),
                                    child: Icon(Icons.emoji_events,
                                        color: Colors.amber, size: 20),
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
                                  if (stop.imageData != null &&
                                      stop.imageData?['data'] != null)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.memory(
                                          base64Decode(
                                              stop.imageData?['data'] ?? ''),
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${index + 1}. ${stop.name}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            decoration: _completedStops[index]
                                                ? TextDecoration.lineThrough
                                                : null,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (stop.description.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 2.0),
                                            child: Text(
                                              stop.description,
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),
              // Completed Button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          allCompleted ? Colors.green : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    onPressed: allCompleted
                        ? () async {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) return;
                            // Find the shadow document
                            final shadowQuery = await _db
                                .collection('shadows')
                                .where('userId', isEqualTo: user.uid)
                                .where('journeyId', isEqualTo: widget.journeyId)
                                .where('status', isEqualTo: 'active')
                                .get();
                            if (shadowQuery.docs.isNotEmpty) {
                              final shadowDoc =
                                  shadowQuery.docs.first.reference;
                              await shadowDoc.update({
                                'status': 'completed',
                                'completedAt': FieldValue.serverTimestamp(),
                                'completedStops': _completedStops,
                              });
                              // Increment journey shadowers count
                              await _db
                                  .collection('journeys')
                                  .doc(widget.journeyId)
                                  .update(
                                      {'shadowers': FieldValue.increment(1)});
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Congratulations! Journey completed.')),
                                );
                                Navigator.of(context).pop();
                              }
                            }
                          }
                        : null,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

double min(double a, double b) => a < b ? a : b;
double max(double a, double b) => a > b ? a : b;
