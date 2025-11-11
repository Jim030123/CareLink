import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:carelink_mobile/utils/graphql_service.dart';

class GraphQLTestPage extends StatefulWidget {
  const GraphQLTestPage({super.key});

  @override
  State<GraphQLTestPage> createState() => _GraphQLTestPageState();
}

class _GraphQLTestPageState extends State<GraphQLTestPage> {
  bool _loading = false;

  Future<void> _checkGraphQL() async {
    setState(() => _loading = true);

    try {
      debugPrint('GraphQL: starting test query');

      final client = createClient();

      final result = await client.query(
        QueryOptions(
          document: gql('''
            query {
              users {
                uid
                email
                displayName
              }
            }
          '''),
        ),
      );

      if (result.hasException) {
        final message = result.exception.toString();
        debugPrint('GraphQL error: $message');
        if (result.exception?.graphqlErrors.isNotEmpty ?? false) {
          debugPrint('GraphQL errors detail: ${result.exception!.graphqlErrors}');
        }
        if (result.exception?.linkException != null) {
          debugPrint('GraphQL link exception: ${result.exception!.linkException}');
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('GraphQL error: $message')));
      } else {
        debugPrint('✅ GraphQL OK, data: ${result.data}');
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('GraphQL OK!')));
      }
    } catch (e, st) {
      debugPrint('❌ Request failed: $e\n$st');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Request failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GraphQL Connection Test')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _checkGraphQL,
                child: const Text('Test GraphQL Connection'),
              ),
      ),
    );
  }
}
