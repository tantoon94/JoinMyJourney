import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'route_detail_page.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Missions', 'Adventures', 'Chill'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Journeys'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = category);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _selectedCategory == 'All'
            ? _db
                .collection('journeys')
                .orderBy('createdAt', descending: true)
                .snapshots()
            : _db
                .collection('journeys')
                .where('category', isEqualTo: _selectedCategory)
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No journeys found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final journey = snapshot.data!.docs[index];
              return _buildJourneyCard(journey);
            },
          );
        },
      ),
    );
  }

  Widget _buildJourneyCard(DocumentSnapshot journey) {
    final data = journey.data() as Map<String, dynamic>?;
    if (data == null) {
      return const SizedBox.shrink();
    }

    final userId = data['creatorId'] as String?;
    if (userId == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RouteDetailPage(journeyId: journey.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: _db.collection('users').doc(userId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const ListTile(
                    leading: CircleAvatar(child: Icon(Icons.person)),
                    title: Text('Loading...'),
                  );
                }
                
                final userData = snapshot.data?.data() as Map<String, dynamic>?;
                final photoUrl = userData?['photoUrl'] as String?;
                final username = userData?['username'] as String? ?? 'User';
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: photoUrl != null
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(username),
                  subtitle: Text(data['category'] as String? ?? ''),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Text('Follow User'),
                        onTap: () => _followUser(userId),
                      ),
                      PopupMenuItem(
                        child: const Text('Save Journey'),
                        onTap: () => _saveJourney(journey.id),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (data['imageUrl'] != null)
              CachedNetworkImage(
                imageUrl: data['imageUrl'] as String,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'] as String? ?? 'Untitled Journey',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (data['description'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      data['description'] as String,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.people, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${data['recommendedPeople'] ?? 2} people',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '£${data['estimatedCost'] ?? '15-20'}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const Spacer(),
                      StreamBuilder<DocumentSnapshot>(
                        stream: _db
                            .collection('likes')
                            .doc('${_auth.currentUser?.uid}_${journey.id}')
                            .snapshots(),
                        builder: (context, snapshot) {
                          final isLiked = snapshot.data?.exists ?? false;
                          return IconButton(
                            icon: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.red : Colors.grey,
                            ),
                            onPressed: () => _toggleLike(journey.id),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLike(String journeyId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final likeDoc = _db.collection('likes').doc('${user.uid}_$journeyId');
    final likeExists = (await likeDoc.get()).exists;

    if (likeExists) {
      await likeDoc.delete();
    } else {
      await likeDoc.set({
        'userId': user.uid,
        'journeyId': journeyId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _followUser(String userId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final followDoc = _db.collection('follows').doc('${user.uid}_$userId');
    final followExists = (await followDoc.get()).exists;

    if (followExists) {
      await followDoc.delete();
    } else {
      await followDoc.set({
        'followerId': user.uid,
        'followingId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _saveJourney(String journeyId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.collection('pins').add({
      'userId': user.uid,
      'journeyId': journeyId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journey saved to pins')),
      );
    }
  }
} 