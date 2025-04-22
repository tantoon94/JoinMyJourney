import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:location/location.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CreateJourneyPage extends StatefulWidget {
  const CreateJourneyPage({super.key});

  @override
  State<CreateJourneyPage> createState() => _CreateJourneyPageState();
}

class _CreateJourneyPageState extends State<CreateJourneyPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _imagePicker = ImagePicker();
  
  GoogleMapController? _mapController;
  Location _location = Location();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> _waypoints = [];
  List<Map<String, dynamic>> _steps = [];
  
  String _selectedCategory = 'Missions';
  int _recommendedPeople = 2;
  double _estimatedCost = 15.0;
  double _durationInHours = 2.0;
  File? _selectedImage;
  bool _isLoading = false;
  bool _showSteps = false;
  bool _isTracking = false;
  StreamSubscription<LocationData>? _locationSubscription;
  List<LatLng> _trackPoints = [];
  
  final List<String> _categories = ['Missions', 'Adventures', 'Chill'];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(String journeyId) async {
    if (_selectedImage == null) return null;
    
    try {
      final ref = _storage.ref().child('journeys/$journeyId.jpg');
      await ref.putFile(_selectedImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationData = await _location.getLocation();
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(locationData.latitude!, locationData.longitude!),
            15,
          ),
        );
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _getCurrentLocation();
  }

  Future<String?> _showAddStepDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Journey Step'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Step Name',
                hintText: 'e.g., Visit Tower Bridge',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Step Description',
                hintText: 'e.g., Take photos from the glass floor',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context, '${nameController.text}|||${descriptionController.text}');
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _onMapTap(LatLng position) async {
    final stepInfo = await _showAddStepDialog();
    if (stepInfo == null) return;

    final parts = stepInfo.split('|||');
    final stepName = parts[0];
    final stepDescription = parts.length > 1 ? parts[1] : '';

    setState(() {
      _waypoints.add(position);
      _markers.add(
        Marker(
          markerId: MarkerId('waypoint_${_waypoints.length}'),
          position: position,
          infoWindow: InfoWindow(
            title: stepName,
            snippet: stepDescription,
          ),
        ),
      );
      _updatePolylines();
    });

    _steps.add({
      'name': stepName,
      'description': stepDescription,
      'position': GeoPoint(position.latitude, position.longitude),
      'duration': 0,
      'distance': 0,
    });
  }

  void _updatePolylines() {
    if (_waypoints.length < 2) return;
    
    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _waypoints,
          color: Colors.blue,
          width: 3,
        ),
      );
    });
  }

  Future<void> _saveJourney() async {
    if (!_formKey.currentState!.validate() || _waypoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and add waypoints')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) {
        throw Exception('User data not found');
      }

      final userData = userDoc.data();
      if (userData == null) {
        throw Exception('User data is null');
      }

      final username = userData['username'] as String?;
      final photoUrl = userData['photoUrl'] as String?;

      if (username == null) {
        throw Exception('Username not found in user data');
      }

      // Upload image if selected
      String? imageUrl;
      if (_selectedImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('journey_images')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      // Prepare journey data
      final journeyData = {
        'id': '',
        'title': _titleController.text,
        'description': _descriptionController.text,
        'creatorId': user.uid,
        'creatorName': username,
        'creatorPhotoUrl': photoUrl,
        'category': _selectedCategory,
        'recommendedPeople': _recommendedPeople,
        'estimatedCost': _estimatedCost,
        'durationInHours': _durationInHours,
        'imageUrl': imageUrl,
        'steps': _steps,
        'waypoints': _waypoints.map((point) => {
          'latitude': point.latitude,
          'longitude': point.longitude,
        }).toList(),
        'trackPoints': _trackPoints.map((point) => {
          'latitude': point.latitude,
          'longitude': point.longitude,
        }).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'isPublic': true,
      };

      // Save journey using batch write
      final batch = FirebaseFirestore.instance.batch();
      
      // Add to main journeys collection
      final journeyRef = FirebaseFirestore.instance.collection('journeys').doc();
      batch.set(journeyRef, journeyData);
      
      // Add to user's journeys subcollection
      final userJourneyRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('journeys')
          .doc(journeyRef.id);
      batch.set(userJourneyRef, {
        'journeyId': journeyRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Update user's journey count
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(user.uid),
        {'journeyCount': FieldValue.increment(1)},
      );

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journey created successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating journey: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showPreviewDialog() async {
    if (!_formKey.currentState!.validate() || _waypoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and add waypoints')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Journey Preview'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImage!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                _titleController.text,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(_descriptionController.text),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.category, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(_selectedCategory),
                  const SizedBox(width: 16),
                  Icon(Icons.people, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('$_recommendedPeople people'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('£$_estimatedCost'),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${_durationInHours.toStringAsFixed(1)} hours'),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Journey Steps',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text('${index + 1}'),
                    ),
                    title: Text(step['name']),
                    subtitle: Text(step['description']),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Edit'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save Journey'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _saveJourney();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showSteps ? 'Journey Steps' : 'Journey Details'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: CircularProgressIndicator(),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _showPreviewDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_showSteps) _buildStepsForm() else _buildGeneralForm(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _showSteps ? 1 : 0,
        onTap: (index) {
          setState(() {
            _showSteps = index == 1;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.edit),
            label: 'Details',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Steps',
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 40),
                            Text('Add Journey Photo'),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Journey Title',
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
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _recommendedPeople.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Recommended People',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _recommendedPeople = int.tryParse(value) ?? 2;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _estimatedCost.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Estimated Cost (£)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _estimatedCost = double.tryParse(value) ?? 15.0;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _durationInHours.toString(),
              decoration: const InputDecoration(
                labelText: 'Duration (hours)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _durationInHours = double.tryParse(value) ?? 2.0;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsForm() {
    return Expanded(
      child: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(51.5074, -0.1278),
              zoom: 13,
            ),
            markers: _markers,
            polylines: _polylines,
            onTap: _onMapTap,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          Positioned(
            right: 16,
            bottom: _steps.isEmpty ? 16 : 240,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'track',
                  onPressed: _toggleTracking,
                  backgroundColor: _isTracking ? Colors.red : Colors.blue,
                  child: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'preview',
                  onPressed: _showJourneyPreview,
                  child: const Icon(Icons.map),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'location',
                  onPressed: _getCurrentLocation,
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
          if (_steps.isNotEmpty)
            DraggableScrollableSheet(
              initialChildSize: 0.3,
              minChildSize: 0.1,
              maxChildSize: 0.7,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _steps.length,
                          itemBuilder: (context, index) {
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text('${index + 1}'),
                                ),
                                title: Text(_steps[index]['name']),
                                subtitle: Text(_steps[index]['description']),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    setState(() {
                                      _steps.removeAt(index);
                                      _waypoints.removeAt(index);
                                      _markers = _markers.where((marker) =>
                                        marker.markerId.value != 'waypoint_${index + 1}').toSet();
                                      _updatePolylines();
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _toggleTracking() async {
    if (_isTracking) {
      _locationSubscription?.cancel();
      setState(() {
        _isTracking = false;
      });
    } else {
      final locationData = await _location.getLocation();
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(locationData.latitude!, locationData.longitude!),
          18,
        ),
      );

      _locationSubscription = _location.onLocationChanged.listen((locationData) {
        if (locationData.latitude != null && locationData.longitude != null) {
          setState(() {
            _trackPoints.add(LatLng(locationData.latitude!, locationData.longitude!));
            _updateTrackPolyline();
          });
        }
      });

      setState(() {
        _isTracking = true;
      });
    }
  }

  void _updateTrackPolyline() {
    if (_trackPoints.length < 2) return;
    
    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('track'),
          points: _trackPoints,
          color: Colors.blue,
          width: 5,
        ),
      );
    });
  }

  Future<void> _showJourneyPreview() async {
    if (_trackPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tracking data available')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Journey Preview'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _trackPoints.first,
                  zoom: 15,
                ),
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_steps.isNotEmpty) ...[
                          const Text(
                            'Journey Steps',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              itemCount: _steps.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text('${index + 1}'),
                                  ),
                                  title: Text(_steps[index]['name']),
                                  subtitle: Text(_steps[index]['description']),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                Text(
                                  '${_trackPoints.length}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text('Points'),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  '${_steps.length}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text('Stops'),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  _durationInHours.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text('Hours'),
                              ],
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

  @override
  void dispose() {
    if (_locationSubscription != null) {
      _locationSubscription!.cancel();
    }
    if (_mapController != null) {
      _mapController!.dispose();
    }
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
} 