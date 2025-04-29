import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/journey.dart' as journey;
import '../utils/image_handler.dart';
import '../services/stop_service.dart';
import 'package:location/location.dart' as location;
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:http/http.dart' as http;

class JourneyTrackingPage extends StatefulWidget {
  final String? journeyId;
  final bool isEditing;

  const JourneyTrackingPage({
    super.key,
    this.journeyId,
    this.isEditing = false,
  });

  @override
  State<JourneyTrackingPage> createState() => _JourneyTrackingPageState();
}

class _JourneyTrackingPageState extends State<JourneyTrackingPage> {
  // Controllers
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  // Services
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;
  final _stopService = StopService();
  final _location = location.Location();

  // Map related
  GoogleMapController? _mapController;
  LatLng _mapCenter = const LatLng(51.5074, -0.1278); // Default to London
  List<LatLng> _route = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Journey data
  List<journey.Stop> _stops = [];
  String _selectedCategory = 'Adventures';
  int _difficulty = 1;
  int _cost = 1;
  int _recommendedPeople = 2;
  double _durationInHours = 1.0;

  // UI state
  bool _isSaving = false;
  bool _isTracking = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Location tracking
  StreamSubscription<location.LocationData>? _locationStreamSubscription;
  DateTime? _trackingStartTime;
  Duration _trackingDuration = Duration.zero;
  Timer? _trackingTimer;
  double _totalDistance = 0.0;

  // Categories
  final List<String> _categories = ['Missions', 'Adventures', 'Chill'];

  // Stop management
  final _stopTitleController = TextEditingController();
  final _stopDescriptionController = TextEditingController();
  final _stopNotesController = TextEditingController();
  Map<String, dynamic>? _stopImage;
  final bool _isAddingStop = false;
  LatLng? _selectedLocation;

  bool _isInitialized = false;

  // Original values for comparison
  String? _originalTitle;
  String? _originalDescription;
  String? _originalLocation;
  String? _originalCategory;
  int? _originalDifficulty;
  int? _originalCost;
  int? _originalRecommendedPeople;
  double? _originalDurationInHours;
  int? _originalStopsCount;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  @override
  void dispose() {
    print('Disposing journey tracking page...');
    _cleanupResources();
    super.dispose();
  }

  void _cleanupResources() {
    print('Cleaning up resources...');
    _trackingTimer?.cancel();
    _locationStreamSubscription?.cancel();
    _mapController?.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _stopTitleController.dispose();
    _stopDescriptionController.dispose();
    _stopNotesController.dispose();
    print('Resources cleaned up');
  }

  Future<void> _initializePage() async {
    try {
      print('Initializing journey tracking page...');
      await _initializeLocation();
      if (widget.journeyId != null && mounted) {
        print('Loading existing journey: ${widget.journeyId}');
        await _loadExistingJourney();
      }
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        print('Page initialized successfully');
      }
    } catch (e) {
      print('Error initializing page: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing page: $e')),
        );
      }
    }
  }

  Future<void> _initializeLocation() async {
    try {
      final permission = await _location.requestPermission();
      if (permission == location.PermissionStatus.granted) {
        final locationData = await _location.getLocation();
        if (mounted) {
          setState(() {
            _mapCenter =
                LatLng(locationData.latitude!, locationData.longitude!);
          });
        }
      }
    } catch (e) {
      print('Error initializing location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing location: $e')),
        );
      }
    }
  }

  Future<void> _loadExistingJourney() async {
    try {
      print('Loading journey data...');
      setState(() => _isLoading = true);

      final doc = await _db.collection('journeys').doc(widget.journeyId).get();
      if (!doc.exists) {
        print('Journey document does not exist');
        return;
      }

      final data = doc.data()!;
      print('Journey data loaded: ${data.keys.join(', ')}');

      setState(() {
        _titleController.text = data['title'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _locationController.text = data['location'] ?? '';
        _selectedCategory = data['category'] ?? 'Adventures';
        _difficulty = data['difficulty'] ?? 1;
        _cost = data['cost'] ?? 1;
        _recommendedPeople = data['recommendedPeople'] ?? 2;
        _durationInHours = (data['durationInHours'] ?? 1.0).clamp(0.5, 24.0);
        // Store original values for comparison
        _originalTitle = data['title'];
        _originalDescription = data['description'];
        _originalLocation = data['location'];
        _originalCategory = data['category'];
        _originalDifficulty = data['difficulty'];
        _originalCost = data['cost'];
        _originalRecommendedPeople = data['recommendedPeople'];
        _originalDurationInHours = data['durationInHours'];
        _originalStopsCount = data['totalStops'];
      });

      // Load route points from subcollection
      print('Loading route points...');
      final routeDoc =
          await doc.reference.collection('route').doc('points').get();
      if (routeDoc.exists) {
        final routeData = routeDoc.data()!;
        final points = (routeData['points'] as List<dynamic>)
            .map((point) => LatLng(
                  (point['latitude'] as num).toDouble(),
                  (point['longitude'] as num).toDouble(),
                ))
            .toList();
        print('Loaded ${points.length} route points');
        setState(() => _route = points);
      }

      // Load stops from subcollection
      print('Loading stops from subcollection...');
      final stopsSnapshot =
          await doc.reference.collection('stops').orderBy('order').get();
      print('Found ${stopsSnapshot.docs.length} stops in subcollection');
      for (var stopDoc in stopsSnapshot.docs) {
        print('Stop: ${stopDoc.data()}');
      }

      setState(() {
        _stops = stopsSnapshot.docs
            .map((doc) => journey.Stop.fromMap(doc.data()))
            .toList();
        _updateMapFeatures();
      });
    } catch (e) {
      print('Error loading journey: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading journey: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startTracking() async {
    try {
      final permission = await _location.requestPermission();
      if (permission == location.PermissionStatus.granted) {
        setState(() {
          _isTracking = true;
          _route = [];
          _totalDistance = 0.0;
          _trackingStartTime = DateTime.now();
          _trackingDuration = Duration.zero;
        });

        // Start tracking timer
        _trackingTimer?.cancel();
        _trackingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _trackingDuration =
                  DateTime.now().difference(_trackingStartTime!);
            });
          }
        });

        // Start location tracking
        _locationStreamSubscription?.cancel();
        _locationStreamSubscription =
            _location.onLocationChanged.listen((locationData) {
          if (_isTracking) {
            final newPoint =
                LatLng(locationData.latitude!, locationData.longitude!);
            setState(() {
              _route.add(newPoint);
              if (_route.length > 1) {
                _totalDistance += Geolocator.distanceBetween(
                  _route[_route.length - 2].latitude,
                  _route[_route.length - 2].longitude,
                  newPoint.latitude,
                  newPoint.longitude,
                );
              }
              _updateMapFeatures();
            });
          }
        });
      }
    } catch (e) {
      print('Error starting tracking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting tracking: $e')),
        );
      }
    }
  }

  Future<void> _stopTracking() async {
    setState(() {
      _isTracking = false;
    });

    _trackingTimer?.cancel();
    _locationStreamSubscription?.cancel();

    // Wait for any pending operations to complete
    await Future.delayed(const Duration(milliseconds: 100));
  }

  void _updateMapFeatures() {
    _markers = _stops.asMap().entries.map((entry) {
      final index = entry.key;
      final stop = entry.value;
      return Marker(
        markerId: MarkerId(stop.id),
        position: stop.location,
        infoWindow: InfoWindow(
          title: '${index + 1}. ${stop.name}',
          snippet: stop.description,
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (stop.imageData != null) _buildStopImage(stop.imageData),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stop.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (stop.description.isNotEmpty) ...[
                            Text(
                              stop.description,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (stop.notes?.isNotEmpty ?? false) ...[
                            const Text(
                              'Notes:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              stop.notes!,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        draggable: true,
        onDragEnd: (newPosition) {
          setState(() {
            _stops[index] = journey.Stop(
              id: stop.id,
              name: stop.name,
              description: stop.description,
              location: newPosition,
              order: stop.order,
              notes: stop.notes,
              imageData: stop.imageData,
              createdAt: stop.createdAt,
              updatedAt: DateTime.now(),
              status: stop.status,
              version: stop.version + 1,
            );
            _updateMapFeatures();
          });
        },
      );
    }).toSet();

    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _route,
        color: Colors.amber,
        width: 3,
      ),
    };

    setState(() {});
  }

  Widget _buildStopImage(Map<String, dynamic>? imageData) {
    if (imageData == null || imageData['data'] == null)
      return const SizedBox.shrink();

    try {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(12),
        ),
        child: Image.memory(
          imageData['data'],
          height: 100,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Error loading image: $error');
            return Container(
              height: 100,
              color: Colors.grey[800],
              child: const Center(
                child: Icon(Icons.error, color: Colors.red),
              ),
            );
          },
        ),
      );
    } catch (e) {
      print('Error building stop image: $e');
      return Container(
        height: 100,
        color: Colors.grey[800],
        child: const Center(
          child: Icon(Icons.error, color: Colors.red),
        ),
      );
    }
  }

  Future<void> _addStop() async {
    if (_mapController == null) return;

    try {
      final center = await _mapController!.getVisibleRegion();
      final stopLocation = LatLng(
        (center.northeast.latitude + center.southwest.latitude) / 2,
        (center.northeast.longitude + center.southwest.longitude) / 2,
      );

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Add Stop'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _stopTitleController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _stopDescriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _stopNotesController,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final image = await ImagePicker()
                            .pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          final imageData =
                              await ImageHandler.getImageData(image);
                          if (imageData != null) {
                            setState(() => _stopImage = imageData);
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error selecting image: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.image),
                    label: const Text('Add Image'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (_stopTitleController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a name')),
                    );
                    return;
                  }
                  Navigator.pop(context, {
                    'name': _stopTitleController.text,
                    'description': _stopDescriptionController.text,
                    'notes': _stopNotesController.text,
                    'image': _stopImage,
                  });
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      );

      if (result != null) {
        final now = DateTime.now();
        final newStop = journey.Stop(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: result['name'],
          description: result['description'],
          location: stopLocation,
          order: _stops.length + 1,
          notes: result['notes'],
          imageData: result['image'],
          createdAt: now,
          updatedAt: now,
          status: 'active',
          version: 1,
        );

        setState(() {
          _stops.add(newStop);
          _updateMapFeatures();
        });
      }
    } catch (e) {
      print('Error adding stop: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding stop: $e')),
        );
      }
    }
  }

  void _reorderStops(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final stop = _stops.removeAt(oldIndex);
      _stops.insert(newIndex, stop);

      // Update order numbers
      final now = DateTime.now();
      for (var i = 0; i < _stops.length; i++) {
        _stops[i] = journey.Stop(
          id: _stops[i].id,
          name: _stops[i].name,
          description: _stops[i].description,
          location: _stops[i].location,
          order: i + 1,
          notes: _stops[i].notes,
          imageData: _stops[i].imageData,
          createdAt: _stops[i].createdAt,
          updatedAt: now,
          status: _stops[i].status,
          version: _stops[i].version + 1,
        );
      }

      _updateMapFeatures();
    });
  }

  bool _hasUnsavedChanges() {
    if (widget.journeyId == null) {
      // New journey
      return _titleController.text.isNotEmpty ||
          _descriptionController.text.isNotEmpty ||
          _locationController.text.isNotEmpty ||
          _stops.isNotEmpty;
    } else {
      // Editing existing journey
      return _titleController.text != _originalTitle ||
          _descriptionController.text != _originalDescription ||
          _locationController.text != _originalLocation ||
          _selectedCategory != _originalCategory ||
          _difficulty != _originalDifficulty ||
          _cost != _originalCost ||
          _recommendedPeople != _originalRecommendedPeople ||
          _durationInHours != _originalDurationInHours ||
          _stops.length != _originalStopsCount;
    }
  }

  Future<bool> _onWillPop() async {
    if (_isTracking) {
      final shouldClose = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Stop Tracking?'),
          content: const Text(
              'You are currently tracking your journey. Do you want to stop tracking and close?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );
      if (shouldClose == true && mounted) {
        await _stopTracking();
        return true;
      }
      return false;
    }

    if (_hasUnsavedChanges()) {
      final shouldClose = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text(
              'You have unsaved changes. Do you want to discard them and close?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );
      return shouldClose ?? false;
    }

    return true;
  }

  void _handleClose() async {
    if (_isTracking) {
      final shouldClose = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Stop Tracking?'),
          content: const Text(
              'You are currently tracking your journey. Do you want to stop tracking and close?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );
      if (shouldClose == true && mounted) {
        await _stopTracking();
        Navigator.pushReplacementNamed(context, '/main');
      }
    } else if (_hasUnsavedChanges()) {
      final shouldClose = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text(
              'You have unsaved changes. Do you want to discard them and close?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );
      if (shouldClose == true && mounted) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  Future<void> _saveJourney() async {
    print('Starting journey save process...');
    if (!_formKey.currentState!.validate()) {
      print('Form validation failed');
      return;
    }

    // Validate required fields
    if (_titleController.text.trim().isEmpty) {
      print('Title is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title for your journey'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      print('Description is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a description for your journey'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_locationController.text.trim().isEmpty) {
      print('Location is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a location for your journey'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_stops.isEmpty) {
      print('No stops added');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one stop to your journey'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    print('Saving ${_stops.length} stops:');
    for (var stop in _stops) {
      print('Stop to save: ${stop.toMap()}');
    }

    setState(() => _isSaving = true);
    print('Saving journey...');

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  color: Colors.amber,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Saving your journey...',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'This may take a few moments',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('User not authenticated');
        throw Exception('User not authenticated');
      }

      // Capture map thumbnail
      print('Capturing map thumbnail...');
      final mapThumbnailData = await _captureMapThumbnail();
      print('Map thumbnail captured: ${mapThumbnailData != null}');

      final journeyRef = _db
          .collection('journeys')
          .doc(widget.journeyId ?? _db.collection('journeys').doc().id);
      print('Journey reference created: ${journeyRef.path}');

      final batch = _db.batch();
      final now = DateTime.now();

      // Create journey data
      final journeyData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'creatorId': user.uid,
        'creatorName': user.displayName ?? 'Anonymous',
        'creatorPhotoUrl': user.photoURL,
        'category': _selectedCategory,
        'difficulty': _difficulty,
        'cost': _cost,
        'recommendedPeople': _recommendedPeople,
        'durationInHours': _durationInHours,
        'createdAt': widget.journeyId == null
            ? Timestamp.fromDate(now)
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'shadowers': 0,
        'totalStops': _stops.length,
        'mapThumbnailData': mapThumbnailData,
        'status': 'active',
        'visibility': 'public',
        'lastModifiedBy': user.uid,
        'version': 1,
      };

      print('Journey data prepared: ${journeyData.keys.join(', ')}');

      // Save journey metadata
      batch.set(journeyRef, journeyData);
      print('Journey metadata added to batch');

      // Save stops in a subcollection
      for (var stop in _stops) {
        final stopData = {
          'name': stop.name,
          'description': stop.description,
          'location': {
            'latitude': stop.location.latitude,
            'longitude': stop.location.longitude,
          },
          'order': stop.order,
          'notes': stop.notes,
          'imageData': stop.imageData,
          'createdAt': widget.journeyId == null
              ? Timestamp.fromDate(now)
              : FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'status': 'active',
          'version': 1,
        };
        batch.set(journeyRef.collection('stops').doc(stop.id), stopData);
        print('Stop added to batch: $stopData');
      }

      // Save route points
      final routePoints = _route
          .map((point) => {
                'latitude': point.latitude,
                'longitude': point.longitude,
                'timestamp': Timestamp.fromDate(now),
              })
          .toList();

      batch.set(journeyRef.collection('route').doc('points'), {
        'points': routePoints,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Route points added to batch');

      print('Committing batch...');
      await batch.commit();
      print('Batch committed successfully');

      // Verify stops saved
      final stopsSnapshot = await journeyRef.collection('stops').get();
      print('Saved stops count: ${stopsSnapshot.docs.length}');
      for (var stopDoc in stopsSnapshot.docs) {
        print('Saved stop: ${stopDoc.data()}');
      }

      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Journey saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to main page
        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e, stackTrace) {
      print('Error saving journey: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();
        // Show error dialog with retry option
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error Saving Journey'),
            content: Text(
                'An error occurred while saving your journey: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _saveJourney(); // Retry saving
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _captureMapThumbnail() async {
    try {
      if (_mapController == null) {
        print('Map controller is null');
        return null;
      }

      print('Getting visible region...');
      final bounds = await _mapController!.getVisibleRegion().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('Timeout getting visible region');
          throw TimeoutException('Getting visible region timed out');
        },
      );
      final center = LatLng(
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      );
      print('Center calculated: ${center.latitude}, ${center.longitude}');

      // Prepare markers for the static map
      final markers = _stops.asMap().entries.map((entry) {
        final stop = entry.value;
        return 'markers=color:amber%7C${stop.location.latitude},${stop.location.longitude}';
      }).join('&');
      print('Markers prepared: ${_stops.length} stops');

      // Prepare path for the route
      final path = _route
          .map((point) => '${point.latitude},${point.longitude}')
          .join('|');
      print('Path prepared: ${_route.length} points');

      // Construct the static map URL
      final staticMapUrl = 'https://maps.googleapis.com/maps/api/staticmap'
          '?center=${center.latitude},${center.longitude}'
          '&zoom=13'
          '&size=800x400'
          '&scale=2'
          '&maptype=roadmap'
          '&$markers'
          '&path=color:0xFFFFA500%7Cweight:3%7C$path'
          '&key=AIzaSyBleoptuqG4muN960mY7UWdTUljJi_Fycc';
      print('Static map URL constructed');

      // Download the static map image
      print('Downloading static map...');
      final response = await http.get(Uri.parse(staticMapUrl)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Timeout downloading static map');
          throw TimeoutException('Downloading static map timed out');
        },
      );
      if (response.statusCode != 200) {
        print('Failed to download static map: ${response.statusCode}');
        return null;
      }
      print('Static map downloaded successfully');

      // Compress the image
      print('Compressing image...');
      final compressedBytes = await ImageHandler.compressAndResizeImage(
        response.bodyBytes,
        maxWidth: 800,
        maxHeight: 400,
        quality: 85,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('Timeout compressing image');
          throw TimeoutException('Compressing image timed out');
        },
      );

      if (compressedBytes == null) {
        print('Failed to compress static map');
        return null;
      }
      print('Image compressed successfully');

      // Convert to base64 for storage
      final base64Data = base64Encode(compressedBytes);
      print('Image converted to base64');

      return {
        'data': base64Data,
        'type': 'image/jpeg',
        'size': compressedBytes.length,
        'timestamp': DateTime.now().toIso8601String(),
        'name': 'map_thumbnail.jpg',
        'dimensions': {
          'width': 800,
          'height': 400,
        },
      };
    } catch (e) {
      print('Error capturing map thumbnail: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error capturing map thumbnail: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _editStop(journey.Stop stop) async {
    try {
      // Set the current stop data in the controllers
      _stopTitleController.text = stop.name;
      _stopDescriptionController.text = stop.description;
      _stopNotesController.text = stop.notes ?? '';
      _stopImage = stop.imageData;

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Edit Stop'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _stopTitleController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _stopDescriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _stopNotesController,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final image = await ImagePicker()
                            .pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          final imageData =
                              await ImageHandler.getImageData(image);
                          if (imageData != null) {
                            setState(() => _stopImage = imageData);
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error selecting image: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.image),
                    label: const Text('Change Image'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (_stopTitleController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a name')),
                    );
                    return;
                  }
                  Navigator.pop(context, {
                    'name': _stopTitleController.text,
                    'description': _stopDescriptionController.text,
                    'notes': _stopNotesController.text,
                    'image': _stopImage,
                  });
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (result != null) {
        final now = DateTime.now();
        final updatedStop = journey.Stop(
          id: stop.id,
          name: result['name'],
          description: result['description'],
          location: stop.location,
          order: stop.order,
          notes: result['notes'],
          imageData: result['image'],
          createdAt: stop.createdAt,
          updatedAt: now,
          status: stop.status,
          version: stop.version + 1,
        );

        setState(() {
          final index = _stops.indexWhere((s) => s.id == stop.id);
          if (index != -1) {
            _stops[index] = updatedStop;
            _updateMapFeatures();
          }
        });
      }
    } catch (e) {
      print('Error editing stop: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error editing stop: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.amber,
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.pushReplacementNamed(context, '/main');
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isSaving ? null : _handleClose,
          ),
          title: Text(widget.isEditing ? 'Edit Journey' : 'Create Journey'),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveJourney,
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              // Map Section with improved controls
              Expanded(
                flex: 2,
                child: Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: (controller) => _mapController = controller,
                      initialCameraPosition: CameraPosition(
                        target: _mapCenter,
                        zoom: 13,
                      ),
                      markers: _markers,
                      polylines: _polylines,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: true,
                      compassEnabled: true,
                      mapToolbarEnabled: false,
                    ),
                    // Enhanced Tracking Controls
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Column(
                        children: [
                          FloatingActionButton(
                            heroTag: 'tracking_main',
                            onPressed: _isSaving
                                ? null
                                : (_isTracking
                                    ? _stopTracking
                                    : _startTracking),
                            backgroundColor:
                                _isTracking ? Colors.red : Colors.green,
                            tooltip: _isTracking
                                ? 'Stop Tracking'
                                : 'Start Tracking',
                            child: Icon(
                                _isTracking ? Icons.stop : Icons.play_arrow),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton(
                            heroTag: 'tracking_add_stop',
                            onPressed: _isSaving ? null : _addStop,
                            backgroundColor: Colors.amber,
                            tooltip: 'Add Stop',
                            child: const Icon(Icons.add_location),
                          ),
                        ],
                      ),
                    ),
                    // Enhanced Tracking Info
                    if (_isTracking)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.timer,
                                        color: Colors.amber),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Duration: ${_trackingDuration.inMinutes}m ${_trackingDuration.inSeconds % 60}s',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.directions_walk,
                                        color: Colors.amber),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Distance: ${(_totalDistance / 1000).toStringAsFixed(2)} km',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Enhanced Stops List
              Container(
                height: 160,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.place, color: Colors.amber),
                          const SizedBox(width: 8),
                          Text(
                            'Journey Stops',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Spacer(),
                          if (!_isSaving)
                            TextButton.icon(
                              onPressed: _addStop,
                              icon: const Icon(Icons.add, color: Colors.amber),
                              label: const Text('Add Stop'),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _isSaving
                          ? ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _stops.length,
                              itemBuilder: (context, index) {
                                final stop = _stops[index];
                                return Container(
                                  width: 280,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: Card(
                                    elevation: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildStopImage(stop.imageData),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    backgroundColor:
                                                        Colors.amber,
                                                    child:
                                                        Text('${stop.order}'),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      stop.name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (stop
                                                  .description.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  stop.description,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.grey[400],
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                          : ReorderableGridView.count(
                              crossAxisCount: 1,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1.5,
                              onReorder: _reorderStops,
                              children: _stops
                                  .map((stop) => Card(
                                        key: ValueKey(stop.id),
                                        elevation: 2,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildStopImage(stop.imageData),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    backgroundColor:
                                                        Colors.amber,
                                                    child:
                                                        Text('${stop.order}'),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          stop.name,
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        if (stop.description
                                                            .isNotEmpty)
                                                          Text(
                                                            stop.description,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .grey[400],
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.edit,
                                                            color:
                                                                Colors.amber),
                                                        onPressed: () =>
                                                            _editStop(stop),
                                                        tooltip: 'Edit Stop',
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.delete,
                                                            color: Colors.red),
                                                        onPressed: () {
                                                          setState(() {
                                                            _stops.removeWhere(
                                                                (s) =>
                                                                    s.id ==
                                                                    stop.id);
                                                            _updateMapFeatures();
                                                          });
                                                        },
                                                        tooltip: 'Delete Stop',
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            ),
                    ),
                  ],
                ),
              ),
              // Enhanced Journey Details
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          readOnly: _isSaving,
                          decoration: InputDecoration(
                            labelText: 'Journey Title',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.title),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a title';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          readOnly: _isSaving,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.description),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _locationController,
                          readOnly: _isSaving,
                          decoration: InputDecoration(
                            labelText: 'Location',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.location_on),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedCategory,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.category),
                                ),
                                items: _categories.map((category) {
                                  return DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  );
                                }).toList(),
                                onChanged: _isSaving
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setState(
                                              () => _selectedCategory = value);
                                        }
                                      },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _difficulty,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Difficulty',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.fitness_center),
                                ),
                                items: [1, 2, 3].map((level) {
                                  return DropdownMenuItem(
                                    value: level,
                                    child: Text('Level $level'),
                                  );
                                }).toList(),
                                onChanged: _isSaving
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setState(() => _difficulty = value);
                                        }
                                      },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _cost,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Cost',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.attach_money),
                                ),
                                items: [1, 2, 3].map((level) {
                                  return DropdownMenuItem(
                                    value: level,
                                    child: Text('Level $level'),
                                  );
                                }).toList(),
                                onChanged: _isSaving
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setState(() => _cost = value);
                                        }
                                      },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _recommendedPeople,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'People',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.people),
                                ),
                                items: [1, 2, 3, 4, 5].map((count) {
                                  return DropdownMenuItem(
                                    value: count,
                                    child: Text('$count people'),
                                  );
                                }).toList(),
                                onChanged: _isSaving
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setState(
                                              () => _recommendedPeople = value);
                                        }
                                      },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                readOnly: _isSaving,
                                initialValue: _durationInHours.toString(),
                                decoration: InputDecoration(
                                  labelText: 'Duration (hours)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.access_time),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  setState(() {
                                    _durationInHours =
                                        double.tryParse(value) ?? 1.0;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createNewJourney(BuildContext context) async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const JourneyTrackingPage(
            isEditing: false,
          ),
          fullscreenDialog: true,
        ),
      );

      if (result == true && mounted) {
        // Refresh the current page if needed
        setState(() {});
      }
    } catch (e) {
      print('Error creating journey: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating journey: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
