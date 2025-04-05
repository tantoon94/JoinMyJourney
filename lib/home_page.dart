import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'journey_map_page.dart';
import 'create_journey_page.dart';
import 'search_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  Map<String, dynamic>? _userData;
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  int _leaderCount = 0;
  int _shadowerCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserStats();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      _user = _auth.currentUser;
      if (_user != null) {
        final doc = await _db.collection('users').doc(_user!.uid).get();
        if (doc.exists) {
          setState(() {
            _userData = doc.data();
          });
        }
      }
    } catch (e, stackTrace) {
      developer.log('Error loading user data', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _loadUserStats() async {
    try {
      if (_user != null) {
        // Get tracks created by user that others have followed
        final shadowerQuery = await _db
            .collection('journey_follows')
            .where('creatorId', isEqualTo: _user!.uid)
            .get();
        
        // Get tracks user has followed from others
        final leaderQuery = await _db
            .collection('journey_follows')
            .where('followerId', isEqualTo: _user!.uid)
            .get();

        if (mounted) {
          setState(() {
            _shadowerCount = shadowerQuery.docs.length;
            _leaderCount = leaderQuery.docs.length;
          });
        }
      }
    } catch (e) {
      developer.log('Error loading user stats', error: e);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  Widget _buildPieChart() {
    // For demonstration when no data is available
    if (_leaderCount == 0 && _shadowerCount == 0) {
      return Container(
        height: 90,
        width: 90,
        padding: const EdgeInsets.all(8),
        child: PieChart(
          PieChartData(
            sections: [
              PieChartSectionData(
                value: 60,
                title: 'Leader',
                color: Colors.black.withOpacity(0.8),
                radius: 35,
                titleStyle: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[300],
                  fontWeight: FontWeight.w500,
                ),
                titlePositionPercentageOffset: 0.5,
              ),
              PieChartSectionData(
                value: 40,
                title: 'Shadower',
                color: Colors.black.withOpacity(0.4),
                radius: 35,
                titleStyle: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[300],
                  fontWeight: FontWeight.w500,
                ),
                titlePositionPercentageOffset: 0.5,
              ),
            ],
            sectionsSpace: 2,
            centerSpaceRadius: 0,
            borderData: FlBorderData(show: false),
          ),
        ),
      );
    }

    return Container(
      height: 90,
      width: 90,
      padding: const EdgeInsets.all(8),
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(
              value: _leaderCount.toDouble(),
              title: 'Leader',
              color: Colors.black.withOpacity(0.8),
              radius: 35,
              titleStyle: TextStyle(
                fontSize: 11,
                color: Colors.grey[300],
                fontWeight: FontWeight.w500,
              ),
              titlePositionPercentageOffset: 0.5,
            ),
            PieChartSectionData(
              value: _shadowerCount.toDouble(),
              title: 'Shadower',
              color: Colors.black.withOpacity(0.4),
              radius: 35,
              titleStyle: TextStyle(
                fontSize: 11,
                color: Colors.grey[300],
                fontWeight: FontWeight.w500,
              ),
              titlePositionPercentageOffset: 0.5,
            ),
          ],
          sectionsSpace: 2,
          centerSpaceRadius: 0,
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildPieBadge(String text) {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String title, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.black : Colors.grey[400],
          ),
          child: Icon(
            Icons.star,
            color: isActive ? const Color(0xFFFFD700) : Colors.grey[600],
            size: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.black : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildLeftColumn() {
    return Container(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile Picture
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[400]!, width: 1),
            ),
            child: _user?.photoURL != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: _user!.photoURL!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const CircularProgressIndicator(),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.person, size: 60, color: Colors.white70),
                    ),
                  )
                : const Icon(Icons.person, size: 60, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          // Profile Info
          Center(
            child: Column(
              children: [
                Text(
                  _userData?['username'] ?? _user?.displayName ?? 'User',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'Bio / Theme',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'Journey plans ${_userData?['journeyCount'] ?? 0}',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightColumn() {
    return Container(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildPieChart(),
          const SizedBox(height: 12),
          // Shadowers count
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '2K',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[100],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Shadowers',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[300],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Badges in row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBadge('Leader', true),
              const SizedBox(width: 16),
              _buildBadge('Seeker', true),
              const SizedBox(width: 16),
              _buildBadge('Agent', false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color) {
    return Container(
      width: 65,
      height: 65,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: const Color(0xFFFFD700), // Golden color
        size: 30,
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Two-column layout with proper margins
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column - Profile picture and info
                Expanded(
                  flex: 1,
                  child: _buildLeftColumn(),
                ),
                // Vertical Divider
                Container(
                  width: 1,
                  color: Colors.grey[600],
                ),
                // Right column - Stats and badges
                Expanded(
                  flex: 1,
                  child: _buildRightColumn(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(Icons.star_border_rounded, Colors.black),
              _buildActionButton(Icons.search_rounded, Colors.black),
              _buildActionButton(Icons.military_tech_rounded, Colors.black),
              _buildActionButton(Icons.push_pin_rounded, Colors.black),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyCard(String title, String description) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: const Color(0xFF353535), // Dark card background
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.map, color: Colors.grey),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              description,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[400]),
              color: const Color(0xFF2A2A2A),
              onSelected: (value) {
                // Handle menu item selection
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit', style: TextStyle(color: Colors.grey[300])),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.grey[300])),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 200,
            child: StreamBuilder<DocumentSnapshot>(
              stream: _db.collection('journeys')
                  .where('title', isEqualTo: title)
                  .limit(1)
                  .snapshots()
                  .map((snapshot) => snapshot.docs.first),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final stops = (data['stops'] as List?)?.map((stop) {
                  if (stop is GeoPoint) {
                    return LatLng(stop.latitude, stop.longitude);
                  }
                  return null;
                }).whereType<LatLng>().toList() ?? [];

                if (stops.isEmpty) {
                  return const Center(child: Text('No stops added'));
                }

                // Calculate bounds for the map
                double minLat = stops.map((e) => e.latitude).reduce(min);
                double maxLat = stops.map((e) => e.latitude).reduce(max);
                double minLng = stops.map((e) => e.longitude).reduce(min);
                double maxLng = stops.map((e) => e.longitude).reduce(max);

                final bounds = LatLngBounds(
                  southwest: LatLng(minLat, minLng),
                  northeast: LatLng(maxLat, maxLng),
                );

                // Calculate center manually
                final center = LatLng(
                  (minLat + maxLat) / 2,
                  (minLng + maxLng) / 2,
                );

                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: center,
                      zoom: 12,
                    ),
                    onMapCreated: (controller) {
                      controller.animateCamera(
                        CameraUpdate.newLatLngBounds(bounds, 50),
                      );
                    },
                    markers: stops.asMap().map((index, position) {
                      return MapEntry(
                        index,
                        Marker(
                          markerId: MarkerId('stop_$index'),
                          position: position,
                          infoWindow: InfoWindow(title: 'Stop ${index + 1}'),
                        ),
                      );
                    }).values.toSet(),
                    polylines: {
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: stops,
                        color: Colors.blue,
                        width: 3,
                      ),
                    },
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    myLocationButtonEnabled: false,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.favorite_border, color: Colors.grey[400]),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Icon(Icons.share, color: Colors.grey[400]),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePage() {
    return _user == null
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: Column(
              children: [
                Container(
                  color: const Color(0xFF2A2A2A),
                  child: _buildProfileHeader(),
                ),
                Expanded(
                  child: Container(
                    color: const Color(0xFF1A1A1A), // Darker background for journeys section
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            border: Border(
                              top: BorderSide(
                                color: Colors.grey[800]!,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'My Journeys',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, color: Colors.white),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const CreateJourneyPage()),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _buildJourneyCard(
                                'Day trip with friends in Canary Wharf',
                                'Join me on this exciting journey!',
                              ),
                              _buildJourneyCard(
                                'Shopping Stops route',
                                'Best shopping locations in the city',
                              ),
                              _buildJourneyCard(
                                'River walks and shops',
                                'Scenic route along the river',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: [
          _buildProfilePage(),
          const JourneyMapPage(),
          const SearchPage(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateJourneyPage()),
          );
        },
        backgroundColor: Colors.grey,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Journey',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
        ],
      ),
    );
  }
} 