import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../models/journey.dart';
import '../utils/image_handler.dart';
import 'create_journey_page.dart';

class JourneysPage extends StatefulWidget {
  const JourneysPage({super.key});

  @override
  State<JourneysPage> createState() => _JourneysPageState();
}

class _JourneysPageState extends State<JourneysPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'Missions', 'Adventures', 'Chill'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextField(
                          onChanged: (value) => setState(() => _searchQuery = value),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Search journeys...',
                            hintStyle: TextStyle(color: Colors.grey),
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.star_border, color: Colors.white),
                        onPressed: () {
                          // TODO: Implement favorites functionality
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Category Filter
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = category == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            category,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedCategory = category);
                          },
                          backgroundColor: Colors.grey[800],
                          selectedColor: Theme.of(context).primaryColor,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Journeys List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getJourneysStream(),
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
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }

                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = data['title']?.toString().toLowerCase() ?? '';
                  final creatorName = data['creatorName']?.toString().toLowerCase() ?? '';
                  final searchLower = _searchQuery.toLowerCase();
                  return title.contains(searchLower) || creatorName.contains(searchLower);
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    return _buildJourneyCard(doc);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getJourneysStream() {
    Query<Map<String, dynamic>> query = _db.collection('journeys')
        .where('status', isEqualTo: 'active')
        .where('visibility', isEqualTo: 'public');
    
    if (_selectedCategory != 'All') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }
    
    return query.orderBy('createdAt', descending: true).snapshots();
  }

  Widget _buildJourneyCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final currentUserId = _auth.currentUser?.uid;
    final isCreator = currentUserId == data['creatorId'];
    final journeyId = doc.id;
    
    print('Building journey card for ID: $journeyId');
    print('Title: ${data['title']}');
    print('Description: ${data['description']}');
    print('Map thumbnail present: ${data['mapThumbnailData'] != null}');
    if (data['mapThumbnailData'] != null) {
      print('Map thumbnail size: ${data['mapThumbnailData']['size']} bytes');
      print('Map thumbnail type: ${data['mapThumbnailData']['type']}');
      print('Map thumbnail dimensions: ${data['mapThumbnailData']['dimensions']}');
    }
    print('Total stops: ${data['totalStops']}');
    print('Created by: ${data['creatorName']}');
    print('Created at: ${data['createdAt']}');
    
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('shadows')
          .where('userId', isEqualTo: currentUserId)
          .where('journeyId', isEqualTo: journeyId)
          .snapshots(),
      builder: (context, shadowSnapshot) {
        final isShadowed = shadowSnapshot.hasData && shadowSnapshot.data!.docs.isNotEmpty;
        bool isLoading = false;
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: Colors.grey[850],
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              // Navigate to journey detail page
              Navigator.pushNamed(
                context,
                '/journey_detail',
                arguments: Journey.fromFirestore(doc),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Journey Image with Map Preview
                Stack(
                  children: [
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
                    // Stats overlay
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        children: [
                          _buildStatChip(Icons.favorite, data['likes']?.toString() ?? '0'),
                          const SizedBox(width: 8),
                          // Shadowers count
                          _buildStatChip(Icons.directions_walk, (data['shadowers'] ?? 0).toString()),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.share, color: Colors.white),
                            onPressed: () => Share.share('Check out this journey: ${data['title']}'),
                          ),
                          if (isCreator) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CreateJourneyPage(
                                      journeyId: doc.id,
                                      isEditing: true,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                // Journey Info
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
                                  data['title'] ?? 'Untitled Journey',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'by ${data['creatorName'] ?? 'Anonymous'}',
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildInfoChip('Difficulty', _getDifficultyIcons(data['difficulty'] ?? 1)),
                          const SizedBox(width: 8),
                          _buildInfoChip('Cost', '\$' * (data['cost'] ?? 1)),
                          const SizedBox(width: 8),
                          _buildInfoChip('People', '${data['recommendedPeople'] ?? 1}'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Shadow button
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          icon: isShadowed
                              ? const Icon(Icons.check, color: Colors.green)
                              : const Icon(Icons.directions_walk),
                          label: isShadowed
                              ? const Text('Shadowed')
                              : isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                    )
                                  : const Text('Shadow'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isShadowed ? Colors.grey : Colors.amber,
                            foregroundColor: isShadowed ? Colors.white : Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: isShadowed
                              ? null
                              : () async {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => const Center(child: CircularProgressIndicator()),
                                  );
                                  await _db.collection('shadows').add({
                                    'userId': _auth.currentUser!.uid,
                                    'journeyId': journeyId,
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'status': 'active',
                                  });
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Journey added to your shadowing list!')),
                                  );
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatChip(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
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
} 