import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'journey_detail_page.dart';
import 'mission_detail_page.dart';
import '../utils/image_handler.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _showJourneys = true;
  bool _showMissions = true;

  final List<String> _categories = ['All', 'Journeys', 'Missions'];

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
                            hintText: 'Search...',
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
                        icon: const Icon(Icons.filter_list, color: Colors.white),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.grey[900],
                            builder: (context) => StatefulBuilder(
                              builder: (context, setState) => Container(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Filter Content',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SwitchListTile(
                                      title: const Text(
                                        'Show Journeys',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      value: _showJourneys,
                                      onChanged: (value) {
                                        setState(() => _showJourneys = value);
                                        this.setState(() {});
                                      },
                                    ),
                                    SwitchListTile(
                                      title: const Text(
                                        'Show Missions',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      value: _showMissions,
                                      onChanged: (value) {
                                        setState(() => _showMissions = value);
                                        this.setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
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
          // Feed Content
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFeedStream(),
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
                          ? 'No content available'
                          : 'No content in $_selectedCategory category',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }

                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = data['title']?.toString().toLowerCase() ?? '';
                  final description = data['description']?.toString().toLowerCase() ?? '';
                  final searchLower = _searchQuery.toLowerCase();
                  return title.contains(searchLower) || description.contains(searchLower);
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isJourney = data['type'] == 'journey';
                    return isJourney
                        ? _buildJourneyCard(doc)
                        : _buildMissionCard(doc);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getFeedStream() {
    if (_selectedCategory == 'Journeys') {
      return _db.collection('journeys')
          .where('status', isEqualTo: 'active')
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else if (_selectedCategory == 'Missions') {
      return _db.collection('missions')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else {
      // Combine both streams
      return _db.collection('feed')
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
  }

  Widget _buildJourneyCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.grey[850],
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JourneyDetailPage(
                journeyId: doc.id,
              ),
            ),
          );
        },
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.grey[850],
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MissionDetailPage(
                missionId: doc.id,
              ),
            ),
          );
        },
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
                  child: Icon(Icons.science, size: 64, color: Colors.grey),
                ),
              ),
            // Mission Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: data['researcherPhotoUrl'] != null
                            ? NetworkImage(data['researcherPhotoUrl'])
                            : null,
                        child: data['researcherPhotoUrl'] == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['title'] ?? 'Untitled Mission',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'by ${data['researcherName'] ?? 'Anonymous'}',
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
                      _buildInfoChip(
                        'Participants',
                        '${data['currentEntries'] ?? 0}/${data['entryLimit'] ?? 0}',
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        'Deadline',
                        data['deadline'] != null
                            ? (data['deadline'] as Timestamp)
                                .toDate()
                                .toString()
                                .split(' ')[0]
                            : 'No deadline',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                ],
              ),
            ),
          ],
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
} 