import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'journey_detail_page.dart';
import 'mission_detail_page.dart';
import '../utils/image_handler.dart';
import '../widgets/journey_card.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _searchQuery = '';
  late TabController _tabController;
  final List<String> _categories = ['All', 'Journeys', 'Missions'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search and Tabs
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
                            hintText: 'Search journeys or missions...',
                            hintStyle: TextStyle(color: Colors.grey),
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Tabs
                TabBar(
                  controller: _tabController,
                  tabs: _categories.map((cat) => Tab(text: cat)).toList(),
                  indicatorColor: Theme.of(context).primaryColor,
                  labelColor: Colors.amber,
                  unselectedLabelColor: Colors.grey,
                ),
              ],
            ),
          ),
          // Feed Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllTab(),
                _buildJourneysTab(),
                _buildMissionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllTab() {
    // Fetch both journeys and missions, merge, sort, and filter
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchAllFeedItems(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('No content available', style: TextStyle(color: Colors.white)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (item['type'] == 'journey') {
              return _JourneyCardWithBadge(data: item, badge: 'Journey');
            } else {
              return _MissionCardWithBadge(data: item, badge: 'Mission');
            }
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAllFeedItems() async {
    final journeysSnap = await _db
        .collection('journeys')
        .where('status', isEqualTo: 'active')
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .get();
    final missionsSnap = await _db
        .collection('missions')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .get();
    final journeys = journeysSnap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      data['type'] = 'journey';
      return data;
    }).toList();
    final missions = missionsSnap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      data['type'] = 'mission';
      return data;
    }).toList();
    final all = [...journeys, ...missions];
    all.sort((a, b) {
      final aTime = a['createdAt'] is Timestamp ? a['createdAt'].toDate() : a['createdAt'];
      final bTime = b['createdAt'] is Timestamp ? b['createdAt'].toDate() : b['createdAt'];
      return bTime.compareTo(aTime);
    });
    // Apply search filter
    final searchLower = _searchQuery.toLowerCase();
    return all.where((item) {
      final title = item['title']?.toString().toLowerCase() ?? '';
      final description = item['description']?.toString().toLowerCase() ?? '';
      return title.contains(searchLower) || description.contains(searchLower);
    }).toList();
  }

  Widget _buildJourneysTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('journeys')
          .where('status', isEqualTo: 'active')
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final docs = snapshot.data?.docs ?? [];
        final filtered = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final title = data['title']?.toString().toLowerCase() ?? '';
          final description = data['description']?.toString().toLowerCase() ?? '';
          final searchLower = _searchQuery.toLowerCase();
          return title.contains(searchLower) || description.contains(searchLower);
        }).toList();
        if (filtered.isEmpty) {
          return const Center(child: Text('No journeys found', style: TextStyle(color: Colors.white)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc = filtered[index];
            final data = doc.data() as Map<String, dynamic>;
            return _JourneyCardWithBadge(data: data);
          },
        );
      },
    );
  }

  Widget _buildMissionsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('missions')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final docs = snapshot.data?.docs ?? [];
        final filtered = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final title = data['title']?.toString().toLowerCase() ?? '';
          final description = data['description']?.toString().toLowerCase() ?? '';
          final searchLower = _searchQuery.toLowerCase();
          return title.contains(searchLower) || description.contains(searchLower);
        }).toList();
        if (filtered.isEmpty) {
          return const Center(child: Text('No missions found', style: TextStyle(color: Colors.white)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc = filtered[index];
            final data = doc.data() as Map<String, dynamic>;
            return _MissionCardWithBadge(data: data);
          },
        );
      },
    );
  }
}

class _JourneyCardWithBadge extends StatelessWidget {
  final Map<String, dynamic> data;
  final String? badge;
  const _JourneyCardWithBadge({required this.data, this.badge});

  @override
  Widget build(BuildContext context) {
    final _auth = FirebaseAuth.instance;
    final _db = FirebaseFirestore.instance;
    final userId = _auth.currentUser?.uid;
    final journeyId = data['id'];
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('shadows')
              .where('userId', isEqualTo: userId)
              .where('journeyId', isEqualTo: journeyId)
              .where('status', isEqualTo: 'active')
              .snapshots(),
          builder: (context, shadowSnapshot) {
            final isShadowed = shadowSnapshot.hasData && shadowSnapshot.data!.docs.isNotEmpty;
            return JourneyCard(
              data: data,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => JourneyDetailPage(
                      journeyId: data['id'],
                    ),
                  ),
                );
              },
              showEditButton: false,
              showLikeButton: true,
              isLiked: false, // Like logic can be added if needed
              trailing: IconButton(
                icon: isShadowed
                    ? const Icon(Icons.check_circle, color: Colors.green, size: 32)
                    : const Icon(Icons.play_circle_fill, color: Colors.amber, size: 32),
                tooltip: isShadowed ? 'Already shadowed' : 'Shadow this journey',
                onPressed: isShadowed
                    ? null
                    : () async {
                        if (userId == null) return;
                        await _db.collection('shadows').add({
                          'userId': userId,
                          'journeyId': journeyId,
                          'createdAt': FieldValue.serverTimestamp(),
                          'status': 'active',
                        });
                        if (context.mounted) {
                          Navigator.pushNamed(context, '/shadowed_journeys');
                        }
                      },
              ),
            );
          },
        ),
        if (badge != null)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badge == 'Journey' ? Colors.amber : Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MissionCardWithBadge extends StatelessWidget {
  final Map<String, dynamic> data;
  final String? badge;
  const _MissionCardWithBadge({required this.data, this.badge});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: Colors.grey[850],
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MissionDetailPage(
                    missionId: data['id'],
                  ),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
        ),
        if (badge != null)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
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
}
