import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/car_provider.dart';
import '../../models/car.dart';
import '../../utils/constants.dart';

/// Form screen for creating or editing a [Car].
///
/// Pass [car] when editing an existing vehicle; leave it `null` to create a
/// new one. The [isEditing] getter drives AppBar title and provider method
/// selection ([CarProvider.updateCar] vs [CarProvider.addCar]).
class AddEditCarScreen extends StatefulWidget {
  /// The car to edit, or `null` to create a new one.
  final Car? car;
  const AddEditCarScreen({super.key, this.car});

  @override
  State<AddEditCarScreen> createState() => _AddEditCarScreenState();
}

/// State for [AddEditCarScreen].
///
/// Manages a [_formKey] and individual [TextEditingController]s for every
/// editable field. [_fuelType] is a separate dropdown string.
class _AddEditCarScreenState extends State<AddEditCarScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _makeCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _yearCtrl;
  late TextEditingController _tankCtrl;
  late TextEditingController _engineVolCtrl;
  late TextEditingController _powerCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _typicalConsumptionCtrl;
  late TextEditingController _spzCtrl;
  late String _fuelType;
  late String _vehicleType;

  /// `true` when editing an existing car, `false` when creating a new one.
  bool get isEditing => widget.car != null;

  bool get _isSpzRequired => _vehicleType == 'Auto';

  /// Populates text controllers from [widget.car] when editing.
  @override
  void initState() {
    super.initState();
    final c = widget.car;
    _makeCtrl = TextEditingController(text: c?.make ?? '');
    _modelCtrl = TextEditingController(text: c?.model ?? '');
    _yearCtrl = TextEditingController(text: c?.year.toString() ?? '');
    _tankCtrl = TextEditingController(text: c?.tankCapacity.toString() ?? '');
    _engineVolCtrl = TextEditingController(text: c?.engineVolume.toString() ?? '');
    _powerCtrl = TextEditingController(text: c?.enginePower.toString() ?? '');
    _noteCtrl = TextEditingController(text: c?.note ?? '');
    _typicalConsumptionCtrl = TextEditingController(text: c?.typicalConsumption?.toString() ?? '');
    _spzCtrl = TextEditingController(text: c?.spz ?? '');
    _fuelType = c?.fuelType ?? AppConstants.fuelTypes.first;
    _vehicleType = c?.vehicleType ?? 'Auto';
  }

  /// Disposes all [TextEditingController]s.
  @override
  void dispose() {
    for (final ctrl in [_makeCtrl, _modelCtrl, _yearCtrl, _tankCtrl, _engineVolCtrl, _powerCtrl, _noteCtrl, _typicalConsumptionCtrl, _spzCtrl]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  /// Validates the form, calls [CarProvider.addCar] or [CarProvider.updateCar],
  /// then pops the route on success.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final spzValue = _spzCtrl.text.trim().isEmpty ? null : _spzCtrl.text.trim().toUpperCase();
    final provider = context.read<CarProvider>();
    if (isEditing) {
      await provider.updateCar(widget.car!.copyWith(
        vehicleType: _vehicleType,
        make: _makeCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        year: int.parse(_yearCtrl.text),
        fuelType: _fuelType,
        tankCapacity: double.parse(_tankCtrl.text),
        engineVolume: double.parse(_engineVolCtrl.text),
        enginePower: int.parse(_powerCtrl.text),
        spz: spzValue,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        typicalConsumption: double.tryParse(_typicalConsumptionCtrl.text),
      ));
    } else {
      await provider.addCar(
        vehicleType: _vehicleType,
        make: _makeCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        year: int.parse(_yearCtrl.text),
        fuelType: _fuelType,
        tankCapacity: double.parse(_tankCtrl.text),
        engineVolume: double.parse(_engineVolCtrl.text),
        enginePower: int.parse(_powerCtrl.text),
        spz: spzValue,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        typicalConsumption: double.tryParse(_typicalConsumptionCtrl.text),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Upravit vozidlo' : 'Přidat vozidlo'),
        actions: [
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
            const _SectionHeader('Základní informace'),
            const SizedBox(height: 8),
            // Vehicle type selector
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Auto', icon: Icon(Icons.directions_car_outlined), label: Text('Auto')),
                ButtonSegment(value: 'Motorka / Skútr', icon: Icon(Icons.two_wheeler_outlined), label: Text('Motorka / Skútr')),
              ],
              selected: {_vehicleType},
              onSelectionChanged: (s) {
                setState(() => _vehicleType = s.first);
                _formKey.currentState?.validate();
              },
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _makeCtrl,
                    decoration: const InputDecoration(labelText: 'Značka', hintText: 'Škoda'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v!.isEmpty ? 'Povinné pole' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _modelCtrl,
                    decoration: const InputDecoration(labelText: 'Model', hintText: 'Octavia'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v!.isEmpty ? 'Povinné pole' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _yearCtrl,
                    decoration: InputDecoration(
                      labelText: 'Rok výroby',
                      hintText: DateTime.now().year.toString(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1900 || n > 2100) return 'Neplatný rok';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _fuelType,
                    decoration: const InputDecoration(labelText: 'Palivo'),
                    items: AppConstants.fuelTypes
                        .map((ft) => DropdownMenuItem(value: ft, child: Text(ft)))
                        .toList(),
                    onChanged: (v) => setState(() => _fuelType = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionHeader('Motor a nádrž'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _engineVolCtrl,
                    decoration: InputDecoration(
                      labelText: 'Objem motoru (l)',
                      hintText: _vehicleType == 'Motorka / Skútr' ? '0.05' : '1.6',
                      helperText: _vehicleType == 'Motorka / Skútr' ? '49 cm³ = 0.049 l' : null,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Zadej kladné číslo (v litrech)';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _powerCtrl,
                    decoration: InputDecoration(
                      labelText: 'Výkon (kW)',
                      hintText: _vehicleType == 'Motorka / Skútr' ? '2' : '85',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Zadej celé číslo > 0';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tankCtrl,
              decoration: InputDecoration(
                labelText: 'Objem nádrže (l)',
                hintText: _vehicleType == 'Motorka / Skútr' ? '4.5' : '55',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Zadej kladné číslo';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _typicalConsumptionCtrl,
              decoration: const InputDecoration(
                labelText: 'Typická spotřeba z palubního počítače (l/100km)',
                hintText: '7.5',
                helperText: 'Použije se pro hodnocení předvídavosti (do 5 jízd)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return null; // optional
                return double.tryParse(v) == null ? 'Neplatná hodnota' : null;
              },
            ),
            const SizedBox(height: 24),
            const _SectionHeader('Identifikace a poznámka'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _spzCtrl,
              decoration: InputDecoration(
                labelText: _isSpzRequired ? 'SPZ *' : 'SPZ',
                hintText: '1AB 2345',
                helperText: _isSpzRequired
                    ? 'Povinné pro auta'
                    : 'Nepovinné pro motorky a skútry bez SPZ',
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) {
                if (_isSpzRequired && (v == null || v.trim().isEmpty)) {
                  return 'SPZ je pro auto povinná';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Poznámka', hintText: 'Zimní gumy, tažné...'),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: _save, child: Text(isEditing ? 'Uložit změny' : 'Přidat vozidlo')),
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
