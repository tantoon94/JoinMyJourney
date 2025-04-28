import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class ImageStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  // Storage paths
  static const String _profilePicturesPath = 'profile_pictures';
  static const String _journeyImagesPath = 'journey_images';

  Future<String> uploadProfilePicture(File image) async {
    try {
      // Create a unique filename with timestamp to avoid conflicts
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${_uuid.v4()}_$timestamp.jpg';
      
      // Use a simpler path structure
      final path = 'users/profile_pictures/$filename';
      
      // Create the storage reference
      final ref = _storage.ref().child(path);
      
      // Set metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'timestamp': timestamp.toString(),
          'type': 'profile_picture',
        },
      );

      // Upload the file
      final uploadTask = ref.putFile(image, metadata);
      
      // Wait for the upload to complete
      final snapshot = await uploadTask;
      
      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } on FirebaseException catch (e) {
      print('Firebase error uploading profile picture: ${e.code} - ${e.message}');
      if (e.code == 'object-not-found') {
        throw 'Storage path does not exist. Please check Firebase Storage rules.';
      }
      throw 'Failed to upload profile picture: ${e.message}';
    } catch (e) {
      print('Error uploading profile picture: $e');
      throw 'Failed to upload profile picture: $e';
    }
  }

  Future<String> uploadJourneyImage(File image) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${_uuid.v4()}_$timestamp.jpg';
      final path = '$_journeyImagesPath/$filename';
      
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'timestamp': timestamp.toString(),
          'type': 'journey_image',
        },
      );

      final uploadTask = ref.putFile(image, metadata);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      print('Firebase error uploading journey image: ${e.code} - ${e.message}');
      throw 'Failed to upload journey image: ${e.message}';
    } catch (e) {
      print('Error uploading journey image: $e');
      throw 'Failed to upload journey image: $e';
    }
  }

  Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } on FirebaseException catch (e) {
      print('Firebase error deleting image: ${e.code} - ${e.message}');
      throw 'Failed to delete image: ${e.message}';
    } catch (e) {
      print('Error deleting image: $e');
      throw 'Failed to delete image: $e';
    }
  }

  Future<String> uploadImageFromXFile(XFile image, String type) async {
    try {
      // Convert XFile to File
      final file = File(image.path);
      
      // Compress the image before upload
      final compressedFile = await _compressImage(file);
      
      // Upload based on type
      switch (type) {
        case 'profile':
          return uploadProfilePicture(compressedFile);
        case 'journey':
          return uploadJourneyImage(compressedFile);
        default:
          throw 'Invalid image type: $type';
      }
    } catch (e) {
      print('Error uploading image from XFile: $e');
      throw 'Failed to upload image: $e';
    }
  }

  Future<File> _compressImage(File file) async {
    try {
      // Get the file size
      final fileSize = await file.length();
      
      // If file is already small enough, return as is
      if (fileSize < 500 * 1024) { // 500KB
        return file;
      }
      
      // Read the file as bytes
      final bytes = await file.readAsBytes();
      
      // Create a temporary file for the compressed image
      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      // Write the compressed bytes to the temporary file
      await tempFile.writeAsBytes(bytes);
      
      return tempFile;
    } catch (e) {
      print('Error compressing image: $e');
      return file; // Return original file if compression fails
    }
  }
} 