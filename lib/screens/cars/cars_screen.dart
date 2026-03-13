import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/car.dart';
import '../../providers/car_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/insurance_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/trip_provider.dart';
import 'add_edit_car_screen.dart';
import '../settings/settings_screen.dart';

/// Garage screen — lists all cars owned by the user.
///
/// Reads from [CarProvider] and renders each vehicle as a [_CarTile].
/// The FAB navigates to [AddEditCarScreen] to create a new car.
/// Settings are accessible via the AppBar action icon.
class CarsScreen extends StatelessWidget {
  const CarsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje vozidla'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Nastavení',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Consumer<CarProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.cars.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.garage_outlined, size: 40,
                        color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 16),
                  Text('Žádná vozidla', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Přidej své první vozidlo kliknutím na +',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: provider.cars.length,
            itemBuilder: (context, index) {
              final car = provider.cars[index];
              return _CarTile(car: car);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab_cars',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEditCarScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Přidat vozidlo'),
      ),
    );
  }
}

/// Card widget showing a single car's key specs and a context menu.
///
/// - Displays a gradient avatar with the car's initial letter and a 
///   brand-derived accent colour (see [_accentColor]).
/// - Tapping opens [AddEditCarScreen] in edit mode.
/// - The popup menu allows **edit** and **delete**; deleting a car also
///   triggers cascade reloads of trips, service records, policies, and goals.
class _CarTile extends StatelessWidget {
  /// The car to render.
  final Car car;
  const _CarTile({required this.car});

  /// Cache shared across all [_CarTile] instances to avoid recomputing
  /// the same hue for the same make+model combination on every rebuild.
  static final _colorCache = <String, Color>{};

  /// Derives a deterministic accent colour from [car.make] + [car.model].
  ///
  /// Uses a simple polynomial hash over the code units to obtain a hue in
  /// [0, 360) and converts to HSL(h, 52%, 42%) for readable, saturated colour.
  /// Results are memoised in [_colorCache].
  Color _accentColor() {
    final key = '${car.make}|${car.model}';
    return _colorCache.putIfAbsent(key, () {
      final seed = car.make.codeUnits.fold(0, (s, c) => s * 31 + c) +
          car.model.codeUnits.fold(0, (s, c) => s * 17 + c);
      final hue = (seed.abs() % 360).toDouble();
      return HSLColor.fromAHSL(1.0, hue, 0.52, 0.42).toColor();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _accentColor();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddEditCarScreen(car: car)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: accent,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, accent.withValues(alpha: 0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.35),
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      car.isMotorcycle
                          ? Icons.two_wheeler_outlined
                          : Icons.directions_car_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          car.fullName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${car.year}  ·  ${car.fuelType}',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _SpecTag('⚡ ${car.enginePower} kW', cs),
                            _SpecTag('🔧 ${car.engineVolume} l', cs),
                            _SpecTag(
                                '⛽ ${car.tankCapacity.toStringAsFixed(0)} l',
                                cs),
                            if (car.typicalConsumption != null)
                              _SpecTag(
                                  '📊 ${car.typicalConsumption!.toStringAsFixed(1)} l/100',
                                  cs),
                            if (car.spz != null)
                              _SpecTag('🔖 ${car.spz!}', cs),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => AddEditCarScreen(car: car)));
                      } else if (value == 'delete') {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Smazat vozidlo?'),
                            content: Text(
                                'Smazáním vozidla "${car.fullName}" se trvale smažou také všechny jeho jízdy, servisní záznamy, pojistky a cíle. Tato akce je nevratná.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Zrušit')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Smazat')),
                            ],
                          ),
                        );
                        if (confirmed == true && context.mounted) {
                          await context.read<CarProvider>().deleteCar(car.id);
                          // Reload all providers whose in-memory data was cascade-deleted
                          if (context.mounted) {
                            await Future.wait([
                              context.read<TripProvider>().loadTrips(),
                              context.read<ServiceProvider>().loadRecords(),
                              context.read<InsuranceProvider>().loadPolicies(),
                              context.read<GoalProvider>().loadGoals(),
                            ]);
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Upravit')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Smazat')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact spec tag chip shown in [_CarTile] for a single technical attribute.
///
/// Renders [label] (e.g. `'⚡ 120 kW'`) on a surface-variant background.
class _SpecTag extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  const _SpecTag(this.label, this.cs);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant),
      ),
    );
  }
}
