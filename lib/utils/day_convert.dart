class DayConvert {
  static int? toInt(dynamic d) {
    if (d == null) return null;
    final s = d.toString().trim().toLowerCase();
    final p = int.tryParse(s);
    if (p != null && p >= 1 && p <= 7) return p;

    switch (s) {
      case 'monday':
      case 'mon':
      case 'm':
        return 1;
      case 'tuesday':
      case 'tue':
      case 't':
        return 2;
      case 'wednesday':
      case 'wed':
      case 'w':
        return 3;
      case 'thursday':
      case 'thu':
      case 'th':
        return 4;
      case 'friday':
      case 'fri':
      case 'f':
        return 5;
      case 'saturday':
      case 'sat':
      case 'sa':
        return 6;
      case 'sunday':
      case 'sun':
      case 'su':
        return 7;
      default:
        return null;
    }
  }

  static String safeString(dynamic d, int fallbackIndex) {
    final v = toInt(d);
    return (v ?? fallbackIndex + 1).toString();
  }
}
