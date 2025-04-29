import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/image_handler.dart';

class ImageUploadWidget extends StatefulWidget {
  final Map<String, dynamic>? initialImageMetadata;
  final Function(XFile)? onImageSelected;
  final Function()? onImageRemoved;
  final double height;
  final double width;
  final BoxFit fit;
  final bool showRemoveButton;
  final String? errorText;

  const ImageUploadWidget({
    super.key,
    this.initialImageMetadata,
    this.onImageSelected,
    this.onImageRemoved,
    this.height = 150,
    this.width = double.infinity,
    this.fit = BoxFit.cover,
    this.showRemoveButton = true,
    this.errorText,
  });

  @override
  State<ImageUploadWidget> createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  XFile? _selectedImage;
  Map<String, dynamic>? _imageMetadata;

  @override
  void initState() {
    super.initState();
    _imageMetadata = widget.initialImageMetadata;
  }

  Future<void> _pickImage() async {
    final image = await ImageHandler.pickImage(context);
    if (image != null) {
      setState(() {
        _selectedImage = image;
        _imageMetadata = null;
      });
      widget.onImageSelected?.call(image);
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _imageMetadata = null;
    });
    widget.onImageRemoved?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_imageMetadata != null || _selectedImage != null)
          Stack(
            children: [
              ImageHandler.buildImagePreview(
                context: context,
                imageData: _imageMetadata,
                height: widget.height,
                width: widget.width,
                fit: widget.fit,
              ),
              if (widget.showRemoveButton)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _removeImage,
                  ),
                ),
            ],
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.photo_library),
          label: const Text('Add Image'),
          onPressed: _pickImage,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[700],
            foregroundColor: Colors.white,
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.errorText!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
