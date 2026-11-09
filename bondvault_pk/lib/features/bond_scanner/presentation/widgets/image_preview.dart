import 'dart:io';

import 'package:flutter/material.dart';

class BondImagePreview extends StatelessWidget {
  final File imageFile;
  final VoidCallback? onRetake;

  const BondImagePreview({super.key, required this.imageFile, this.onRetake});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            imageFile,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
          ),
        ),
        if (onRetake != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: onRetake,
                tooltip: 'Retake Photo',
              ),
            ),
          ),
      ],
    );
  }
}
