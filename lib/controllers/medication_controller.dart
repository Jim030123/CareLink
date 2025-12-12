import 'package:graphql_flutter/graphql_flutter.dart';

class MedicationController {
  MedicationController();

  static const String _fetchQuery = r'''
    query GetMedications {
      medications {
        id
        name
        description
        packageQuantity
        standardUnit
        picture
        form
        packageUnit
        brand
        sku
        strength

      }
    }
  ''';

  static const String _upsertMutation = r'''
    mutation UpsertMedication($object: medication_insert_input!) {
      insert_medication_one(object: $object, on_conflict: {constraint: medication_pkey, update_columns: [name, description, packageQuantity, standardUnit, picture, form, packageUnit, brand, sku, strength, caregiverId]}) {
        id
        name
        description
        packageQuantity
        standardUnit
        picture
        form
        packageUnit
        brand
        sku
        strength
        caregiverId
      }
    }
  ''';

  static const String _deleteMutation = r'''
    mutation DeleteMedication($id: String!) {
      delete_medication_by_pk(id: $id)
    }
  ''';

  /// Fetch all medications (no caregiver filtering)
  Future<List<Map<String, dynamic>>> fetchMedications(GraphQLClient client) async {
    final result = await client.query(
      QueryOptions(document: gql(_fetchQuery), fetchPolicy: FetchPolicy.networkOnly),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    final List<dynamic>? meds = result.data?['medications'] as List<dynamic>?;
    if (meds == null) return <Map<String, dynamic>>[];

    return meds.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Upsert medication and return returned map (or null on failure)
  Future<Map<String, dynamic>?> upsertMedication(GraphQLClient client, Map<String, dynamic> input) async {
    final res = await client.mutate(
      MutationOptions(document: gql(_upsertMutation), variables: {'object': input}),
    );

    if (res.hasException) {
      return null;
    }

    final data = res.data?['insert_medication_one'] as Map<String, dynamic>?;
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  /// Delete medication by id. Returns true if deletion request succeeded.
  Future<bool> deleteMedication(GraphQLClient client, String id) async {
    final res = await client.mutate(
      MutationOptions(document: gql(_deleteMutation), variables: {'id': id}),
    );

    if (res.hasException) return false;

    final dyn = res.data?['delete_medication_by_pk'];
    final bool success = dyn == true || (dyn is String && dyn.isNotEmpty) || dyn == null;
    return success;
  }
}
