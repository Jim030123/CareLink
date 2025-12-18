import 'dart:io';

import 'package:carelink_mobile/utils/user_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:carelink_mobile/utils/graphql_service.dart';

Future<Map<String, dynamic>> postDeviceRegistration(
  Map<String, dynamic> payload,
) async {
  try {
    // -----------------------------
    // 1. Auth token
    // -----------------------------
    String? idToken;
    try {
      idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      idToken = null;
    }

    print('[postDeviceRegistration] idToken ${idToken != null ? "present" : "null"}');

    // try to determine a roleId: prefer provided payload, else fetch by Firebase uid
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    String? fetchedRoleId;
    if (uid != null) {
      try {
        fetchedRoleId = await fetchUserIdByUid(uid);
      } catch (e) {
        fetchedRoleId = null;
      }
    }
    final computedRoleId = payload['roleId'] ?? fetchedRoleId;

    final client = createClient(idToken: idToken);

    // -----------------------------
    // 2. Required fields
    // -----------------------------
    final userId = payload['userId'];
    final token = payload['fcmToken'];

    print('[postDeviceRegistration] payload userId=$userId token=${token != null ? "present" : "null"} platform=${payload['platform']} deviceId=${payload['deviceId']}');

    if (userId == null || token == null) {
      print('[postDeviceRegistration] missing userId or fcmToken');
      return {'statusCode': 400, 'body': 'missing userId or fcmToken'};
    }

    // -----------------------------
    // 3. Query existing devices by user
    // -----------------------------
    const query = r'''
      query UserDevicesByUser($userId: ID!) {
        user_devices_by_user(userId: $userId) {
          id
          fcmToken
        }
      }
    ''';

    final qres = await client.query(
      QueryOptions(
        document: gql(query),
        variables: {'userId': userId},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (qres.hasException) {
      print('[postDeviceRegistration] query error: ${qres.exception}');
      return {'statusCode': 500, 'body': qres.exception.toString()};
    }

    final List devices = (qres.data?['user_devices_by_user'] as List?) ?? [];
    print('[postDeviceRegistration] found ${devices.length} existing devices for user $userId');

    // -----------------------------
    // 4. Check existing by fcmToken
    // -----------------------------
    final Map? existing = devices.cast<Map?>().firstWhere(
      (d) => d != null && d['fcmToken'] == token,
      orElse: () => null,
    );

    if (existing != null) print('[postDeviceRegistration] matched existing device id=${existing['id']}');

    // -----------------------------
    // 5A. Update existing device (try by_pk then fallback)
    // -----------------------------
    if (existing != null && existing['id'] != null) {
      const updateByPkMut = r'''
        mutation UpdateDeviceByPk(
          $id: ID!,
          $changes: user_device_insert_input!
        ) {
          update_user_device_by_pk(
            id: $id,
            changes: $changes
          ) {
            id
            userId
            platform
            fcmToken
            deviceName
            deviceId
            isActive
            lastSeenAt
            createdAt
            roleId
          }
        }
      ''';

      final changes = {
        'platform': payload['platform'],
        'deviceName': payload['deviceName'],
        'deviceId': payload['deviceId'],
        'roleId': computedRoleId,
        'isActive': true,
        'lastSeenAt': DateTime.now().toUtc().toIso8601String(),
      };

      print('[postDeviceRegistration] updating device by pk id=${existing['id']} changes=$changes');

      final mres = await client.mutate(
        MutationOptions(
          document: gql(updateByPkMut),
          variables: {'id': existing['id'], 'changes': changes},
        ),
      );

      if (mres.hasException) {
        print('[postDeviceRegistration] update_by_pk failed: ${mres.exception}');
        // Fallback to update_user_device (pk + _set)
        const updateMut = r'''
          mutation UpdateDevice($pk_columns: user_device_pk_columns_input!, $_set: user_device_insert_input!) {
            update_user_device(pk_columns: $pk_columns, _set: $_set) {
              id
              userId
              platform
              fcmToken
              deviceName
              deviceId
              isActive
              lastSeenAt
              createdAt
              roleId
            }
          }
        ''';

        print('[postDeviceRegistration] attempting fallback update_user_device pk=${existing['id']}');

        final fbRes = await client.mutate(
          MutationOptions(
            document: gql(updateMut),
            variables: {
              'pk_columns': {'id': existing['id']},
              '_set': changes,
            },
          ),
        );

        if (fbRes.hasException) {
          print('[postDeviceRegistration] fallback update failed: ${fbRes.exception}');
          return {'statusCode': 500, 'body': fbRes.exception.toString()};
        }

        print('[postDeviceRegistration] fallback update succeeded: ${fbRes.data}');
        return {'statusCode': 200, 'body': fbRes.data};
      }

      print('[postDeviceRegistration] update_by_pk succeeded: ${mres.data}');
      return {'statusCode': 200, 'body': mres.data};
    }

    // -----------------------------
    // 5B. Insert new device
    // -----------------------------
    const insertMut = r'''
      mutation InsertDevice(
        $object: user_device_insert_input!
      ) {
        insert_user_device_one(object: $object) {
          id
          userId
          platform
          fcmToken
          deviceName
          deviceId
          isActive
          lastSeenAt
          createdAt
          roleId
        }
      }
    ''';

    final object = {
      'id': payload['id'] ?? Uuid().v4(),
      'userId': userId,
      'platform': payload['platform'],
      'deviceName': payload['deviceName'],
      'deviceId': payload['deviceId'],
      'roleId': computedRoleId,
      'fcmToken': token,
      'isActive': true,
      'lastSeenAt': DateTime.now().toUtc().toIso8601String(),
    };

    print('[postDeviceRegistration] inserting new device object=$object');

    final mres = await client.mutate(
      MutationOptions(document: gql(insertMut), variables: {'object': object}),
    );

    if (mres.hasException) {
      print('[postDeviceRegistration] insert failed: ${mres.exception}');
      return {'statusCode': 500, 'body': mres.exception.toString()};
    }

    print('[postDeviceRegistration] insert succeeded: ${mres.data}');
    return {'statusCode': 201, 'body': mres.data};
  } catch (e, st) {
    print('GraphQL device registration failed: $e\n$st');
    return {'statusCode': 500, 'body': e.toString()};
  }
}
