import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/trailer.dart';
import '../../providers/trailer_provider.dart';

/// Form screen for creating or editing a [Trailer].
///
/// Collects name, licence plate, year, max weight, next MOT date, and note.
/// Pass [trailer] to open in edit mode. When in edit mode an AppBar delete
/// button calls [_delete] with a confirmation dialog.
class AddEditTrailerScreen extends StatefulWidget {
  /// The trailer to edit, or `null` to create a new one.
  final Trailer? trailer;
  const AddEditTrailerScreen({super.key, this.trailer});

  @override
  State<AddEditTrailerScreen> createState() => _AddEditTrailerScreenState();
}

/// State for [AddEditTrailerScreen].
class _AddEditTrailerScreenState extends State<AddEditTrailerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime? _nextTechDate;

  /// `true` when editing an existing trailer.
  bool get isEditing => widget.trailer != null;

  /// Populates text controllers and [_nextTechDate] from [widget.trailer].
  @override
  void initState() {
    super.initState();
    final t = widget.trailer;
    if (t != null) {
      _nameCtrl.text = t.name;
      _plateCtrl.text = t.licensePlate ?? '';
      _yearCtrl.text = t.year?.toString() ?? '';
      _weightCtrl.text = t.maxWeightKg?.toString() ?? '';
      _noteCtrl.text = t.note ?? '';
      _nextTechDate = t.nextTechDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _plateCtrl.dispose();
    _yearCtrl.dispose();
    _weightCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// Validates form; calls [TrailerProvider.updateTrailer] or
  /// [TrailerProvider.addTrailer] then pops on success.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<TrailerProvider>();

    final name = _nameCtrl.text.trim();
    final plate =
        _plateCtrl.text.trim().isEmpty ? null : _plateCtrl.text.trim();
    final year = int.tryParse(_yearCtrl.text);
    final weight = double.tryParse(_weightCtrl.text);
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();

    if (isEditing) {
      await provider.updateTrailer(widget.trailer!.copyWith(
        name: name,
        licensePlate: plate,
        year: year,
        nextTechDate: _nextTechDate,
        maxWeightKg: weight,
        note: note,
      ));
    } else {
      await provider.addTrailer(
        name: name,
        licensePlate: plate,
        year: year,
        nextTechDate: _nextTechDate,
        maxWeightKg: weight,
        note: note,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  /// Shows a confirmation dialog and deletes the trailer via
  /// [TrailerProvider.deleteTrailer] if confirmed.
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Smazat vozík?'),
        content: const Text(
            'Jízdy s tímto vozíkem budou zachovány, ale bez vazby na vozík.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Zrušit')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Smazat',
                  style:
                      TextStyle(color: Theme.of(ctx).colorScheme.error))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<TrailerProvider>().deleteTrailer(widget.trailer!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  static final _dateFmt = DateFormat('d. M. yyyy');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Upravit vozík' : 'Přidat vozík'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Smazat vozík',
              onPressed: _delete,
            ),
          TextButton(onPressed: _save, child: const Text('Uložit')),
        ],
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
                // --- BASIC INFORMATION ---
                _SectionHeader('Základní informace'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Název vozíku *',
                    hintText: 'Př. Sklápěcí přívěs, Karavan Adria',
                    prefixIcon: Icon(Icons.rv_hookup),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Povinné pole' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _plateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'SPZ (volitelné)',
                          hintText: '1A2 3456',
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _yearCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Rok výroby',
                          hintText: '2015',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final y = int.tryParse(v);
                          if (y == null || y < 1970 || y > 2100) {
                            return 'Neplatný rok';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _weightCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Celková hmotnost (kg)',
                    hintText: '750',
                    helperText:
                        'Přívěsy do 750 kg nepotřebují STK dle ČR zákona',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),

                const SizedBox(height: 24),
                _SectionHeader('Technická kontrola (STK)'),
                const SizedBox(height: 8),

                // Info box o STK
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Přívěsy nad 750 kg podléhají pravidelné STK.\n'
                          'Zadáním data dostaneš upozornění 30 dní předem.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_available),
                  title: Text(
                    _nextTechDate != null
                        ? 'STK do: ${_dateFmt.format(_nextTechDate!)}'
                        : 'Datum příští STK (volitelné)',
                    style: _nextTechDate == null
                        ? TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant)
                        : null,
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          _nextTechDate ?? DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2040),
                    );
                    if (picked != null) setState(() => _nextTechDate = picked);
                  },
                  trailing: _nextTechDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Smazat datum STK',
                          onPressed: () =>
                              setState(() => _nextTechDate = null),
                        )
                      : null,
                ),

                const SizedBox(height: 24),
                _SectionHeader('Poznámka'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Poznámka (volitelné)',
                    hintText: 'Hmotnost, nosnost, typ, stav...',
                  ),
                  maxLines: 3,
                  maxLength: 500,
                ),

                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _save,
                  child: Text(isEditing ? 'Uložit změny' : 'Přidat vozík'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
