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

  // ─────────────────────────── EXPORT ───────────────────────────

  /// Exports all data to JSON and opens the system share dialog
  /// (save to disk, send by e-mail, upload to Google Drive, etc.).
  Future<void> exportBackup() async {
    final db = await DatabaseHelper.instance.database;

    final backup = <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'cars': await db.query('cars'),
      'trips': await db.query('trips'),
      'service_records': await db.query('service_records'),
      'goals': await db.query('goals'),
      'insurance_policies': await db.query('insurance_policies'),
      'trailers': await db.query('trailers'),
    };

    final json = const JsonEncoder.withIndent('  ').convert(backup);
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
    if (result.status == ShareResultStatus.success && file.existsSync()) {
      file.deleteSync();
    }
  }

  // ─────────────────────────── IMPORT ───────────────────────────

  /// Reads a backup JSON file, wipes the current database and restores data.
  /// Returns a summary string with the counts of restored records.
  Future<String> importBackup(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) throw Exception('File not found: $filePath');

    final Map<String, dynamic> backup =
        jsonDecode(await file.readAsString());

    final version = backup['version'] as int?;
    if (version == null || version != 1) {
      throw Exception('Unsupported or missing backup version (found: $version)');
    }

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
      for (final row in (backup['cars'] as List<dynamic>)) {
        batch.insert('cars', Map<String, dynamic>.from(row as Map),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in (backup['trips'] as List<dynamic>)) {
        batch.insert('trips', Map<String, dynamic>.from(row as Map),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in (backup['service_records'] as List<dynamic>)) {
        batch.insert('service_records', Map<String, dynamic>.from(row as Map),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in (backup['goals'] as List<dynamic>)) {
        batch.insert('goals', Map<String, dynamic>.from(row as Map),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in (backup['insurance_policies'] as List<dynamic>)) {
        batch.insert('insurance_policies', Map<String, dynamic>.from(row as Map),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in ((backup['trailers'] as List<dynamic>?) ?? [])) {
        batch.insert('trailers', Map<String, dynamic>.from(row as Map),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });

    final carCount = (backup['cars'] as List).length;
    final tripCount = (backup['trips'] as List).length;
    final serviceCount = (backup['service_records'] as List).length;
    final insuranceCount = (backup['insurance_policies'] as List).length;
    final trailerCount  = ((backup['trailers'] as List?) ?? []).length;

    return 'Restored: $carCount cars • $tripCount trips • $serviceCount service records • $insuranceCount policies • $trailerCount trailers';
  }
}
