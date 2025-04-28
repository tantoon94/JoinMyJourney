import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addJourney(Map<String, dynamic> journeyData) async {
    await _db.collection('journeys').add(journeyData);
  }

  Stream<QuerySnapshot> getJourneys() {
    return _db.collection('journeys').snapshots();
  }

  Future<Map<String, dynamic>?> verifyJourneyData(String journeyId) async {
    try {
      developer.log('Verifying journey data for ID: $journeyId');
      
      // Get the main journey document
      final journeyDoc = await _db.collection('journeys').doc(journeyId).get();
      if (!journeyDoc.exists) {
        developer.log('Journey document does not exist');
        return null;
      }

      final journeyData = journeyDoc.data()!;
      developer.log('Journey data loaded: ${journeyData.keys.join(', ')}');
      developer.log('Title: ${journeyData['title']}');
      developer.log('Description: ${journeyData['description']}');
      
      // Check map thumbnail
      if (journeyData['mapThumbnailData'] != null) {
        final thumbnailData = journeyData['mapThumbnailData'];
        developer.log('Map thumbnail details:');
        developer.log('- Size: ${thumbnailData['size']} bytes');
        developer.log('- Type: ${thumbnailData['type']}');
        developer.log('- Dimensions: ${thumbnailData['dimensions']}');
      } else {
        developer.log('No map thumbnail data found');
      }

      // Get stops
      final stopsSnapshot = await journeyDoc.reference.collection('stops').orderBy('order').get();
      developer.log('Found ${stopsSnapshot.docs.length} stops');
      
      for (var stopDoc in stopsSnapshot.docs) {
        final stopData = stopDoc.data();
        developer.log('Stop ${stopData['order']}: ${stopData['name']}');
        if (stopData['imageData'] != null) {
          developer.log('- Has image data');
        }
      }

      // Get route points
      final routeDoc = await journeyDoc.reference.collection('route').doc('points').get();
      if (routeDoc.exists) {
        final routeData = routeDoc.data()!;
        final points = routeData['points'] as List<dynamic>;
        developer.log('Found ${points.length} route points');
      } else {
        developer.log('No route points found');
      }

      return journeyData;
    } catch (e) {
      developer.log('Error verifying journey data', error: e);
      return null;
    }
  }
}