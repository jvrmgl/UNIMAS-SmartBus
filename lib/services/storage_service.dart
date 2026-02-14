import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<List<String>> uploadReportImages({
    required String reportId,
    required List<File> files,
  }) async {
    final List<String> urls = [];

    for (int index = 0; index < files.length; index++) {
      final file = files[index];
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
