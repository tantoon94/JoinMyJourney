import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/mission.dart';
import '../services/storage_service.dart';

class MissionCreationPage extends StatefulWidget {
  const MissionCreationPage({super.key});

  @override
  State<MissionCreationPage> createState() => _MissionCreationPageState();
}

class _MissionCreationPageState extends State<MissionCreationPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subjectController = TextEditingController();
  final _purposeController = TextEditingController();
  final _tagsController = TextEditingController();
  final _entryLimitController = TextEditingController();
  
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StorageService _storageService = StorageService();
  
  DateTime _deadline = DateTime.now().add(const Duration(days: 30));
  final List<Map<String, dynamic>> _locations = [];
  String? _gdprFileUrl;
  bool _isLoading = false;
  final Set<Marker> _markers = {};
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subjectController.dispose();
    _purposeController.dispose();
    _tagsController.dispose();
    _entryLimitController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _pickGdprFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      
      if (result != null) {
        setState(() => _isLoading = true);
        final file = result.files.first;
        final url = await _storageService.uploadFile(
          File(file.path!),
          'gdpr/${_auth.currentUser!.uid}/${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
        setState(() {
          _gdprFileUrl = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading GDPR file: $e')),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _locations.add({
        'lat': location.latitude,
        'lng': location.longitude,
        'title': 'Location ${_locations.length + 1}',
        'description': '',
      });
      _markers.add(
        Marker(
          markerId: MarkerId('location_${_locations.length}'),
          position: location,
          infoWindow: InfoWindow(
            title: 'Location ${_locations.length}',
            snippet: 'Tap to edit details',
          ),
        ),
      );
    });
  }

  Future<void> _createMission() async {
    if (!_formKey.currentState!.validate()) return;
    if (_locations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one location')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      final mission = Mission(
        id: '',
        title: _titleController.text,
        description: _descriptionController.text,
        researcherId: user.uid,
        researcherName: user.displayName ?? 'Anonymous',
        subject: _subjectController.text,
        purpose: _purposeController.text,
        gdprFileUrl: _gdprFileUrl,
        tags: _tagsController.text.split(',').map((e) => e.trim()).toList(),
        locations: _locations,
        deadline: _deadline,
        entryLimit: int.parse(_entryLimitController.text),
        currentEntries: 0,
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _db.collection('missions').add(mission.toMap());

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mission created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating mission: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Mission'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Research Subject',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the research subject';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _purposeController,
                      decoration: const InputDecoration(
                        labelText: 'Purpose of Data Collection',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the purpose';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tagsController,
                      decoration: const InputDecoration(
                        labelText: 'Tags (comma-separated)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _entryLimitController,
                      decoration: const InputDecoration(
                        labelText: 'Entry Limit',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an entry limit';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Deadline'),
                      subtitle: Text(_deadline.toString().split(' ')[0]),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _deadline,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() => _deadline = date);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _pickGdprFile,
                      icon: const Icon(Icons.upload_file),
                      label: Text(_gdprFileUrl != null
                          ? 'GDPR File Uploaded'
                          : 'Upload GDPR File'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Add Locations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 300,
                      child: GoogleMap(
                        onMapCreated: _onMapCreated,
                        initialCameraPosition: const CameraPosition(
                          target: LatLng(51.5074, -0.1278),
                          zoom: 13,
                        ),
                        markers: _markers,
                        onTap: _onMapTap,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _createMission,
                      child: const Text('Create Mission'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 