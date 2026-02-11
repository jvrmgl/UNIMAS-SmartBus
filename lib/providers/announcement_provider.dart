import 'package:flutter/material.dart';
import '../models/announcement_model.dart';
import '../services/firestore_service.dart';

class AnnouncementProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<Announcement> _announcements = [];
  bool _isLoading = false;
  String? _error;

  List<Announcement> get announcements => _announcements;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchAnnouncements() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _announcements = await _firestoreService.getAnnouncements();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<List<Announcement>> watchAnnouncements() {
    return _firestoreService.getAnnouncementsStream();
  }

  List<Announcement> getAnnouncementsForRoute(String routeId) {
    return _announcements
        .where((announcement) =>
            announcement.affectedRoutes.isEmpty ||
            announcement.affectedRoutes.contains(routeId))
        .toList();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
