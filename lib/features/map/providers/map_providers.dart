import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../auth/providers/auth_providers.dart';
import '../../pairing/providers/pairing_providers.dart';
import '../services/battery_service.dart';
import '../services/location_service.dart';

/// Provider for toggling between Normal and Satellite map views.
final mapTypeProvider = StateProvider<MapType>((ref) => MapType.normal);

/// Provider for tracking whether the map camera is centered on user or partner.
final isCameraFollowModeProvider = StateProvider<bool>((ref) => true);

/// Provider for LocationService instance
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Provider for BatteryService instance
final batteryServiceProvider = Provider<BatteryService>((ref) {
  return BatteryService();
});

/// Stream provider for the current device's GPS position
final userLocationStreamProvider =
    StreamProvider.autoDispose<Position>((ref) async* {
  final service = ref.watch(locationServiceProvider);
  final hasPermission = await service.checkAndRequestPermission();
  if (!hasPermission) return;

  yield* service.getPositionStream();
});

/// Provider for tracking current user's live position
final currentUserPositionProvider = StateProvider<Position?>((ref) => null);

/// Stream provider for the active pair document
final activePairDocumentProvider =
    StreamProvider.autoDispose<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final userDoc = ref.watch(currentUserDocumentProvider);
  final pairId = userDoc.valueOrNull?.data()?['activePairId'] as String?;
  if (pairId == null || pairId.isEmpty) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('pairs')
      .doc(pairId)
      .snapshots();
});

/// Provider returning the partner's UID
final partnerUidProvider = Provider.autoDispose<String?>((ref) {
  final pairDoc = ref.watch(activePairDocumentProvider).valueOrNull;
  if (pairDoc == null || !pairDoc.exists) return null;

  final data = pairDoc.data();
  if (data == null) return null;

  final memberUids = List<String>.from(data['memberUids'] ?? []);
  final myUid = ref.watch(authServiceProvider).currentUser?.uid;
  if (myUid == null) return null;

  try {
    return memberUids.firstWhere((uid) => uid != myUid);
  } catch (_) {
    return null;
  }
});

/// Stream provider for partner's public profile data (displayName, photoURL)
final partnerProfileProvider =
    StreamProvider.autoDispose<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final partnerUid = ref.watch(partnerUidProvider);
  if (partnerUid == null || partnerUid.isEmpty) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(partnerUid)
      .snapshots();
});

/// Stream provider for partner's live GPS location document
final partnerLocationStreamProvider =
    StreamProvider.autoDispose<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final userDoc = ref.watch(currentUserDocumentProvider);
  final pairId = userDoc.valueOrNull?.data()?['activePairId'] as String?;
  final partnerUid = ref.watch(partnerUidProvider);

  if (pairId == null ||
      pairId.isEmpty ||
      partnerUid == null ||
      partnerUid.isEmpty) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('pairs')
      .doc(pairId)
      .collection('locations')
      .doc(partnerUid)
      .snapshots();
});

/// Stream provider for partner's live battery status document
final partnerDeviceStatusStreamProvider =
    StreamProvider.autoDispose<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final userDoc = ref.watch(currentUserDocumentProvider);
  final pairId = userDoc.valueOrNull?.data()?['activePairId'] as String?;
  final partnerUid = ref.watch(partnerUidProvider);

  if (pairId == null ||
      pairId.isEmpty ||
      partnerUid == null ||
      partnerUid.isEmpty) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('pairs')
      .doc(pairId)
      .collection('deviceStatus')
      .doc(partnerUid)
      .snapshots();
});
