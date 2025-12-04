import 'dart:math';

class PasswordGenerator {
  PasswordGenerator._(); // no instances

  static final Random _rand = Random.secure();

  static const String _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _lower = 'abcdefghijklmnopqrstuvwxyz';
  static const String _digits = '0123456789';
  static const String _symbols = '!@#\$%ˆ&*()-_=+[]{}|;:,.<>?/~`';

  /// Generate a random password.
  ///
  /// Parameters:
  /// - [length]: desired password length (default 12). Must be >= number of
  ///   enabled character classes.
  /// - [useUpper], [useLower], [useDigits], [useSymbols]: enable character classes.
  ///
  /// The function guarantees that at least one character from each enabled
  /// character class appears in the result (to satisfy common password rules).
  static String generate({
    int length = 12,
    bool useUpper = true,
    bool useLower = true,
    bool useDigits = true,
    bool useSymbols = true,
  }) {
    final pools = <String>[];
    if (useUpper) pools.add(_upper);
    if (useLower) pools.add(_lower);
    if (useDigits) pools.add(_digits);
    if (useSymbols) pools.add(_symbols);

    if (pools.isEmpty) {
      throw ArgumentError('At least one character class must be enabled');
    }

    if (length < pools.length) {
      throw ArgumentError('length must be >= number of enabled character classes (${pools.length})');
    }

    // Start with one guaranteed character from each enabled pool
    final chars = <String>[];
    for (final pool in pools) {
      chars.add(_pick(pool));
    }

    final all = pools.join();
    for (var i = chars.length; i < length; i++) {
      chars.add(_pick(all));
    }

    // Shuffle in-place using Fisher-Yates
    for (var i = chars.length - 1; i > 0; i--) {
      final j = _rand.nextInt(i + 1);
      final tmp = chars[i];
      chars[i] = chars[j];
      chars[j] = tmp;
    }

    return chars.join();
  }

  /// Convenience helper: generate a 10-character password combining
  /// upper, lower, digits and symbols.
  static String generateCombined10() {
    return generate(length: 10, useUpper: true, useLower: true, useDigits: true, useSymbols: true);
  }

  static String _pick(String pool) => pool[_rand.nextInt(pool.length)];
}
