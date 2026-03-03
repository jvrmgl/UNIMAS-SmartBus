import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/announcement_model.dart';
import '../services/firestore_service.dart';

class AnnouncementProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  static const String _boxName = 'cleared_announcements';

  List<Announcement> _announcements = [];
  bool _isLoading = false;
  String? _error;

  final Map<String, Set<String>> _clearedByRole = {};
  bool _clearedLoaded = false;

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

  /// Loads persisted cleared-ID sets for all roles from Hive.
  Future<void> _loadCleared() async {
    if (_clearedLoaded) return;
    final box = await Hive.openBox(_boxName);
    for (final role in ['student', 'admin', 'driver']) {
      final stored = box.get(role);
      if (stored is List) {
        _clearedByRole[role] = stored.map((e) => e.toString()).toSet();
      }
    }
    _clearedLoaded = true;
  }

  /// Persists the cleared-ID set for [role] to Hive.
  Future<void> _saveCleared(String role) async {
    final box = await Hive.openBox(_boxName);
    await box.put(role, _roleSet(role).toList());
  }

  Future<void> clearAnnouncementsFor(String role) async {
    _roleSet(role).addAll(_announcements.map((a) => a.announcementId));
    await _saveCleared(role); // persist across sessions
    notifyListeners();
  }

  Future<void> fetchAnnouncements() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _loadCleared(); // restore any previously cleared IDs
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
