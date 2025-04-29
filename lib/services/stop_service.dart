import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/journey.dart' as journey;

class StopService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<Map<String, dynamic>?> uploadStopImage(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      final ref = _storage
          .ref()
          .child('stops/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();

      return {
        'url': url,
        'path': ref.fullPath,
        'size': bytes.length,
        'type': 'image/jpeg',
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error uploading stop image: $e');
      return null;
    }
  }

  Future<void> addStop(String journeyId, journey.Stop stop) async {
    try {
      final stopRef = _db
          .collection('journeys')
          .doc(journeyId)
          .collection('stops')
          .doc(stop.id);
      await stopRef.set(stop.toMap());
    } catch (e) {
      print('Error adding stop: $e');
      rethrow;
    }
  }

  Future<void> updateStop(String journeyId, journey.Stop stop) async {
    try {
      final stopRef = _db
          .collection('journeys')
          .doc(journeyId)
          .collection('stops')
          .doc(stop.id);
      await stopRef.update(stop.toMap());
    } catch (e) {
      print('Error updating stop: $e');
      rethrow;
    }
  }

  Future<void> deleteStop(String journeyId, String stopId) async {
    try {
      final stopRef = _db
          .collection('journeys')
          .doc(journeyId)
          .collection('stops')
          .doc(stopId);
      await stopRef.delete();
    } catch (e) {
      print('Error deleting stop: $e');
      rethrow;
    }
  }

  Future<void> reorderStops(String journeyId, List<journey.Stop> stops) async {
    try {
      final batch = _db.batch();
      for (var i = 0; i < stops.length; i++) {
        final stop = stops[i];
        final stopRef = _db
            .collection('journeys')
            .doc(journeyId)
            .collection('stops')
            .doc(stop.id);
        batch.update(stopRef, {'order': i + 1});
      }
      await batch.commit();
    } catch (e) {
      print('Error reordering stops: $e');
      rethrow;
    }
  }

  Stream<List<journey.Stop>> getStops(String journeyId) {
    return _db
        .collection('journeys')
        .doc(journeyId)
        .collection('stops')
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => journey.Stop.fromMap(doc.data()))
            .toList());
  }
}
