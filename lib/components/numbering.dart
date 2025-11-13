String generateCode(String prefix, int index) {
  // padLeft(3, '0') means: ensure at least 3 digits, pad with 0s in front
  final formattedIndex = index.toString().padLeft(3, '0');
  return '$prefix$formattedIndex';
}

void main() {
  print(generateCode('CG-', 1));   // CG-001
  print(generateCode('CG-', 12));  // CG-012
  print(generateCode('CG-', 123)); // CG-123
}