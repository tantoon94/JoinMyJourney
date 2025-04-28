import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../models/journey.dart';
import '../utils/image_handler.dart';

class RouteDetailPage extends StatefulWidget {
  final String journeyId;

  const RouteDetailPage({
    super.key,
    required this.journeyId,
  });

  @override
  State<RouteDetailPage> createState() => _RouteDetailPageState();
}

class _RouteDetailPageState extends State<RouteDetailPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> _route = [];
  List<Stop> _stops = [];

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _updateMarkersAndPolylines();
    if (_route.isNotEmpty) {
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(_getBounds(_route), 50.0),
      );
    }
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;
    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _updateMarkersAndPolylines() {
    _markers = _stops.asMap().entries.map((entry) {
      final i = entry.key;
      final stop = entry.value;
      return Marker(
        markerId: MarkerId('stop_$i'),
        position: stop.location,
        infoWindow: InfoWindow(title: stop.name, snippet: stop.description),
      );
    }).toSet();
    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _route,
        color: Colors.amber,
        width: 3,
      ),
    };
    setState(() {});
  }

  void _shareJourney(Map<String, dynamic> data) {
    final title = data['title'] ?? 'Untitled Journey';
    final description = data['description'] ?? '';
    final category = data['category'] ?? '';
    final recommendedPeople = data['recommendedPeople']?.toString() ?? '2';
    final estimatedCost = data['cost']?.toString() ?? '1';
    final shareText = '''
Check out this journey: $title
$description

Category: $category
Recommended People: $recommendedPeople
Estimated Cost: £$estimatedCost

Join me on this adventure!
''';
    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('journeys')
          .doc(widget.journeyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final journey = snapshot.data!;
        final data = journey.data() as Map<String, dynamic>;
        
        return StreamBuilder<DocumentSnapshot>(
          stream: _db.collection('journeys')
              .doc(widget.journeyId)
              .collection('route')
              .doc('points')
              .snapshots(),
          builder: (context, routeSnapshot) {
            if (routeSnapshot.hasData) {
              final routeData = routeSnapshot.data!.data() as Map<String, dynamic>;
              _route = (routeData['points'] as List<dynamic>? ?? [])
                  .map((point) => LatLng(point['lat'], point['lng']))
                  .toList();
            }

            return StreamBuilder<QuerySnapshot>(
              stream: _db.collection('journeys')
                  .doc(widget.journeyId)
                  .collection('stops')
                  .orderBy('order')
                  .snapshots(),
              builder: (context, stopsSnapshot) {
                if (stopsSnapshot.hasData) {
                  _stops = stopsSnapshot.data!.docs
                      .map((doc) => Stop.fromMap(doc.data() as Map<String, dynamic>))
                      .toList();
                }

                _updateMarkersAndPolylines();
                return Scaffold(
                  appBar: AppBar(
                    title: Text(data['title'] ?? 'Route Detail'),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () => _shareJourney(data),
                      ),
                    ],
                  ),
                  body: Column(
                    children: [
                      SizedBox(
                        height: 300,
                        child: GoogleMap(
                          onMapCreated: _onMapCreated,
                          initialCameraPosition: _route.isNotEmpty
                              ? CameraPosition(target: _route[0], zoom: 13)
                              : const CameraPosition(target: LatLng(51.5074, -0.1278), zoom: 13),
                          markers: _markers,
                          polylines: _polylines,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _stops.length,
                          itemBuilder: (context, index) {
                            final stop = _stops[index];
                            return Card(
                              color: Colors.grey[900],
                              child: ListTile(
                                leading: stop.imageData != null
                                    ? ImageHandler.buildImagePreview(
                                        context: context,
                                        imageData: stop.imageData,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(Icons.place, color: Colors.amber),
                                title: Text(stop.name, style: const TextStyle(color: Colors.white)),
                                subtitle: Text(stop.description, style: const TextStyle(color: Colors.grey)),
                                trailing: Text('#${stop.order}', style: const TextStyle(color: Colors.amber)),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.directions),
                                label: const Text('Get Directions'),
                                onPressed: () {
                                  // TODO: Implement directions functionality
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.share),
                                label: const Text('Share'),
                                onPressed: () => _shareJourney(data),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
} 