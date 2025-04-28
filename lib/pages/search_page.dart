import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Timer? _debounce;
  List<QueryDocumentSnapshot>? _journeyResults;
  List<QueryDocumentSnapshot>? _userResults;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    setState(() {
      _searchQuery = _searchController.text;
      _isSearching = _searchQuery.isNotEmpty;
      if (!_isSearching) {
        _journeyResults = null;
        _userResults = null;
      }
    });

    if (_isSearching) {
      _debounce = Timer(const Duration(milliseconds: 500), () {
        _performSearch();
      });
    }
  }

  Future<void> _performSearch() async {
    if (!_isSearching) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _searchJourneys(),
        _searchUsers(),
      ]);

      if (mounted) {
        setState(() {
          _journeyResults = results[0];
          _userResults = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<List<QueryDocumentSnapshot>> _searchJourneys() async {
    if (_searchQuery.isEmpty) return [];

    final journeysQuery = await _db.collection('journeys')
        .where('isPublic', isEqualTo: true)
        .where('title', isGreaterThanOrEqualTo: _searchQuery)
        .where('title', isLessThan: '${_searchQuery}z')
        .limit(10) // Limit results for better performance
        .get();

    return journeysQuery.docs;
  }

  Future<List<QueryDocumentSnapshot>> _searchUsers() async {
    if (_searchQuery.isEmpty) return [];

    final usersQuery = await _db.collection('users')
        .where('username', isGreaterThanOrEqualTo: _searchQuery)
        .where('username', isLessThan: '${_searchQuery}z')
        .limit(10) // Limit results for better performance
        .get();

    return usersQuery.docs;
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_journeyResults == null && _userResults == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final journeys = _journeyResults ?? [];
    final users = _userResults ?? [];

    if (journeys.isEmpty && users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No results found for "$_searchQuery"',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        if (journeys.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Journeys',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...journeys.map((doc) => _buildJourneyTile(doc)),
        ],
        if (users.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Users',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...users.map((doc) => _buildUserTile(doc)),
        ],
      ],
    );
  }

  Widget _buildJourneyTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ListTile(
      leading: const CircleAvatar(
        child: Icon(Icons.map),
      ),
      title: Text(data['title'] ?? 'Untitled Journey'),
      subtitle: Text(data['description'] ?? ''),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // Navigate to journey details
      },
    );
  }

  Widget _buildUserTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: data['photoURL'] != null
            ? NetworkImage(data['photoURL'])
            : null,
        child: data['photoURL'] == null ? const Icon(Icons.person) : null,
      ),
      title: Text(data['username'] ?? 'Unknown User'),
      subtitle: Text(data['userType'] ?? 'User'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // Navigate to user profile
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Search',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search for journeys, users, or tags',
                          prefixIcon: _isLoading 
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    if (_isSearching) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                            _isSearching = false;
                            _journeyResults = null;
                            _userResults = null;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isSearching
                ? _buildSearchResults()
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start typing to search',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
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
} 