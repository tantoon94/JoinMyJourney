import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

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

  void _onMapCreated(GoogleMapController controller, List<GeoPoint> waypoints) {
    _mapController = controller;
    _createMarkersAndPolylines(waypoints);
    
    if (waypoints.isNotEmpty) {
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          _getBounds(waypoints),
          50.0,
        ),
      );
    }
  }

  LatLngBounds _getBounds(List<GeoPoint> waypoints) {
    double minLat = waypoints[0].latitude;
    double maxLat = waypoints[0].latitude;
    double minLng = waypoints[0].longitude;
    double maxLng = waypoints[0].longitude;

    for (var point in waypoints) {
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

  void _createMarkersAndPolylines(List<GeoPoint> waypoints) {
    _markers.clear();
    _polylines.clear();

    // Create markers for each waypoint
    for (var i = 0; i < waypoints.length; i++) {
      final point = waypoints[i];
      _markers.add(
        Marker(
          markerId: MarkerId('waypoint_$i'),
          position: LatLng(point.latitude, point.longitude),
          infoWindow: InfoWindow(title: 'Stop ${i + 1}'),
        ),
      );
    }

    // Create polyline connecting all waypoints
    if (waypoints.length >= 2) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: waypoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList(),
          color: Colors.blue,
          width: 3,
        ),
      );
    }

    setState(() {});
  }

  void _shareJourney(Map<String, dynamic> data) {
    final title = data['title'] ?? 'Untitled Journey';
    final description = data['description'] ?? '';
    final category = data['category'] ?? '';
    final recommendedPeople = data['recommendedPeople']?.toString() ?? '2';
    final estimatedCost = data['estimatedCost']?.toString() ?? '15-20';

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
      stream: _db.collection('journeys').doc(widget.journeyId).snapshots(),
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
        final steps = (data['steps'] as List? ?? []).cast<Map<String, dynamic>>();
        final waypoints = (data['waypoints'] as List? ?? []).cast<GeoPoint>();

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
                  onMapCreated: (controller) => _onMapCreated(controller, waypoints),
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(51.5074, -0.1278), // London coordinates
                    zoom: 13,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: steps.length,
                  itemBuilder: (context, index) {
                    final step = steps[index];
                    return _buildStepItem(step, index + 1);
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
  }

  Widget _buildStepItem(Map<String, dynamic> step, int index) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor,
        child: Text(
          index.toString(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(step['name'] ?? 'Step $index'),
      subtitle: Text(step['description'] ?? ''),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (step['duration'] != null) ...[
            const Icon(Icons.access_time, size: 16),
            const SizedBox(width: 4),
            Text('${step['duration']} min'),
            const SizedBox(width: 16),
          ],
          if (step['distance'] != null) ...[
            const Icon(Icons.directions_walk, size: 16),
            const SizedBox(width: 4),
            Text('${step['distance']} m'),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
} 