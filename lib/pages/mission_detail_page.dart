import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/mission.dart';
import '../utils/image_handler.dart';

class MissionDetailPage extends StatefulWidget {
  final String missionId;

  const MissionDetailPage({
    super.key,
    required this.missionId,
  });

  @override
  State<MissionDetailPage> createState() => _MissionDetailPageState();
}

class _MissionDetailPageState extends State<MissionDetailPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isLoading = false;
  bool _isParticipating = false;

  @override
  void initState() {
    super.initState();
    _checkParticipationStatus();
  }

  Future<void> _checkParticipationStatus() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final participantDoc = await _db
        .collection('mission_participants')
        .doc('${widget.missionId}_${user.uid}')
        .get();

    setState(() {
      _isParticipating = participantDoc.exists;
    });
  }

  Future<void> _participateInMission() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Check if mission is still accepting participants
      final missionDoc =
          await _db.collection('missions').doc(widget.missionId).get();
      final mission = Mission.fromFirestore(missionDoc);

      if (mission.currentEntries >= mission.entryLimit) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Mission has reached its participant limit')),
          );
        }
        return;
      }

      // Add participant
      await _db
          .collection('mission_participants')
          .doc('${widget.missionId}_${user.uid}')
          .set({
        'missionId': widget.missionId,
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonymous',
        'joinedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // Update mission participant count
      await _db.collection('missions').doc(widget.missionId).update({
        'currentEntries': FieldValue.increment(1),
      });

      setState(() {
        _isParticipating = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully joined the mission')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining mission: $e')),
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

  void _updateMarkers(List<Map<String, dynamic>> locations) {
    _markers = locations.asMap().entries.map((entry) {
      final i = entry.key;
      final location = entry.value;
      return Marker(
        markerId: MarkerId('location_$i'),
        position: LatLng(location['lat'], location['lng']),
        infoWindow: InfoWindow(
          title: location['title'],
          snippet: location['description'],
        ),
      );
    }).toSet();
    setState(() {});
  }

  void _shareMission(Map<String, dynamic> data) {
    final title = data['title'] ?? 'Untitled Mission';
    final description = data['description'] ?? '';
    final subject = data['subject'] ?? '';
    final purpose = data['purpose'] ?? '';
    final deadline = data['deadline'] != null
        ? (data['deadline'] as Timestamp).toDate().toString().split(' ')[0]
        : 'No deadline';
    final entryLimit = data['entryLimit']?.toString() ?? '0';
    final currentEntries = data['currentEntries']?.toString() ?? '0';

    final shareText = '''
Check out this research mission: $title
$description

Subject: $subject
Purpose: $purpose
Deadline: $deadline
Participants: $currentEntries/$entryLimit

Join me in contributing to this research!
''';
    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('missions').doc(widget.missionId).snapshots(),
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

        final docData = snapshot.data?.data();
        if (docData == null) {
          return const Center(child: Text('Mission data not found'));
        }
        final data = docData as Map<String, dynamic>;
        final locations =
            List<Map<String, dynamic>>.from(data['locations'] ?? []);
        _updateMarkers(locations);

        return Scaffold(
          appBar: AppBar(
            title: Text(data['title'] ?? 'Mission Detail'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _shareMission(data),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mission Image
                if (data['mapThumbnailData'] != null)
                  ImageHandler.buildImagePreview(
                    context: context,
                    imageData: data['mapThumbnailData'],
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

                // Mission Details
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['title'] ?? 'Untitled Mission',
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
                      // Research Details
                      const Text(
                        'Research Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow('Subject', data['subject'] ?? ''),
                      _buildDetailRow('Purpose', data['purpose'] ?? ''),
                      _buildDetailRow(
                        'Deadline',
                        data['deadline'] != null
                            ? (data['deadline'] as Timestamp)
                                .toDate()
                                .toString()
                                .split(' ')[0]
                            : 'No deadline',
                      ),
                      _buildDetailRow(
                        'Participants',
                        '${data['currentEntries'] ?? 0}/${data['entryLimit'] ?? 0}',
                      ),
                      if (data['gdprFileUrl'] != null) ...[
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Open GDPR file
                          },
                          icon: const Icon(Icons.description),
                          label: const Text('View GDPR Document'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Tags
                      Wrap(
                        spacing: 8,
                        children: (data['tags'] as List<dynamic>? ?? [])
                            .map((tag) => Chip(
                                  label: Text(
                                    tag.toString(),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: Colors.grey[800],
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      // Map
                      const Text(
                        'Mission Locations',
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
                          initialCameraPosition: locations.isNotEmpty
                              ? CameraPosition(
                                  target: LatLng(
                                    locations[0]['lat'],
                                    locations[0]['lng'],
                                  ),
                                  zoom: 13,
                                )
                              : const CameraPosition(
                                  target: LatLng(51.5074, -0.1278),
                                  zoom: 13,
                                ),
                          markers: _markers,
                        ),
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
              onPressed:
                  _isParticipating || _isLoading ? null : _participateInMission,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(
                      _isParticipating
                          ? 'Already Participating'
                          : 'Join Mission',
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
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
