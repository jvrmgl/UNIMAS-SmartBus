import 'package:flutter/material.dart';
import '../models/announcement_model.dart';
import '../services/firestore_service.dart';

class AnnouncementProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<Announcement> _announcements = [];
  bool _isLoading = false;
  String? _error;

  final Map<String, Set<String>> _clearedByRole = {};

  Set<String> _roleSet(String role) =>
      _clearedByRole.putIfAbsent(role, () => {});

  List<Announcement> get announcements => _announcements;
  List<Announcement> visibleAnnouncementsFor(String role) => _announcements
      .where((a) => !_roleSet(role).contains(a.announcementId))
      .toList();
  bool hasVisibleAnnouncementsFor(String role) =>
      visibleAnnouncementsFor(role).isNotEmpty;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void clearAnnouncementsFor(String role) {
    _roleSet(role).addAll(_announcements.map((a) => a.announcementId));
    notifyListeners();
  }

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
