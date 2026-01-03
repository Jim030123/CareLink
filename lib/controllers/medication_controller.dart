import 'package:graphql_flutter/graphql_flutter.dart';

/// Controller helpers for `ShowMedication` screen.
/// Contains pure/logic helpers (mapping, applying subscription payloads)
class MedicationHandBookController {
  String? _lastMedEventKey;

  /// Map backend medication object to UI item structure
  Map<String, dynamic> mapMedicationToItem(Map<String, dynamic> m) {
    final id = m['id'] ?? '';
    final description = m['description'] ?? '';
    final packageQuantity = m['packageQuantity']?.toString() ?? '';
    final packageUnit = m['packageUnit'] ?? '';
    final name = m['name'] ?? '';
    final strength = m['strength']?.toString() ?? '';
    final standardUnit = m['standardUnit'] ?? '';
    final form = (m['form'] ?? '').toString();
    final type = form.trim().toLowerCase();
    final assetName = 'assets/icons/${type.isNotEmpty ? type : 'capsule'}.png';
    final sku = m['sku'] ?? '';
    final brand = m['brand'] ?? '';

    return {
      'id': id,
      'name': name,
      'strength': strength,
      'asset': assetName,
      'type': type,
      'standardUnit': standardUnit,
      'description': description,
      'packageQuantity': packageQuantity,
      'packageUnit': packageUnit,
      'brand': brand,
      'sku': sku,
    };
  }

  /// Apply a subscription payload to a copy of the current items list and
  /// return the new list. This keeps the UI code simple: call this and
  /// setState with the returned list.
  List<Map<String, dynamic>> applyMedUpdateTo(
    List<Map<String, dynamic>> items,
    Map<String, dynamic> payload,
  ) {
    try {
      final String? rawEventType =
          payload['eventType']?.toString() ?? payload['event']?.toString();
      final String eventType = (rawEventType ?? '').toUpperCase();
      final String? timestamp = payload['timestamp']?.toString();

      final medRaw = payload['medication'];
      final String? medId = medRaw is Map ? (medRaw['id']?.toString()) : null;

      final String? deletedId =
          payload['deletedId']?.toString() ??
          payload['deleted_id']?.toString() ??
          payload['id']?.toString();

      final String key =
          '${eventType}_${timestamp ?? ''}_${deletedId ?? medId ?? ''}';

      if (key.isNotEmpty && _lastMedEventKey == key) {
        // duplicate event — ignore and return original list
        return items;
      }

      _lastMedEventKey = key;

      // resolve event type and medication object
      final String? eventTypeRaw = payload['eventType']?.toString();
      final Map<String, dynamic>? med = medRaw is Map
          ? Map<String, dynamic>.from(medRaw)
          : null;

      final String? altEvent = payload['event']?.toString();
      final String? altType = payload['type']?.toString();
      final String resolvedEventType =
          (eventTypeRaw ?? altEvent ?? altType ?? '').toUpperCase();

      final bool medMarkedDeleted =
          med != null &&
          (med['deleted'] == true ||
              (med['status'] as String?)?.toLowerCase() == 'deleted');

      final bool payloadIsOnlyId =
          (payload.keys.length == 1 && payload.containsKey('id')) ||
          (payload['id'] is String &&
              med == null &&
              deletedId == null &&
              resolvedEventType.isEmpty &&
              !medMarkedDeleted);

      // idCandidate not required here — resolution uses deletedId/med/payload when needed

      final List<Map<String, dynamic>> newItems = List.from(items);

      if ((resolvedEventType == 'CREATED' || resolvedEventType == 'CREATE') &&
          med != null) {
        final mapped = mapMedicationToItem(med);
        final idx = newItems.indexWhere(
          (e) => e['id']?.toString() == mapped['id']?.toString(),
        );
        if (idx >= 0) {
          newItems[idx] = mapped;
        } else {
          newItems.insert(0, mapped);
        }
      } else if ((resolvedEventType == 'UPDATED' ||
              resolvedEventType == 'UPDATE') &&
          med != null) {
        final mapped = mapMedicationToItem(med);
        final idx = newItems.indexWhere(
          (e) => e['id']?.toString() == mapped['id']?.toString(),
        );
        if (idx >= 0) {
          newItems[idx] = mapped;
        } else {
          newItems.insert(0, mapped);
        }
      } else if (resolvedEventType.contains('DELET') ||
          medMarkedDeleted ||
          payloadIsOnlyId) {
        final String? idToRemove =
            deletedId ?? med?['id']?.toString() ?? payload['id']?.toString();
        if (idToRemove != null) {
          newItems.removeWhere((m) => m['id']?.toString() == idToRemove);
        }
      } else {
        // no clear event type but medication present => upsert
        if (med != null) {
          final mapped = mapMedicationToItem(med);
          final idx = newItems.indexWhere(
            (e) => e['id']?.toString() == mapped['id']?.toString(),
          );
          if (idx >= 0) {
            newItems[idx] = mapped;
          } else {
            newItems.insert(0, mapped);
          }
        }
      }

      return newItems;
    } catch (e) {
      // on error, just return original list
      return items;
    }
  }

  /// Build an optimistic UI item for an upsert operation. If [input] has no
  /// `id` a temporary id will be created.
  Map<String, dynamic> buildOptimisticItem(Map<String, dynamic> input) {
    final tempId =
        input['id'] ?? 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final copy = Map<String, dynamic>.from(input);
    copy['id'] = tempId;
    return mapMedicationToItem(copy);
  }

  /// Merge server upsert [data] into [items]. If [tempId] is provided, it will
  /// replace the temporary item. Returns the new items list.
  List<Map<String, dynamic>> mergeUpsertResult(
    List<Map<String, dynamic>> items,
    Map<String, dynamic>? data, {
    String? tempId,
    Map<String, dynamic>? previous,
  }) {
    final newItems = List<Map<String, dynamic>>.from(items);
    if (data == null) {
      // revert optimistic if tempId provided
      if (tempId != null) {
        newItems.removeWhere((e) => e['id'] == tempId);
      } else if (previous != null) {
        final idx = newItems.indexWhere(
          (e) => e['id']?.toString() == previous['id']?.toString(),
        );
        if (idx >= 0) {
          newItems[idx] = previous;
        }
      }
      return newItems;
    }

    final mapped = mapMedicationToItem(data);
    if (tempId != null) {
      final idx = newItems.indexWhere((e) => e['id'] == tempId);
      if (idx >= 0) {
        newItems[idx] = mapped;
      } else {
        newItems.insert(0, mapped);
      }
      return newItems;
    }

    final idx = newItems.indexWhere(
      (e) => e['id']?.toString() == mapped['id']?.toString(),
    );
    if (idx >= 0) {
      newItems[idx] = mapped;
    } else {
      newItems.insert(0, mapped);
    }
    return newItems;
  }

  /// Perform an upsert operation using [backend] and return a result object
  /// containing the final items and server data (or null on failure).
  ///
  /// Returns: `{'items': List<Map>, 'data': Map? , 'tempId': String? , 'previous': Map? }
  ///
  Map<String, dynamic> _normalizeMedicationInput(Map<String, dynamic> input) {
    final out = <String, dynamic>{};

    input.forEach((key, value) {
      if (value == null) return;
      out[key] = value.toString();
    });

    return out;
  }

  Future<Map<String, dynamic>> upsertMedicationRemote(
    GraphQLClient client,
    MedicationController backend,
    Map<String, dynamic> input,
    List<Map<String, dynamic>> items,
  ) async {
    // 🔐 关键：先统一把 input 全部转成 String
    final normalizedInput = _normalizeMedicationInput(input);

    final isCreate =
        normalizedInput['id'] == null ||
        normalizedInput['id'].toString().isEmpty;

    Map<String, dynamic>? previous;
    String? tempId;
    final working = List<Map<String, dynamic>>.from(items);

    /// ---------- Optimistic UI ----------
    if (isCreate) {
      tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';

      final optimisticMed = mapMedicationToItem({
        'id': tempId,
        'name': normalizedInput['name'] ?? '',
        'strength': normalizedInput['strength'],
        'standardUnit': normalizedInput['standardUnit'],
        'packageQuantity': normalizedInput['packageQuantity'],
        'form': normalizedInput['form'],
      });

      working.insert(0, optimisticMed);
    } else {
      final idx = working.indexWhere(
        (e) => e['id']?.toString() == normalizedInput['id']?.toString(),
      );

      if (idx >= 0) {
        previous = Map<String, dynamic>.from(working[idx]);

        final optimisticMed = mapMedicationToItem({
          'id': normalizedInput['id'],
          'name': normalizedInput['name'] ?? previous['name'],
          'strength': normalizedInput['strength'] ?? previous['strength'],
          'standardUnit':
              normalizedInput['standardUnit'] ?? previous['standardUnit'],
          'packageQuantity':
              normalizedInput['packageQuantity'] ?? previous['packageQuantity'],
          'form': normalizedInput['form'] ?? previous['form'],
        });

        working[idx] = optimisticMed;
      }
    }

    /// ---------- Call backend ----------
    final data = await backend.upsertMedication(client, normalizedInput);

    /// ---------- Revert on failure ----------
    if (data == null) {
      final reverted = mergeUpsertResult(
        working,
        null,
        tempId: tempId,
        previous: previous,
      );

      return {
        'items': reverted,
        'data': null,
        'tempId': tempId,
        'previous': previous,
      };
    }

    /// ---------- Merge server result ----------
    final merged = mergeUpsertResult(working, data, tempId: tempId);

    return {
      'items': merged,
      'data': data,
      'tempId': tempId,
      'previous': previous,
    };
  }

  /// Perform delete operation and return updated items and result flag.
  /// Returns: `{'items': List<Map>, 'success': bool, 'error': String?}`
  Future<Map<String, dynamic>> deleteMedicationRemote(
    GraphQLClient client,
    MedicationController backend,
    String id,
    int localIndex,
    List<Map<String, dynamic>> items,
  ) async {
    final working = List<Map<String, dynamic>>.from(items);
    Map<String, dynamic>? removed;
    if (localIndex >= 0 && localIndex < working.length) {
      removed = working[localIndex];
      working.removeAt(localIndex);
    }

    final success = await backend.deleteMedication(client, id);
    if (!success) {
      // reinsert if we removed
      if (removed != null) {
        working.insert(localIndex.clamp(0, working.length), removed);
      }
      return {
        'items': working,
        'success': false,
        'error': 'Delete failed',
        'removed': removed,
      };
    }

    // on success, return working list; caller may optionally refetch
    return {
      'items': working,
      'success': true,
      'error': null,
      'removed': removed,
    };
  }

  /// Fetch medications from backend and return them mapped to UI items.
  Future<List<Map<String, dynamic>>> fetchMappedMedications(
    GraphQLClient client,
    MedicationController backend,
  ) async {
    final meds = await backend.fetchMedications(client);
    return meds
        .map((e) => mapMedicationToItem(Map<String, dynamic>.from(e)))
        .toList();
  }
}

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
 mutation UpsertMedication($object: MedicationInput!) {
  insert_medication(
    objects: [$object]
    on_conflict: {
      update_columns: [
        "name"
        "description"
        "packageQuantity"
        "standardUnit"

        "form"
        "packageUnit"
        "brand"
        "sku"
        "strength"
      ]
    }
  ) {
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

  static const String _deleteMutation = r'''
    mutation DeleteMedication($id: String!) {
      delete_medication_by_pk(id: $id)
    }
  ''';

  /// Fetch all medications (no caregiver filtering)
  Future<List<Map<String, dynamic>>> fetchMedications(
    GraphQLClient client,
  ) async {
    final result = await client.query(
      QueryOptions(
        document: gql(_fetchQuery),
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    final List<dynamic>? meds = result.data?['medications'] as List<dynamic>?;
    if (meds == null) return <Map<String, dynamic>>[];

    return meds.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Upsert medication and return returned map (or null on failure)
  Future<Map<String, dynamic>?> upsertMedication(
    GraphQLClient client,
    Map<String, dynamic> input,
  ) async {
    final res = await client.mutate(
      MutationOptions(
        document: gql(_upsertMutation),
        variables: {'object': input},
      ),
    );

    // ✅ 第一步：先看有没有 GraphQL 错误
    if (res.hasException) {
      print('❌ GraphQL Exception:');
      print(res.exception); // 总览
      print(res.exception?.graphqlErrors); // GraphQL validation / resolver 错误
      print(res.exception?.linkException); // 网络 / 连接错误
      return null;
    }

    // ✅ 第二步：再安全地读 data
    final list = res.data?['insert_medication'] as List<dynamic>?;

    if (list == null || list.isEmpty) {
      print('⚠️ insert_medication returned empty list');
      return null;
    }

    return Map<String, dynamic>.from(list.first);
  }

  /// Delete medication by id. Returns true if deletion request succeeded.
  Future<bool> deleteMedication(GraphQLClient client, String id) async {
    final res = await client.mutate(
      MutationOptions(document: gql(_deleteMutation), variables: {'id': id}),
    );

    if (res.hasException) return false;

    final dyn = res.data?['delete_medication_by_pk'];
    final bool success =
        dyn == true || (dyn is String && dyn.isNotEmpty) || dyn == null;
    return success;
  }



}
