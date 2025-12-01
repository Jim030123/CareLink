import 'package:carelink_mobile/utils/auth_service.dart';
import 'package:carelink_mobile/utils/graphql_service.dart';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';

class HomeResolver extends StatefulWidget {
  const HomeResolver({super.key});

  @override
  State<HomeResolver> createState() => _HomeResolverState();
}

class _HomeResolverState extends State<HomeResolver> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      // Not signed in: send to login
      if (mounted) context.go('/login');
      return;
    }

    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.query(
        QueryOptions(
          document: gql(r"""
            query {
              users {
                uid
                userType
              }
            }
          """),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (result.hasException) {
        debugPrint('HomeResolver: GraphQL exception: ${result.exception}');
        // Fallback to recipient home
        if (mounted) context.go('/home/recipient');
        return;
      }

      final users = result.data?['users'] as List<dynamic>?;
      final me = users?.firstWhere(
        (u) => (u['uid'] as String?) == uid,
        orElse: () => null,
      );

      final userType = me != null ? (me['userType'] as String?) : null;
      print('userType: $userType');

      if (userType ==  'Caregiver') {
        if (mounted) context.go('/home/caregiver');
      } else {
        if (mounted) context.go('/home/recipient');
      }
    } catch (e, st) {
      debugPrint('HomeResolver error: $e\n$st');
      if (mounted) context.go('/home/recipient');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Brief loading UI while resolver runs
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text('Routing to your home...'),
          ],
        ),
      ),
    );
  }
}
