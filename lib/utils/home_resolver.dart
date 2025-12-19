import 'package:carelink_mobile/utils/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

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

      if (kDebugMode) {
        print('userType: $userType');
      }

      switch (userType) {
        case 'Caregiver':
          if (mounted) context.go('/home/caregiver');
          break;
        case 'Care Recipient':
          if (mounted) context.go('/home/recipient');
          break;
        case 'Doctor':
          if (mounted) context.go('/home/doctor');
          break;
        default:
          if (mounted) context.go('/notFound');
      }
    } catch (e, st) {
      debugPrint('HomeResolver error: $e\n$st');
      if (mounted) context.go('/notFound');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading UI only while resolving; once _loading is false, return an empty view.
    if (!_loading) {
      return const SizedBox.shrink();
    }

    // Brief loading UI while resolver runs (Lottie animation)
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/animations/loading.json',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            const Text('Routing to your home...'),
          ],
        ),
      ),
    );
  }
}
