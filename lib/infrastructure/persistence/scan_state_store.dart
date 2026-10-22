import 'dart:convert';

import '../../application/libraries/scan_state.dart';
import 'database.dart';

/// Each library's existing settings table owns its scan hints and exclusions.
class SqlScanStateStore implements ScanStateStore {
  SqlScanStateStore(this.database);
  static const key = 'library_scan';
  final QuizDatabase database;

  static Map<String, ScanRecord> decode(String value) =>
      (jsonDecode(value) as Map<String, dynamic>).map(
        (origin, record) => MapEntry(
          origin,
          ScanRecord.fromJson(record as Map<String, dynamic>),
        ),
      );

  static String encode(Map<String, ScanRecord> records) => jsonEncode(
    records.map((origin, record) => MapEntry(origin, record.toJson())),
  );

  @override
  Future<Map<String, ScanRecord>> load() async {
    final row = await database
        .customSelect("SELECT value FROM settings WHERE key='$key'")
        .getSingleOrNull();
    return row == null ? {} : decode(row.read<String>('value'));
  }

  @override
  Future<void> save(Map<String, ScanRecord> records) =>
      database.customStatement(
        "INSERT OR REPLACE INTO settings VALUES ('$key', ?)",
        [encode(records)],
      );
}
