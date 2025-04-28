import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  @override
  Widget build(BuildContext context) {
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

        final data = snapshot.data!.data() as Map<String, dynamic>;
        return Card(
          color: Colors.grey[850],
          child: ListTile(
            leading: data['mapThumbnailData'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ImageHandler.buildImagePreview(
                      context: context,
                      imageData: data['mapThumbnailData'],
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
            trailing: const Icon(Icons.chevron_right, color: Colors.amber),
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