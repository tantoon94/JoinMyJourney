import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:developer' as developer;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Maximum file size (10MB)
  static const int maxFileSize = 10 * 1024 * 1024;
  
  // Allowed file types
  static const List<String> allowedFileTypes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ];

  Future<String> uploadFile(
    File file, 
    String path, {
    Function(double)? onProgress,
    Function(String)? onError,
  }) async {
    try {
      developer.log('Starting file upload: ${file.path}');
      
      // Validate file size
      final fileSize = await file.length();
      developer.log('File size: ${fileSize / 1024 / 1024}MB');
      if (fileSize > maxFileSize) {
        throw 'File size exceeds maximum limit of 10MB';
      }

      // Validate file type
      final fileType = file.path.split('.').last.toLowerCase();
      developer.log('File type: $fileType');
      if (!allowedFileTypes.contains('application/$fileType')) {
        throw 'File type not allowed';
      }

      final ref = _storage.ref().child(path);
      developer.log('Uploading to path: $path');
      
      final uploadTask = ref.putFile(file);
      
      // Listen to upload progress
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          developer.log('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
          onProgress?.call(progress);
        },
        onError: (error) {
          developer.log('Upload error: $error', error: error);
          onError?.call(error.toString());
        },
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      developer.log('Upload completed. Download URL: $downloadUrl');
      return downloadUrl;
    } catch (e, stackTrace) {
      developer.log('Upload failed', error: e, stackTrace: stackTrace);
      onError?.call(e.toString());
      rethrow;
    }
  }

  Future<void> deleteFile(String path) async {
    try {
      developer.log('Attempting to delete file: $path');
      final ref = _storage.ref().child(path);
      await ref.delete();
      developer.log('File deleted successfully');
    } catch (e, stackTrace) {
      developer.log('Delete failed', error: e, stackTrace: stackTrace);
      throw 'Failed to delete file: $e';
    }
  }

  Future<Map<String, dynamic>> getFileMetadata(String path) async {
    try {
      developer.log('Getting metadata for: $path');
      final ref = _storage.ref().child(path);
      final metadata = await ref.getMetadata();
      developer.log('Metadata retrieved: ${metadata.name}');
      return {
        'name': metadata.name,
        'size': metadata.size,
        'contentType': metadata.contentType,
        'timeCreated': metadata.timeCreated,
        'updated': metadata.updated,
        'md5Hash': metadata.md5Hash,
      };
    } catch (e, stackTrace) {
      developer.log('Get metadata failed', error: e, stackTrace: stackTrace);
      throw 'Failed to get file metadata: $e';
    }
  }

  Future<List<Map<String, dynamic>>> listFiles(String path) async {
    try {
      developer.log('Listing files in: $path');
      final ref = _storage.ref().child(path);
      final result = await ref.listAll();
      developer.log('Found ${result.items.length} files');
      
      final files = await Future.wait(result.items.map((item) async {
        final metadata = await item.getMetadata();
        developer.log('File: ${item.name}, Size: ${metadata.size}');
        return {
          'name': item.name,
          'path': item.fullPath,
          'size': metadata.size,
        };
      }));
      
      return files;
    } catch (e, stackTrace) {
      developer.log('List files failed', error: e, stackTrace: stackTrace);
      throw 'Failed to list files: $e';
    }
  }

  Future<File> downloadFile(String path, String localPath) async {
    try {
      developer.log('Downloading file from: $path to: $localPath');
      final ref = _storage.ref().child(path);
      final file = File(localPath);
      await ref.writeToFile(file);
      developer.log('File downloaded successfully');
      return file;
    } catch (e, stackTrace) {
      developer.log('Download failed', error: e, stackTrace: stackTrace);
      throw 'Failed to download file: $e';
    }
  }

  Future<String> getDownloadUrl(String path) async {
    try {
      developer.log('Getting download URL for: $path');
      final ref = _storage.ref().child(path);
      final url = await ref.getDownloadURL();
      developer.log('Download URL retrieved: $url');
      return url;
    } catch (e, stackTrace) {
      developer.log('Get download URL failed', error: e, stackTrace: stackTrace);
      throw 'Failed to get download URL: $e';
    }
  }
}