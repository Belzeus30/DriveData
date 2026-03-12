import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../models/insurance_policy.dart';
import '../../providers/car_provider.dart';
import '../../providers/insurance_provider.dart';
import '../../services/notification_service.dart';
import '../../utils/constants.dart';
import '../../widgets/vehicle_filter_widgets.dart';
import 'travel_insurance_info_screen.dart';

/// Form screen for creating or editing an [InsurancePolicy].
///
/// Supports all policy types defined in [AppConstants.insuranceTypes].
/// When [isTravel] is `true`, an additional section exposes travel-specific
/// coverage checkboxes (medical, luggage, delay, liability, cancellation,
/// sports) and a medical-limit field.
///
/// Pass [policy] to open in edit mode.
///
/// Notable logic:
/// - [_attachmentPath] tracks the copied file path; unsaved picks that differ
///   from [_originalAttachmentPath] are deleted in [dispose].
/// - The [_saved] flag prevents file cleanup when the record was committed.
class AddEditInsuranceScreen extends StatefulWidget {
  /// The policy to edit, or `null` to create a new one.
  final InsurancePolicy? policy;
  const AddEditInsuranceScreen({super.key, this.policy});

  @override
  State<AddEditInsuranceScreen> createState() => _AddEditInsuranceScreenState();
}

/// State for [AddEditInsuranceScreen].
///
/// Manages form controllers, date pickers, coverage booleans, and attachment
/// file path.
class _AddEditInsuranceScreenState extends State<AddEditInsuranceScreen> {
  static final _dateFmt = DateFormat('d. M. yyyy');

  final _formKey = GlobalKey<FormState>();

  late String _type;
  String? _carId;
  final _providerCtrl = TextEditingController();
  final _policyNumberCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _medicalLimitCtrl = TextEditingController();

  String? _attachmentPath;
  String? _originalAttachmentPath; // path from DB at form-open time; never mutated
  bool _isSaving = false;
  bool _saved = false; // true only after a successful save

  DateTime? _validFrom;
  late DateTime _validTo;

  bool _coversMedical = false;
  bool _coversLuggage = false;
  bool _coversDelay = false;
  bool _coversLiability = false;
  bool _coversCancellation = false;
  bool _coversSports = false;

  /// `true` when editing an existing policy.
  bool get isEditing => widget.policy != null;
  /// `true` when the selected policy type is travel insurance.
  bool get isTravel => _type == 'travel';

  /// Populates all form controllers and boolean flags from [widget.policy].
  /// Defaults [_validTo] to one year from today when creating a new policy.
  @override
  void initState() {
    super.initState();
    final pol = widget.policy;
    _type = pol?.type ?? AppConstants.insuranceTypes.first;
    _carId = pol?.carId;
    _providerCtrl.text = pol?.provider ?? '';
    _policyNumberCtrl.text = pol?.policyNumber ?? '';
    _costCtrl.text = pol?.costPerYear?.toStringAsFixed(0) ?? '';
    _phoneCtrl.text = pol?.phone ?? '';
    _noteCtrl.text = pol?.notes ?? '';
    _medicalLimitCtrl.text = pol?.medicalLimitEur?.toStringAsFixed(0) ?? '';
    _validFrom = pol?.validFrom;
    final now = DateTime.now();
    _validTo = pol?.validTo ??
        DateTime(now.year + 1, now.month, now.day);
    _coversMedical = pol?.coversMedical ?? false;
    _coversLuggage = pol?.coversLuggage ?? false;
    _coversDelay = pol?.coversDelay ?? false;
    _coversLiability = pol?.coversLiability ?? false;
    _coversCancellation = pol?.coversCancellation ?? false;
    _coversSports = pol?.coversSports ?? false;
    _attachmentPath = pol?.attachmentPath;
    _originalAttachmentPath = pol?.attachmentPath;
  }

  /// Disposes all controllers and removes any orphaned attachment copy
  /// that was picked but not saved.
  @override
  void dispose() {
    // If the form was closed without saving and the user picked a NEW attachment
    // (different from what was in DB), clean up the orphaned copied file.
    if (!_saved &&
        _attachmentPath != null &&
        _attachmentPath != _originalAttachmentPath) {
      final f = File(_attachmentPath!);
      if (f.existsSync()) f.deleteSync();
    }
    _providerCtrl.dispose();
    _policyNumberCtrl.dispose();
    _costCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    _medicalLimitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final policy = InsurancePolicy(
        id: widget.policy?.id ?? '',
        carId: isTravel ? null : _carId,
        type: _type,
        provider: _providerCtrl.text.trim(),
        policyNumber: _policyNumberCtrl.text.trim().isEmpty
            ? null
            : _policyNumberCtrl.text.trim(),
        validFrom: _validFrom,
        validTo: _validTo,
        costPerYear: double.tryParse(_costCtrl.text.replaceAll(' ', '')),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        notes: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        coversMedical: _coversMedical,
        coversLuggage: _coversLuggage,
        coversDelay: _coversDelay,
        coversLiability: _coversLiability,
        coversCancellation: _coversCancellation,
        coversSports: _coversSports,
        medicalLimitEur: double.tryParse(_medicalLimitCtrl.text),
        attachmentPath: _attachmentPath,
      );

      final insuranceProvider = context.read<InsuranceProvider>();
      final carName = policy.carId != null
          ? (context.read<CarProvider>().getCarById(policy.carId!)?.fullName ?? 'vozidlo')
          : 'osobní';

      InsurancePolicy savedPolicy;
      if (isEditing) {
        // Delete the original file only after successful DB update
        if (_originalAttachmentPath != null &&
            _originalAttachmentPath != _attachmentPath) {
          final old = File(_originalAttachmentPath!);
          if (old.existsSync()) old.deleteSync();
        }
        await insuranceProvider.updatePolicy(policy);
        savedPolicy = policy;
      } else {
        savedPolicy = await insuranceProvider.addPolicy(policy);
      }
      await NotificationService.instance.scheduleInsuranceReminder(savedPolicy, carName);

      _saved = true;
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba při ukládání: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Upravit pojistku' : 'Nová pojistka / doklad'),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // 1. TYP
            _SectionCard(
              title: 'Typ pojistky',
              child: _TypeChips(
                selected: _type,
                onSelected: (t) => setState(() {
                  _type = t;
                  if (t == 'travel') _carId = null;
                }),
              ),
            ),

            // 2. BASIC INFO
            _SectionCard(
              title: 'Základní informace',
              child: Column(
                children: [
                  TextFormField(
                    controller: _providerCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Pojišťovna / poskytovatel *',
                      hintText: 'Allianz, Kooperativa, ERV...',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Povinné pole' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _policyNumberCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Číslo smlouvy',
                      hintText: 'POL-2025-123456',
                      prefixIcon: Icon(Icons.tag_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!isTravel) ...[
                    VehicleDropdownField(
                      vehicles: context.watch<CarProvider>().cars,
                      value: _carId,
                      labelText: 'Přiřadit k vozidlu',
                      emptyOptionText: 'Osobní / bez vozidla',
                      prefixIcon: const Icon(Icons.directions_car_outlined),
                      onChanged: (v) => setState(() => _carId = v),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _costCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Roční cena',
                            hintText: '3 500',
                            prefixIcon: Icon(Icons.payments_outlined),
                            suffixText: 'Kč',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Asistence',
                            hintText: '+420 800 …',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Poznámka',
                      prefixIcon: Icon(Icons.notes_outlined),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 2,
                    minLines: 1,
                  ),
                ],
              ),
            ),

            // 3. PLATNOST
            _SectionCard(
              title: 'Platnost',
              child: Column(
                children: [
                  _DateRow(
                    validFrom: _validFrom,
                    validTo: _validTo,
                    dateFmt: _dateFmt,
                    onPickFrom: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _validFrom ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2050),
                      );
                      if (picked != null) setState(() => _validFrom = picked);
                    },
                    onClearFrom: _validFrom != null ? () => setState(() => _validFrom = null) : null,
                    onPickTo: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _validTo,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2050),
                      );
                      if (picked != null) setState(() => _validTo = picked);
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Datum konce platnosti slouží pro plánování upozornění.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 4. COVERAGE SCOPE (travel policies only)
            if (isTravel)
              _SectionCard(
                title: 'Rozsah krytí',
                trailing: TextButton.icon(
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: const Text('Co to znamená?'),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const TravelInsuranceInfoScreen())),
                ),
                child: Column(
                  children: [
                    _CoverageCheckbox(
                      icon: '🏥',
                      label: 'Léčebné výlohy v zahraničí',
                      value: _coversMedical,
                      onChanged: (v) => setState(() => _coversMedical = v),
                    ),
                    if (_coversMedical)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 4, top: 4),
                        child: TextFormField(
                          controller: _medicalLimitCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Limit léčebných výloh',
                            hintText: '120 000',
                            isDense: true,
                            suffixText: 'EUR',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    _CoverageCheckbox(
                      icon: '🧳',
                      label: 'Zavazadla a osobní věci',
                      value: _coversLuggage,
                      onChanged: (v) => setState(() => _coversLuggage = v),
                    ),
                    _CoverageCheckbox(
                      icon: '✈️',
                      label: 'Zpoždění letu / zmeškaný spoj',
                      value: _coversDelay,
                      onChanged: (v) => setState(() => _coversDelay = v),
                    ),
                    _CoverageCheckbox(
                      icon: '⚖️',
                      label: 'Odpovědnost za škodu třetím osobám',
                      value: _coversLiability,
                      onChanged: (v) => setState(() => _coversLiability = v),
                    ),
                    _CoverageCheckbox(
                      icon: '❌',
                      label: 'Storno cesty',
                      value: _coversCancellation,
                      onChanged: (v) => setState(() => _coversCancellation = v),
                    ),
                    _CoverageCheckbox(
                      icon: '🎿',
                      label: 'Sportovní aktivity (lyže, kolo...)',
                      value: _coversSports,
                      onChanged: (v) => setState(() => _coversSports = v),
                    ),
                  ],
                ),
              ),

            // 5. ATTACHMENT
            _SectionCard(
              title: 'Doklad / příloha',
              child: _attachmentPath != null
                  ? _AttachmentTile(
                      path: _attachmentPath!,
                      onOpen: () => OpenFilex.open(_attachmentPath!),
                      onRemove: _removeAttachment,
                    )
                  : OutlinedButton.icon(
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Nahrát PDF nebo foto dokladu'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: _pickAttachment,
                    ),
            ),

            // SAVE
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: Text(isEditing ? 'Uložit změny' : 'Přidat pojistku'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _isSaving ? null : _save,
            ),
          ],
        ),
      ),
    );
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
    final attachDir = Directory('${dir.path}/insurance_attachments');
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
    // Only delete the file on disk if it is a newly-picked temp file,
    // NOT the original saved attachment — that will be deleted on actual save.
    if (_attachmentPath != null && _attachmentPath != _originalAttachmentPath) {
      final file = File(_attachmentPath!);
      if (file.existsSync()) file.deleteSync();
    }
    setState(() => _attachmentPath = null);
  }
}

// ══════════════════════════════════════════════════════════════
// SUB-WIDGETS
// ══════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: theme.colorScheme.primary)),
                if (trailing != null) ...[const Spacer(), trailing!],
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _TypeChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  const _TypeChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppConstants.insuranceTypes.map((t) {
        return ChoiceChip(
          avatar: Text(AppConstants.insuranceTypeIcons[t] ?? ''),
          label: Text(_short(t)),
          selected: t == selected,
          onSelected: (_) => onSelected(t),
        );
      }).toList(),
    );
  }

  String _short(String t) => switch (t) {
        'pov' => 'POV',
        'comprehensive' => 'Havarijní',
        'vignette' => 'Dáln. známka',
        'travel' => 'Cestovní',
        _ => 'Jiné',
      };
}

class _DateRow extends StatelessWidget {
  final DateTime? validFrom;
  final DateTime validTo;
  final DateFormat dateFmt;
  final VoidCallback onPickFrom;
  final VoidCallback? onClearFrom;
  final VoidCallback onPickTo;

  const _DateRow({
    required this.validFrom,
    required this.validTo,
    required this.dateFmt,
    required this.onPickFrom,
    this.onClearFrom,
    required this.onPickTo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final expired = validTo.isBefore(DateTime.now());
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(
              validFrom == null ? 'Platí od' : dateFmt.format(validFrom!),
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: validFrom == null ? cs.onSurfaceVariant : null,
            ),
            onPressed: onPickFrom,
          ),
        ),
        if (validFrom != null && onClearFrom != null)
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: onClearFrom,
          )
        else
          const SizedBox(width: 8),
        Expanded(
          child: FilledButton.tonalIcon(
            icon: Icon(Icons.event_outlined, size: 18,
                color: expired ? cs.error : null),
            label: Text(
              dateFmt.format(validTo),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: expired ? cs.error : null),
            ),
            onPressed: onPickTo,
          ),
        ),
      ],
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final String path;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  const _AttachmentTile({required this.path, required this.onOpen, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = p.extension(path).toLowerCase();
    final icon = ext == '.pdf' ? Icons.picture_as_pdf_outlined : Icons.image_outlined;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: cs.outlineVariant),
      ),
      leading: Icon(icon, color: cs.primary),
      title: Text(p.basename(path), overflow: TextOverflow.ellipsis),
      subtitle: const Text('Klepni pro otevření'),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: cs.error),
        tooltip: 'Odebrat přílohu',
        onPressed: onRemove,
      ),
      onTap: onOpen,
    );
  }
}

class _CoverageCheckbox extends StatelessWidget {
  final String icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _CoverageCheckbox({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      visualDensity: VisualDensity.compact,
      title: Text('$icon  $label'),
      value: value,
      onChanged: (v) => onChanged(v ?? false),
    );
  }
}