import 'dart:async';
import 'package:flutter/material.dart';
import '../models/bus_model.dart';
import '../services/firestore_service.dart';

class BusProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<Bus> _buses = [];
  Bus? _selectedBus;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<Bus>>? _busesSubscription;

  List<Bus> get buses => _buses;
  Bus? get selectedBus => _selectedBus;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchBuses() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _buses = await _firestoreService.getBuses();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Bus?> fetchBus(String busId) async {
    try {
      final bus = await _firestoreService.getBus(busId);
      _selectedBus = bus;
      notifyListeners();
      return bus;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Stream<Bus?> watchBus(String busId) {
    return _firestoreService.getBusStream(busId);
  }

  Future<bool> updateBusLocation({
    required String busId,
    required double latitude,
    required double longitude,
    required int currentOccupancy,
  }) async {
    try {
      final result = await _firestoreService.updateBusLocation(
        busId: busId,
        latitude: latitude,
        longitude: longitude,
        currentOccupancy: currentOccupancy,
      );
      return result == null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBusOccupancy({
    required String busId,
    required int occupancy,
  }) async {
    try {
      final result = await _firestoreService.updateBusOccupancy(
        busId: busId,
        currentOccupancy: occupancy,
      );
      if (result == null) {
        await fetchBuses(); // Refresh the bus list
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void selectBus(Bus bus) {
    _selectedBus = bus;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Directly replace the matching bus in the cached list with [updatedBus].
  /// Useful for optimistic/immediate UI updates (e.g. after tap-in/out).
  void updateBusInList(Bus updatedBus) {
    final index = _buses.indexWhere((b) => b.busId == updatedBus.busId);
    if (index != -1) {
      _buses[index] = updatedBus;
      notifyListeners();
    }
  }

  /// Subscribe to real-time bus list updates. Call once from a screen's
  /// initState that needs live sync (e.g. admin bus management).
  void listenToBuses() {
    _busesSubscription?.cancel();
    _isLoading = true;
    notifyListeners();
    _busesSubscription = _firestoreService.getBusesStream().listen(
      (buses) {
        _buses = buses;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void stopListeningToBuses() {
    _busesSubscription?.cancel();
    _busesSubscription = null;
  }

  @override
  void dispose() {
    _busesSubscription?.cancel();
    super.dispose();
  }
}
