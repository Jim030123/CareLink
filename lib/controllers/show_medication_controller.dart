import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:carelink_mobile/controllers/medication_controller.dart';

/// Controller helpers for `ShowMedication` screen.
/// Contains pure/logic helpers (mapping, applying subscription payloads)
class ShowMedicationController {
  String? _lastMedEventKey;

  /// Map backend medication object to UI item structure
  Map<String, dynamic> mapMedicationToItem(Map<String, dynamic> m) {
    final name = m['name'] ?? '';
    final dosageAmount = m['strength']?.toString() ?? '';
    final dosageUnit = m['standardUnit'] ?? '';
    final qty = m['packageQuantity']?.toString() ?? '';
    final rawType = (m['form'] ?? '').toString();
    final type = rawType.trim().toLowerCase();
    final assetName = 'assets/icons/${type.isNotEmpty ? type : 'capsule'}.png';

    return {
      'id': m['id'],
      'name': name,
      'dose': '$dosageAmount$dosageUnit',
      'left': qty,
      'color': const Color(0xFFF7EAD3),
      'asset': assetName,
      'type': type,
    };
  }

  /// Apply a subscription payload to a copy of the current items list and
  /// return the new list. This keeps the UI code simple: call this and
  /// setState with the returned list.
  List<Map<String, dynamic>> applyMedUpdateTo(
      List<Map<String, dynamic>> items, Map<String, dynamic> payload) {
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
      final Map<String, dynamic>? med =
          medRaw is Map ? Map<String, dynamic>.from(medRaw) : null;

      final String? altEvent = payload['event']?.toString();
      final String? altType = payload['type']?.toString();
      final String resolvedEventType = (eventTypeRaw ?? altEvent ?? altType ?? '')
          .toUpperCase();

      final bool medMarkedDeleted =
          med != null &&
              (med['deleted'] == true ||
                  (med['status'] as String?)?.toLowerCase() == 'deleted');

      final bool payloadIsOnlyId =
          (payload.keys.length == 1 && payload.containsKey('id')) ||
          (payload['id'] is String && med == null && deletedId == null &&
              resolvedEventType.isEmpty && !medMarkedDeleted);

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
    final tempId = input['id'] ?? 'temp-${DateTime.now().millisecondsSinceEpoch}';
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
  Future<Map<String, dynamic>> upsertMedicationRemote(
    GraphQLClient client,
    MedicationController backend,
    Map<String, dynamic> input,
    List<Map<String, dynamic>> items,
  ) async {
    final isCreate = input['id'] == null || input['id'].toString().isEmpty;
    Map<String, dynamic>? previous;
    String? tempId;
    final working = List<Map<String, dynamic>>.from(items);

    if (isCreate) {
      tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
      final optimisticMed = mapMedicationToItem({
        'id': tempId,
        'name': input['name'] ?? '',
        'strength': input['strength'],
        'standardUnit': input['standardUnit'],
        'packageQuantity': input['packageQuantity'],
        'form': input['form'],
      });
      working.insert(0, optimisticMed);
    } else {
      final idx = working.indexWhere(
        (e) => e['id']?.toString() == input['id']?.toString(),
      );
      if (idx >= 0) {
        previous = Map<String, dynamic>.from(working[idx]);
        final optimisticMed = mapMedicationToItem({
          'id': input['id'],
          'name': input['name'] ?? previous['name'],
          'strength': input['strength'] ?? previous['strength'],
          'standardUnit': input['standardUnit'] ?? previous['standardUnit'],
          'packageQuantity': input['packageQuantity'] ?? previous['packageQuantity'],
          'form': input['form'] ?? previous['form'],
        });
        working[idx] = optimisticMed;
      }
    }

    // call backend
    final data = await backend.upsertMedication(client, input);

    if (data == null) {
      // revert optimistic
      final reverted = mergeUpsertResult(working, null, tempId: tempId, previous: previous);
      return {'items': reverted, 'data': null, 'tempId': tempId, 'previous': previous};
    }

    final merged = mergeUpsertResult(working, data, tempId: tempId);
    return {'items': merged, 'data': data, 'tempId': tempId, 'previous': previous};
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
    return {'items': working, 'success': true, 'error': null, 'removed': removed};
  }
}
