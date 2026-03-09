import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../models/service_record.dart';
import '../../providers/car_provider.dart';
import '../../providers/service_provider.dart';
import '../../services/notification_service.dart';
import '../../utils/constants.dart';

/// Form screen for creating or editing a [ServiceRecord].
///
/// Collects service type, car, date, odometer, cost, provider, next-due date,
/// next-due odometer, note, and an optional attachment (photo or PDF).
/// Pass [record] to open in edit mode.
///
/// Notable logic:
/// - [_applySmartNextDue] automatically suggests the next service date based
///   on the selected service type when the user hasn't entered one manually.
/// - Unsaved attachments are cleaned up in [dispose] to avoid orphaned files.
class AddEditServiceScreen extends StatefulWidget {
  /// The service record to edit, or `null` to create a new one.
  final ServiceRecord? record;
  const AddEditServiceScreen({super.key, this.record});

  @override
  State<AddEditServiceScreen> createState() => _AddEditServiceScreenState();
}

/// State for [AddEditServiceScreen].
class _AddEditServiceScreenState extends State<AddEditServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _carId;
  late DateTime _date;
  late String _serviceType;
  final _odometerCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _providerCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _nextOdometerCtrl = TextEditingController();
  DateTime? _nextDueDate;
  String? _attachmentPath;
  String? _originalAttachmentPath;

  /// `true` when editing an existing service record.
  bool get isEditing => widget.record != null;

  /// Auto-fills nextDueDate based on the selected service type and record date.
  /// Called when the type or date changes — only when the user has not already
  /// entered a date manually.
  void _applySmartNextDue({bool force = false}) {
    if (!force && _nextDueDate != null) return;
    final months = AppConstants.serviceNextDueMonths[_serviceType];
    if (months == null) {
      if (force) setState(() => _nextDueDate = null);
      return;
    }
    final proposed = DateTime(_date.year, _date.month + months, _date.day);
    setState(() => _nextDueDate = proposed);
  }

  /// Populates all form fields from [widget.record] when editing.
  /// For new records, immediately calls [_applySmartNextDue] to pre-fill
  /// the next-due date.
  @override
  void initState() {
    super.initState();
    final r = widget.record;
    final carProvider = context.read<CarProvider>();
    _carId = r?.carId ?? carProvider.cars.firstOrNull?.id ?? '';
    _date = r?.date ?? DateTime.now();
    _serviceType = r?.serviceType ?? AppConstants.serviceTypes.first;
    _odometerCtrl.text = r?.odometer.toString() ?? '';
    _costCtrl.text = r?.cost.toString() ?? '';
    _providerCtrl.text = r?.provider ?? '';
    _noteCtrl.text = r?.note ?? '';
    _nextOdometerCtrl.text = r?.nextDueOdometer?.toStringAsFixed(0) ?? '';
    _nextDueDate = r?.nextDueDate;
    _attachmentPath = r?.attachmentPath;
    _originalAttachmentPath = r?.attachmentPath;
    // For new records, auto-suggest next due date
    if (!isEditing) _applySmartNextDue(force: true);
  }

  @override
  void dispose() {
    _odometerCtrl.dispose();
    _costCtrl.dispose();
    _providerCtrl.dispose();
    _noteCtrl.dispose();
    _nextOdometerCtrl.dispose();
    // Delete temp attachment if the user never saved the record
    if (_attachmentPath != null && _attachmentPath != _originalAttachmentPath) {
      final f = File(_attachmentPath!);
      if (f.existsSync()) f.deleteSync();
    }
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Vyfotit'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Vybrat ze souborů / galerie'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    String? sourcePath;
    String? fileName;

    if (choice == 'camera') {
      final xfile = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (xfile == null) return;
      sourcePath = xfile.path;
      fileName = xfile.name;
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result == null || result.files.single.path == null) return;
      sourcePath = result.files.single.path!;
      fileName = result.files.single.name;
    }

    final baseName = fileName.split(RegExp(r'[\\/]')).last;
    final safeName = baseName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final ext = safeName.split('.').last.toLowerCase();
    if (!['pdf', 'jpg', 'jpeg', 'png'].contains(ext)) return;

    final dir = await getApplicationDocumentsDirectory();
    final attachDir = Directory('${dir.path}/service_attachments');
    if (!attachDir.existsSync()) attachDir.createSync(recursive: true);
    if (_attachmentPath != null && _attachmentPath != _originalAttachmentPath) {
      final old = File(_attachmentPath!);
      if (old.existsSync()) old.deleteSync();
    }
    final destPath = '${attachDir.path}/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await File(sourcePath).copy(destPath);
    if (mounted) setState(() => _attachmentPath = destPath);
  }

  void _removeAttachment() {
    if (_attachmentPath != null && _attachmentPath != _originalAttachmentPath) {
      final f = File(_attachmentPath!);
      if (f.existsSync()) f.deleteSync();
    }
    setState(() => _attachmentPath = null);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final serviceProvider = context.read<ServiceProvider>();
    final carName = context.read<CarProvider>().getCarById(_carId)?.fullName ?? 'auto';
    ServiceRecord savedRecord;
    if (isEditing) {
      savedRecord = widget.record!.copyWith(
        carId: _carId,
        date: _date,
        serviceType: _serviceType,
        odometer: double.parse(_odometerCtrl.text),
        cost: double.parse(_costCtrl.text),
        provider:
            _providerCtrl.text.trim().isEmpty ? null : _providerCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        nextDueDate: _nextDueDate,
        nextDueOdometer: double.tryParse(_nextOdometerCtrl.text),
        attachmentPath: _attachmentPath,
      );
      await serviceProvider.updateRecord(savedRecord);
    } else {
      savedRecord = await serviceProvider.addRecord(
        carId: _carId,
        date: _date,
        serviceType: _serviceType,
        odometer: double.parse(_odometerCtrl.text),
        cost: double.parse(_costCtrl.text),
        provider:
            _providerCtrl.text.trim().isEmpty ? null : _providerCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        nextDueDate: _nextDueDate,
        nextDueOdometer: double.tryParse(_nextOdometerCtrl.text),
        attachmentPath: _attachmentPath,
      );
    }
    await NotificationService.instance.scheduleServiceReminder(savedRecord, carName);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cars = context.watch<CarProvider>().cars;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Upravit záznam' : 'Přidat servisní záznam'),
        actions: [TextButton(onPressed: _save, child: const Text('Uložit'))],
      ),
      body: Form(
        key: _formKey,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _carId.isEmpty ? null : _carId,
              decoration: const InputDecoration(labelText: 'Auto'),
              items: cars
                  .map((c) =>
                      DropdownMenuItem(value: c.id, child: Text(c.fullName)))
                  .toList(),
              onChanged: (v) => setState(() => _carId = v!),
              validator: (v) => v == null ? 'Vyber auto' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _serviceType,
              decoration: const InputDecoration(labelText: 'Typ servisu'),
              items: AppConstants.serviceTypes
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                            '${AppConstants.serviceTypeIcons[t]} ${AppConstants.serviceTypeLabels[t]}'),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() => _serviceType = v!);
                _applySmartNextDue(force: true);
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(
                  'Datum: ${_date.day}. ${_date.month}. ${_date.year}'),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _date = picked);
                  _applySmartNextDue(force: true);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _odometerCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Tachometr (km)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) =>
                        double.tryParse(v ?? '') == null ? 'Povinné' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _costCtrl,
                    decoration: const InputDecoration(labelText: 'Cena (Kč)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) =>
                        double.tryParse(v ?? '') == null ? 'Povinné' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _providerCtrl,
              decoration: const InputDecoration(
                  labelText: 'Autoservis / kde',
                  hintText: 'Škoda Servis Praha, doma...'),
              textCapitalization: TextCapitalization.words,
              maxLength: 100,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              decoration:
                  const InputDecoration(labelText: 'Poznámka', hintText: ''),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 24),            // --- ATTACHMENT ---
            Text('Příloha (faktura, fotka)',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8),
            if (_attachmentPath == null)
              OutlinedButton.icon(
                onPressed: _pickAttachment,
                icon: const Icon(Icons.attach_file),
                label: const Text('Přidat přílohu (PDF / foto)'),
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _attachmentPath!.toLowerCase().endsWith('.pdf')
                      ? Icons.picture_as_pdf
                      : Icons.image_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  _attachmentPath!.split(RegExp(r'[\\/]')).last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: const Text('Klepni pro otevření'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Odebrat přílohu',
                  onPressed: _removeAttachment,
                ),
                onTap: () => OpenFilex.open(_attachmentPath!),
              ),
            const SizedBox(height: 24),            // --- NEXT SERVICE ---
            Text('Příští servis (upozornění)',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 4),
            Builder(builder: (context) {
              final days = AppConstants.serviceReminderDays[_serviceType] ?? 30;
              final km = AppConstants.serviceReminderKm[_serviceType];
              final months = AppConstants.serviceNextDueMonths[_serviceType];
              final parts = <String>[
                if (months != null) 'Navrhováno za $months měsíce',
                'Upozornění $days dní předem',
                if (km != null) '/ ${km.toStringAsFixed(0)} km předem',
              ];
              return Text(
                parts.join(' • '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              );
            }),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.event_available,
                color: _nextDueDate != null
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(_nextDueDate == null
                  ? 'Datum příštího servisu (volitelné)'
                  : 'Příští servis: ${_nextDueDate!.day}. ${_nextDueDate!.month}. ${_nextDueDate!.year}'),
              trailing: _nextDueDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _nextDueDate = null),
                    )
                  : null,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _nextDueDate ?? DateTime.now().add(const Duration(days: 365)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                );
                if (picked != null) setState(() => _nextDueDate = picked);
              },
            ),
            TextFormField(
              controller: _nextOdometerCtrl,
              decoration: const InputDecoration(
                labelText: 'Příští servis při km (volitelné)',
                hintText: 'např. 250000',
                prefixIcon: Icon(Icons.speed),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                return double.tryParse(v) == null ? 'Neplatná hodnota' : null;
              },
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child: Text(isEditing ? 'Uložit změny' : 'Přidat záznam'),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}
