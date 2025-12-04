
import 'package:flutter_riverpod/legacy.dart';


/// Holds transient caregiver identifier (e.g. generated code) during
/// the multi-step registration flow.
final currentUserIdProvider = StateProvider<String?>((ref) => null);
