class AmountFormatter {
  static Map<String, String> format(double amount) {
    final abs = amount.abs();
    if (abs >= 10000000) {
      return {'value': (abs / 10000000).toStringAsFixed(2), 'unit': 'Cr'};
    } else if (abs >= 100000) {
      return {'value': (abs / 100000).toStringAsFixed(2), 'unit': 'L'};
    } else if (abs >= 1000) {
      return {'value': (abs / 1000).toStringAsFixed(1), 'unit': 'K'};
    }
    return {'value': abs.toStringAsFixed(0), 'unit': ''};
  }

  static String short(double amount) {
    final f = format(amount);
    final unit = f['unit']!;
    return unit.isEmpty ? f['value']! : '${f['value']}$unit';
  }

  static String shortSpaced(double amount) {
    final f = format(amount);
    final unit = f['unit']!;
    return unit.isEmpty ? f['value']! : '${f['value']} $unit';
  }

  /// "₹12.45 Cr" — with rupee sign, handles negative
  static String currencyShort(double amount) {
    final neg = amount < 0;
    final f = format(amount);
    final unit = f['unit']!;
    final prefix = neg ? '-₹' : '₹';
    return unit.isEmpty ? '$prefix${f['value']}' : '$prefix${f['value']} $unit';
  }

  /// "12.45 Cr" or "-12.45 Cr" — no rupee sign, handles negative
  static String shortSigned(double amount) {
    final neg = amount < 0;
    final f = format(amount);
    final unit = f['unit']!;
    final prefix = neg ? '-' : '';
    return unit.isEmpty ? '$prefix${f['value']}' : '$prefix${f['value']} $unit';
  }

  /// "₹1,23,456.78" — full Indian format with rupee sign
  static String currencyIndian(double amount) {
    return '₹${formatIndian(amount)}';
  }

  static double unitMultiplier(String unit) {
    switch (unit) {
      case 'Cr': return 10000000;
      case 'L': return 100000;
      case 'K': return 1000;
      default: return 1;
    }
  }

  static String formatIndian(double amount) {
    final isNeg = amount < 0;
    final abs = amount.abs();
    final parts = abs.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    String formatted = '';
    if (intPart.length <= 3) {
      formatted = intPart;
    } else {
      formatted = intPart.substring(intPart.length - 3);
      var remaining = intPart.substring(0, intPart.length - 3);
      while (remaining.length > 2) {
        formatted = '${remaining.substring(remaining.length - 2)},$formatted';
        remaining = remaining.substring(0, remaining.length - 2);
      }
      if (remaining.isNotEmpty) formatted = '$remaining,$formatted';
    }
    return '${isNeg ? '-' : ''}$formatted.$decPart';
  }
}
