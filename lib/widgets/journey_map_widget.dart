import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

enum JourneyMapMode {
  planning, // For CreateJourneyPage
  tracking, // For JourneyMapPage
  viewing   // For viewing existing journeys
}

class JourneyMapWidget extends StatefulWidget {
  final JourneyMapMode mode;
  final void Function(LatLng)? onMapTap;
  final void Function(Position)? onPositionUpdate;
  final Set<Marker>? initialMarkers;
  final Set<Polyline>? initialPolylines;
  final bool centerOnUser;
  final GoogleMapController? Function(GoogleMapController)? onMapCreated;

  const JourneyMapWidget({
    super.key,
    required this.mode,
    this.onMapTap,
    this.onPositionUpdate,
    this.initialMarkers,
    this.initialPolylines,
    this.centerOnUser = true,
    this.onMapCreated,
  });

  @override
  State<JourneyMapWidget> createState() => _JourneyMapWidgetState();
}

class _JourneyMapWidgetState extends State<JourneyMapWidget> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _markers = widget.initialMarkers ?? {};
    _polylines = widget.initialPolylines ?? {};
    _checkLocationPermission();
  }

  @override
  void didUpdateWidget(JourneyMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMarkers != oldWidget.initialMarkers) {
      setState(() {
        _markers = widget.initialMarkers ?? {};
      });
      _updateCameraToShowAllMarkers();
    }
    if (widget.initialPolylines != oldWidget.initialPolylines) {
      setState(() {
        _polylines = widget.initialPolylines ?? {};
      });
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    final status = await Geolocator.checkPermission();
    if (status == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      if (result == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required')),
        );
        return;
      }
    }
    if (status == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission is permanently denied')),
      );
      return;
    }
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        if (widget.centerOnUser) {
          _updateCamera();
        }
      });
      widget.onPositionUpdate?.call(position);

      if (widget.mode == JourneyMapMode.tracking) {
        _startPositionStream();
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _startPositionStream() {
    _positionStream = Geolocator.getPositionStream().listen((position) {
      setState(() {
        _currentPosition = position;
        if (widget.centerOnUser) {
          _updateCamera();
        }
      });
      widget.onPositionUpdate?.call(position);
    });
  }

  void _updateCamera() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        ),
      );
    }
  }

  void _updateCameraToShowAllMarkers() {
    if (_markers.isEmpty || _mapController == null) return;

    double minLat = _markers.first.position.latitude;
    double maxLat = _markers.first.position.latitude;
    double minLng = _markers.first.position.longitude;
    double maxLng = _markers.first.position.longitude;

    for (final marker in _markers) {
      if (marker.position.latitude < minLat) minLat = marker.position.latitude;
      if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
      if (marker.position.longitude < minLng) minLng = marker.position.longitude;
      if (marker.position.longitude > maxLng) maxLng = marker.position.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50.0),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (widget.onMapCreated != null) {
      _mapController = widget.onMapCreated!(controller);
    }
    _getCurrentLocation();
    if (_markers.isNotEmpty) {
      _updateCameraToShowAllMarkers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: _onMapCreated,
      initialCameraPosition: CameraPosition(
        target: _currentPosition != null
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : const LatLng(51.5074, -0.1278), // Default to London
        zoom: 15,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      markers: _markers,
      polylines: _polylines,
      onTap: widget.mode == JourneyMapMode.planning ? widget.onMapTap : null,
    );
  }
} 