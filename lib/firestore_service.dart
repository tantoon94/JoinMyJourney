import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addJourney(Map<String, dynamic> journeyData) async {
    await _db.collection('journeys').add(journeyData);
  }

  Stream<QuerySnapshot> getJourneys() {
    return _db.collection('journeys').snapshots();
  }
}