import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  // ─────────────────────────── EXPORT ───────────────────────────

  /// Exportuje všechna data do JSON a otevře systémový sdílovací dialog
  /// (uložení na disk, odeslání e-mailem, Google Drive…).
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
      subject: 'DriveData záloha ${now.day}.${now.month}.${now.year}',
    );

    // Po úspěšném sdílení dočasný soubor smaž
    if (result.status == ShareResultStatus.success && file.existsSync()) {
      file.deleteSync();
    }
  }

  // ─────────────────────────── IMPORT ───────────────────────────

  /// Načte zálohu z JSON souboru, smaže stávající DB a obnoví data.
  /// Vrátí popisný řetězec s počty obnovených záznamů.
  Future<String> importBackup(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) throw Exception('Soubor nenalezen: $filePath');

    final Map<String, dynamic> backup =
        jsonDecode(await file.readAsString());

    final version = backup['version'] as int?;
    if (version == null || version != 1) {
      throw Exception('Nepodporovaná nebo chybějící verze zálohy (nalezeno: $version)');
    }

    final db = await DatabaseHelper.instance.database;

    // Smaž + obnov v JEDNÉ transakci — pokud cokoliv selže, DB zůstane nedotčena
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

    return 'Obnoveno: $carCount aut \u2022 $tripCount jízd \u2022 $serviceCount servisů \u2022 $insuranceCount pojistek \u2022 $trailerCount vozíků';
  }
}
