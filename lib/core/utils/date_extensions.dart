import 'package:intl/intl.dart';

extension DateExtensions on DateTime {
  /// Formats as "MMM dd, yyyy" e.g., "Jun 15, 2026"
  String toDisplayFormat() {
    return DateFormat('MMM dd, yyyy').format(this);
  }

  /// Formats as strict ISO-8601 date string (no time) e.g., "2026-06-15"
  String toIsoDate() {
    return DateFormat('yyyy-MM-dd').format(this);
  }
}