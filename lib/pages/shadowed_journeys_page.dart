import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'shadowing_page.dart';
import '../utils/image_handler.dart';

class ShadowedJourneysPage extends StatefulWidget {
  const ShadowedJourneysPage({super.key});

  @override
  State<ShadowedJourneysPage> createState() => _ShadowedJourneysPageState();
}

class _ShadowedJourneysPageState extends State<ShadowedJourneysPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _stopShadowing(String journeyId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Delete from shadows collection
      await _db
          .collection('shadows')
          .doc('${journeyId}_${user.uid}')
          .delete();

      // Decrement shadowers count
      await _db.collection('journeys').doc(journeyId).update({
        'shadowers': FieldValue.increment(-1),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully stopped shadowing')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping shadowing: $e')),
      );
    }
  }

  Future<void> _confirmStopShadowing(String journeyId, String journeyTitle) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[850],
          title: const Text('Stop Shadowing?', 
            style: TextStyle(color: Colors.white)),
          content: Text(
            'Are you sure you want to stop shadowing "$journeyTitle"?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', 
                style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _stopShadowing(journeyId);
              },
              child: const Text('Stop Shadowing', 
                style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shadowed Journeys'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('shadows')
            .where('userId', isEqualTo: _auth.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_walk, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No journeys shadowed yet!',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Browse journeys and tap the "Shadow" button to follow them here.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final shadow = snapshot.data!.docs[index];
              return _buildShadowedJourneyCard(shadow['journeyId']);
            },
          );
        },
      ),
    );
  }

  Widget _buildShadowedJourneyCard(String journeyId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('journeys').doc(journeyId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final docData = snapshot.data?.data();
        if (docData == null) {
          return const SizedBox.shrink();
        }
        final data = docData as Map<String, dynamic>;
        return Card(
          color: Colors.grey[850],
          child: ListTile(
            leading: data['mapThumbnailUrl'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      data['mapThumbnailUrl'],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  )
                : data['imageData'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ImageHandler.buildImagePreview(
                          context: context,
                          imageData: data['imageData'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.map, color: Colors.grey),
                      ),
            title: Text(
              data['title'] ?? 'Untitled Journey',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              data['description'] ?? '',
              style: const TextStyle(color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.amber),
              color: Colors.grey[850],
              onSelected: (value) {
                if (value == 'view') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ShadowingPage(
                        journeyId: journeyId,
                        creatorId: data['creatorId'],
                      ),
                    ),
                  );
                } else if (value == 'stop') {
                  _confirmStopShadowing(journeyId, data['title'] ?? 'Untitled Journey');
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'view',
                  child: Row(
                    children: const [
                      Icon(Icons.visibility, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Text('View Journey', 
                        style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'stop',
                  child: Row(
                    children: const [
                      Icon(Icons.stop_circle, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Stop Shadowing', 
                        style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShadowingPage(
                    journeyId: journeyId,
                    creatorId: data['creatorId'],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
