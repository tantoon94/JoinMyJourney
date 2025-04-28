import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'mission_creation_page.dart';
import '../utils/image_handler.dart';

class ResearcherProfilePage extends StatefulWidget {
  const ResearcherProfilePage({super.key});

  @override
  State<ResearcherProfilePage> createState() => _ResearcherProfilePageState();
}

class _ResearcherProfilePageState extends State<ResearcherProfilePage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _username;
  String? _bio;
  int _missionCount = 0;
  int _totalParticipants = 0;
  int _completedMissions = 0;
  bool _showHeart = false;

  // Pie chart data
  double _activePercentage = 0.6;
  double _completedPercentage = 0.3;
  double _draftPercentage = 0.1;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Get user data
      final userData = await _db.collection('users').doc(user.uid).get();
      
      // Get mission count
      final missionSnapshot = await _db
          .collection('missions')
          .where('researcherId', isEqualTo: user.uid)
          .get();
      
      // Get total participants
      final participantsSnapshot = await _db
          .collection('mission_participants')
          .where('researcherId', isEqualTo: user.uid)
          .get();
      
      // Get completed missions
      final completedSnapshot = await _db
          .collection('missions')
          .where('researcherId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .get();
      
      if (userData.exists) {
        setState(() {
          _username = userData.data()?['displayName'] ?? user.displayName ?? '[Name]';
          _bio = userData.data()?['bio'];
          _missionCount = missionSnapshot.docs.length;
          _totalParticipants = participantsSnapshot.docs.length;
          _completedMissions = completedSnapshot.docs.length;
          _activePercentage = userData.data()?['activePercentage'] ?? 0.6;
          _completedPercentage = userData.data()?['completedPercentage'] ?? 0.3;
          _draftPercentage = userData.data()?['draftPercentage'] ?? 0.1;
        });
      }
    }
  }

  void _showHeartAnimation(BuildContext context) {
    setState(() {
      _showHeart = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        _showHeart = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        cardColor: const Color(0xFF2A2A2A),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Menu Icon at top right
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                      onPressed: () {
                        // TODO: Implement menu options
                      },
                    ),
                  ),
                ),
                
                // Profile Section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Picture and Pie Chart
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Info Column
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundImage: _auth.currentUser?.photoURL != null
                                        ? NetworkImage(_auth.currentUser!.photoURL!)
                                        : null,
                                    child: _auth.currentUser?.photoURL == null
                                        ? const Icon(Icons.person, size: 50)
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _username ?? '[Name]',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Missions $_missionCount',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Pie Chart and Stats Column
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: Column(
                                children: [
                                  Center(
                                    child: SizedBox(
                                      width: 80,
                                      height: 80,
                                      child: PieChart(
                                        PieChartData(
                                          sections: [
                                            PieChartSectionData(
                                              value: _activePercentage * 100,
                                              color: Colors.amber,
                                              title: 'Active',
                                              radius: 40,
                                              titleStyle: const TextStyle(
                                                fontSize: 8,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            PieChartSectionData(
                                              value: _completedPercentage * 100,
                                              color: Colors.green,
                                              title: 'Completed',
                                              radius: 40,
                                              titleStyle: const TextStyle(
                                                fontSize: 8,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            PieChartSectionData(
                                              value: _draftPercentage * 100,
                                              color: Colors.grey,
                                              title: 'Draft',
                                              radius: 40,
                                              titleStyle: const TextStyle(
                                                fontSize: 8,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                          sectionsSpace: 3,
                                          centerSpaceRadius: 0,
                                          borderData: FlBorderData(show: false),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Stats Row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Total Participants
                                      Column(
                                        children: [
                                          Text(
                                            '$_totalParticipants',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const Text(
                                            'Participants',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      // Completed Missions
                                      Column(
                                        children: [
                                          Text(
                                            '$_completedMissions',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const Text(
                                            'Completed',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Bio Section
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          _bio ?? 'Add a bio...',
                          style: TextStyle(
                            fontSize: 16,
                            color: _bio == null ? Colors.grey : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(Icons.analytics, Colors.amber),
                      _buildActionButton(Icons.people, Colors.amber),
                      _buildActionButton(Icons.assignment, Colors.amber),
                      _buildActionButton(Icons.settings, Colors.amber),
                    ],
                  ),
                ),

                // My Missions Section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'My Missions',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 30, color: Colors.white),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const MissionCreationPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      // Mission Cards
                      StreamBuilder<QuerySnapshot>(
                        stream: _db
                            .collection('missions')
                            .where('researcherId', isEqualTo: _auth.currentUser?.uid)
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error: ${snapshot.error}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            );
                          }

                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const Center(
                              child: Text(
                                'No missions created yet',
                                style: TextStyle(color: Colors.white),
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: snapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              final mission = snapshot.data!.docs[index];
                              return _buildMissionCard(mission);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: () {
          // TODO: Implement action button functionality
        },
      ),
    );
  }

  Widget _buildMissionCard(DocumentSnapshot mission) {
    final data = mission.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mission Image with Map Preview
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
              decoration: const BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.map,
                  size: 64,
                  color: Colors.white,
                ),
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
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (data['description'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    data['description'],
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Mission Stats
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // Mission Metrics
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Participants and Progress
                    Row(
                      children: [
                        const Icon(Icons.people, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '${data['currentEntries'] ?? 0}/${data['entryLimit'] ?? 0}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Deadline
                        const Icon(Icons.access_time, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(data['deadline']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    // Status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(data['status']),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        data['status'] ?? 'active',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
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
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'draft':
        return Colors.grey;
      default:
        return Colors.amber;
    }
  }

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      final dateTime = date.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    return 'No deadline';
  }
} 