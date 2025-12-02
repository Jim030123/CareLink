import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:carelink_mobile/utils/secure_auth.dart';
import 'package:carelink_mobile/utils/auth_service.dart';
import 'package:carelink_mobile/utils/graphql_service.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

/// Holds transient caregiver identifier (e.g. generated code) during
/// the multi-step registration flow.
final currentUserIdProvider = StateProvider<String?>((ref) => null);
