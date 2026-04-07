// ============================================
// DATE UTILITY FUNCTIONS
// ============================================

/// Convert DateTime to string format YYYYMMDD
String dateToString(DateTime date) {
  return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
}

/// Convert string YYYYMMDD to DateTime
DateTime stringToDate(String dateStr) {
  final year = int.parse(dateStr.substring(0, 4));
  final month = int.parse(dateStr.substring(4, 6));
  final day = int.parse(dateStr.substring(6, 8));
  return DateTime(year, month, day);
}

/// Get previous day as string (YYYYMMDD) from DateTime
String getPreviousDayString(DateTime date) {
  final previousDate = date.subtract(const Duration(days: 1));
  return dateToString(previousDate);
}

/// Get previous day as string (YYYYMMDD) from string (YYYYMMDD)
String getPreviousDate(String dateStr) {
  final date = stringToDate(dateStr);
  return getPreviousDayString(date);
}

/// Get next day as string (YYYYMMDD) from DateTime
String getNextDayString(DateTime date) {
  final nextDate = date.add(const Duration(days: 1));
  return dateToString(nextDate);
}

/// Get next day as string (YYYYMMDD) from string (YYYYMMDD)
String getNextDate(String dateStr) {
  final date = stringToDate(dateStr);
  return getNextDayString(date);
}

// ============================================
// FINANCIAL YEAR UTILITY FUNCTIONS
// ============================================

const int fyStartMonth = 4;  // April
const int fyStartDay = 1;

/// Get financial year start date from DateTime
/// FY starts on April 1st
/// Example: 15-Jan-2024 → 01-Apr-2023
/// Example: 15-May-2024 → 01-Apr-2024
DateTime getFyStartDate(DateTime date) {
  if (date.month < fyStartMonth) {
    // Before April, FY started previous year
    return DateTime(date.year - 1, fyStartMonth, fyStartDay);
  } else {
    // April onwards, FY started this year
    return DateTime(date.year, fyStartMonth, fyStartDay);
  }
}

/// Get financial year end date from DateTime
/// FY ends on March 31st
/// Example: 15-Jan-2024 → 31-Mar-2024
/// Example: 15-May-2024 → 31-Mar-2025
DateTime getFyEndDate(DateTime date) {
  if (date.month < fyStartMonth) {
    // Before April, FY ends this year
    return DateTime(date.year, 3, 31);
  } else {
    // April onwards, FY ends next year
    return DateTime(date.year + 1, 3, 31);
  }
}

/// Get financial year start date as string (YYYYMMDD) from DateTime
String getFyStartDateString(DateTime date) {
  return dateToString(getFyStartDate(date));
}

/// Get financial year end date as string (YYYYMMDD) from DateTime
String getFyEndDateString(DateTime date) {
  return dateToString(getFyEndDate(date));
}

/// Get financial year start date as string from string (YYYYMMDD)
String getFyStartFromString(String dateStr) {
  final date = stringToDate(dateStr);
  return getFyStartDateString(date);
}

/// Get financial year end date as string from string (YYYYMMDD)
String getFyEndFromString(String dateStr) {
  final date = stringToDate(dateStr);
  return getFyEndDateString(date);
}

/// Get current financial year start date
String getCurrentFyStartDate() {
  return getFyStartDateString(DateTime.now());
}

/// Get current financial year end date
String getCurrentFyEndDate() {
  return getFyEndDateString(DateTime.now());
}

/// Get financial year label (e.g., "2024-25")
String getFyLabel(DateTime date) {
  final fyStart = getFyStartDate(date);
  final startYear = fyStart.year;
  final endYear = startYear + 1;
  return '$startYear-${endYear.toString().substring(2)}';
}

/// Get current financial year label
String getCurrentFyLabel() {
  return getFyLabel(DateTime.now());
}

// ============================================
// ADAPTIVE FY HELPERS (early-year fallback)
// ============================================

/// True when we're in April or May — new FY has barely started,
/// so queries should default to previous FY for meaningful data.
bool isEarlyInFy([DateTime? date]) {
  final d = date ?? DateTime.now();
  return d.month == 4 || d.month == 5;
}

/// Previous financial year start date (e.g. 01-Apr-2025 when current FY is 2026-27)
DateTime getPrevFyStartDate([DateTime? date]) {
  final currentFyStart = getFyStartDate(date ?? DateTime.now());
  return DateTime(currentFyStart.year - 1, fyStartMonth, fyStartDay);
}

/// Previous financial year end date (e.g. 31-Mar-2026 when current FY is 2026-27)
DateTime getPrevFyEndDate([DateTime? date]) {
  final currentFyStart = getFyStartDate(date ?? DateTime.now());
  return DateTime(currentFyStart.year, 3, 31);
}

/// Previous FY label (e.g. "2025-26")
String getPrevFyLabel([DateTime? date]) {
  return getFyLabel(getPrevFyStartDate(date));
}