import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/action_result.dart';

/// Result of the last register / login attempt, read by the result screen.
///
/// It lives outside the widget tree on purpose: go_router may redirect the
/// form screen away before it can navigate, so the outcome has to survive
/// the widget being disposed.
final actionResultProvider = StateProvider<ActionResult?>((ref) => null);
