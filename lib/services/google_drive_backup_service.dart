import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import 'backup_service.dart';

/// Singleton service that backs up and restores the DriveData database via
/// the user's Google Drive (appDataFolder — hidden, app-private storage).
///
/// **Setup required (one-time, Google Cloud Console):**
/// 1. Create a project and enable the **Google Drive API**.
/// 2. Create an **OAuth 2.0 Client ID → Android** type.
///    - Package name: `com.drivedata.drivedata`
///    - SHA-1: run `keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore
///              -alias androiddebugkey -storepass android -keypass android`
/// 3. No `google-services.json` needed — the credentials are tied to the
///    package name + SHA-1 automatically via Play Services.
///
/// **Usage:**
/// ```dart
/// await GoogleDriveBackupService.instance.signIn();
/// await GoogleDriveBackupService.instance.backupToDrive();
/// final message = await GoogleDriveBackupService.instance.restoreFromDrive();
/// ```
class GoogleDriveBackupService {
  GoogleDriveBackupService._();
  static final GoogleDriveBackupService instance = GoogleDriveBackupService._();

  /// File name used on Drive (inside appDataFolder).
  static const _fileName = 'drivedata_backup.json';

  /// SharedPreferences key that stores the last successful backup timestamp.
  static const _prefKey = 'lastDriveBackupAt';

  /// Drive scope — appDataFolder is invisible to the user in Drive UI and is
  /// deleted automatically when the app is uninstalled.
  static const _driveScope = 'https://www.googleapis.com/auth/drive.appdata';

  final _googleSignIn = GoogleSignIn(scopes: [_driveScope]);

  // ──────────────────────────── AUTH ────────────────────────────

  /// Current signed-in account, or `null` if not signed in.
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// Attempts a silent (non-interactive) sign-in first; falls back to the
  /// interactive sign-in sheet if no previous session exists.
  /// Returns the signed-in account, or `null` if the user cancelled.
  Future<GoogleSignInAccount?> signIn() async {
    final silent = await _googleSignIn.signInSilently();
    if (silent != null) return silent;
    return _googleSignIn.signIn();
  }

  /// Tries to restore a previous sign-in without showing any UI.
  /// Call this during app startup / settings screen init.
  Future<GoogleSignInAccount?> signInSilently() =>
      _googleSignIn.signInSilently();

  /// Signs out of Google.
  Future<void> signOut() => _googleSignIn.signOut();

  // ─────────────────────── TIMESTAMP ────────────────────────────

  /// Returns the last time any data was changed locally (written by [DatabaseHelper]).
  /// Returns `null` if no data has ever been written.
  Future<DateTime?> getLastDataChangeTime() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('lastDataChangeAt');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Returns the last time a backup was successfully pushed from this device,
  /// read from local [SharedPreferences].  Returns `null` if never backed up.
  Future<DateTime?> getLastLocalBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _saveBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, DateTime.now().toIso8601String());
  }

  // ───────────────────────── INTERNAL ───────────────────────────

  /// Returns an authenticated [drive.DriveApi], triggering sign-in if needed.
  Future<drive.DriveApi> _getApi() async {
    final account = await signIn();
    if (account == null) throw Exception('Přihlášení bylo zrušeno.');
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) throw Exception('Nepodařilo se získat auth token.');
    return drive.DriveApi(httpClient);
  }

  // ───────────────────────── BACKUP ─────────────────────────────

  /// Exports all data to JSON and uploads it to Drive (appDataFolder).
  /// If a previous backup exists it is overwritten in-place.
  ///
  /// Throws on auth failure or Drive API error.
  Future<void> backupToDrive() async {
    final api = await _getApi();
    final jsonStr = await BackupService.instance.exportBackupJson();
    final bytes = utf8.encode(jsonStr);

    // Check for an existing backup file so we can update it (keeps 1 copy).
    final existing = await api.files.list(
      spaces: 'appDataFolder',
      $fields: 'files(id,name)',
      q: "name='$_fileName'",
    );

    final metadata = drive.File()..name = _fileName;
    final media = drive.Media(
      Stream.fromIterable([bytes]),
      bytes.length,
      contentType: 'application/json',
    );

    if (existing.files?.isNotEmpty == true) {
      // Update (PATCH) the existing file — only content changes.
      await api.files.update(
        metadata,
        existing.files!.first.id!,
        uploadMedia: media,
      );
    } else {
      // Create new file in the hidden appDataFolder.
      metadata.parents = ['appDataFolder'];
      await api.files.create(metadata, uploadMedia: media);
    }
    // Record successful backup time locally.
    await _saveBackupTime();
  }

  // ──────────────────────────── RESTORE ─────────────────────────

  /// Downloads the latest backup from Drive and restores it into the local
  /// database.  Returns a human-readable summary string on success.
  ///
  /// Throws if no backup is found or on any Drive / DB error.
  Future<String> restoreFromDrive() async {
    final api = await _getApi();

    final list = await api.files.list(
      spaces: 'appDataFolder',
      $fields: 'files(id,name,modifiedTime)',
      q: "name='$_fileName'",
    );

    if (list.files == null || list.files!.isEmpty) {
      throw Exception(
          'Na Google Drive nebyla nalezena žádná záloha pro tento účet.');
    }

    final fileId = list.files!.first.id!;
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    // Collect all chunks from the stream.
    final chunks = <int>[];
    await for (final chunk in media.stream) {
      chunks.addAll(chunk);
    }
    final jsonStr = utf8.decode(chunks);

    return BackupService.instance.importBackupJson(jsonStr);
  }

  /// Returns the `modifiedTime` of the backup on Drive, or `null` if no
  /// backup exists yet.  Use this to display "Last backup: …" in the UI.
  Future<DateTime?> lastBackupTime() async {
    try {
      final api = await _getApi();
      final list = await api.files.list(
        spaces: 'appDataFolder',
        $fields: 'files(modifiedTime)',
        q: "name='$_fileName'",
      );
      final t = list.files?.firstOrNull?.modifiedTime;
      return t;
    } catch (_) {
      return null;
    }
  }
}
