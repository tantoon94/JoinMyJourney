import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Saved'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pinned'),
              Tab(text: 'Shadowed'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPinnedJourneys(),
            _buildShadowedJourneys(),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedJourneys() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('pins')
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
            child: Text('You have no pinned journeys'),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final pin = snapshot.data!.docs[index];
            return _buildSavedJourneyCard(
              pin['journeyId'],
              isPinned: true,
            );
          },
        );
      },
    );
  }

  Widget _buildShadowedJourneys() {
    return StreamBuilder<QuerySnapshot>(
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
            child: Text('You have no shadowed journeys'),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final shadow = snapshot.data!.docs[index];
            return _buildSavedJourneyCard(
              shadow['journeyId'],
              isPinned: false,
            );
          },
        );
      },
    );
  }

  Widget _buildSavedJourneyCard(String journeyId, {required bool isPinned}) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('journeys').doc(journeyId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final journey = snapshot.data!;
        final data = journey.data() as Map<String, dynamic>;

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: data['imageUrl'] != null
                        ? CachedNetworkImage(
                            imageUrl: data['imageUrl'],
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.map, size: 50),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['title'] ?? 'Untitled Journey',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          data['description'] ?? '',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    Icon(
                      isPinned ? Icons.push_pin : Icons.remove_red_eye,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    StreamBuilder<DocumentSnapshot>(
                      stream: _db
                          .collection('likes')
                          .doc('${_auth.currentUser?.uid}_$journeyId')
                          .snapshots(),
                      builder: (context, snapshot) {
                        final isLiked = snapshot.data?.exists ?? false;
                        return Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.white,
                          size: 20,
                        );
                      },
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
} 