import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/image_handler.dart';

class JourneyDetailPage extends StatefulWidget {
  final String journeyId;

  const JourneyDetailPage({
    super.key,
    required this.journeyId,
  });

  @override
  State<JourneyDetailPage> createState() => _JourneyDetailPageState();
}

class _JourneyDetailPageState extends State<JourneyDetailPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> _route = [];
  List<Map<String, dynamic>> _stops = [];
  bool _isLoading = false;
  bool _isShadowing = false;

  @override
  void initState() {
    super.initState();
    _checkShadowingStatus();
  }

  Future<void> _checkShadowingStatus() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final shadowDoc = await _db
        .collection('shadows')
        .doc('${widget.journeyId}_${user.uid}')
        .get();

    setState(() {
      _isShadowing = shadowDoc.exists;
    });
  }

  Future<void> _startShadowing() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await _db.collection('shadows').doc('${widget.journeyId}_${user.uid}').set({
        'journeyId': widget.journeyId,
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonymous',
        'startedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      await _db.collection('journeys').doc(widget.journeyId).update({
        'shadowers': FieldValue.increment(1),
      });

      setState(() {
        _isShadowing = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully started shadowing')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting shadowing: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _updateMarkersAndPolylines() {
    _markers = _stops.asMap().entries.map((entry) {
      final i = entry.key;
      final stop = entry.value;
      return Marker(
        markerId: MarkerId('stop_$i'),
        position: LatLng(stop['lat'], stop['lng']),
        infoWindow: InfoWindow(
          title: stop['title'],
          snippet: stop['description'],
        ),
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

        final data = snapshot.data!.data() as Map<String, dynamic>;
        _route = (data['route'] as List<dynamic>? ?? [])
            .map((point) => LatLng(point['lat'], point['lng']))
            .toList();
        _stops = List<Map<String, dynamic>>.from(data['stops'] ?? []);
        _updateMarkersAndPolylines();

        return Scaffold(
          appBar: AppBar(
            title: Text(data['title'] ?? 'Journey Detail'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _shareJourney(data),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Journey Image
                if (data['mapThumbnailData'] != null)
                  ImageHandler.buildImagePreview(
                    context: context,
                    imageData: data['mapThumbnailData'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                else if (data['imageData'] != null)
                  ImageHandler.buildImagePreview(
                    context: context,
                    imageData: data['imageData'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                else
                  Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey[900],
                    child: const Center(
                      child: Icon(Icons.map, size: 64, color: Colors.grey),
                    ),
                  ),

                // Journey Details
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['title'] ?? 'Untitled Journey',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['description'] ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Journey Info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInfoChip('Difficulty', _getDifficultyIcons(data['difficulty'] ?? 1)),
                          _buildInfoChip('Cost', '\$' * (data['cost'] ?? 1)),
                          _buildInfoChip('People', '${data['recommendedPeople'] ?? 1}'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Map
                      const Text(
                        'Journey Route',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 300,
                        child: GoogleMap(
                          onMapCreated: _onMapCreated,
                          initialCameraPosition: _route.isNotEmpty
                              ? CameraPosition(
                                  target: _route[0],
                                  zoom: 13,
                                )
                              : const CameraPosition(
                                  target: LatLng(51.5074, -0.1278),
                                  zoom: 13,
                                ),
                          markers: _markers,
                          polylines: _polylines,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Stops
                      const Text(
                        'Stops',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _stops.length,
                        itemBuilder: (context, index) {
                          final stop = _stops[index];
                          return Card(
                            color: Colors.grey[850],
                            child: ListTile(
                              leading: stop['imageData'] != null
                                  ? ImageHandler.buildImagePreview(
                                      context: context,
                                      imageData: stop['imageData'],
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(Icons.place, color: Colors.amber),
                              title: Text(
                                stop['title'] ?? 'Stop ${index + 1}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                stop['description'] ?? '',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              trailing: Text(
                                '#${index + 1}',
                                style: const TextStyle(color: Colors.amber),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isShadowing || _isLoading
                  ? null
                  : _startShadowing,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(
                      _isShadowing
                          ? 'Already Shadowing'
                          : 'Start Shadowing',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: $value',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _getDifficultyIcons(int difficulty) {
    return '💧' * difficulty;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
} 