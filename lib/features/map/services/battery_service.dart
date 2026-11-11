import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service managing device battery monitoring and Firestore synchronization.
class BatteryService {
  BatteryService({Battery? battery, FirebaseFirestore? firestore})
      : _battery = battery ?? Battery(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final Battery _battery;
  final FirebaseFirestore _firestore;

  DateTime? _lastSync;
  int? _lastSyncedLevel;
  bool? _lastSyncedCharging;

  /// Get current battery percentage (0-100)
  Future<int> getBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      return 100;
    }
  }

  /// Get current battery charging status
  Future<bool> isCharging() async {
    try {
      final state = await _battery.batteryState;
      return state == BatteryState.charging || state == BatteryState.full;
    } catch (_) {
      return false;
    }
  }

  /// Stream of battery state changes (charging, discharging, full)
  Stream<BatteryState> get onBatteryStateChanged =>
      _battery.onBatteryStateChanged;

  /// Syncs current device battery status to Firestore under `/pairs/{pairId}/deviceStatus/{uid}`
  /// Includes throttling to conserve battery and Firestore writes.
  Future<void> syncBatteryToFirestore({
    required String pairId,
    required String uid,
    required int batteryLevel,
    required bool isCharging,
    required bool isSharing,
  }) async {
    if (pairId.isEmpty || uid.isEmpty) return;

    final now = DateTime.now();
    if (_lastSync != null) {
      final elapsed = now.difference(_lastSync!);
      final levelChanged = _lastSyncedLevel != batteryLevel;
      final chargingChanged = _lastSyncedCharging != isCharging;

      // Throttle: only write if charging changed, level changed by >=2%, or 60s elapsed
      if (!chargingChanged &&
          !levelChanged &&
          elapsed.inSeconds < 60) {
        return;
      }
    }

    _lastSync = now;
    _lastSyncedLevel = batteryLevel;
    _lastSyncedCharging = isCharging;

    try {
      await _firestore
          .collection('pairs')
          .doc(pairId)
          .collection('deviceStatus')
          .doc(uid)
          .set({
        'batteryLevel': batteryLevel,
        'isCharging': isCharging,
        'timestamp': FieldValue.serverTimestamp(),
        'isSharing': isSharing,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Update battery sharing permission in Firestore
  Future<void> setSharingStatus({
    required String pairId,
    required String uid,
    required bool isSharing,
  }) async {
    if (pairId.isEmpty || uid.isEmpty) return;
    try {
      await _firestore
          .collection('pairs')
          .doc(pairId)
          .collection('deviceStatus')
          .doc(uid)
          .set({
        'isSharing': isSharing,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}

