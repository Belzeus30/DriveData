import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/car_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/insurance_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/trailer_provider.dart';
import '../../providers/trip_provider.dart';
import '../../services/backup_service.dart';
import '../../services/google_drive_backup_service.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Settings screen.
///
/// Provides three sections:
/// 1. **Data backup** — export/import a JSON backup via [BackupService].
/// 2. **Appearance** — light/dark/system theme toggle and seed colour picker
///    via [ThemeProvider].
/// 3. **About** — app name, version, and description.
///
/// Import triggers a confirmation dialog (all current data is overwritten) and
/// reloads all providers after a successful restore.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// State for [SettingsScreen].
///
/// Tracks loading states for export and import operations so buttons can
/// show a progress indicator while an async operation is in progress.
class _SettingsScreenState extends State<SettingsScreen> {
  /// `true` while [BackupService.exportBackup] is running.
  bool _exportLoading = false;
  /// `true` while [BackupService.importBackup] is running.
  bool _importLoading = false;

  // ─── Google Drive ───
  GoogleSignInAccount? _driveUser;
  DateTime? _lastDriveBackup;
  bool _driveBackupLoading = false;
  bool _driveRestoreLoading = false;

  @override
  void initState() {
    super.initState();
    _initDrive();
  }

  Future<void> _initDrive() async {
    final svc = GoogleDriveBackupService.instance;
    final account = await svc.signInSilently();
    final last = await svc.getLastLocalBackupTime();
    if (mounted) setState(() { _driveUser = account; _lastDriveBackup = last; });
  }

  /// Runs [BackupService.exportBackup] and shows error feedback on failure.
  Future<void> _export() async {
    setState(() => _exportLoading = true);
    try {
      await BackupService.instance.exportBackup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export selhal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exportLoading = false);
    }
  }

  /// Opens a JSON file picker, shows a destructive-action confirmation,
  /// calls [BackupService.importBackup], reloads all providers, and
  /// shows a success / error [SnackBar].
  Future<void> _import() async {
    // File picker
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;

    if (!mounted) return;
    // Confirmation dialog — will overwrite ALL existing data
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Obnovit zálohu?'),
        content: const Text(
          'Tato akce SMAŽE všechna aktuální data (jízdy, auta, servis, pojistky) '
          'a nahradí je daty ze zálohy.\n\nFotky a PDF přílohy NEJSOU součástí zálohy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Zrušit'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obnovit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _importLoading = true);
    try {
      final message = await BackupService.instance.importBackup(path);

      // Reload all providers after import
      if (mounted) {
        await Future.wait([
          context.read<CarProvider>().loadCars(),
          context.read<TripProvider>().loadTrips(),
          context.read<ServiceProvider>().loadRecords(),
          context.read<GoalProvider>().loadGoals(),
          context.read<InsuranceProvider>().loadPolicies(),
          context.read<TrailerProvider>().loadTrailers(),
        ]);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import selhal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _importLoading = false);
    }
  }

  // ─── Google Drive methods ───

  Future<void> _driveSignIn() async {
    final account = await GoogleDriveBackupService.instance.signIn();
    if (mounted) setState(() => _driveUser = account);
  }

  Future<void> _driveSignOut() async {
    await GoogleDriveBackupService.instance.signOut();
    if (mounted) setState(() { _driveUser = null; });
  }

  Future<void> _backupToDrive() async {
    setState(() => _driveBackupLoading = true);
    try {
      await GoogleDriveBackupService.instance.backupToDrive();
      final last = await GoogleDriveBackupService.instance.getLastLocalBackupTime();
      if (mounted) {
        setState(() => _lastDriveBackup = last);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Záloha na Google Drive proběhla ✓'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Zaloha selhala: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _driveBackupLoading = false);
    }
  }

  Future<void> _restoreFromDrive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Obnovit ze zalohy?'),
        content: const Text(
          'Tato akce SMAZE vsechna aktualni data a nahradi je posledni zalohou z Google Drive.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Zrusit')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obnovit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _driveRestoreLoading = true);
    try {
      final message = await GoogleDriveBackupService.instance.restoreFromDrive();
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        await Future.wait([
          context.read<CarProvider>().loadCars(),
          context.read<TripProvider>().loadTrips(),
          context.read<ServiceProvider>().loadRecords(),
          context.read<GoalProvider>().loadGoals(),
          context.read<InsuranceProvider>().loadPolicies(),
          context.read<TrailerProvider>().loadTrailers(),
        ]);
        messenger.showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Obnova selhala: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _driveRestoreLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nastavení'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader('Záloha dat'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Export a import', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Záloha obsahuje všechna auta, jízdy, servisní záznamy a pojistky. '
                    'Fotky a přílohy (PDF) zálohovány nejsou.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _exportLoading ? null : _export,
                          icon: _exportLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_outlined),
                          label: const Text('Exportovat zálohu'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _importLoading ? null : _import,
                          icon: _importLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download_outlined),
                          label: const Text('Obnovit zálohu'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error,
                            side: BorderSide(
                                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ─── Google Drive záloha ───
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text('Google Drive', style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Automatická záloha dat do vašeho Google Drive (skrytá složka appdata viditelná pouze pro tuto aplikaci).',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  if (_driveUser == null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _driveSignIn,
                        icon: const Icon(Icons.login),
                        label: const Text('Přihlásit se přes Google'),
                      ),
                    ),
                  ] else ...[
                    // Signed-in user info
                    Row(
                      children: [
                        if (_driveUser!.photoUrl != null)
                          CircleAvatar(
                            radius: 14,
                            backgroundImage: NetworkImage(_driveUser!.photoUrl!),
                          )
                        else
                          const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _driveUser!.email,
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: _driveSignOut,
                          style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error),
                          child: const Text('Odhlásit'),
                        ),
                      ],
                    ),
                    if (_lastDriveBackup != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Poslední záloha: ${_lastDriveBackup!.day}.${_lastDriveBackup!.month}.${_lastDriveBackup!.year} '
                        '${_lastDriveBackup!.hour.toString().padLeft(2, '0')}:${_lastDriveBackup!.minute.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _driveBackupLoading ? null : _backupToDrive,
                            icon: _driveBackupLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.cloud_upload_outlined),
                            label: const Text('Zálohovat'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _driveRestoreLoading ? null : _restoreFromDrive,
                            icon: _driveRestoreLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.cloud_download_outlined),
                            label: const Text('Obnovit'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error,
                              side: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .error
                                      .withValues(alpha: 0.5)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          const _SectionHeader('Vzhled'),
          const SizedBox(height: 8),

          // Dark / light theme toggle
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Téma aplikace',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto),
                        label: Text('Systém'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode),
                        label: Text('Světlé'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode),
                        label: Text('Tmavé'),
                      ),
                    ],
                    selected: {themeProvider.themeMode},
                    onSelectionChanged: (modes) =>
                        themeProvider.setThemeMode(modes.first),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Colour picker
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Barva aplikace',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(
                        ThemeProvider.availableColors.length, (i) {
                      final color = ThemeProvider.availableColors[i];
                      final name = ThemeProvider.colorNames[i];
                      final selected = themeProvider.seedColor == color;
                      return GestureDetector(
                        onTap: () => themeProvider.setSeedColor(color),
                        child: Tooltip(
                          message: name,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                          color: color.withValues(alpha: 0.6),
                                          blurRadius: 8)
                                    ]
                                  : [],
                            ),
                            child: selected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 20)
                                : null,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          const _SectionHeader('O aplikaci'),
          const SizedBox(height: 8),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('DriveData'),
                  subtitle: Text('Verze 1.0.0'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.directions_car),
                  title: Text('Aplikace pro sledování jízd'),
                  subtitle: Text(
                      'Zaznamenávej jízdy, sleduj spotřebu a zlepšuj se.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Styled section-header label inside the settings list.
///
/// Renders [text] in the theme's primary colour using `labelLarge` style.
class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary));
  }
}
