import 'dart:async';

import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../models/bus_stop_model.dart';
import '../services/firestore_service.dart';

class RouteProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<BusRoute> _routes = [];
  List<BusStop> _busStops = [];
  BusRoute? _selectedRoute;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<BusStop>>? _busStopsSubscription;
  Map<String, List<double>> _routeLegDistanceMeters = {};

  List<BusRoute> get routes => _routes;
  List<BusStop> get busStops => _busStops;
  BusRoute? get selectedRoute => _selectedRoute;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<double>? getRouteLegDistances(String routeId) =>
      _routeLegDistanceMeters[routeId];

  Future<void> fetchRoutes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _routes = await _firestoreService.getRoutes();
      _syncRouteLegDistancesFromRoutes();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchBusStops() async {
    try {
      _busStops = await _firestoreService.getBusStops();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Subscribe to real-time bus stop updates.
  void listenToBusStops() {
    _busStopsSubscription?.cancel();
    _busStopsSubscription = _firestoreService.getBusStopsStream().listen(
      (stops) {
        _busStops = stops;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  void stopListeningToBusStops() {
    _busStopsSubscription?.cancel();
    _busStopsSubscription = null;
  }

  BusStop? getBusStop(String stopId) {
    try {
      return _busStops.firstWhere((stop) => stop.stopId == stopId);
    } catch (e) {
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _syncRouteLegDistancesFromRoutes() {
    _routeLegDistanceMeters = {
      for (final route in _routes) route.routeId: route.legDistancesMeters ?? const []
    };
  }

  @override
  void dispose() {
    _busStopsSubscription?.cancel();
    super.dispose();
  }
}
