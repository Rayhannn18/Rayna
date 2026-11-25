import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/glass_bottom_nav_bar.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../map/providers/map_providers.dart';
import '../../../pairing/providers/pairing_providers.dart';

/// Main application shell that hosts the 4 primary tabs with a shared
/// floating [GlassBottomNavBar].
///
/// Also performs a lightweight initial battery sync whenever the user has an
/// active pair so the partner sees live battery percentage even before opening
/// the Map tab.
class MainShellScaffold extends ConsumerStatefulWidget {
  const MainShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShellScaffold> createState() => _MainShellScaffoldState();
}

class _MainShellScaffoldState extends ConsumerState<MainShellScaffold> {
  String? _lastSyncedPairId;

  Future<void> _syncInitialBattery(String pairId) async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null || uid.isEmpty || pairId.isEmpty) return;

    final batteryService = ref.read(batteryServiceProvider);
    final level = await batteryService.getBatteryLevel();
    final charging = await batteryService.isCharging();
    await batteryService.syncBatteryToFirestore(
      pairId: pairId,
      uid: uid,
      batteryLevel: level,
      isCharging: charging,
      isSharing: true,
      force: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userDoc = ref.watch(currentUserDocumentProvider);
    final activePairId =
        userDoc.valueOrNull?.data()?['activePairId'] as String?;

    if (activePairId != null &&
        activePairId.isNotEmpty &&
        activePairId != _lastSyncedPairId) {
      _lastSyncedPairId = activePairId;
      Future.microtask(() => _syncInitialBattery(activePairId));
    } else if (activePairId == null || activePairId.isEmpty) {
      _lastSyncedPairId = null;
    }

    final isOnHomeTab = widget.navigationShell.currentIndex == 0;

    return PopScope(
      canPop: isOnHomeTab,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !isOnHomeTab) {
          widget.navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: AppColors.scaffoldBackground,
        body: widget.navigationShell,
        bottomNavigationBar: GlassBottomNavBar(
          currentIndex: widget.navigationShell.currentIndex,
          onTap: (index) {
            widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            );
          },
        ),
      ),
    );
  }
}
