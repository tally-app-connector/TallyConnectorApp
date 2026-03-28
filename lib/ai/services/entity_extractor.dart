/// Entity Extractor Service
/// Extracts dates, amounts, party names, and other entities from user questions.

class EntityExtractor {
  static const Map<String, int> _monthMap = {
    'jan': 1, 'january': 1,
    'feb': 2, 'february': 2,
    'mar': 3, 'march': 3,
    'apr': 4, 'april': 4,
    'may': 5,
    'jun': 6, 'june': 6,
    'jul': 7, 'july': 7,
    'aug': 8, 'august': 8,
    'sep': 9, 'sept': 9, 'september': 9,
    'oct': 10, 'october': 10,
    'nov': 11, 'november': 11,
    'dec': 12, 'december': 12,
  };

  /// Extract entities from user question
  Map<String, dynamic> extract(String question) {
    final entities = <String, dynamic>{};

    final dateRange = _extractDateRange(question);
    if (dateRange != null) entities.addAll(dateRange);

    final amountRange = _extractAmountRange(question);
    if (amountRange != null) entities.addAll(amountRange);

    final partyName = _extractPartyName(question);
    if (partyName != null) entities['party_name'] = partyName;

    final limit = _extractLimit(question);
    if (limit != null) entities['limit'] = limit;

    return entities;
  }

  Map<String, String>? _extractDateRange(String question) {
    final q = question.toLowerCase();
    final today = DateTime.now();

    // Last month
    if (q.contains('last month')) {
      final firstDayLastMonth = DateTime(today.year, today.month - 1, 1);
      final lastDayLastMonth = DateTime(today.year, today.month, 0);
      return {
        'from_date': _formatDate(firstDayLastMonth),
        'to_date': _formatDate(lastDayLastMonth),
      };
    }

    // This month
    if (q.contains('this month')) {
      final firstDay = DateTime(today.year, today.month, 1);
      return {
        'from_date': _formatDate(firstDay),
        'to_date': _formatDate(today),
      };
    }

    // Last week
    if (q.contains('last week')) {
      final startOfLastWeek = today.subtract(Duration(days: today.weekday + 7));
      final endOfLastWeek = startOfLastWeek.add(const Duration(days: 6));
      return {
        'from_date': _formatDate(startOfLastWeek),
        'to_date': _formatDate(endOfLastWeek),
      };
    }

    // This week
    if (q.contains('this week')) {
      final startOfWeek = today.subtract(Duration(days: today.weekday));
      return {
        'from_date': _formatDate(startOfWeek),
        'to_date': _formatDate(today),
      };
    }

    // This quarter
    if (q.contains('this quarter') || q.contains('current quarter')) {
      final quarter = (today.month - 1) ~/ 3;
      final firstMonth = quarter * 3 + 1;
      final firstDay = DateTime(today.year, firstMonth, 1);
      return {
        'from_date': _formatDate(firstDay),
        'to_date': _formatDate(today),
      };
    }

    // Last quarter
    if (q.contains('last quarter')) {
      final currentQuarter = (today.month - 1) ~/ 3;
      final lastQuarter = (currentQuarter - 1) % 4;
      final year = currentQuarter > 0 ? today.year : today.year - 1;
      final firstMonth = lastQuarter * 3 + 1;
      final lastMonth = firstMonth + 2;
      final firstDay = DateTime(year, firstMonth, 1);
      final lastDay = DateTime(year, lastMonth + 1, 0);
      return {
        'from_date': _formatDate(firstDay),
        'to_date': _formatDate(lastDay),
      };
    }

    // This year
    if (q.contains('this year')) {
      final firstDay = DateTime(today.year, 1, 1);
      return {
        'from_date': _formatDate(firstDay),
        'to_date': _formatDate(today),
      };
    }

    // Last year
    if (q.contains('last year')) {
      final firstDay = DateTime(today.year - 1, 1, 1);
      final lastDay = DateTime(today.year - 1, 12, 31);
      return {
        'from_date': _formatDate(firstDay),
        'to_date': _formatDate(lastDay),
      };
    }

    // Today
    if (q.contains('today')) {
      return {
        'from_date': _formatDate(today),
        'to_date': _formatDate(today),
      };
    }

    // Yesterday
    if (q.contains('yesterday')) {
      final yesterday = today.subtract(const Duration(days: 1));
      return {
        'from_date': _formatDate(yesterday),
        'to_date': _formatDate(yesterday),
      };
    }

    // Absolute date range
    final absRange = _extractAbsoluteDateRange(q);
    if (absRange != null) return absRange;

    // Single month + year
    final singleMonth = _extractMonthYear(q);
    if (singleMonth != null) return singleMonth;

    // Default: current financial year (Apr 1 - Mar 31)
    DateTime fyStart;
    DateTime fyEnd;
    if (today.month >= 4) {
      fyStart = DateTime(today.year, 4, 1);
      fyEnd = DateTime(today.year + 1, 3, 31);
    } else {
      fyStart = DateTime(today.year - 1, 4, 1);
      fyEnd = DateTime(today.year, 3, 31);
    }

    return {
      'from_date': _formatDate(fyStart),
      'to_date': _formatDate(today.isBefore(fyEnd) ? today : fyEnd),
    };
  }

  DateTime? _parseDateStr(String text) {
    text = text.trim().toLowerCase().replaceAll(',', '');

    // Pattern: day-month_name-year (e.g., 1-apr-2025, 01 april 2025)
    final m1 = RegExp(r'(\d{1,2})[\s\-/]([a-z]+)[\s\-/](\d{4})').firstMatch(text);
    if (m1 != null) {
      final day = int.parse(m1.group(1)!);
      final month = _monthMap[m1.group(2)!];
      final year = int.parse(m1.group(3)!);
      if (month != null) {
        try { return DateTime(year, month, day); } catch (_) {}
      }
    }

    // Pattern: month_name day year (e.g., april 1 2025)
    final m2 = RegExp(r'([a-z]+)[\s\-/](\d{1,2})[\s\-/,]*(\d{4})').firstMatch(text);
    if (m2 != null) {
      final month = _monthMap[m2.group(1)!];
      final day = int.parse(m2.group(2)!);
      final year = int.parse(m2.group(3)!);
      if (month != null) {
        try { return DateTime(year, month, day); } catch (_) {}
      }
    }

    // Pattern: dd/mm/yyyy or dd-mm-yyyy
    final m3 = RegExp(r'(\d{1,2})[\-/](\d{1,2})[\-/](\d{4})').firstMatch(text);
    if (m3 != null) {
      final day = int.parse(m3.group(1)!);
      final month = int.parse(m3.group(2)!);
      final year = int.parse(m3.group(3)!);
      try { return DateTime(year, month, day); } catch (_) {}
    }

    return null;
  }

  Map<String, String>? _extractAbsoluteDateRange(String question) {
    final monthNames = _monthMap.keys.join('|');
    final pattern = RegExp(
      r'(?:from\s+)?'
      r'(\d{1,2}[\s\-/](?:' + monthNames + r'|[\d]{1,2})[\s\-/]\d{4})'
      r'\s+to\s+'
      r'(\d{1,2}[\s\-/](?:' + monthNames + r'|[\d]{1,2})[\s\-/]\d{4})'
    );

    final m = pattern.firstMatch(question);
    if (m != null) {
      final fromDt = _parseDateStr(m.group(1)!);
      final toDt = _parseDateStr(m.group(2)!);
      if (fromDt != null && toDt != null) {
        return {
          'from_date': _formatDate(fromDt),
          'to_date': _formatDate(toDt),
        };
      }
    }
    return null;
  }

  Map<String, String>? _extractMonthYear(String question) {
    final monthNames = _monthMap.keys.join('|');
    final pattern = RegExp(r'(?:in|for|of|during)?\s*(' + monthNames + r')\s+(\d{4})');

    final m = pattern.firstMatch(question);
    if (m != null) {
      final month = _monthMap[m.group(1)!];
      final year = int.parse(m.group(2)!);
      if (month != null) {
        final firstDay = DateTime(year, month, 1);
        final lastDay = DateTime(year, month + 1, 0);
        return {
          'from_date': _formatDate(firstDay),
          'to_date': _formatDate(lastDay),
        };
      }
    }
    return null;
  }

  Map<String, double>? _extractAmountRange(String question) {
    final q = question.toLowerCase();

    // Above/greater than
    final above = RegExp(r'(?:above|greater than|more than|over)\s+(\d+(?:,\d+)*(?:\.\d+)?)').firstMatch(q);
    if (above != null) {
      return {'amount_min': double.parse(above.group(1)!.replaceAll(',', ''))};
    }

    // Below/less than
    final below = RegExp(r'(?:below|less than|under)\s+(\d+(?:,\d+)*(?:\.\d+)?)').firstMatch(q);
    if (below != null) {
      return {'amount_max': double.parse(below.group(1)!.replaceAll(',', ''))};
    }

    // Between
    final between = RegExp(
      r'between\s+(\d+(?:,\d+)*(?:\.\d+)?)\s+(?:and|to)\s+(\d+(?:,\d+)*(?:\.\d+)?)'
    ).firstMatch(q);
    if (between != null) {
      return {
        'amount_min': double.parse(between.group(1)!.replaceAll(',', '')),
        'amount_max': double.parse(between.group(2)!.replaceAll(',', '')),
      };
    }

    return null;
  }

  String? _extractPartyName(String question) {
    // Salary-specific patterns
    final salaryPatterns = [
      RegExp(r'(?:salary|salaries|wage|wages|payroll)\s+(?:of|for)\s+([A-Z][A-Za-z\s&\.]+?)(?:\s+(?:last|this|in|on|during|from)|$)'),
      RegExp(r'([A-Z][A-Za-z\s&\.]+?)\s+(?:ka|ki|ke)\s+(?:salary|salaries|wage|wages|payroll)'),
      RegExp(r'([A-Z][A-Za-z\s&\.]+?)\s+(?:salary|salaries|wage|wages)\s+(?:detail|details|report|transaction|transactions|paid|payment)'),
    ];

    final falsePositives = {'month', 'year', 'week', 'quarter', 'day', 'total', 'all', 'the'};

    for (final pattern in salaryPatterns) {
      final match = pattern.firstMatch(question);
      if (match != null) {
        final name = match.group(1)!.trim();
        if (!falsePositives.contains(name.toLowerCase())) return name;
      }
    }

    // General patterns
    final generalPatterns = [
      RegExp(r'(?:from|to|for)\s+([A-Z][A-Za-z\s&\.]+?)(?:\s+(?:last|this|in|on|during)|$)'),
      RegExp(r'(?:customer|supplier|party|employee)\s+([A-Z][A-Za-z\s&\.]+?)(?:\s+(?:last|this|in|on|during)|$)'),
    ];

    for (final pattern in generalPatterns) {
      final match = pattern.firstMatch(question);
      if (match != null) {
        final name = match.group(1)!.trim();
        if (!falsePositives.contains(name.toLowerCase())) return name;
      }
    }

    return null;
  }

  int? _extractLimit(String question) {
    final q = question.toLowerCase();
    final patterns = [
      RegExp(r'top\s+(\d+)'),
      RegExp(r'first\s+(\d+)'),
      RegExp(r'last\s+(\d+)'),
      RegExp(r'(\d+)\s+(?:top|best|highest|lowest)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(q);
      if (match != null) return int.parse(match.group(1)!);
    }
    return null;
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
