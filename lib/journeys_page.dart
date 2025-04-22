import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

class JourneysPage extends StatefulWidget {
  const JourneysPage({super.key});

  @override
  State<JourneysPage> createState() => _JourneysPageState();
}

class _JourneysPageState extends State<JourneysPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'Missions', 'Adventures', 'Chill'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Filter
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.black87,
                    ),
                  ),
                );
              },
            ),
          ),
          // Journeys List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                  return Center(
                    child: Text(
                      _selectedCategory == 'All'
                          ? 'No journeys available'
                          : 'No journeys in $_selectedCategory category',
                    ),
                  );
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
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyCard(DocumentSnapshot journey) {
    final data = journey.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data['imageUrl'] != null)
            Image.network(
              data['imageUrl'],
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: data['creatorPhotoUrl'] != null
                          ? NetworkImage(data['creatorPhotoUrl'])
                          : null,
                      child: data['creatorPhotoUrl'] == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['creatorName'] ?? 'Anonymous',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            data['category'] ?? 'Uncategorized',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () {
                        Share.share(
                          'Check out this amazing journey: ${data['title']}\n'
                          'Created by: ${data['creatorName']}\n'
                          'Category: ${data['category']}\n'
                          'Recommended for ${data['recommendedPeople']} people\n'
                          'Estimated cost: £${data['estimatedCost']}\n'
                          'Duration: ${data['durationInHours']} hours',
                        );
                      },
                    ),
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
                const SizedBox(height: 12),
                Text(
                  data['title'] ?? 'Untitled Journey',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (data['description'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    data['description'],
                    style: TextStyle(color: Colors.grey[600]),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
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
                    const SizedBox(width: 16),
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${data['durationInHours'] ?? 2} hours',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLike(String journeyId) async {
    if (_auth.currentUser == null) return;

    final likeDoc =
        _db.collection('likes').doc('${_auth.currentUser!.uid}_$journeyId');
    final likeSnapshot = await likeDoc.get();

    if (likeSnapshot.exists) {
      await likeDoc.delete();
    } else {
      await likeDoc.set({
        'userId': _auth.currentUser!.uid,
        'journeyId': journeyId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
} 