import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

Future<String?> fetchGeneratedCode(
  BuildContext context, {
  required int id,
}) async {
  final client = GraphQLProvider.of(context).value;

  final idxResult = await client.query(
    QueryOptions(
      document: gql(r'''
        query GetIndexByPk($id: Int!) {
          index_table_by_pk(id: $id) {
            id
            name
            index
            prefix
          }
        }
      '''),
      variables: {'id': id},
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );

  if (idxResult.hasException) {
    final msg = idxResult.exception.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Index fetch failed: $msg')),
    );
    return null;
  }

  final data = idxResult.data?['index_table_by_pk'];
  if (data == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Index not found')),
    );
    return null;
  }

  final index = data['index'] as int;
  final prefix = data['prefix'] as String?;
  final generatedCode = "${prefix ?? ''}-${index.toString().padLeft(3, '0')}";

  debugPrint('Generated Code = $generatedCode');

  // Increment the index in the database
  final mutationResult = await client.mutate(
    MutationOptions(
      document: gql(r'''
        mutation IncrementIndex($id: Int!) {
          update_index_table_by_pk(pk_columns: {id: $id}, _inc: {index: 1}) {
            id
            index
          }
        }
      '''),
      variables: {'id': id},
    ),
  );

  if (mutationResult.hasException) {
    final msg = mutationResult.exception.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Index increment failed: $msg')),
    );
    return null;
  }

  return generatedCode;
}
