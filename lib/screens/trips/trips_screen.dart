import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/car.dart';
import '../../models/trip.dart';
import '../../providers/car_provider.dart';
import '../../providers/trailer_provider.dart';
import '../../providers/trip_provider.dart';
import '../../utils/constants.dart';
import 'add_edit_trip_screen.dart';
import '../settings/settings_screen.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  String? _carFilterId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje jízdy'),
        centerTitle: false,
        actions: [
          Consumer<CarProvider>(
            builder: (context, carProvider, _) {
              final cars = carProvider.cars;
              if (cars.isEmpty) return const SizedBox.shrink();
              final isFiltered = _carFilterId != null;
              return PopupMenuButton<String>(
                icon: Icon(
                  isFiltered ? Icons.filter_alt : Icons.filter_list,
                  color: isFiltered ? Theme.of(context).colorScheme.primary : null,
                ),
                tooltip: isFiltered ? 'Filtr aktivní — klikni pro změnu' : 'Filtrovat podle auta',
                onSelected: (v) => setState(() => _carFilterId = v == '__all__' ? null : v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: '__all__', child: Text('Všechna auta')),
                  ...cars.map((c) => PopupMenuItem(value: c.id, child: Text(c.fullName))),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Nastavení',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Consumer2<TripProvider, CarProvider>(
        builder: (context, tripProvider, carProvider, _) {
          if (tripProvider.isLoading || carProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          // Use full trips list with LOCAL filter — independent from Analytics filter
          final allTrips = tripProvider.trips;
          final trips = _carFilterId == null
              ? allTrips
              : allTrips.where((t) => t.carId == _carFilterId).toList();
          final activeCarName = _carFilterId != null
              ? carProvider.getCarById(_carFilterId!)?.fullName
              : null;
          if (trips.isEmpty) {
            final noCars = carProvider.cars.isEmpty;
            return Column(
              children: [
                if (activeCarName != null)
                  _FilterBanner(carName: activeCarName, onClear: () => setState(() => _carFilterId = null)),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          noCars ? Icons.directions_car_outlined : Icons.route_outlined,
                          size: 72, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          noCars ? 'Nejprve přidej auto' : 'Žádné jízdy',
                          style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          noCars
                              ? 'Přejdi na záložku Auta a přidej své vozidlo.\nPak budeš moci přidávat jízdy.'
                              : 'Přidej první jízdu kliknutím na +',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          final baselines = tripProvider.baselinePerCar;
          final trailerProvider = context.read<TrailerProvider>();
          return Column(
            children: [
              if (activeCarName != null)
                _FilterBanner(carName: activeCarName, onClear: () => setState(() => _carFilterId = null)),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: trips.length,
                  itemBuilder: (context, index) {
                    final trip = trips[index];
                    final car = carProvider.getCarById(trip.carId);
                    return _TripCard(
                      trip: trip,
                      car: car,
                      baseline: baselines[trip.carId] ?? car?.typicalConsumption,
                      trailerName: trip.trailerId != null
                          ? trailerProvider.getById(trip.trailerId!)?.name
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<CarProvider>(
        builder: (context, carProvider, _) {
          if (carProvider.cars.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            heroTag: 'fab_trips',
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const AddEditTripScreen())),
            icon: const Icon(Icons.add),
            label: const Text('Přidat jízdu'),
          );
        },
      ),
    );
  }
}

class _FilterBanner extends StatelessWidget {
  final String carName;
  final VoidCallback onClear;
  const _FilterBanner({required this.carName, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.filter_alt, size: 16, color: cs.onPrimaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Filtr: $carName',
                style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                foregroundColor: cs.onPrimaryContainer,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Zrušit filtr'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final Car? car;
  final double? baseline;
  final String? trailerName;

  const _TripCard({required this.trip, required this.car, this.baseline, this.trailerName});

  static const _routeColors = {
    'city': Color(0xFF1565C0),
    'highway': Color(0xFF2E7D32),
    'mixed': Color(0xFFE65100),
    'offroad': Color(0xFF5D4037),
  };

  static final _dateFmt = DateFormat('d. M. yyyy');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final score = trip.drivingScoreFor(baseline);
    final carName = car?.fullName ?? 'Neznámé auto';
    final dateStr = _dateFmt.format(trip.date);
    final routeColor = _routeColors[trip.routeType] ?? const Color(0xFF607D8B);
    final scoreColor = score == null
        ? cs.outline
        : score >= 8
            ? Colors.green
            : score >= 6
                ? Colors.orange
                : Colors.red;

    return Dismissible(
      key: Key(trip.id),
      direction: DismissDirection.endToStart,
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: cs.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Smazat jízdu?'),
            content: const Text('Tato akce je nevratná.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Zrušit'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Smazat',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          await context.read<TripProvider>().deleteTrip(trip.id);
        }
        return false;
      },
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddEditTripScreen(trip: trip)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored left strip
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: routeColor,
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(16)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      dateStr,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                              color: cs.primary,
                                              fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: routeColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${AppConstants.routeIcons[trip.routeType] ?? ''} ${AppConstants.routeTypeLabels[trip.routeType] ?? trip.routeType}',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: routeColor),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  carName,
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                if (trip.startLocation != null ||
                                    trip.endLocation != null)
                                  Text(
                                    [trip.startLocation, trip.endLocation]
                                        .where((s) => s != null)
                                        .join(' → '),
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Score badge
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scoreColor.withValues(alpha: 0.12),
                              border: Border.all(
                                  color: scoreColor.withValues(alpha: 0.5),
                                  width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              score != null ? score.toStringAsFixed(1) : '–',
                              style: TextStyle(
                                  color: scoreColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: score != null ? 14 : 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _StatsRow(trip: trip, trailerName: trailerName),
                      if (trip.note != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.notes,
                                size: 13, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                trip.note!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: cs.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

class _StatsRow extends StatelessWidget {
  final Trip trip;
  final String? trailerName;
  const _StatsRow({required this.trip, this.trailerName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _StatChip(Icons.straighten, '${trip.distance.toStringAsFixed(0)} km', cs),
        _StatChip(Icons.timer_outlined, '${trip.drivingDuration} min', cs),
        if (trip.fuelConsumption != null)
          _StatChip(Icons.local_gas_station_outlined,
              '${trip.fuelConsumption!.toStringAsFixed(1)} l/100km', cs),
        if (trip.costPerKm != null)
          _StatChip(Icons.payments_outlined,
              '${trip.costPerKm!.toStringAsFixed(1)} Kč/km', cs),
        if (trailerName != null)
          _StatChip(Icons.rv_hookup, trailerName!, cs,
              color: Colors.deepOrange.shade700),
        _EmojiChip(AppConstants.weatherIcons[trip.weatherCondition] ?? '', cs),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final ColorScheme cs;
  final Color? color;
  const _StatChip(this.icon, this.text, this.cs, {this.color});

  @override
  Widget build(BuildContext context) {
    final fg = color ?? cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color != null
            ? color!.withValues(alpha: 0.1)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11,
                  color: fg,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _EmojiChip extends StatelessWidget {
  final String emoji;
  final ColorScheme cs;
  const _EmojiChip(this.emoji, this.cs);

  @override
  Widget build(BuildContext context) {
    if (emoji.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 13)),
    );
  }
}
