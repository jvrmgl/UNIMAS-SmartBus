import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const int _maxImagesPerReport = 5;
  static const int _maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const Set<String> _allowedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  };

  bool _isAllowedImage(String path) {
    final lower = path.toLowerCase();
    return _allowedExtensions.any(lower.endsWith);
  }

  Future<List<String>> uploadReportImages({
    required String reportId,
    required List<File> files,
  }) async {
    if (files.length > _maxImagesPerReport) {
      throw ArgumentError(
        'Maximum $_maxImagesPerReport images allowed per report.',
      );
    }

    final List<String> urls = [];

    for (int index = 0; index < files.length; index++) {
      final file = files[index];

      if (!_isAllowedImage(file.path)) {
        throw ArgumentError(
          'Unsupported file type. Allowed: ${_allowedExtensions.join(', ')}',
        );
      }

      final size = await file.length();
      if (size > _maxFileSizeBytes) {
        throw ArgumentError('Each image must be 5 MB or smaller.');
      }

      final ref = _storage
          .ref()
          .child('reports')
          .child(reportId)
          .child('image_$index.jpg');

      final task = await ref.putFile(file);
      final url = await task.ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }
}
