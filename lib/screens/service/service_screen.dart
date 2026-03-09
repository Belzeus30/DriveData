import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../../models/service_record.dart';
import '../../providers/car_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/trip_provider.dart';
import '../../utils/constants.dart';
import '../settings/settings_screen.dart';
import 'add_edit_service_screen.dart';

/// Service records screen.
///
/// Shows upcoming service reminders at the top, followed by a cost-summary
/// bar and a scrollable list of all service records. Supports optional
/// per-car filtering: the selected car ID is persisted inside [ServiceProvider]
/// (unlike [TripsScreen] which keeps the filter locally in its state).
///
/// Depends on [CarProvider], [ServiceProvider], and [TripProvider].
class ServiceScreen extends StatelessWidget {
  const ServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final carProvider = context.watch<CarProvider>();
    final serviceProvider = context.watch<ServiceProvider>();
    final tripProvider = context.watch<TripProvider>();
    final cars = carProvider.cars;

    final reminders = serviceProvider.getReminders(tripProvider.latestOdometerPerCar);

    // Records are already filtered to the selected car by loadRecords(carId:)
    final displayed = serviceProvider.records;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Servis'),
        centerTitle: false,
        actions: [
          if (cars.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(
                serviceProvider.selectedCarId != null ? Icons.filter_alt : Icons.filter_list,
                color: serviceProvider.selectedCarId != null
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              tooltip: serviceProvider.selectedCarId != null
                  ? 'Filtr aktivní — klikni pro změnu'
                  : 'Filtrovat podle auta',
              onSelected: (v) async {
                await serviceProvider.loadRecords(carId: v == '__all__' ? null : v);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: '__all__', child: Text('Všechna auta')),
                ...cars.map(
                    (c) => PopupMenuItem(value: c.id, child: Text(c.fullName))),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Nastavení',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Column(
          children: [
              if (serviceProvider.selectedCarId != null)
                _ServiceFilterBanner(
                  carName: carProvider.getCarById(serviceProvider.selectedCarId!)?.fullName ?? '',
                  onClear: () => serviceProvider.loadRecords(),
                ),
              if (reminders.isNotEmpty)
                _RemindersSection(
                  reminders: reminders,
                  carProvider: carProvider,
                ),
              if (serviceProvider.records.isNotEmpty)
                _SummaryBar(provider: serviceProvider),
              Expanded(
                child: serviceProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : displayed.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.build_circle_outlined,
                                    size: 72, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  cars.isEmpty ? 'Nejprve přidej auto' : 'Žádné záznamy',
                                  style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                Text(
                                  cars.isEmpty
                                      ? 'Přejdi na záložku Auta a přidej\nsvé vozidlo. Pak budeš moci přidávat servisní záznamy.'
                                      : 'Přidej první servisní záznam',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: displayed.length,
                            itemBuilder: (context, i) {
                              final record = displayed[i];
                              final car = carProvider.getCarById(record.carId);
                              return _ServiceTile(
                                record: record,
                                carName: car?.fullName ?? '',
                              );
                            },
                          ),
              ),
          ],
      ),
      floatingActionButton: cars.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab_service',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddEditServiceScreen())),
              icon: const Icon(Icons.add),
              label: const Text('Přidat záznam'),
            ),
    );
  }
}

// ---------- Filter banner ----------

/// Thin coloured banner displayed when a car filter is active in [ServiceScreen].
///
/// Mirrors the design of [_FilterBanner] used in [TripsScreen].
class _ServiceFilterBanner extends StatelessWidget {
  final String carName;
  final VoidCallback onClear;
  const _ServiceFilterBanner({required this.carName, required this.onClear});

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

// ---------- Reminders ----------

/// Section widget that groups all upcoming/overdue service reminders.
///
/// Rendered above the main list. Each item is a [_ReminderTile] whose
/// background colour indicates urgency (red = overdue, orange = due soon).
class _RemindersSection extends StatelessWidget {
  /// List of reminder structs returned by [ServiceProvider.getReminders].
  final List<({ServiceRecord record, bool isOverdue, bool isDueSoon})> reminders;
  final CarProvider carProvider;

  const _RemindersSection({
    required this.reminders,
    required this.carProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text(
            'Nadcházející servis',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        ...reminders.map((r) => _ReminderTile(
              reminder: r,
              carProvider: carProvider,
            )),
        const Divider(height: 1),
      ],
    );
  }
}

/// Individual reminder row inside [_RemindersSection].
///
/// Shows the service type icon, label, car name, and either a date (from
/// [ServiceRecord.nextDueDate]) or an odometer threshold
/// ([ServiceRecord.nextDueOdometer]) or both. Tapping opens the record
/// in [AddEditServiceScreen].
class _ReminderTile extends StatelessWidget {
  /// The reminder data record with its urgency flags.
  final ({ServiceRecord record, bool isOverdue, bool isDueSoon}) reminder;
  final CarProvider carProvider;

  const _ReminderTile({required this.reminder, required this.carProvider});

  /// Shared date formatter for the due-date display.
  static final _dateFmt = DateFormat('d. M. yyyy');

  @override
  Widget build(BuildContext context) {
    final r = reminder.record;
    final isOverdue = reminder.isOverdue;
    final car = carProvider.getCarById(r.carId);
    final icon = AppConstants.serviceTypeIcons[r.serviceType] ?? '🔧';
    final label =
        AppConstants.serviceTypeLabels[r.serviceType] ?? r.serviceType;

    final bgColor = isOverdue
        ? Colors.red.shade50
        : Colors.orange.shade50;
    final borderColor = isOverdue ? Colors.red.shade400 : Colors.orange.shade400;
    final iconColor = isOverdue ? Colors.red : Colors.orange;

    final List<Widget> dueParts = [];
    if (r.nextDueDate != null) {
      final dateStr = _ReminderTile._dateFmt.format(r.nextDueDate!);
      dueParts.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event, size: 13, color: iconColor),
          const SizedBox(width: 3),
          Text(
            isOverdue ? 'Prošlo $dateStr' : 'Do $dateStr',
            style: TextStyle(fontSize: 12, color: iconColor, fontWeight: FontWeight.w600),
          ),
        ],
      ));
    }
    if (r.nextDueOdometer != null) {
      dueParts.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speed, size: 13, color: iconColor),
          const SizedBox(width: 3),
          Text(
            'Při ${r.nextDueOdometer!.toStringAsFixed(0)} km',
            style: TextStyle(fontSize: 12, color: iconColor, fontWeight: FontWeight.w600),
          ),
        ],
      ));
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddEditServiceScreen(record: r),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (car != null)
                      Text(car.fullName,
                          style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                    const SizedBox(height: 2),
                    Wrap(spacing: 10, runSpacing: 2, children: dueParts),
                  ],
                ),
              ),
              Icon(isOverdue ? Icons.warning_rounded : Icons.access_time_rounded,
                  color: iconColor),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Summary & Tiles ----------

/// Horizontal summary banner showing total service cost and record count
/// for the currently filtered set of records.
class _SummaryBar extends StatelessWidget {
  /// The provider whose [ServiceProvider.totalServiceCost] and
  /// [ServiceProvider.records] are displayed.
  final ServiceProvider provider;
  const _SummaryBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Celkové náklady na servis',
                    style: Theme.of(context).textTheme.labelMedium),
                Text(
                  '${provider.totalServiceCost.toStringAsFixed(0)} Kč',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${provider.records.length} záznamů',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// List tile for a single [ServiceRecord].
///
/// - Shows service type icon, label, car name, date, odometer, cost, and note.
/// - Optional attachment opens via [OpenFilex.open] when the attachment icon
///   is tapped (PDF uses a PDF icon; images use an image icon).
/// - The delete icon button presents a confirmation dialog before calling
///   [ServiceProvider.deleteRecord].
class _ServiceTile extends StatelessWidget {
  final ServiceRecord record;
  final String carName;
  const _ServiceTile({required this.record, required this.carName});

  static final _dateFmt = DateFormat('d. M. yyyy');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = AppConstants.serviceTypeIcons[record.serviceType] ?? '🔧';
    final label =
        AppConstants.serviceTypeLabels[record.serviceType] ?? record.serviceType;
    final dateStr = _dateFmt.format(record.date);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AddEditServiceScreen(record: record))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(icon, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (carName.isNotEmpty)
                      Text(carName,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today,
                                size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(dateStr,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.speed,
                                size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                                '${record.odometer.toStringAsFixed(0)} km',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ],
                    ),
                    if (record.note != null)
                      Text(record.note!,
                          style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[600])),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 90),
                    child: Text(
                      '${record.cost.toStringAsFixed(0)} Kč',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Smazat záznam?'),
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
                        await context.read<ServiceProvider>().deleteRecord(record.id);
                      }
                    },
                  ),
                  if (record.attachmentPath != null)
                    IconButton(
                      icon: Icon(
                        record.attachmentPath!.toLowerCase().endsWith('.pdf')
                            ? Icons.picture_as_pdf_outlined
                            : Icons.image_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      tooltip: 'Otevřít přílohu',
                      onPressed: () => OpenFilex.open(record.attachmentPath!),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
