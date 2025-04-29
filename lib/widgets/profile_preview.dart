import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../pages/shadowing_page.dart';
import 'dart:convert';

class ProfilePreview extends StatefulWidget {
  final String userId;
  final VoidCallback? onClose;

  const ProfilePreview({
    super.key,
    required this.userId,
    this.onClose,
  });

  @override
  State<ProfilePreview> createState() => _ProfilePreviewState();
}

class _ProfilePreviewState extends State<ProfilePreview> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isFollowing = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final followDoc = await _db
        .collection('followers')
        .doc(widget.userId)
        .collection('userFollowers')
        .doc(currentUser.uid)
        .get();

    setState(() {
      _isFollowing = followDoc.exists;
      _isLoading = false;
    });
  }

  Future<void> _toggleFollow() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    final followRef = _db
        .collection('followers')
        .doc(widget.userId)
        .collection('userFollowers')
        .doc(currentUser.uid);

    final followingRef = _db
        .collection('followers')
        .doc(currentUser.uid)
        .collection('userFollowing')
        .doc(widget.userId);

    if (_isFollowing) {
      // Unfollow
      await followRef.delete();
      await followingRef.delete();
    } else {
      // Follow
      await followRef.set({
        'timestamp': FieldValue.serverTimestamp(),
      });
      await followingRef.set({
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    setState(() {
      _isFollowing = !_isFollowing;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users').doc(widget.userId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) {
          return const Center(child: Text('User not found'));
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Profile Picture
                CircleAvatar(
                  radius: 40,
                  backgroundImage: userData['photoURL'] != null
                      ? NetworkImage(userData['photoURL'])
                      : null,
                  child: userData['photoURL'] == null
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
                const SizedBox(height: 12),
                // Username
                Text(
                  userData['displayName'] ?? 'Unknown User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (userData['bio'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    userData['bio'],
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn('Journeys', userData['journeyCount'] ?? 0),
                    _buildStatColumn(
                        'Followers', userData['followersCount'] ?? 0),
                    _buildStatColumn(
                        'Following', userData['followingCount'] ?? 0),
                  ],
                ),
                const SizedBox(height: 16),
                // Follow Button
                if (widget.userId != _auth.currentUser?.uid)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _toggleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isFollowing ? Colors.grey[800] : Colors.amber,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _isFollowing ? 'Unfollow' : 'Follow',
                              style: TextStyle(
                                color:
                                    _isFollowing ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                const SizedBox(height: 16),
                // Journeys Section
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Journeys',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Journeys List
                StreamBuilder<QuerySnapshot>(
                  stream: _db
                      .collection('journeys')
                      .where('creatorId', isEqualTo: widget.userId)
                      .orderBy('createdAt', descending: true)
                      .limit(5)
                      .snapshots(),
                  builder: (context, journeySnapshot) {
                    if (!journeySnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (journeySnapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No journeys yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: journeySnapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final journey = journeySnapshot.data!.docs[index];
                          final data = journey.data() as Map<String, dynamic>;
                          return Container(
                            width: 180,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Journey Image
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Stack(
                                      children: [
                                        if (data['mapThumbnailUrl'] != null)
                                          CachedNetworkImage(
                                            imageUrl: data['mapThumbnailUrl'],
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                Container(
                                              color: Colors.grey[800],
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(Colors.amber),
                                                ),
                                              ),
                                            ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    Container(
                                              color: Colors.grey[800],
                                              child: const Center(
                                                child: Icon(
                                                  Icons.map,
                                                  size: 50,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          )
                                        else if (data['mapThumbnailData'] !=
                                            null)
                                          Image.memory(
                                            base64Decode(
                                                data['mapThumbnailData']
                                                    ['data']),
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              print(
                                                  'Error loading map thumbnail: $error');
                                              return Container(
                                                color: Colors.grey[800],
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.map,
                                                    size: 50,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              );
                                            },
                                          )
                                        else
                                          Container(
                                            color: Colors.grey[800],
                                            child: const Center(
                                              child: Icon(
                                                Icons.map,
                                                size: 50,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        if (_isFollowing)
                                          Positioned.fill(
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          ShadowingPage(
                                                        journeyId: journey.id,
                                                        creatorId:
                                                            widget.userId,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.3),
                                                  ),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.play_circle_fill,
                                                      color: Colors.white,
                                                      size: 40,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Journey Info
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['title'] ?? 'Untitled Journey',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.local_fire_department,
                                            color: Colors.amber,
                                            size: 14,
                                          ),
                                          Text(
                                            ' ${data['difficulty'] ?? 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.attach_money,
                                            color: Colors.amber,
                                            size: 14,
                                          ),
                                          Text(
                                            ' ${data['cost'] ?? 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
