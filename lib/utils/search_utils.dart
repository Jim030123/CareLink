// Utilities for medication search and filtering
List<Map<String, dynamic>> filterMedications(
  List<Map<String, dynamic>> source,
  String query, {
  String? selectedType,
  bool searching = false,
}) {
  final q = query.trim().toLowerCase();

  // If searching mode is enabled, ignore the selected type and search across all items.
  final base = searching
      ? source
      : source
          .where((it) => (it['type'] ?? it['form'] ?? '')
              .toString()
              .toLowerCase()
              .contains((selectedType ?? '').toLowerCase()))
          .toList();

  if (q.isEmpty) return base;

  return base.where((it) {
    final name = (it['name'] ?? '').toString().toLowerCase();
    final brand = (it['brand'] ?? '').toString().toLowerCase();
    final sku = (it['sku'] ?? '').toString().toLowerCase();
    final desc = (it['description'] ?? '').toString().toLowerCase();
    return name.contains(q) || brand.contains(q) || sku.contains(q) || desc.contains(q);
  }).toList();
}
