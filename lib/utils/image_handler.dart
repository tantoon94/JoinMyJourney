import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;

class ImageHandler {
  static Future<bool> requestImagePermission(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        // Always request permission for Android
        final status = await Permission.photos.request();
        if (status.isDenied) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permission to access photos is required'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }
      } else if (Platform.isIOS) {
        // Always request permission for iOS
        final status = await Permission.photos.request();
        if (status.isDenied) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permission to access photos is required'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }
      }
      return true;
    } catch (e) {
      print('Error requesting permission: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting permission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getImageData(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      final compressedBytes = await compressAndResizeImage(bytes);
      if (compressedBytes == null) return null;
      
      return {
        'data': base64Encode(compressedBytes),
        'type': 'image/jpeg',
        'size': compressedBytes.length,
        'timestamp': DateTime.now().toIso8601String(),
        'name': image.name,
        'dimensions': {
          'width': 800,
          'height': 400,
        },
      };
    } catch (e) {
      print('Error getting image data: $e');
      return null;
    }
  }

  static Future<Uint8List?> compressAndResizeImage(
    Uint8List imageData, {
    int maxWidth = 800,
    int maxHeight = 400,
    int quality = 85,
  }) async {
    try {
      // Decode the image
      final img.Image? image = img.decodeImage(imageData);
      if (image == null) return null;

      // Calculate new dimensions while maintaining aspect ratio
      double aspectRatio = image.width / image.height;
      int newWidth = image.width;
      int newHeight = image.height;

      if (newWidth > maxWidth) {
        newWidth = maxWidth;
        newHeight = (newWidth / aspectRatio).round();
      }

      if (newHeight > maxHeight) {
        newHeight = maxHeight;
        newWidth = (newHeight * aspectRatio).round();
      }

      // Resize the image
      final resizedImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );

      // Encode the image with specified quality
      final compressedBytes = img.encodeJpg(resizedImage, quality: quality);
      if (compressedBytes.isEmpty) return null;
      
      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  static Future<XFile?> pickImage(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  static Widget buildImagePreview({
    required BuildContext context,
    Map<String, dynamic>? imageData,
    double height = 100,
    double width = double.infinity,
    BoxFit fit = BoxFit.cover,
  }) {
    print('Building image preview with data: ${imageData != null ? 'present' : 'null'}');
    if (imageData != null && imageData['data'] != null) {
      try {
        print('Attempting to decode base64 data...');
        // Decode base64 data
        final bytes = base64Decode(imageData['data']);
        print('Successfully decoded base64 data, length: ${bytes.length}');
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            height: height,
            width: width,
            fit: fit,
            cacheWidth: (width * MediaQuery.of(context).devicePixelRatio).toInt(),
            cacheHeight: (height * MediaQuery.of(context).devicePixelRatio).toInt(),
            errorBuilder: (context, error, stackTrace) {
              print('Error loading image: $error');
              print('Stack trace: $stackTrace');
              return _buildPlaceholderContainer(height, width);
            },
          ),
        );
      } catch (e) {
        print('Error decoding image data: $e');
        print('Image data type: ${imageData['data'].runtimeType}');
        return _buildPlaceholderContainer(height, width);
      }
    }
    print('No image data available, showing placeholder');
    return _buildPlaceholderContainer(height, width);
  }

  static Widget _buildPlaceholderContainer(double height, double width) {
    return Container(
      height: height,
      width: width,
      color: Colors.grey[800],
      child: const Center(
        child: Icon(Icons.map, color: Colors.grey, size: 32),
      ),
    );
  }
} 