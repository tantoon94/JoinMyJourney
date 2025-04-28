import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'journey_tracking_page.dart';
import 'search_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'profile_settings_page.dart';
import '../utils/image_handler.dart';
import 'create_journey_page.dart';
import '../utils/firestore_utils.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _username;
  String? _bio;
  int _journeyCount = 0;
  int _shadowersCount = 0;
  int _shadowingCount = 0;
  String? _theme;
  bool _showHeart = false;
  
  // Pie chart data
  double _plansPercentage = 0.4;
  double _missionsPercentage = 0.35;
  double _adventuresPercentage = 0.25;

  // Theme colors
  static const backgroundColor = Color(0xFF1E1E1E);
  static const cardColor = Color(0xFF2A2A2A);
  static const surfaceColor = Color(0xFF333333);

  final TextEditingController _bioController = TextEditingController();
  bool _isEditingBio = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  void _showMenuOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.amber),
                title: const Text(
                  'Profile Settings',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context); // Close menu
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileSettingsPage(),
                    ),
                  ).then((_) => _loadUserData()); // Refresh profile data after returning
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.amber),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pop(context); // Close menu
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        // Get user data with retry
        final userData = await FirestoreUtils.withRetry(
          operation: () => _db.collection('users').doc(user.uid).get(),
        );
        
        // Get journey count with retry
        final journeySnapshot = await FirestoreUtils.withRetry(
          operation: () => _db
              .collection('journeys')
              .where('creatorId', isEqualTo: user.uid)
              .get(),
        );
        
        // Get followers count with retry
        final followersSnapshot = await FirestoreUtils.withRetry(
          operation: () => _db
              .collection('followers')
              .doc(user.uid)
              .collection('userFollowers')
              .get(),
        );
        
        // Get following count with retry
        final followingSnapshot = await FirestoreUtils.withRetry(
          operation: () => _db
              .collection('followers')
              .doc(user.uid)
              .collection('userFollowing')
              .get(),
        );
        
        if (userData.exists && mounted) {
          setState(() {
            _username = userData.data()?['displayName'] ?? user.displayName ?? '[Name]';
            _bio = userData.data()?['bio'];
            _bioController.text = _bio ?? '';
            _theme = userData.data()?['theme'];
            _journeyCount = journeySnapshot.docs.length;
            _shadowersCount = followersSnapshot.docs.length;
            _shadowingCount = followingSnapshot.docs.length;
            _plansPercentage = userData.data()?['plansPercentage'] ?? 0.4;
            _missionsPercentage = userData.data()?['missionsPercentage'] ?? 0.35;
            _adventuresPercentage = userData.data()?['adventuresPercentage'] ?? 0.25;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading user data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _updateBio() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await FirestoreUtils.withRetry(
          operation: () => _db.collection('users').doc(user.uid).set({
            'bio': _bioController.text,
            'displayName': _username ?? user.displayName ?? '[Name]',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
        );
        
        if (mounted) {
          setState(() {
            _bio = _bioController.text;
            _isEditingBio = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bio updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update bio: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        print('Error updating bio: $e');
      }
    }
  }

  void _showHeartAnimation(BuildContext context) {
    if (!mounted) return;
    
    setState(() {
      _showHeart = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _showHeart = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: backgroundColor,
        cardColor: cardColor,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
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
                      onPressed: () => _showMenuOptions(context),
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
                                    'Journey plans $_journeyCount',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Pie Chart and Badges Column
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
                                              value: _plansPercentage * 100,
                                              color: surfaceColor,
                                              title: 'Plans',
                                              radius: 40,
                                              titleStyle: const TextStyle(
                                                fontSize: 8,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              titlePositionPercentageOffset: 0.5,
                                            ),
                                            PieChartSectionData(
                                              value: _missionsPercentage * 100,
                                              color: surfaceColor,
                                              title: 'Missions',
                                              radius: 40,
                                              titleStyle: const TextStyle(
                                                fontSize: 8,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              titlePositionPercentageOffset: 0.5,
                                            ),
                                            PieChartSectionData(
                                              value: _adventuresPercentage * 100,
                                              color: surfaceColor,
                                              title: 'Adventures',
                                              radius: 40,
                                              titleStyle: const TextStyle(
                                                fontSize: 8,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              titlePositionPercentageOffset: 0.5,
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
                                  // Badges Row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildBadge('Leader'),
                                      const SizedBox(width: 8),
                                      _buildBadge('Seeker'),
                                      const SizedBox(width: 8),
                                      _buildBadge('Agent'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Shadowers and Shadowing Count
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Shadowers
                                      Column(
                                        children: [
                                          Text(
                                            '$_shadowersCount',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const Text(
                                            'Shadowers',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      // Shadowing
                                      Column(
                                        children: [
                                          Text(
                                            '$_shadowingCount',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const Text(
                                            'Shadowing',
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
                      
                      // Editable Bio
                      const SizedBox(height: 24),
                      if (_isEditingBio)
                        Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _bioController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    hintText: 'Enter your bio',
                                    hintStyle: TextStyle(color: Colors.grey),
                                    border: InputBorder.none,
                                  ),
                                  onSubmitted: (_) => _updateBio(),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.amber),
                                onPressed: _updateBio,
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.grey),
                                onPressed: () => setState(() {
                                  _isEditingBio = false;
                                  _bioController.text = _bio ?? '';
                                }),
                              ),
                            ],
                          ),
                        )
                      else
                        InkWell(
                          onTap: () => setState(() {
                            _isEditingBio = true;
                            _bioController.text = _bio ?? '';
                          }),
                          child: Container(
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _bio ?? 'Add a bio...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _bio == null ? Colors.grey : Colors.white,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.edit, color: Colors.amber, size: 20),
                              ],
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
                      _buildActionButton(Icons.star, Colors.amber),
                      _buildActionButton(Icons.search, Colors.amber),
                      _buildActionButton(Icons.emoji_events, Colors.amber),
                      _buildActionButton(Icons.push_pin, Colors.amber),
                    ],
                  ),
                ),

                // My Journeys Section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'My Journeys',
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
                                  builder: (context) => const CreateJourneyPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      // Journey Cards
                      StreamBuilder<QuerySnapshot>(
                        stream: _db
                            .collection('journeys')
                            .where('creatorId', isEqualTo: _auth.currentUser?.uid)
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
                                'No journeys created yet',
                                style: TextStyle(color: Colors.white),
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: snapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              final journey = snapshot.data!.docs[index];
                              return _buildJourneyCard(journey);
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

  Widget _buildBadge(String label) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.amber, width: 2),
          ),
          child: const Center(
            child: Icon(Icons.workspace_premium, color: Colors.amber, size: 16),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
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

  Widget _buildJourneyCard(DocumentSnapshot journey) {
    final data = journey.data() as Map<String, dynamic>;
    print('Building journey card for: ${data['title']}');
    print('Map thumbnail data present: ${data['mapThumbnailData'] != null}');
    print('Image data present: ${data['imageData'] != null}');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Journey Map Thumbnail
          if (data['mapThumbnailData'] != null)
            GestureDetector(
              onDoubleTap: () async {
                final user = _auth.currentUser;
                if (user == null) return;
                final likeRef = _db
                    .collection('journeys')
                    .doc(journey.id)
                    .collection('likes')
                    .doc(user.uid);
                final likeDoc = await likeRef.get();
                if (!likeDoc.exists) {
                  await likeRef.set({'timestamp': FieldValue.serverTimestamp()});
                  await _db.collection('journeys').doc(journey.id).update({'likes': FieldValue.increment(1)});
                  if (mounted) {
                    _showHeartAnimation(context);
                  }
                }
              },
              child: ImageHandler.buildImagePreview(
                context: context,
                imageData: data['mapThumbnailData'],
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
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

          // Journey Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['title'] ?? 'Untitled Journey',
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

          // Journey Stats
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // Journey Metrics
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Likes and Comments
                    Row(
                      children: [
                        // Like Button
                        StreamBuilder<DocumentSnapshot>(
                          stream: _db
                              .collection('journeys')
                              .doc(journey.id)
                              .collection('likes')
                              .doc(_auth.currentUser?.uid)
                              .snapshots(),
                          builder: (context, likeSnapshot) {
                            final isLiked = likeSnapshot.hasData && likeSnapshot.data!.exists;
                            return IconButton(
                              icon: Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                color: isLiked ? Colors.red : Colors.amber,
                                size: 20,
                              ),
                              onPressed: () async {
                                final user = _auth.currentUser;
                                if (user == null) return;
                                final likeRef = _db
                                    .collection('journeys')
                                    .doc(journey.id)
                                    .collection('likes')
                                    .doc(user.uid);
                                if (isLiked) {
                                  await likeRef.delete();
                                  await _db.collection('journeys').doc(journey.id).update({'likes': FieldValue.increment(-1)});
                                } else {
                                  await likeRef.set({'timestamp': FieldValue.serverTimestamp()});
                                  await _db.collection('journeys').doc(journey.id).update({'likes': FieldValue.increment(1)});
                                  _showHeartAnimation(context);
                                }
                              },
                            );
                          },
                        ),
                        Text(
                          '${data['likes'] ?? 0}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Shadowers Count
                        const Icon(Icons.directions_walk,
                            color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '${data['shadowers'] ?? 0}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Journey Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Difficulty
                    Row(
                      children: List.generate(
                        (data['difficulty'] ?? 1).clamp(1, 3),
                        (index) => const Padding(
                          padding: EdgeInsets.only(right: 2),
                          child: Icon(
                            Icons.local_fire_department,
                            color: Colors.amber,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    // Cost Level
                    Row(
                      children: List.generate(
                        (data['cost'] ?? 1).clamp(1, 3),
                        (index) => const Padding(
                          padding: EdgeInsets.only(right: 2),
                          child: Icon(
                            Icons.attach_money,
                            color: Colors.amber,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    // Duration
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(data['durationInHours'] ?? 0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    // People
                    Row(
                      children: [
                        const Icon(Icons.people,
                            color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${data['recommendedPeople'] ?? 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
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

  String _getTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp.toDate());

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }

  String _formatDuration(double hours) {
    if (hours < 1) {
      final minutes = (hours * 60).round();
      return '$minutes min';
    } else if (hours % 1 == 0) {
      return '${hours.toInt()} h';
    } else {
      final h = hours.floor();
      final m = ((hours - h) * 60).round();
      return '$h h $m min';
    }
  }
} 