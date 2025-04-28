import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DataMigrationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Current schema version
  static const int currentSchemaVersion = 1;

  // Migration functions for each version
  Future<void> migrateToVersion1() async {
    final batch = _db.batch();
    
    // Migrate users
    final usersSnapshot = await _db.collection('users').get();
    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      if (!data.containsKey('schemaVersion')) {
        batch.update(doc.reference, {
          'schemaVersion': 1,
          'userType': data['userType'] ?? 'regular',
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    }

    // Migrate journeys
    final journeysSnapshot = await _db.collection('journeys').get();
    for (var doc in journeysSnapshot.docs) {
      final data = doc.data();
      if (!data.containsKey('schemaVersion')) {
        batch.update(doc.reference, {
          'schemaVersion': 1,
          'totalStops': data['totalStops'] ?? 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // Migrate stops
    for (var journeyDoc in journeysSnapshot.docs) {
      final stopsSnapshot = await journeyDoc.reference.collection('stops').get();
      for (var doc in stopsSnapshot.docs) {
        final data = doc.data();
        if (!data.containsKey('schemaVersion')) {
          batch.update(doc.reference, {
            'schemaVersion': 1,
            'isActive': data['isActive'] ?? true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    await batch.commit();
  }

  // Check and perform necessary migrations
  Future<void> checkAndMigrate() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;

      final currentVersion = userDoc.data()?['schemaVersion'] ?? 0;
      if (currentVersion < currentSchemaVersion) {
        // Perform migrations in sequence
        if (currentVersion < 1) {
          await migrateToVersion1();
        }
        // Add more migrations here as needed

        // Update user's schema version
        await _db.collection('users').doc(user.uid).update({
          'schemaVersion': currentSchemaVersion,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error during migration: $e');
      // Log error to your error tracking service
    }
  }

  // Helper method to check if a document needs migration
  Future<bool> needsMigration(String collection, String docId) async {
    final doc = await _db.collection(collection).doc(docId).get();
    if (!doc.exists) return false;
    
    final currentVersion = doc.data()?['schemaVersion'] ?? 0;
    return currentVersion < currentSchemaVersion;
  }

  // Helper method to get document version
  Future<int> getDocumentVersion(String collection, String docId) async {
    final doc = await _db.collection(collection).doc(docId).get();
    if (!doc.exists) return 0;
    
    return doc.data()?['schemaVersion'] ?? 0;
  }
} 