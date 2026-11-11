import 'dart:async';
import 'dart:math' as math;

import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../pairing/providers/pairing_providers.dart';
import '../../providers/map_providers.dart';
import '../../utils/marker_generator.dart';
import '../widgets/map_bottom_panel.dart';
import '../widgets/map_controls.dart';
import '../widgets/map_header.dart';

/// Full-screen interactive map page for Rayna Live Location.
class LiveLocationPage extends ConsumerStatefulWidget {
  const LiveLocationPage({super.key});

  @override
  ConsumerState<LiveLocationPage> createState() => _LiveLocationPageState();
}

class _LiveLocationPageState extends ConsumerState<LiveLocationPage> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<BatteryState>? _batterySubscription;
  Timer? _batteryPeriodicTimer;

  // Initial fallback target (Indonesia)
  static const LatLng _initialPosition = LatLng(-6.2088, 106.8456);
  static const double _defaultZoom = 15.0;

  LatLng? _currentLatLng;
  BitmapDescriptor? _userMarkerIcon;
  BitmapDescriptor? _partnerMarkerIcon;
  String? _cachedUserName;
  String? _cachedUserPhoto;
  String? _cachedPartnerName;
  String? _cachedPartnerPhoto;

  bool _hasCenteredOnUser = false;
  bool _permissionDenied = false;

  // Device Battery Status
  int _myBatteryLevel = 100;
  bool _isMyCharging = false;

  // Movement Trails (Phase 7)
  final List<LatLng> _myTrail = [];
  final List<LatLng> _partnerTrail = [];
  bool _isTrailVisible = true;

  // Local state toggles (sharing controls)
  final bool _isSharingLocation = true;
  final bool _isSharingBattery = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocationTracking();
      _initBatteryTracking();
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _batterySubscription?.cancel();
    _batteryPeriodicTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  /// Initialize GPS location tracking and custom avatar marker
  Future<void> _initLocationTracking() async {
    final locationService = ref.read(locationServiceProvider);
    final user = ref.read(authServiceProvider).currentUser;

    // 1. Generate custom romantic avatar marker for the user
    try {
      final name = user?.displayName ?? 'You';
      final marker = await MarkerGenerator.createCustomAvatarMarker(
        imageUrl: user?.photoURL,
        label: name,
        borderColor: AppColors.dustyRose,
        backgroundColor: AppColors.softIvory,
        textColor: AppColors.charcoal,
      );
      if (mounted) {
        setState(() => _userMarkerIcon = marker);
      }
    } catch (_) {}

    // 2. Request GPS permission and fetch initial fix
    final hasPermission = await locationService.checkAndRequestPermission();
    if (!hasPermission) {
      if (mounted) {
        setState(() => _permissionDenied = true);
      }
      return;
    }

    if (mounted) {
      setState(() => _permissionDenied = false);
    }

    final initialFix = await locationService.getCurrentPosition();
    if (initialFix != null && mounted) {
      _handleNewPosition(initialFix, animateCamera: true);
    }

    // 3. Start real-time position stream
    _positionSubscription?.cancel();
    _positionSubscription = locationService.getPositionStream().listen((
      position,
    ) {
      if (mounted) {
        _handleNewPosition(position, animateCamera: !_hasCenteredOnUser);
      }
    }, onError: (_) {});
  }

  /// Initialize device battery monitoring & listeners
  Future<void> _initBatteryTracking() async {
    final batteryService = ref.read(batteryServiceProvider);

    final initialLevel = await batteryService.getBatteryLevel();
    final initialCharging = await batteryService.isCharging();
    if (mounted) {
      setState(() {
        _myBatteryLevel = initialLevel;
        _isMyCharging = initialCharging;
      });
    }
    _syncBatteryToFirestore();

    _batterySubscription?.cancel();
    _batterySubscription = batteryService.onBatteryStateChanged.listen((
      state,
    ) async {
      final newLevel = await batteryService.getBatteryLevel();
      final charging =
          state == BatteryState.charging || state == BatteryState.full;
      if (mounted) {
        setState(() {
          _myBatteryLevel = newLevel;
          _isMyCharging = charging;
        });
      }
      _syncBatteryToFirestore();
    }, onError: (_) {});

    _batteryPeriodicTimer?.cancel();
    _batteryPeriodicTimer = Timer.periodic(const Duration(seconds: 45), (
      _,
    ) async {
      final newLevel = await batteryService.getBatteryLevel();
      final charging = await batteryService.isCharging();
      if (mounted) {
        setState(() {
          _myBatteryLevel = newLevel;
          _isMyCharging = charging;
        });
      }
      _syncBatteryToFirestore();
    });
  }

  void _syncBatteryToFirestore() {
    final userDoc = ref.read(currentUserDocumentProvider);
    final activePairId =
        userDoc.valueOrNull?.data()?['activePairId'] as String?;
    final uid = ref.read(authServiceProvider).currentUser?.uid;

    if (activePairId != null && activePairId.isNotEmpty && uid != null) {
      ref
          .read(batteryServiceProvider)
          .syncBatteryToFirestore(
            pairId: activePairId,
            uid: uid,
            batteryLevel: _myBatteryLevel,
            isCharging: _isMyCharging,
            isSharing: _isSharingBattery,
          );
    }
  }

  void _handleNewPosition(Position position, {bool animateCamera = false}) {
    final latLng = LatLng(position.latitude, position.longitude);
    setState(() {
      _currentLatLng = latLng;

      // Update movement trail (keep last 25 significant points)
      if (_myTrail.isEmpty) {
        _myTrail.add(latLng);
      } else {
        final dist = Geolocator.distanceBetween(
          _myTrail.last.latitude,
          _myTrail.last.longitude,
          latLng.latitude,
          latLng.longitude,
        );
        if (dist >= 10.0) {
          _myTrail.add(latLng);
          if (_myTrail.length > 25) {
            _myTrail.removeAt(0);
          }
        }
      }
    });

    ref.read(currentUserPositionProvider.notifier).state = position;

    // Sync to Firestore if sharing is enabled
    final userDoc = ref.read(currentUserDocumentProvider);
    final activePairId =
        userDoc.valueOrNull?.data()?['activePairId'] as String?;
    final uid = ref.read(authServiceProvider).currentUser?.uid;

    if (activePairId != null && activePairId.isNotEmpty && uid != null) {
      final trailData = _myTrail
          .map((pt) => {'lat': pt.latitude, 'lng': pt.longitude})
          .toList();

      ref
          .read(locationServiceProvider)
          .syncLocationToFirestore(
            pairId: activePairId,
            uid: uid,
            position: position,
            isSharing: _isSharingLocation,
            trail: trailData,
          );
    }

    if (animateCamera && _mapController != null) {
      _centerOnLocation(latLng);
      _hasCenteredOnUser = true;
    }
  }

  Future<void> _updateUserMarker(String name, String? photoUrl) async {
    if (_userMarkerIcon != null &&
        _cachedUserName == name &&
        _cachedUserPhoto == photoUrl) {
      return;
    }
    _cachedUserName = name;
    _cachedUserPhoto = photoUrl;

    try {
      final icon = await MarkerGenerator.createCustomAvatarMarker(
        imageUrl: photoUrl,
        label: name,
        borderColor: AppColors.dustyRose,
        backgroundColor: AppColors.softIvory,
        textColor: AppColors.charcoal,
        size: 64.0,
      );
      if (mounted) {
        setState(() => _userMarkerIcon = icon);
      }
    } catch (_) {}
  }

  Future<void> _updatePartnerMarker(String name, String? photoUrl) async {
    if (_partnerMarkerIcon != null &&
        _cachedPartnerName == name &&
        _cachedPartnerPhoto == photoUrl) {
      return;
    }
    _cachedPartnerName = name;
    _cachedPartnerPhoto = photoUrl;

    try {
      final icon = await MarkerGenerator.createCustomAvatarMarker(
        imageUrl: photoUrl,
        label: name,
        borderColor: AppColors.success, // Romantic soft green border
        backgroundColor: AppColors.softSage,
        textColor: AppColors.charcoal,
        size: 64.0,
      );
      if (mounted) {
        setState(() => _partnerMarkerIcon = icon);
      }
    } catch (_) {}
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentLatLng != null && !_hasCenteredOnUser) {
      _centerOnLocation(_currentLatLng!);
      _hasCenteredOnUser = true;
    }
  }

  void _zoomIn() {
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  void _centerOnLocation(LatLng position) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 16.5),
      ),
    );
  }

  void _fitBothPartners(LatLng userLoc, LatLng partnerLoc) {
    final southwest = LatLng(
      math.min(userLoc.latitude, partnerLoc.latitude),
      math.min(userLoc.longitude, partnerLoc.longitude),
    );
    final northeast = LatLng(
      math.max(userLoc.latitude, partnerLoc.latitude),
      math.max(userLoc.longitude, partnerLoc.longitude),
    );

    // If locations are identical or very close, just center
    if ((southwest.latitude - northeast.latitude).abs() < 0.0001 &&
        (southwest.longitude - northeast.longitude).abs() < 0.0001) {
      _centerOnLocation(userLoc);
      return;
    }

    final bounds = LatLngBounds(southwest: southwest, northeast: northeast);
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 90.0));
  }

  String _formatRelativeTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Awaiting live signal';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Set<Marker> _buildMarkers({
    required LatLng? partnerLatLng,
    required bool isPartnerSharing,
    required String partnerName,
    required double? distanceKm,
  }) {
    final markers = <Marker>{};

    // 1. Current user marker
    if (_currentLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_user_marker'),
          position: _currentLatLng!,
          icon: _userMarkerIcon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 1.0),
          infoWindow: const InfoWindow(
            title: 'You',
            snippet: 'Your current location',
          ),
        ),
      );
    }

    // 2. Partner marker (only visible if partner is actively sharing)
    if (partnerLatLng != null && isPartnerSharing) {
      markers.add(
        Marker(
          markerId: const MarkerId('partner_marker'),
          position: partnerLatLng,
          icon: _partnerMarkerIcon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 1.0),
          infoWindow: InfoWindow(
            title: partnerName,
            snippet: distanceKm != null
                ? '${distanceKm.toStringAsFixed(1)} km away from you'
                : 'Partner location',
          ),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines({required bool isPartnerSharing}) {
    if (!_isTrailVisible) return {};

    final polylines = <Polyline>{};

    // 1. Current user movement trail (Dusty Rose)
    if (_myTrail.length >= 2) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('my_movement_trail'),
          points: List.from(_myTrail),
          color: AppColors.dustyRose.withValues(alpha: 0.70),
          width: 4,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          geodesic: true,
        ),
      );
    }

    // 2. Partner movement trail (Soft Sage Green)
    if (_partnerTrail.length >= 2 && isPartnerSharing) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('partner_movement_trail'),
          points: List.from(_partnerTrail),
          color: AppColors.success.withValues(alpha: 0.70),
          width: 4,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          geodesic: true,
        ),
      );
    }

    return polylines;
  }

  @override
  Widget build(BuildContext context) {
    final mapType = ref.watch(mapTypeProvider);

    // ── 1. Pairing & Partner Identity ───────────────────────────────────────
    final userDoc = ref.watch(currentUserDocumentProvider);
    final userData = userDoc.valueOrNull?.data() ?? <String, dynamic>{};
    final activePairId = userData['activePairId'] as String?;
    final paired = activePairId != null && activePairId.isNotEmpty;

    final partnerProfileDoc = ref.watch(partnerProfileProvider);
    final partnerProfileData =
        partnerProfileDoc.valueOrNull?.data() ?? <String, dynamic>{};
    final partnerName =
        partnerProfileData['displayName'] as String? ??
        partnerProfileData['username'] as String? ??
        'Partner';
    final partnerPhoto = partnerProfileData['photoURL'] as String?;

    final userName = userData['displayName'] as String? ??
        userData['username'] as String? ??
        ref.read(authServiceProvider).currentUser?.displayName ??
        'You';
    final userPhoto = userData['photoURL'] as String? ??
        ref.read(authServiceProvider).currentUser?.photoURL;
    _updateUserMarker(userName, userPhoto);

    if (paired) {
      _updatePartnerMarker(partnerName, partnerPhoto);
    }

    // ── 2. Partner Live GPS Location & Trail ──────────────────────────────────
    final partnerLocationDoc = ref.watch(partnerLocationStreamProvider);
    final partnerLocData = partnerLocationDoc.valueOrNull?.data();
    LatLng? partnerLatLng;
    bool isPartnerSharingLoc = false;
    Timestamp? partnerLocTimestamp;

    if (partnerLocData != null) {
      isPartnerSharingLoc = partnerLocData['isSharing'] == true;
      final lat = partnerLocData['latitude'];
      final lng = partnerLocData['longitude'];
      if (lat is num && lng is num) {
        partnerLatLng = LatLng(lat.toDouble(), lng.toDouble());
      }
      partnerLocTimestamp = partnerLocData['timestamp'] as Timestamp?;

      // Parse partner movement trail
      final rawTrail = partnerLocData['trail'] as List<dynamic>?;
      _partnerTrail.clear();
      if (rawTrail != null && isPartnerSharingLoc) {
        for (final item in rawTrail) {
          if (item is Map) {
            final tLat = item['lat'];
            final tLng = item['lng'];
            if (tLat is num && tLng is num) {
              _partnerTrail.add(LatLng(tLat.toDouble(), tLng.toDouble()));
            }
          }
        }
        if (partnerLatLng != null &&
            (_partnerTrail.isEmpty || _partnerTrail.last != partnerLatLng)) {
          _partnerTrail.add(partnerLatLng);
        }
      }
    }

    // ── 3. Real-Time Distance Calculation ───────────────────────────────────
    double? distanceKm;
    if (_currentLatLng != null &&
        partnerLatLng != null &&
        isPartnerSharingLoc) {
      final meters = Geolocator.distanceBetween(
        _currentLatLng!.latitude,
        _currentLatLng!.longitude,
        partnerLatLng.latitude,
        partnerLatLng.longitude,
      );
      distanceKm = meters / 1000.0;
    }

    // ── 4. Partner Live Battery Status ──────────────────────────────────────
    final partnerDeviceDoc = ref.watch(partnerDeviceStatusStreamProvider);
    final partnerDeviceData = partnerDeviceDoc.valueOrNull?.data();
    int? partnerBatteryLevel;
    bool isPartnerCharging = false;

    if (partnerDeviceData != null) {
      final isPartnerSharingBatt = partnerDeviceData['isSharing'] == true;
      if (isPartnerSharingBatt) {
        partnerBatteryLevel = partnerDeviceData['batteryLevel'] as int?;
        isPartnerCharging = partnerDeviceData['isCharging'] == true;
      }
    }

    // Clearance above floating GlassBottomNavBar (68 container + 16 bottom padding + system inset)
    // Positioned slightly lower (8px gap) so it sits comfortably close without overlapping
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final panelBottom = bottomPadding + 68.0 + 16.0 + 8.0;

    final markers = _buildMarkers(
      partnerLatLng: partnerLatLng,
      isPartnerSharing: isPartnerSharingLoc,
      partnerName: partnerName,
      distanceKm: distanceKm,
    );
    final polylines = _buildPolylines(isPartnerSharing: isPartnerSharingLoc);

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Full-screen Google Map ────────────────────────────────────
          Positioned.fill(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _currentLatLng ?? _initialPosition,
                zoom: _defaultZoom,
              ),
              markers: markers,
              polylines: polylines,
              mapType: mapType,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              buildingsEnabled: true,
              trafficEnabled: false,
              padding: EdgeInsets.fromLTRB(16, 110, 16, panelBottom + 115),
            ),
          ),

          // ── 2. Floating Top Header ────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: MapHeaderBar(
              paired: paired,
              partnerName: paired ? partnerName : null,
              isSharingLocation: _isSharingLocation,
              isPartnerSharing: isPartnerSharingLoc,
            ),
          ),

          // ── 3. Floating Right Map Controls ────────────────────────────────
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 76,
            child: MapFloatingControls(
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
              isTrailVisible: _isTrailVisible,
              onToggleTrail: () =>
                  setState(() => _isTrailVisible = !_isTrailVisible),
              onCenterUser: () {
                if (_currentLatLng != null) {
                  _centerOnLocation(_currentLatLng!);
                } else {
                  _initLocationTracking();
                }
              },
              onFitBoth: () {
                if (_currentLatLng != null && partnerLatLng != null) {
                  _fitBothPartners(_currentLatLng!, partnerLatLng);
                } else if (_currentLatLng != null) {
                  _centerOnLocation(_currentLatLng!);
                }
              },
              hasPartnerLocation:
                  paired && partnerLatLng != null && isPartnerSharingLoc,
            ),
          ),

          // ── 4. Permission Denied Banner ──────────────────────────────────
          if (_permissionDenied)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 20,
              right: 80,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.charcoal.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_off_rounded,
                      color: AppColors.dustyRose,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Location access needed for live tracking',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.charcoal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _initLocationTracking,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.dustyRose,
                      ),
                      child: const Text('Enable'),
                    ),
                  ],
                ),
              ),
            ),

          // ── 5. Floating Bottom Info Panel (above bottom nav) ─────────────
          Positioned(
            left: 16,
            right: 16,
            bottom: panelBottom,
            child: MapBottomInfoPanel(
              paired: paired,
              partnerName: paired ? partnerName : null,
              distanceKm: distanceKm,
              partnerBatteryLevel: partnerBatteryLevel,
              isPartnerCharging: isPartnerCharging,
              myBatteryLevel: _myBatteryLevel,
              isMyCharging: _isMyCharging,
              lastLocationUpdate: _formatRelativeTime(partnerLocTimestamp),
              onConnectPartner: () => context.push(AppRoutes.pairing),
            ),
          ),
        ],
      ),
    );
  }
}
