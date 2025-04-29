import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/journey.dart';
import '../utils/image_handler.dart';
import 'package:location/location.dart' as location;
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

class CreateJourneyPage extends StatefulWidget {
  final String? journeyId;
  final bool isEditing;

  const CreateJourneyPage({
    super.key,
    this.journeyId,
    this.isEditing = false,
  });

  @override
  State<CreateJourneyPage> createState() => _CreateJourneyPageState();
}

class _CreateJourneyPageState extends State<CreateJourneyPage> {
  // Controllers
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  // Services
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;
  final _location = location.Location();

  // Map related
  GoogleMapController? _mapController;
  LatLng _mapCenter = const LatLng(51.5074, -0.1278); // Default to London
  List<LatLng> _route = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Journey data
  List<Stop> _stops = [];
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
  bool _isAddingStop = false;
  LatLng? _selectedLocation;

  bool _isInitialized = false;

  // Add these fields to the state class
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
    _cleanupResources();
    super.dispose();
  }

  void _cleanupResources() {
    _trackingTimer?.cancel();
    _locationStreamSubscription?.cancel();
    _mapController?.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _stopTitleController.dispose();
    _stopDescriptionController.dispose();
    _stopNotesController.dispose();
  }

  Future<void> _initializePage() async {
    try {
      await _initializeLocation();
      if (widget.journeyId != null && mounted) {
        await _loadExistingJourney();
      }
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing location: $e')),
        );
      }
    }
  }

  Future<void> _loadExistingJourney() async {
    try {
      setState(() => _isLoading = true);

      final doc = await _db.collection('journeys').doc(widget.journeyId).get();
      if (!doc.exists) return;

      final data = doc.data()!;

      setState(() {
        _titleController.text = data['title'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _locationController.text = data['location'] ?? '';
        _selectedCategory = data['category'] ?? 'Adventures';
        _difficulty = data['difficulty'] ?? 1;
        _cost = data['cost'] ?? 1;
        _recommendedPeople = data['recommendedPeople'] ?? 2;
        _durationInHours = (data['durationInHours'] ?? 1.0).clamp(0.5, 24.0);
        // Store original values for unsaved changes detection
        _originalTitle = _titleController.text;
        _originalDescription = _descriptionController.text;
        _originalLocation = _locationController.text;
        _originalCategory = _selectedCategory;
        _originalDifficulty = _difficulty;
        _originalCost = _cost;
        _originalRecommendedPeople = _recommendedPeople;
        _originalDurationInHours = _durationInHours;
      });

      // Load route points
      final routeDoc =
          await doc.reference.collection('route').doc('points').get();
      if (routeDoc.exists) {
        final routeData = routeDoc.data()!;
        final points = (routeData['points'] as List<dynamic>)
            .map((point) => LatLng(
                  point['latitude'] as double,
                  point['longitude'] as double,
                ))
            .toList();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _route = points;
            _updateMapFeatures();
          });
        });
      }

      // Load stops
      final stopsSnapshot =
          await doc.reference.collection('stops').orderBy('order').get();
      final stops =
          stopsSnapshot.docs.map((doc) => Stop.fromMap(doc.data())).toList();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _stops = stops;
          _updateMapFeatures();
          _originalStopsCount = stops.length;
        });
      });
    } catch (e) {
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
          if (mounted) {
            setState(() {
              final newPoint =
                  LatLng(locationData.latitude!, locationData.longitude!);
              if (_route.isNotEmpty) {
                final lastPoint = _route.last;
                _totalDistance += Geolocator.distanceBetween(
                  lastPoint.latitude,
                  lastPoint.longitude,
                  newPoint.latitude,
                  newPoint.longitude,
                );
              }
              _route.add(newPoint);
              _updateMapFeatures();
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting tracking: $e')),
        );
      }
    }
  }

  void _stopTracking() {
    _trackingTimer?.cancel();
    _locationStreamSubscription?.cancel();
    setState(() {
      _isTracking = false;
      _trackingStartTime = null;
      _trackingDuration = Duration.zero;
    });
  }

  void _updateMapFeatures() {
    _markers = _stops.asMap().entries.map((entry) {
      final i = entry.key;
      final stop = entry.value;
      return Marker(
        markerId: MarkerId('stop_$i'),
        position: stop.location,
        infoWindow: InfoWindow(
          title: '${stop.order}. ${stop.name}',
          snippet: stop.description,
        ),
        draggable: true,
        onDragEnd: (newPosition) {
          setState(() {
            _stops[i] = Stop(
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

  void _reorderStops(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final stop = _stops.removeAt(oldIndex);
      _stops.insert(newIndex, stop);

      // Update order numbers
      for (var i = 0; i < _stops.length; i++) {
        _stops[i] = Stop(
          id: _stops[i].id,
          name: _stops[i].name,
          description: _stops[i].description,
          location: _stops[i].location,
          order: i + 1,
          notes: _stops[i].notes,
          imageData: _stops[i].imageData,
          createdAt: _stops[i].createdAt,
          updatedAt: DateTime.now(),
          status: _stops[i].status,
          version: _stops[i].version + 1,
        );
      }

      _updateMapFeatures();
    });
  }

  Future<void> _saveJourney() async {
    print('=== Starting journey save process ===');
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

    setState(() => _isSaving = true);
    print('Saving journey...');

    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('User not authenticated');
        throw Exception('User not authenticated');
      }

      // Show loading dialog
      if (mounted) {
        print('Showing loading dialog...');
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(
              color: Colors.amber,
            ),
          ),
        );
      }

      // Generate Google Static Maps URL for map thumbnail
      String generateStaticMapUrl(
          List<LatLng> route, List<Stop> stops, String apiKey) {
        final path = route.map((p) => '${p.latitude},${p.longitude}').join('|');
        final markers = stops
            .map((s) => '${s.location.latitude},${s.location.longitude}')
            .join('|');
        return 'https://maps.googleapis.com/maps/api/staticmap'
            '?size=600x300'
            '&path=color:0x0000ff|weight:5|$path'
            '&markers=color:red|$markers'
            '&key=AIzaSyBleoptuqG4muN960mY7UWdTUljJi_Fycc';
      }

      final mapThumbnailUrl = generateStaticMapUrl(
          _route, _stops, 'AIzaSyBleoptuqG4muN960mY7UWdTUljJi_Fycc');

      print('Creating journey reference...');
      final journeyRef = _db
          .collection('journeys')
          .doc(widget.journeyId ?? _db.collection('journeys').doc().id);
      print('Journey reference created: ${journeyRef.path}');

      print('Initializing batch write...');
      final batch = _db.batch();
      final now = DateTime.now();

      // Create journey data
      print('Preparing journey data...');
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
        'mapThumbnailUrl': mapThumbnailUrl,
        'imageData': _stops.isNotEmpty && _stops[0].imageData != null
            ? _stops[0].imageData
            : null,
        'status': 'active',
        'visibility': 'public',
        'lastModifiedBy': user.uid,
        'version': 1,
      };

      print(
          'Journey data prepared with fields: ${journeyData.keys.join(', ')}');
      print('Adding journey metadata to batch...');
      batch.set(journeyRef, journeyData);
      print('Journey metadata added to batch');

      // Save stops in a subcollection
      print('Starting to add stops to batch...');
      for (var stop in _stops) {
        print('Processing stop: ${stop.name} (Order: ${stop.order})');
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
        print('Adding stop to batch: ${stop.name}');
        batch.set(journeyRef.collection('stops').doc(stop.id), stopData);
      }
      print('All stops added to batch');

      // Save route points
      print('Preparing route points...');
      final routePoints = _route
          .map((point) => {
                'latitude': point.latitude,
                'longitude': point.longitude,
                'timestamp': Timestamp.fromDate(now),
              })
          .toList();
      print('Route points prepared: ${routePoints.length} points');

      print('Adding route points to batch...');
      batch.set(journeyRef.collection('route').doc('points'), {
        'points': routePoints,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Route points added to batch');

      print('Committing batch...');
      await batch.commit();
      print('Batch committed successfully');

      // Verify the saved data
      print('Verifying saved journey data...');
      final savedDoc = await journeyRef.get();
      print('Document exists: ${savedDoc.exists}');
      if (savedDoc.exists) {
        final savedData = savedDoc.data()!;
        print('Saved journey details:');
        print('- Title: ${savedData['title']}');
        print('- Description: ${savedData['description']}');
        print(
            '- Map thumbnail present: ${savedData['mapThumbnailUrl'] != null}');
        if (savedData['mapThumbnailUrl'] != null) {
          print('- Map thumbnail URL: ${savedData['mapThumbnailUrl']}');
        }
      }

      if (mounted) {
        print('Closing loading dialog...');
        Navigator.of(context).pop();

        print('Showing success message...');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Journey saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        print('Navigating to main page...');
        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e) {
      print('Error saving journey: $e');
      print('Stack trace: ${StackTrace.current}');
      if (mounted) {
        print('Closing loading dialog due to error...');
        Navigator.of(context).pop();

        print('Showing error message...');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving journey: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        print('Resetting saving state...');
        setState(() => _isSaving = false);
      }
      print('=== Journey save process completed ===');
    }
  }

  Future<void> _editStop(Stop stop) async {
    setState(() {
      _stopTitleController.text = stop.name;
      _stopDescriptionController.text = stop.description;
      _stopNotesController.text = stop.notes ?? '';
      _stopImage = stop.imageData;
      _selectedLocation = stop.location;
    });

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
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add Photo'),
                  onPressed: () async {
                    final image = await ImageHandler.pickImage(context);
                    if (image != null) {
                      final imageData = await ImageHandler.getImageData(image);
                      if (imageData != null) {
                        setState(() => _stopImage = imageData);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_stopTitleController.text.isNotEmpty &&
                    _stopDescriptionController.text.isNotEmpty &&
                    _selectedLocation != null) {
                  Navigator.of(context).pop({
                    'name': _stopTitleController.text,
                    'description': _stopDescriptionController.text,
                    'notes': _stopNotesController.text,
                    'imageData': _stopImage,
                    'location': _selectedLocation,
                  });
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        final index = _stops.indexWhere((s) => s.id == stop.id);
        if (index != -1) {
          _stops[index] = Stop(
            id: stop.id,
            name: result['name'],
            description: result['description'],
            location: result['location'],
            order: stop.order,
            notes: result['notes'],
            imageData: result['imageData'],
            createdAt: stop.createdAt,
            updatedAt: DateTime.now(),
            status: stop.status,
            version: stop.version + 1,
          );
          _updateMapFeatures();
        }
      });
    }

    _stopTitleController.clear();
    _stopDescriptionController.clear();
    _stopNotesController.clear();
    _stopImage = null;
    _selectedLocation = null;
  }

  void _startAddingStop() {
    setState(() {
      _isAddingStop = true;
      _selectedLocation = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tap on the map to add a stop'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleMapTap(LatLng location) {
    if (_isAddingStop) {
      setState(() {
        _selectedLocation = location;
      });
      _showAddStopDialog();
    }
  }

  Future<void> _showAddStopDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Stop'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _stopTitleController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'Enter stop name',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _stopDescriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Enter stop description',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _stopNotesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Enter additional notes',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Add Photo'),
                      onPressed: () async {
                        final image = await ImageHandler.pickImage(context);
                        if (image != null) {
                          final imageData =
                              await ImageHandler.getImageData(image);
                          if (imageData != null) {
                            setState(() => _stopImage = imageData);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_stopTitleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a name for the stop'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (_stopDescriptionController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Please enter a description for the stop'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (_selectedLocation == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select a location on the map'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop({
                      'name': _stopTitleController.text.trim(),
                      'description': _stopDescriptionController.text.trim(),
                      'notes': _stopNotesController.text.trim(),
                      'imageData': _stopImage,
                      'location': _selectedLocation,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Add Stop'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _stops.add(Stop(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: result['name'],
          description: result['description'],
          location: result['location'],
          order: _stops.length + 1,
          notes: result['notes'],
          imageData: result['imageData'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: 'active',
          version: 1,
        ));
        _updateMapFeatures();
      });
    }

    setState(() {
      _isAddingStop = false;
      _selectedLocation = null;
    });
    _stopTitleController.clear();
    _stopDescriptionController.clear();
    _stopNotesController.clear();
    _stopImage = null;
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
        _stopTracking();
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
    final shouldClose = await _onWillPop();
    if (shouldClose && mounted) {
      Navigator.pushReplacementNamed(context, '/main');
    }
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
      // Store original values when loading the journey for comparison
      // You may need to add fields like _originalTitle, _originalDescription, etc.
      return _titleController.text != (_originalTitle ?? '') ||
          _descriptionController.text != (_originalDescription ?? '') ||
          _locationController.text != (_originalLocation ?? '') ||
          _selectedCategory != (_originalCategory ?? 'Adventures') ||
          _difficulty != (_originalDifficulty ?? 1) ||
          _cost != (_originalCost ?? 1) ||
          _recommendedPeople != (_originalRecommendedPeople ?? 2) ||
          _durationInHours != (_originalDurationInHours ?? 1.0) ||
          _stops.length != (_originalStopsCount ?? 0);
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
        return await _onWillPop();
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
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Journey Details
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
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
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Journey Settings
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Map
              SizedBox(
                height: 300,
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
                      onTap: _handleMapTap,
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Column(
                        children: [
                          FloatingActionButton(
                            heroTag: 'create_main',
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
                            heroTag: 'create_add_stop',
                            onPressed: _isSaving ? null : _startAddingStop,
                            backgroundColor: Colors.amber,
                            tooltip: 'Add Stop',
                            child: const Icon(Icons.add_location),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tracking Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (_isTracking)
                    Text(
                      '${_trackingDuration.inHours}:${(_trackingDuration.inMinutes % 60).toString().padLeft(2, '0')}:${(_trackingDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 18),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Stops List
              const Text(
                'Stops',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ReorderableGridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  childAspectRatio: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _stops.length,
                itemBuilder: (context, index) {
                  final stop = _stops[index];
                  return Card(
                    key: ValueKey(stop.id),
                    child: ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Center(
                              child: Text(
                                '${stop.order}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          stop.imageData != null
                              ? ImageHandler.buildImagePreview(
                                  context: context,
                                  imageData: stop.imageData,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(Icons.place),
                        ],
                      ),
                      title: Text(stop.name),
                      subtitle: Text(stop.description),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editStop(stop),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              setState(() {
                                _stops.removeWhere((s) => s.id == stop.id);
                                _updateMapFeatures();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                onReorder: _reorderStops,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
