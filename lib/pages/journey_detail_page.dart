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
  Map<String, dynamic>? _journeyData;

  @override
  void initState() {
    super.initState();
    _checkShadowingStatus();
    _loadJourneyDataAndUpdate();
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

  Future<Map<String, dynamic>> _loadJourneyData() async {
    final doc = await _db.collection('journeys').doc(widget.journeyId).get();
    if (!doc.exists) throw Exception('Journey not found');
    final data = doc.data()!;
    // Load route points from subcollection
    final routeDoc =
        await doc.reference.collection('route').doc('points').get();
    List<LatLng> route = [];
    if (routeDoc.exists) {
      final routeData = routeDoc.data()!;
      route = (routeData['points'] as List<dynamic>? ?? [])
          .where((point) => point['lat'] != null && point['lng'] != null)
          .map((point) => LatLng(
                (point['lat'] as num).toDouble(),
                (point['lng'] as num).toDouble(),
              ))
          .toList();
    }
    // Load stops from subcollection
    final stopsSnapshot =
        await doc.reference.collection('stops').orderBy('order').get();
    final stops = stopsSnapshot.docs.map((d) => d.data()).toList();
    return {
      'data': data,
      'route': route,
      'stops': stops,
    };
  }

  Future<void> _loadJourneyDataAndUpdate() async {
    try {
      final data = await _loadJourneyData();
      if (mounted) {
        setState(() {
          _journeyData = data;
          _route = data['route'] as List<LatLng>;
          _stops = data['stops'] as List<Map<String, dynamic>>;
          _updateMarkersAndPolylines(_stops, _route);
        });
      }
    } catch (e) {
      print('Error loading journey data: $e');
    }
  }

  void _updateMarkersAndPolylines(
      List<Map<String, dynamic>> stops, List<LatLng> route) {
    _markers = stops.asMap().entries.map((entry) {
      final i = entry.key;
      final stop = entry.value;
      return Marker(
        markerId: MarkerId('stop_${i + 1}'),
        position: LatLng(stop['location']['lat'], stop['location']['lng']),
        infoWindow: InfoWindow(
          title: stop['name'],
          snippet: stop['description'],
        ),
      );
    }).toSet();
    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: route,
        color: Colors.amber,
        width: 3,
      ),
    };
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
    if (_journeyData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final data = _journeyData!['data'] as Map<String, dynamic>;
    
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
            if (data['mapThumbnailUrl'] != null)
              Image.network(
                data['mapThumbnailUrl'],
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
                      _buildInfoChip('Difficulty',
                          _getDifficultyIcons(data['difficulty'] ?? 1)),
                      _buildInfoChip('Cost', '\$' * (data['cost'] ?? 1)),
                      _buildInfoChip(
                          'People', '${data['recommendedPeople'] ?? 1}'),
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
                              : const Icon(Icons.place,
                                  color: Colors.amber),
                          title: Text(
                            stop['name'] ?? 'Stop ${index + 1}',
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
          onPressed: _isLoading ? null : _toggleShadowing,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isShadowing ? Colors.red : Colors.amber,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _isLoading
              ? const CircularProgressIndicator()
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isShadowing ? Icons.stop : Icons.play_arrow,
                      color: Colors.black,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isShadowing ? 'Stop Shadowing' : 'Start Shadowing',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
        ),
      ),
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

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  Future<void> _startShadowing() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    print(
        '[_startShadowing] Start: userId=${user.uid}, journeyId=${widget.journeyId}');

    try {
      print('[_startShadowing] Writing to shadows collection...');
      await _db
          .collection('shadows')
          .doc('${widget.journeyId}_${user.uid}')
          .set({
        'journeyId': widget.journeyId,
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonymous',
        'startedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });
      print('[_startShadowing] Successfully wrote to shadows collection.');

      print('[_startShadowing] Updating shadowers count in journeys...');
      await _db.collection('journeys').doc(widget.journeyId).update({
        'shadowers': FieldValue.increment(1),
      });
      print('[_startShadowing] Successfully updated shadowers count.');

      setState(() {
        _isShadowing = true;
      });

      if (mounted) {
        print('[_startShadowing] Showing success SnackBar.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully started shadowing')),
        );
      }
    } catch (e) {
      print('[_startShadowing] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting shadowing: $e')),
        );
      }
    } finally {
      if (mounted) {
        print('[_startShadowing] End. Setting _isLoading = false');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _stopShadowing() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    print(
        '[_stopShadowing] Start: userId=${user.uid}, journeyId=${widget.journeyId}');

    try {
      print('[_stopShadowing] Deleting from shadows collection...');
      await _db
          .collection('shadows')
          .doc('${widget.journeyId}_${user.uid}')
          .delete();
      print('[_stopShadowing] Successfully deleted from shadows collection.');

      print('[_stopShadowing] Updating shadowers count in journeys...');
      await _db.collection('journeys').doc(widget.journeyId).update({
        'shadowers': FieldValue.increment(-1),
      });
      print('[_stopShadowing] Successfully updated shadowers count.');

      setState(() {
        _isShadowing = false;
      });

      if (mounted) {
        print('[_stopShadowing] Showing success SnackBar.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully stopped shadowing')),
        );
      }
    } catch (e) {
      print('[_stopShadowing] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping shadowing: $e')),
        );
      }
    } finally {
      if (mounted) {
        print('[_stopShadowing] End. Setting _isLoading = false');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleShadowing() async {
    if (_isShadowing) {
      await _stopShadowing();
    } else {
      await _startShadowing();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
