import 'package:cloud_firestore/cloud_firestore.dart';

/// Lifecycle states for the 80 km/h GPS Speed Alert monitor.
enum SpeedAlertState {
  normal,
  monitoring,
  speedWarning,
  alertSent,
  speedBackToNormal,
  locationStale,
  sharingDisabled,
}

/// Configurable thresholds for GPS speed monitoring and hysteresis.
class SpeedAlertConfig {
  const SpeedAlertConfig({
    this.triggerThresholdKmh = 80.0,
    this.resetThresholdKmh = 70.0,
    this.sustainedDuration = const Duration(seconds: 10),
    this.resetDuration = const Duration(seconds: 10),
    this.maxAccuracyMeters = 25.0,
    this.maxStaleAge = const Duration(seconds: 30),
    this.cooldown = const Duration(minutes: 10),
  });

  final double triggerThresholdKmh;
  final double resetThresholdKmh;
  final Duration sustainedDuration;
  final Duration resetDuration;
  final double maxAccuracyMeters;
  final Duration maxStaleAge;
  final Duration cooldown;
}

/// Pure GPS reading input so [SpeedMonitorService] is 100% unit-testable
/// without requiring physical GPS hardware.
class SpeedSample {
  const SpeedSample({
    required this.speedMetersPerSecond,
    required this.accuracyMeters,
    required this.timestamp,
    this.latitude,
    this.longitude,
  });

  final double speedMetersPerSecond;
  final double accuracyMeters;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;

  double get speedKmh =>
      speedMetersPerSecond > 0 ? speedMetersPerSecond * 3.6 : 0.0;
}

/// Result returned on each [SpeedMonitorService.evaluate] call.
class SpeedEvaluationResult {
  const SpeedEvaluationResult({
    required this.state,
    required this.shouldTriggerAlert,
    required this.speedKmh,
  });

  final SpeedAlertState state;
  final bool shouldTriggerAlert;
  final double speedKmh;
}

/// Stateful GPS speed monitor implementing:
/// - 80 km/h sustained threshold (~10s)
/// - 70 km/h hysteresis reset (~10s)
/// - GPS accuracy <= 25m validation
/// - Stale timestamp rejection
/// - Per-session cooldown to prevent notification spam
class SpeedMonitorService {
  SpeedMonitorService({
    this.config = const SpeedAlertConfig(),
    FirebaseFirestore? firestore,
  }) : _firestore = firestore;

  final SpeedAlertConfig config;
  final FirebaseFirestore? _firestore;

  SpeedAlertState _state = SpeedAlertState.normal;
  DateTime? _highSpeedStartedAt;
  DateTime? _belowResetStartedAt;
  DateTime? _lastAlertSentAt;

  SpeedAlertState get state => _state;

  void reset() {
    _state = SpeedAlertState.normal;
    _highSpeedStartedAt = null;
    _belowResetStartedAt = null;
  }

  /// Evaluates a single GPS [sample] against threshold, accuracy, freshness,
  /// hysteresis, and cooldown rules.
  SpeedEvaluationResult evaluate(
    SpeedSample sample, {
    required bool isSharingLocation,
    required bool isSpeedAlertEnabled,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();

    if (!isSharingLocation || !isSpeedAlertEnabled) {
      _highSpeedStartedAt = null;
      _belowResetStartedAt = null;
      _state = SpeedAlertState.sharingDisabled;
      return SpeedEvaluationResult(
        state: _state,
        shouldTriggerAlert: false,
        speedKmh: 0,
      );
    }

    // Reject invalid / stale GPS samples
    final age = currentTime.difference(sample.timestamp);
    if (age > config.maxStaleAge || age < const Duration(seconds: -10)) {
      _highSpeedStartedAt = null;
      _state = SpeedAlertState.locationStale;
      return SpeedEvaluationResult(
        state: _state,
        shouldTriggerAlert: false,
        speedKmh: sample.speedKmh,
      );
    }

    if (sample.speedMetersPerSecond.isNaN ||
        sample.speedMetersPerSecond < 0 ||
        sample.accuracyMeters.isNaN ||
        sample.accuracyMeters <= 0 ||
        sample.accuracyMeters > config.maxAccuracyMeters) {
      // Ignore noisy GPS reading without immediately resetting an active alert
      if (_state != SpeedAlertState.alertSent) {
        _highSpeedStartedAt = null;
        _state = SpeedAlertState.monitoring;
      }
      return SpeedEvaluationResult(
        state: _state,
        shouldTriggerAlert: false,
        speedKmh: sample.speedKmh,
      );
    }

    final kmh = sample.speedKmh;

    // Case A: An alert was already sent for this high-speed session -> wait for hysteresis reset (<70 km/h)
    if (_state == SpeedAlertState.alertSent) {
      if (kmh < config.resetThresholdKmh) {
        _belowResetStartedAt ??= sample.timestamp;
        final belowElapsed = sample.timestamp.difference(_belowResetStartedAt!);
        if (belowElapsed >= config.resetDuration) {
          _belowResetStartedAt = null;
          _highSpeedStartedAt = null;
          _state = SpeedAlertState.speedBackToNormal;
        }
      } else {
        _belowResetStartedAt = null;
      }
      return SpeedEvaluationResult(
        state: _state,
        shouldTriggerAlert: false,
        speedKmh: kmh,
      );
    }

    // Case B: Speed meets or exceeds trigger threshold (>= 80 km/h)
    if (kmh >= config.triggerThresholdKmh) {
      _belowResetStartedAt = null;
      _highSpeedStartedAt ??= sample.timestamp;
      final sustained = sample.timestamp.difference(_highSpeedStartedAt!);

      if (sustained >= config.sustainedDuration) {
        final inCooldown =
            _lastAlertSentAt != null &&
            currentTime.difference(_lastAlertSentAt!) < config.cooldown;
        if (inCooldown) {
          _state = SpeedAlertState.speedWarning;
          return SpeedEvaluationResult(
            state: _state,
            shouldTriggerAlert: false,
            speedKmh: kmh,
          );
        }

        _lastAlertSentAt = currentTime;
        _state = SpeedAlertState.alertSent;
        return SpeedEvaluationResult(
          state: _state,
          shouldTriggerAlert: true,
          speedKmh: kmh,
        );
      }

      _state = SpeedAlertState.speedWarning;
      return SpeedEvaluationResult(
        state: _state,
        shouldTriggerAlert: false,
        speedKmh: kmh,
      );
    }

    // Case C: Below threshold
    _highSpeedStartedAt = null;
    _state = _state == SpeedAlertState.speedBackToNormal
        ? SpeedAlertState.normal
        : SpeedAlertState.monitoring;
    return SpeedEvaluationResult(
      state: _state,
      shouldTriggerAlert: false,
      speedKmh: kmh,
    );
  }

  /// Writes a validated Speed Alert event to `pairs/{pairId}/speedAlerts/{alertId}`
  /// so the backend Cloud Function can validate & dispatch high-priority FCM.
  Future<String?> recordSpeedAlertEvent({
    required String pairId,
    required String uid,
    required String displayName,
    required SpeedSample sample,
  }) async {
    if (pairId.isEmpty || uid.isEmpty) return null;
    final db = _firestore ?? FirebaseFirestore.instance;
    final docRef = await db
        .collection('pairs')
        .doc(pairId)
        .collection('speedAlerts')
        .add({
          'uid': uid,
          'displayName': displayName.isNotEmpty ? displayName : 'Your partner',
          'pairId': pairId,
          'speedKmh': double.parse(sample.speedKmh.toStringAsFixed(1)),
          'accuracy': sample.accuracyMeters,
          'latitude': sample.latitude,
          'longitude': sample.longitude,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
    return docRef.id;
  }
}
