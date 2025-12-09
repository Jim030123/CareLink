import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

/// Checks whether the given [email] already exists on the server.
///
/// Returns:
/// - `true`  => email exists (a snackbar is shown informing the user)
/// - `false` => email does not exist
/// - `null`  => error occurred while checking (a snackbar is shown)
Future<bool?> checkEmailExists(BuildContext context, String email) async {
  try {
    final client = GraphQLProvider.of(context).value;

    final result = await client.query(
      QueryOptions(
        document: gql(r'''
          query {
            users {
              email
            }
          }
        '''),
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      final msg = result.exception.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Server error: $msg')),
      );
      return null;
    }

    final users = result.data?['users'] as List<dynamic>?;
    final exists = users?.any((u) =>
          (u['email'] as String?)?.toLowerCase() == email.toLowerCase(),
        ) ??
        false;

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already created an account before, please sign in'),
        ),
      );
      return true;
    }

    return false;
  } catch (e) {
    debugPrint('GraphQL check failed: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Email check failed: $e')),
    );
    return null;
  }
}
