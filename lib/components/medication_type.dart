import 'package:flutter/material.dart';

enum MedicationType { capsule, tablet, injection, cream }

Widget buildOption({
  required MedicationType type,
  required String label,
  required String assetName,
  required MedicationType selected,
  required void Function(MedicationType) onSelect,
}) {
  final bool isSelected = selected == type;
  final bg = isSelected ? const Color(0xFFFFECB3) : Colors.white;
  final border = isSelected
      ? Border.all(color: Colors.orange, width: 1.6)
      : Border.all(color: Colors.grey.shade300, width: 1);

  return GestureDetector(
    onTap: () => onSelect(type),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: border,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          child: Image.asset(assetName, width: 28, height: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.black87 : Colors.black54,
          ),
        ),
      ],
    ),
  );
}
