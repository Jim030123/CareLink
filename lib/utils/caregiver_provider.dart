import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Holds transient caregiver identifier (e.g. generated code) during
/// the multi-step registration flow.
final caregiverIdProvider = StateProvider<String?>((ref) => null);
