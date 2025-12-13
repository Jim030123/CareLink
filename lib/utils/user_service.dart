import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:carelink_mobile/utils/graphql_service.dart';
import 'package:carelink_mobile/utils/auth_service.dart';

/// GraphQL 查询：根据 uid 获取用户对象。请根据后端 schema 调整字段。
const String _getUserQuery = r'''
query GetUser($uid: String!) {
  user(uid: $uid) {
    uid
    email
    emailVerified
    phoneNumber
    displayName
    photoURL
    providerID
    creationTime
    lastSignInTime
    disable
    userType
    id
  }
}
''';

/// Fetch current signed-in user from backend using their Firebase uid.
/// Returns the `user` map from GraphQL result, or null on failure / not found.
Future<Map<String, dynamic>?> fetchCurrentUser() async {
  final uid = AuthService.instance.currentUser?.uid;
  if (uid == null) {
    debugPrint('fetchCurrentUser: no current user uid (not signed in)');
    return null;
  }

  final idToken = await AuthService.instance.getIdToken();
  if (idToken == null) {
    debugPrint('fetchCurrentUser: failed to get idToken for uid=$uid');
    return null;
  }

  final client = createClient(idToken: idToken);
  debugPrint('fetchCurrentUser: querying backend for uid=$uid');
  QueryResult result;
  try {
    result = await client.query(
    QueryOptions(
      document: gql(_getUserQuery),
      variables: {'uid': uid},
      fetchPolicy: FetchPolicy.networkOnly,
    ),
    );
  } catch (e, st) {
    debugPrint('fetchCurrentUser: query threw exception: $e\n$st');
    return null;
  }

  if (result.hasException) {
    debugPrint('fetchCurrentUser: GraphQL exception for uid=$uid -> ${result.exception}');
    debugPrint('fetchCurrentUser: result.data = ${result.data}');
    return null;
  }

  final user = result.data?['user'] as Map<String, dynamic>?;
  debugPrint('fetchCurrentUser: fetched user for uid=$uid -> $user');
  return user;
}

/// Fetch a user by explicit uid (useful for admin/lookup flows).
Future<Map<String, dynamic>?> fetchUserByUid(
  String uid, {
  String? idToken,
}) async {
  final token = idToken ?? await AuthService.instance.getIdToken();
  if (token == null) {
    debugPrint('fetchUserByUid: no idToken available for uid=$uid');
    return null;
  }

  final client = createClient(idToken: token);

  final result = await client.query(
    QueryOptions(
      document: gql(_getUserQuery),
      variables: {'uid': uid},
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );

  if (result.hasException) {
    debugPrint(
      'fetchUserByUid: GraphQL exception for uid=$uid -> ${result.exception}',
    );
    return null;
  }

  final user = result.data?['user'] as Map<String, dynamic>?;
  if (user == null) {
    debugPrint(
      'fetchUserByUid: query returned no user for uid=$uid, data=${result.data}',
    );
  }
  return user;
}
