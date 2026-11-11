import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

/// Service managing GPS location permissions, streaming, and Firestore synchronization.
class LocationService {
  final FirebaseFirestore _firestore;
  DateTime? _lastFirestoreSync;
  Position? _lastSyncedPosition;

  LocationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Check GPS service and request location permissions gracefully
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location service is disabled on device
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get current one-time GPS fix
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return await Geolocator.getLastKnownPosition();
    }
  }

  /// Real-time position stream
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // update every 5 meters
      ),
    );
  }

  /// Syncs current location to Firestore under `/pairs/{pairId}/locations/{uid}`
  /// Includes throttling (minimum 4 seconds between writes or significant distance move)
  Future<void> syncLocationToFirestore({
    required String pairId,
    required String uid,
    required Position position,
    required bool isSharing,
    List<Map<String, double>>? trail,
  }) async {
    if (pairId.isEmpty || uid.isEmpty) return;

    final now = DateTime.now();
    if (_lastFirestoreSync != null && _lastSyncedPosition != null) {
      final elapsed = now.difference(_lastFirestoreSync!);
      final distanceMoved = Geolocator.distanceBetween(
        _lastSyncedPosition!.latitude,
        _lastSyncedPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      // Throttling: only update if 4s passed OR moved more than 15 meters
      if (elapsed.inSeconds < 4 && distanceMoved < 15) {
        return;
      }
    }

    _lastFirestoreSync = now;
    _lastSyncedPosition = position;

    try {
      final updateData = <String, dynamic>{
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': FieldValue.serverTimestamp(),
        'isSharing': isSharing,
      };

      if (trail != null && trail.isNotEmpty) {
        updateData['trail'] = trail;
      }

      await _firestore
          .collection('pairs')
          .doc(pairId)
          .collection('locations')
          .doc(uid)
          .set(updateData, SetOptions(merge: true));
    } catch (e) {
      // Fail silently or handle network disconnects gracefully
    }
  }

  /// Stop sharing location explicitly in Firestore
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
          .collection('locations')
          .doc(uid)
          .set({
        'isSharing': isSharing,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}

