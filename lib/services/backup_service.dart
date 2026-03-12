import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

/// Singleton service for JSON backup export and import.
///
/// **Export** ([exportBackup]):
/// Queries all 6 database tables, serialises them to an indented JSON file,
/// then opens the system share sheet so the user can save to disk, send by
/// e-mail, upload to Google Drive, etc.  The temporary file is deleted after
/// a successful share.
///
/// **Import** ([importBackup]):
/// Reads the JSON file produced by export, validates the version header,
/// then — inside a single database transaction — truncates all tables and
/// re-inserts every row.  If anything fails the transaction is rolled back
/// and the database is left untouched.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const int backupVersion = 1;
  static const List<String> _requiredTables = [
    'cars',
    'trips',
    'service_records',
    'goals',
    'insurance_policies',
  ];
  static const List<String> _optionalTables = ['trailers'];
  static const List<String> _allTables = [
    ..._requiredTables,
    ..._optionalTables,
  ];

  Future<Map<String, dynamic>> buildBackupPayload() async {
    final db = await DatabaseHelper.instance.database;
    final payload = <String, dynamic>{
      'version': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
    };

    for (final table in _allTables) {
      payload[table] = await db.query(table);
    }

    return payload;
  }

  String encodeBackupPayload(Map<String, dynamic> payload) {
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<String> exportBackupJson() async {
    final payload = await buildBackupPayload();
    return encodeBackupPayload(payload);
  }

  // ─────────────────────────── EXPORT ───────────────────────────

  /// Exports all data to JSON and opens the system share dialog
  /// (save to disk, send by e-mail, upload to Google Drive, etc.).
  Future<void> exportBackup() async {
    final json = await exportBackupJson();
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final stamp = now.millisecondsSinceEpoch;
    final file = File('${dir.path}/drivedata_backup_$stamp.json');
    await file.writeAsString(json);

    final result = await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'DriveData backup ${now.day}.${now.month}.${now.year}',
    );

    // Delete temporary file after successful share
    if (result.status == ShareResultStatus.success && await file.exists()) {
      await file.delete();
    }
  }

  // ─────────────────────────── IMPORT ───────────────────────────

  /// Reads a backup JSON file, wipes the current database and restores data.
  /// Returns a summary string with the counts of restored records.
  Future<String> importBackup(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('File not found: $filePath');

    return importBackupJson(await file.readAsString());
  }

  Future<String> importBackupJson(String jsonString) async {
    final Map<String, dynamic> backup =
        Map<String, dynamic>.from(jsonDecode(jsonString) as Map);

    _validateBackupPayload(backup);

    final db = await DatabaseHelper.instance.database;

    // Wipe + restore in ONE transaction — if anything fails the DB is untouched
    await db.transaction((txn) async {
      await txn.delete('insurance_policies');
      await txn.delete('trailers');
      await txn.delete('goals');
      await txn.delete('service_records');
      await txn.delete('trips');
      await txn.delete('cars');

      final batch = txn.batch();
      for (final table in _allTables) {
        final rows = (backup[table] as List<dynamic>?) ?? const [];
        for (final row in rows) {
          batch.insert(
            table,
            Map<String, dynamic>.from(row as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      await batch.commit(noResult: true);
    });

    final carCount = (backup['cars'] as List).length;
    final tripCount = (backup['trips'] as List).length;
    final serviceCount = (backup['service_records'] as List).length;
    final insuranceCount = (backup['insurance_policies'] as List).length;
    final trailerCount = ((backup['trailers'] as List?) ?? const []).length;

    return 'Restored: $carCount cars • $tripCount trips • $serviceCount service records • $insuranceCount policies • $trailerCount trailers';
  }

  void _validateBackupPayload(Map<String, dynamic> backup) {
    final version = backup['version'] as int?;
    if (version == null || version != backupVersion) {
      throw Exception('Unsupported or missing backup version (found: $version)');
    }

    for (final table in _requiredTables) {
      if (backup[table] is! List<dynamic>) {
        throw Exception('Backup is missing required table: $table');
      }
    }

    for (final table in _optionalTables) {
      final value = backup[table];
      if (value != null && value is! List<dynamic>) {
        throw Exception('Backup has invalid table payload: $table');
      }
    }
  }
}
