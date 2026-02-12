import 'package:hive_flutter/hive_flutter.dart';

class TapData {
  final String id;
  final String busId;
  final String busNumber;
  final DateTime timestamp;
  final bool isTapIn; // true = tap in, false = tap out
  final bool synced; // true = synced to cloud, false = pending

  TapData({
    required this.id,
    required this.busId,
    required this.busNumber,
    required this.timestamp,
    required this.isTapIn,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'busId': busId,
    'busNumber': busNumber,
    'timestamp': timestamp.toIso8601String(),
    'isTapIn': isTapIn,
    'synced': synced,
  };

  factory TapData.fromMap(Map<String, dynamic> map) => TapData(
    id: map['id'],
    busId: map['busId'],
    busNumber: map['busNumber'],
    timestamp: DateTime.parse(map['timestamp']),
    isTapIn: map['isTapIn'],
    synced: map['synced'] ?? false,
  );
}

class LocalStorageService {
  static const String _tapsBoxName = 'guest_taps';
  late Box _tapsBox;

  Future<void> initialize() async {
    _tapsBox = await Hive.openBox(_tapsBoxName);
  }

  /// Save a tap action (in/out)
  Future<void> saveTap({
    required String busId,
    required String busNumber,
    required bool isTapIn,
  }) async {
    final tapData = TapData(
      id: '${busId}_${DateTime.now().millisecondsSinceEpoch}',
      busId: busId,
      busNumber: busNumber,
      timestamp: DateTime.now(),
      isTapIn: isTapIn,
      synced: false,
    );

    await _tapsBox.put(tapData.id, tapData.toMap());
  }

  /// Get all pending taps (not synced)
  List<TapData> getPendingTaps() {
    return _tapsBox.values
        .map((tap) => TapData.fromMap(tap))
        .where((tap) => !tap.synced)
        .toList();
  }

  /// Get all taps (synced + pending)
  List<TapData> getAllTaps() {
    return _tapsBox.values
        .map((tap) => TapData.fromMap(tap))
        .toList();
  }

  /// Mark a tap as synced
  Future<void> markAsSynced(String tapId) async {
    final tapMap = _tapsBox.get(tapId);
    if (tapMap != null) {
      tapMap['synced'] = true;
      await _tapsBox.put(tapId, tapMap);
    }
  }

  /// Clear all taps (for testing)
  Future<void> clearAllTaps() async {
    await _tapsBox.clear();
  }

  /// Get tap history for a specific bus
  List<TapData> getTapsForBus(String busId) {
    return _tapsBox.values
        .map((tap) => TapData.fromMap(tap))
        .where((tap) => tap.busId == busId)
        .toList();
  }
}
