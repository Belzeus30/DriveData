import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/goal.dart';
import '../../providers/car_provider.dart';
import '../../providers/goal_provider.dart';
import '../../utils/constants.dart';

/// Form screen for creating or editing a driving [Goal].
///
/// Allows the user to pick a goal type (distance, trip count, fuel, etc.),
/// optionally scope it to a specific car, set a target value, and add an
/// optional deadline. Pass [goal] to open in edit mode.
class AddEditGoalScreen extends StatefulWidget {
  /// The goal to edit, or `null` to create a new one.
  final Goal? goal;
  const AddEditGoalScreen({super.key, this.goal});

  @override
  State<AddEditGoalScreen> createState() => _AddEditGoalScreenState();
}

/// State for [AddEditGoalScreen].
class _AddEditGoalScreenState extends State<AddEditGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _goalType;
  String? _carId;
  final _targetCtrl = TextEditingController();
  DateTime? _deadline;

  /// `true` when editing an existing goal, `false` for a new goal.
  bool get isEditing => widget.goal != null;

  /// Populates state from [widget.goal] when editing.
  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    _goalType = g?.type ?? AppConstants.goalTypes.first;
    _carId = g?.carId;
    _targetCtrl.text = g?.targetValue.toString() ?? '';
    _deadline = g?.deadline;
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    super.dispose();
  }

  /// Validates form; calls [GoalProvider.addGoal] or [GoalProvider.updateGoal]
  /// then pops on success.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<GoalProvider>();
    if (isEditing) {
      await provider.updateGoal(widget.goal!.copyWith(
        carId: _carId,
        type: _goalType,
        targetValue: double.parse(_targetCtrl.text),
        deadline: _deadline,
      ));
    } else {
      await provider.addGoal(
        carId: _carId,
        type: _goalType,
        targetValue: double.parse(_targetCtrl.text),
        deadline: _deadline,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cars = context.watch<CarProvider>().cars;
    final unit = AppConstants.goalTypeUnits[_goalType] ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Upravit cíl' : 'Nový cíl'),
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
            // Goal type
            Text('Typ cíle',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.goalTypes.map((type) {
                final selected = _goalType == type;
                return ChoiceChip(
                  label: Text(
                      '${AppConstants.goalTypeIcons[type]} ${AppConstants.goalTypeLabels[type]}'),
                  selected: selected,
                  onSelected: (_) => setState(() => _goalType = type),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // Target value
            TextFormField(
              controller: _targetCtrl,
              decoration: InputDecoration(
                labelText: 'Cílová hodnota ($unit)',
                hintText: _hint,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) =>
                  double.tryParse(v ?? '') == null ? 'Povinné' : null,
            ),
            const SizedBox(height: 12),
            // Car (optional)
            DropdownButtonFormField<String?>(
              initialValue: _carId,
              decoration: const InputDecoration(
                  labelText: 'Pro auto (volitelné)'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Všechna auta')),
                ...cars.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.fullName))),
              ],
              onChanged: (v) => setState(() => _carId = v),
            ),
            const SizedBox(height: 12),
            // Deadline
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(_deadline == null
                  ? 'Bez termínu'
                  : 'Termín: ${_deadline!.day}. ${_deadline!.month}. ${_deadline!.year}'),
              trailing: _deadline != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _deadline = null),
                    )
                  : null,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                );
                if (picked != null) setState(() => _deadline = picked);
              },
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: _save, child: Text(isEditing ? 'Uložit změny' : 'Přidat cíl')),

            const SizedBox(height: 16),
            // Hint card
            if (!isEditing) _HintCard(goalType: _goalType),
          ],
        ),
          ),
        ),
      ),
    );
  }

  String get _hint {
    switch (_goalType) {
      case 'fuel':
        return 'např. 6.5 = snížit spotřebu pod 6.5 l/100km';
      case 'score':
        return 'např. 8 = dosáhnout skóre 8/10';
      case 'km_month':
        return 'např. 1000 = ujet 1000 km za měsíc';
      case 'cost_km':
        return 'např. 2.5 = max 2.5 Kč/km';
      case 'trips_month':
        return 'např. 20 = zaznamenat 20 jízd za měsíc';
      default:
        return '';
    }
  }
}

class _HintCard extends StatelessWidget {
  final String goalType;
  const _HintCard({required this.goalType});

  @override
  Widget build(BuildContext context) {
    String text;
    switch (goalType) {
      case 'fuel':
        text =
            'Průměrná spotřeba se počítá ze všech jízd kde jsi zadal tankování. Čím nižší, tím lépe.';
        break;
      case 'score':
        text =
            'Skóre se vypočítá jako průměr plynulosti, předvídavosti a dodržování limitů ze všech jízd.';
        break;
      case 'km_month':
        text = 'Počítají se km ujetá v aktuálním kalendářním měsíci.';
        break;
      case 'cost_km':
        text =
            'Průměrné náklady na km ze jízd kde jsi zadal cenu tankování.';
        break;
      case 'trips_month':
        text = 'Počet zaznamenaných jízd v aktuálním kalendářním měsíci.';
        break;
      default:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
