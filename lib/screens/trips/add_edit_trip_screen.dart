import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/trip.dart';
import '../../providers/car_provider.dart';
import '../../providers/trailer_provider.dart';
import '../../providers/trip_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/vehicle_filter_widgets.dart';

/// Form screen for creating or editing a [Trip].
///
/// Collects all trip data: car selection, date, odometer readings, route type,
/// weather, traffic level, fuel info, speed stats, AC usage, outside temperature,
/// trip-computer consumption, locations, and a free-text note. Pass [trip] to
/// open in edit mode.
///
/// The fuel section is conditionally shown when [_didFuel] is `true`.
/// [_fullTank] toggles whether the full-tank cost field is required.
class AddEditTripScreen extends StatefulWidget {
  /// The trip to edit, or `null` to create a new one.
  final Trip? trip;
  const AddEditTripScreen({super.key, this.trip});

  @override
  State<AddEditTripScreen> createState() => _AddEditTripScreenState();
}

/// State for [AddEditTripScreen].
///
/// One [TextEditingController] per numeric/text field; dropdown/chip
/// selections stored as typed state variables.
class _AddEditTripScreenState extends State<AddEditTripScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _carId;
  late DateTime _date;
  final _odometerStartCtrl = TextEditingController();
  final _odometerEndCtrl = TextEditingController();
  final _fuelAddedCtrl = TextEditingController();
  final _fuelPriceCtrl = TextEditingController();
  final _fuelTotalCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _maxSpeedCtrl = TextEditingController();
  final _avgSpeedCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _tripConsumptionCtrl = TextEditingController();
  final _startLocCtrl = TextEditingController();
  final _endLocCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  late String _routeType;
  late String _weatherCondition;
  late int _trafficLevel;
  late bool _acUsed;
  bool _didFuel = false;
  bool _fullTank = false;
  String? _trailerId;

  /// `true` when editing an existing trip.
  bool get isEditing => widget.trip != null;

  /// Populates all controllers and state variables from [widget.trip].
  @override
  void initState() {
    super.initState();
    final t = widget.trip;
    final carProvider = context.read<CarProvider>();
    _carId = t?.carId ?? carProvider.cars.firstOrNull?.id ?? '';
    _date = t?.date ?? DateTime.now();
    _routeType = t?.routeType ?? 'mixed';
    _weatherCondition = t?.weatherCondition ?? 'clear';
    _trafficLevel = t?.trafficLevel ?? 2;
    _acUsed = t?.acUsed ?? false;
    _didFuel = t?.fuelAdded != null;
    _fullTank = t?.fullTank ?? false;
    _trailerId = t?.trailerId;

    if (t != null) {
      _odometerStartCtrl.text = t.odometerStart.toString();
      _odometerEndCtrl.text = t.odometerEnd.toString();
      _fuelAddedCtrl.text = t.fuelAdded?.toString() ?? '';
      _fuelPriceCtrl.text = t.fuelPricePerLiter?.toString() ?? '';
      _fuelTotalCtrl.text = t.fullTankCost?.toString() ?? '';
      _durationCtrl.text = t.drivingDuration.toString();
      _maxSpeedCtrl.text = t.maxSpeed?.toString() ?? '';
      _avgSpeedCtrl.text = t.averageSpeed?.toString() ?? '';
      _tempCtrl.text = t.outsideTemp?.toString() ?? '';
      _tripConsumptionCtrl.text = t.tripComputerConsumption?.toString() ?? '';
      _startLocCtrl.text = t.startLocation ?? '';
      _endLocCtrl.text = t.endLocation ?? '';
      _noteCtrl.text = t.note ?? '';
    } else {
      // New trip — pre-fill odometer start from the last trip's end for this car.
      _prefillOdometerStart(_carId);
    }
  }

  /// Pre-fills [_odometerStartCtrl] with the last recorded odometer value
  /// for [carId]. Only used when creating a new trip (not when editing).
  void _prefillOdometerStart(String carId) {
    final latest = context.read<TripProvider>().latestOdometerPerCar[carId];
    if (latest != null) {
      _odometerStartCtrl.text = latest.toStringAsFixed(0);
    }
  }

  /// Disposes all [TextEditingController]s.
  @override
  void dispose() {
    for (final ctrl in [
      _odometerStartCtrl, _odometerEndCtrl, _fuelAddedCtrl, _fuelPriceCtrl,
      _fuelTotalCtrl, _durationCtrl, _maxSpeedCtrl, _avgSpeedCtrl, _tempCtrl,
      _tripConsumptionCtrl, _startLocCtrl, _endLocCtrl, _noteCtrl
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  /// Collects form values, validates, and calls [TripProvider.addTrip] or
  /// [TripProvider.updateTrip]. Pops the route on success.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<TripProvider>();
    final args = (
      carId: _carId,
      date: _date,
      odometerStart: double.parse(_odometerStartCtrl.text),
      odometerEnd: double.parse(_odometerEndCtrl.text),
      fuelAdded: _didFuel ? double.tryParse(_fuelAddedCtrl.text) : null,
      fuelPricePerLiter: _didFuel ? double.tryParse(_fuelPriceCtrl.text) : null,
      fullTankCost: _didFuel ? double.tryParse(_fuelTotalCtrl.text) : null,
      drivingDuration: int.parse(_durationCtrl.text),
      routeType: _routeType,
      weatherCondition: _weatherCondition,
      trafficLevel: _trafficLevel,
      maxSpeed: double.tryParse(_maxSpeedCtrl.text),
      averageSpeed: double.tryParse(_avgSpeedCtrl.text),
      acUsed: _acUsed,
      outsideTemp: int.tryParse(_tempCtrl.text),
      tripComputerConsumption: double.tryParse(_tripConsumptionCtrl.text),
      startLocation: _startLocCtrl.text.trim().isEmpty ? null : _startLocCtrl.text.trim(),
      endLocation: _endLocCtrl.text.trim().isEmpty ? null : _endLocCtrl.text.trim(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );

    if (isEditing) {
      await provider.updateTrip(widget.trip!.copyWith(
        carId: args.carId,
        date: args.date,
        odometerStart: args.odometerStart,
        odometerEnd: args.odometerEnd,
        fuelAdded: args.fuelAdded,
        fuelPricePerLiter: args.fuelPricePerLiter,
        fullTankCost: args.fullTankCost,
        drivingDuration: args.drivingDuration,
        routeType: args.routeType,
        weatherCondition: args.weatherCondition,
        trafficLevel: args.trafficLevel,
        maxSpeed: args.maxSpeed,
        averageSpeed: args.averageSpeed,
        acUsed: args.acUsed,
        outsideTemp: args.outsideTemp,
        tripComputerConsumption: args.tripComputerConsumption,
        fullTank: _didFuel ? _fullTank : false,
        trailerId: _trailerId,
        startLocation: args.startLocation,
        endLocation: args.endLocation,
        note: args.note,
      ));
    } else {
      await provider.addTrip(
        carId: args.carId,
        date: args.date,
        odometerStart: args.odometerStart,
        odometerEnd: args.odometerEnd,
        fuelAdded: args.fuelAdded,
        fuelPricePerLiter: args.fuelPricePerLiter,
        fullTankCost: args.fullTankCost,
        drivingDuration: args.drivingDuration,
        routeType: args.routeType,
        weatherCondition: args.weatherCondition,
        trafficLevel: args.trafficLevel,
        maxSpeed: args.maxSpeed,
        averageSpeed: args.averageSpeed,
        acUsed: args.acUsed,
        outsideTemp: args.outsideTemp,
        tripComputerConsumption: args.tripComputerConsumption,
        fullTank: _didFuel ? _fullTank : false,
        trailerId: _trailerId,
        startLocation: args.startLocation,
        endLocation: args.endLocation,
        note: args.note,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final tripProvider = context.read<TripProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Smazat jízdu?'),
        content: const Text('Tato akce je nevratná.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Zrušit')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Smazat',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await tripProvider.deleteTrip(widget.trip!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cars = context.watch<CarProvider>().cars;
    final trailers = context.watch<TrailerProvider>().trailers;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Upravit jízdu' : 'Přidat jízdu'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Smazat jízdu',
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
            // --- VOZIDLO & DATUM ---
            const _SectionHeader('Vozidlo a datum'),
            const SizedBox(height: 8),
            VehicleDropdownField(
              vehicles: cars,
              value: _carId.isEmpty ? null : _carId,
              onChanged: (v) {
                setState(() => _carId = v!);
                // When switching car on a new trip, update the suggested odometer start.
                if (!isEditing) _prefillOdometerStart(v!);
              },
              validator: (v) => v == null ? 'Vyber vozidlo' : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text('Datum: ${_date.day}. ${_date.month}. ${_date.year}'),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),

            const SizedBox(height: 16),
            const _SectionHeader('Kilometry'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _odometerStartCtrl,
                    decoration: const InputDecoration(labelText: 'Tachometr start (km)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => double.tryParse(v ?? '') == null ? 'Povinné' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _odometerEndCtrl,
                    decoration: const InputDecoration(labelText: 'Tachometr konec (km)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final end = double.tryParse(v ?? '');
                      final start = double.tryParse(_odometerStartCtrl.text);
                      if (end == null) return 'Povinné';
                      if (start != null && end <= start) return 'Musí být > start';
                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const _SectionHeader('Jízda'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _durationCtrl,
              decoration: const InputDecoration(labelText: 'Délka jízdy (minuty)', hintText: '45'),
              keyboardType: TextInputType.number,
              validator: (v) => int.tryParse(v ?? '') == null ? 'Povinné' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _routeType,
                    decoration: const InputDecoration(labelText: 'Typ trasy'),
                    items: AppConstants.routeTypes
                        .map((rt) => DropdownMenuItem(
                              value: rt,
                              child: Text(AppConstants.routeTypeLabels[rt]!),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _routeType = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _weatherCondition,
                    decoration: const InputDecoration(labelText: 'Počasí'),
                    items: AppConstants.weatherConditions
                        .map((wc) => DropdownMenuItem(
                              value: wc,
                              child: Text(AppConstants.weatherLabels[wc]!),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _weatherCondition = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Hustota provozu: $_trafficLevel / 5',
                style: Theme.of(context).textTheme.bodyMedium),
            Slider(
              value: _trafficLevel.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: _trafficLevel.toString(),
              onChanged: (v) => setState(() => _trafficLevel = v.round()),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _maxSpeedCtrl,
                    decoration: const InputDecoration(labelText: 'Max rychlost (km/h)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _avgSpeedCtrl,
                    decoration: const InputDecoration(labelText: 'Prům. rychlost (km/h)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tripConsumptionCtrl,
              decoration: const InputDecoration(
                labelText: 'Spotřeba dle palubáku (l/100 km)',
                hintText: '6.4',
                prefixIcon: Icon(Icons.local_gas_station_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final val = double.tryParse(v);
                if (val == null || val <= 0 || val > 50) return 'Zadej reálnou hodnotu (0–50)';
                return null;
              },
            ),

            const SizedBox(height: 16),
            const _SectionHeader('Hodnocení jízdy'),
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.auto_awesome,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Text('Skóre se počítá automaticky',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 8),
                    const _ScoreInfoRow(
                      icon: Icons.speed,
                      label: 'Plynulost',
                      desc: 'průměrná ÷ max. rychlost',
                    ),
                    const _ScoreInfoRow(
                      icon: Icons.local_gas_station,
                      label: 'Předvídavost',
                      desc: 'spotřeba vs. norma pro typ trasy',
                    ),
                    const _ScoreInfoRow(
                      icon: Icons.warning_amber_rounded,
                      label: 'Limity',
                      desc: 'max. rychlost vs. limit trasy',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            const _SectionHeader('Klimatizace a teplota'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Klimatizace'),
                    value: _acUsed,
                    onChanged: (v) => setState(() => _acUsed = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _tempCtrl,
                    decoration: const InputDecoration(labelText: 'Teplota (°C)', hintText: '20'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const _SectionHeader('Tankování (volitelné)'),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Při této jízdě jsem tankoval/a'),
              value: _didFuel,
              onChanged: (v) => setState(() => _didFuel = v),
            ),
            if (_didFuel) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fuelAddedCtrl,
                      decoration: const InputDecoration(labelText: 'Natankováno (l)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fuelPriceCtrl,
                      decoration: const InputDecoration(labelText: 'Cena/l (Kč)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _fuelTotalCtrl,
                decoration: const InputDecoration(labelText: 'Celková cena tankování (Kč)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dotankoval/a jsem DO PLNA'),
                subtitle: const Text(
                  'Označ, pokud jsi natankoval/a plnou nádrž — potřebné pro přesný výpočet spotřeby',
                  style: TextStyle(fontSize: 11),
                ),
                secondary: Icon(
                  _fullTank ? Icons.local_gas_station : Icons.local_gas_station_outlined,
                  color: _fullTank ? Theme.of(context).colorScheme.primary : null,
                ),
                value: _fullTank,
                onChanged: (v) => setState(() => _fullTank = v),
              ),
            ],

            const SizedBox(height: 16),
            const _SectionHeader('Vozík / přívěs (volitelné)'),
            const SizedBox(height: 8),
            if (trailers.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Text('🚗🔗', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nemáš zadán žádný vozík. Přidej ho v záložce Vozíky.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  DropdownButtonFormField<String?>(
                    initialValue: _trailerId,
                    decoration: const InputDecoration(
                      labelText: 'Jel jsem s vozíkem',
                      prefixIcon: Icon(Icons.rv_hookup),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Bez vozíku')),
                      ...trailers.map((t) =>
                          DropdownMenuItem(value: t.id, child: Text(t.name))),
                    ],
                    onChanged: (v) => setState(() => _trailerId = v),
                  ),
                  if (_trailerId != null) ...
                    [
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Skóre bere v úvahu limit max 80 km/h na dálnici/silnici'
                                ' (zákonný limit CZ s přívěsem).',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                ],
              ),

            const SizedBox(height: 16),
            const _SectionHeader('Trasa a poznámky (volitelné)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startLocCtrl,
                    decoration: const InputDecoration(labelText: 'Odkud', hintText: 'Praha'),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _endLocCtrl,
                    decoration: const InputDecoration(labelText: 'Kam', hintText: 'Brno'),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                  labelText: 'Poznámka', hintText: 'Jak šla jízda, co bys příště udělal jinak...'),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child: Text(isEditing ? 'Uložit změny' : 'Přidat jízdu'),
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

class _ScoreInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;

  const _ScoreInfoRow({
    required this.icon,
    required this.label,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
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
