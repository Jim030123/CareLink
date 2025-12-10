import 'package:shared_preferences/shared_preferences.dart';

/// Get or create a persistent clientId for a given role.
/// If `provided` is non-null and non-empty, it is returned (caller-supplied id).
/// Otherwise a stable id is read from SharedPreferences or generated and stored.
Future<String> getOrCreateClientId(String role, {String? provided}) async {
  if (provided != null && provided.isNotEmpty) return provided;
  final prefs = await SharedPreferences.getInstance();
  final key = 'clientId.$role';
  final existing = prefs.getString(key);
  if (existing != null && existing.isNotEmpty) return existing;
  final prefix = role == 'caregiver' ? 'caregiver-' : 'care-recipient-';
  final generated = '$prefix${DateTime.now().millisecondsSinceEpoch}';
  await prefs.setString(key, generated);
  return generated;
}
