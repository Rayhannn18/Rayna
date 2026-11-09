import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/moments_service.dart';

final momentsServiceProvider = Provider<MomentsService>(
  (ref) => MomentsService(),
);
