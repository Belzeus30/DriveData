import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/trip.dart';
import '../../providers/car_provider.dart';
import '../../providers/insurance_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/trip_provider.dart';
import '../settings/settings_screen.dart';

/// Analytics dashboard screen.
///
/// Aggregates driving behaviour and cost metrics from [TripProvider],
/// [ServiceProvider], and [InsuranceProvider]. A car filter dropdown in the
/// AppBar delegates to [TripProvider.setCarFilter] so that all sub-sections
/// (overview cards, charts, TCO) react in sync.
///
/// Key sub-sections:
/// - [_OverviewCards] — total km, trips, avg score, avg fuel.
/// - Driving-score and fuel-consumption line trends (via [_LineChartWidget]).
/// - Route-type fuel comparison (via [_RouteBarChart]).
/// - [_DetailedScores] — per-skill averages (smoothness, anticipation, speeding).
/// - [_TcoSection] — total cost of ownership breakdown.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

/// State for [AnalyticsScreen].
///
/// Holds [_selectedCarId] and synchronises it with [TripProvider.setCarFilter].
class _AnalyticsScreenState extends State<AnalyticsScreen> {
  /// The car UUID currently selected in the filter dropdown, or `null` for all cars.
  String? _selectedCarId;

  @override
  Widget build(BuildContext context) {
    final carProvider = context.watch<CarProvider>();
    final tripProvider = context.watch<TripProvider>();
    final serviceProvider = context.watch<ServiceProvider>();
    final insuranceProvider = context.watch<InsuranceProvider>();
    final cars = carProvider.cars;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analýza'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Nastavení',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
        bottom: cars.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedCarId,
                    decoration: InputDecoration(
                      labelText: 'Vozidlo',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Všechna vozidla')),
                      ...cars.map((c) => DropdownMenuItem(value: c.id, child: Text(c.fullName))),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedCarId = v);
                      tripProvider.setCarFilter(v);
                    },
                  ),
                ),
              ),
      ),
      body: Builder(builder: (context) {
        final trips = tripProvider.filteredTrips;
        if (trips.isEmpty) {
          return const Center(
            child: Text('Žádná data k zobrazení.\nPřidej první jízdy!',
                textAlign: TextAlign.center),
          );
        }

        final baselines = tripProvider.baselinePerCar;
        final carFallback = {for (final c in cars) c.id: c.typicalConsumption};
        double? baselineFor(Trip t) =>
            baselines[t.carId] ?? carFallback[t.carId];
        final scoreTrend = tripProvider.getDrivingScoreTrend(baselineFor: baselineFor);
        final fuelTrend = tripProvider.getFuelConsumptionTrend();
        final byRoute = tripProvider.consumptionByRouteType;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- OVERVIEW CARDS ---
            _OverviewCards(provider: tripProvider, carProvider: carProvider, baselineFor: baselineFor),
            const SizedBox(height: 24),

            // --- SCORE TREND ---
            if (scoreTrend.length >= 2) ...[
              _ChartTitle('Trend skóre řidiče', 'Posledních ${scoreTrend.length} jízd'),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: _LineChartWidget(
                  data: scoreTrend,
                  minY: 1,
                  maxY: 10,
                  yInterval: 2,
                  color: Colors.blue,
                  dotColor: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 24),
            ],

            // --- CONSUMPTION TREND ---
            if (fuelTrend.length >= 2) ...[
              _ChartTitle('Trend spotřeby paliva', 'l/100 km · posledních ${fuelTrend.length} tankování'),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: _LineChartWidget(
                  data: fuelTrend,
                  color: Colors.orange,
                  dotColor: Colors.deepOrange,
                ),
              ),
              const SizedBox(height: 24),
            ],

            // --- CONSUMPTION BY ROUTE ---
            if (byRoute.isNotEmpty) ...[
              const _ChartTitle('Průměrná spotřeba dle trasy', 'l/100 km'),
              const SizedBox(height: 8),
              _RouteBarChart(data: byRoute),
              const SizedBox(height: 24),
            ],

            // --- DETAILED SCORES ---
            _DetailedScores(provider: tripProvider, baselineFor: baselineFor),
            const SizedBox(height: 32),

            // --- TOTAL COST OF OWNERSHIP (TCO) ---
            _TcoSection(
              tripProvider: tripProvider,
              serviceProvider: serviceProvider,
              insuranceProvider: insuranceProvider,
              selectedCarId: _selectedCarId,
            ),
          ],
        );
      }),
    );
  }
}

// -----------------------------------------------------------------------
// TCO — total cost of ownership

/// Section widget showing the Total Cost of Ownership breakdown per category.
///
/// Computes monthly fuel costs from trip refuel events, pulls service and
/// insurance costs from their respective providers, and presents cumulative
/// totals in [_TcoCard] tiles plus a stacked-bar monthly history.
class _TcoSection extends StatelessWidget {
  final TripProvider tripProvider;
  final ServiceProvider serviceProvider;
  final InsuranceProvider insuranceProvider;
  final String? selectedCarId;

  const _TcoSection({
    required this.tripProvider,
    required this.serviceProvider,
    required this.insuranceProvider,
    required this.selectedCarId,
  });

  static final _fmt = NumberFormat('#,##0', 'cs');

  /// Returns a map of month key (`YYYY-MM`) to total fuel (refuel) costs.
  Map<String, double> _monthlyFuelCosts() {
    final result = <String, double>{};
    for (final t in tripProvider.filteredTrips) {
      if (t.fullTankCost == null) continue;
      final key =
          '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      result[key] = (result[key] ?? 0) + t.fullTankCost!;
    }
    return result;
  }

  /// Returns a map of month key to service costs.
  Map<String, double> _monthlyServiceCosts() {
    final result = <String, double>{};
    final records = selectedCarId == null
        ? serviceProvider.records
        : serviceProvider.records
            .where((r) => r.carId == selectedCarId)
            .toList();
    for (final r in records) {
      final key =
          '${r.date.year}-${r.date.month.toString().padLeft(2, '0')}';
      result[key] = (result[key] ?? 0) + r.cost;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fuelMonthly = _monthlyFuelCosts();
    final serviceMonthly = _monthlyServiceCosts();

    // Celkov\u00e9 sou\u010dty
    final totalFuel =
        fuelMonthly.values.fold(0.0, (s, v) => s + v);
    final totalService =
        serviceMonthly.values.fold(0.0, (s, v) => s + v);
    final annualInsurance = selectedCarId != null
        ? insuranceProvider.annualCostForCar(selectedCarId!)
        : insuranceProvider.policies
            .where((p) => p.isActive)
            .fold(0.0, (s, p) => s + (p.costPerYear ?? 0));
    final total = totalFuel + totalService + annualInsurance;

    if (total == 0) return const SizedBox.shrink();

    // Posledn\u00edch 6 m\u011bs\u00edc\u016f
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - 5 + i, 1);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Celkové n\u00e1klady na vozidlo (TCO)',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Palivo + servis + pojistky',
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 12),

        // -- Shrnut\u00ed karet --
        Row(
          children: [
            _TcoCard('Palivo', totalFuel, Colors.orange.shade100),
            const SizedBox(width: 8),
            _TcoCard('Servis', totalService, Colors.blue.shade100),
            const SizedBox(width: 8),
            _TcoCard('Pojistky / rok', annualInsurance, Colors.purple.shade100),
          ],
        ),
        const SizedBox(height: 12),

        // -- Celkov\u00e1 suma --
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Celkem evidováno',
                  style: theme.textTheme.labelMedium),
              Text(
                '${_fmt.format(total)} Kč',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // -- M\u011bs\u00ed\u010dn\u00ed sloupcov\u00fd graf (palivo + servis) --
        if (months.any((m) =>
            (fuelMonthly[m] ?? 0) > 0 ||
            (serviceMonthly[m] ?? 0) > 0)) ...[
          Text('M\u011bs\u00ed\u010dn\u00ed n\u00e1klady — posledn\u00edch 6 m\u011bs\u00edc\u016f',
              style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: months
                        .map((m) =>
                            (fuelMonthly[m] ?? 0) +
                            (serviceMonthly[m] ?? 0))
                        .reduce((a, b) => a > b ? a : b) *
                    1.3,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(
                    show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (val, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          _fmt.format(val.toInt()),
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
                        final parts = months[idx].split('-');
                        return SideTitleWidget(
                          meta: meta,
                          child: Text('${parts[1]}/${parts[0].substring(2)}',
                              style: const TextStyle(fontSize: 9)),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                barGroups: months.asMap().entries.map((e) {
                  final fuel = fuelMonthly[e.value] ?? 0;
                  final service = serviceMonthly[e.value] ?? 0;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: fuel + service,
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                        rodStackItems: [
                          BarChartRodStackItem(0, fuel,
                              Colors.orange.shade400),
                          BarChartRodStackItem(
                              fuel, fuel + service, Colors.blue.shade400),
                        ],
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(Colors.orange, 'Palivo'),
              SizedBox(width: 12),
              _Legend(Colors.blue, 'Servis'),
            ],
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

/// Compact summary card for a single TCO cost category (fuel/service/insurance).
///
/// Displays the total amount formatted in Czech locale and a short [label].
class _TcoCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _TcoCard(this.label, this.value, this.color);

  /// Czech-locale number formatter (e.g. `12 345`).
  static final _fmt = NumberFormat('#,##0', 'cs');

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            FittedBox(
              child: Text(
                  '${_fmt.format(value)} Kč',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

/// Small colour swatch + label used in chart legends.
class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

// -----------------------------------------------------------------------

/// Responsive grid of summary stat cards at the top of the analytics screen.
///
/// Renders total distance, trip count, average driving score, and average
/// fuel consumption. Uses [LayoutBuilder] to decide between a 2-column and
/// 4-column grid based on available width.
class _OverviewCards extends StatelessWidget {
  final TripProvider provider;
  final CarProvider carProvider;
  final double? Function(Trip) baselineFor;
  const _OverviewCards({
    required this.provider,
    required this.carProvider,
    required this.baselineFor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avgScore = provider.averageDrivingScoreWith(baselineFor: baselineFor);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Aspect ratio adapts to actual card width so text never overflows
        final cardWidth = (constraints.maxWidth - 12) / 2;
        final aspectRatio = (cardWidth / 100).clamp(1.2, 2.0);
        final crossCount = constraints.maxWidth >= 800 ? 3 : 2;
        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: aspectRatio,
          children: [
        _StatCard('Celkem km', '${provider.totalKilometers.toStringAsFixed(0)} km',
            Icons.route, theme.colorScheme.primaryContainer),
        _StatCard(
          'Průměrná spotřeba',
          provider.averageFuelConsumption != null
              ? '${provider.averageFuelConsumption!.toStringAsFixed(1)} l/100km'
              : '–',
          Icons.local_gas_station,
          Colors.orange.shade100,
        ),
        _StatCard('Celkové náklady', '${provider.totalCost.toStringAsFixed(0)} Kč',
            Icons.payments, Colors.green.shade100),
        _StatCard(
          'Průměrné skóre',
          avgScore != null
              ? '${avgScore.toStringAsFixed(1)} / 10'
              : '–',
          Icons.star,
          Colors.amber.shade100,
        ),
        _StatCard('Počet jízd', '${provider.filteredTrips.length}', Icons.list_alt,
            Colors.purple.shade100),
        _StatCard(
          'Náklady / km',
          provider.costPerKmAverage != null
              ? '${provider.costPerKmAverage!.toStringAsFixed(2)} Kč'
              : '–',
          Icons.trending_up,
          Colors.teal.shade100,
        ),
          ],
        );
      },
    );
  }
}

/// A single coloured summary card inside [_OverviewCards].
///
/// Shows an [icon], a large [value] string (auto-scaled via [FittedBox]),
/// and a [label].
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color bgColor;

  const _StatCard(this.label, this.value, this.icon, this.bgColor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Text(label,
              style: const TextStyle(fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Two-line title + subtitle widget placed above each chart.
class _ChartTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _ChartTitle(this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}

/// Simple `fl_chart` [LineChart] wrapper.
///
/// Plots [data] as sequential Y values with automatic scaling between
/// [minY]/[maxY]. Dots use [dotColor] and the line uses [color].
/// An optional [yInterval] controls the left-axis label spacing.
class _LineChartWidget extends StatelessWidget {
  final List<double> data;
  final double? minY;
  final double? maxY;
  final Color color;
  final Color dotColor;
  /// Optional interval between left-axis labels (e.g. 2.0 for a 1–10 score).
  final double? yInterval;

  const _LineChartWidget({
    required this.data,
    this.minY,
    this.maxY,
    required this.color,
    required this.dotColor,
    this.yInterval,
  });

  @override
  Widget build(BuildContext context) {
    final spots = List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i]));

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: yInterval,
              getTitlesWidget: (val, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
              s.y.toStringAsFixed(1),
              const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            )).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 4,
                color: dotColor,
                strokeColor: Colors.white,
                strokeWidth: 2,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal bar chart comparing average fuel consumption by route type.
///
/// Bars are proportionally sized relative to the maximum value in [data].
/// Route type labels are localised from [_routeLabels].
class _RouteBarChart extends StatelessWidget {
  /// Map of route-type key (e.g. `'city'`) to average fuel consumption (l/100 km).
  final Map<String, double> data;
  const _RouteBarChart({required this.data});

  static const _routeLabels = {
    'city': 'Město',
    'highway': 'Dálnice',
    'mixed': 'Kombi',
    'offroad': 'Terén',
  };

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: maxVal * 1.3,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (val, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    val.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final idx = val.toInt();
                  if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                  final key = entries[idx].key;
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(_routeLabels[key] ?? key,
                        style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: List.generate(entries.length, (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: entries[i].value,
                color: Colors.orange,
                width: 32,
                borderRadius: BorderRadius.circular(4),
                rodStackItems: [],
              ),
            ],
            showingTooltipIndicators: [],
          )),
        ),
      ),
    );
  }
}

/// Detailed per-skill driving score section.
///
/// Computes per-trip averages for:
/// - **Smoothness** — from [Trip.smoothnessScore].
/// - **Anticipation** — from [Trip.anticipationScoreFor] (requires baseline).
/// - **Speed compliance** — from [Trip.speedingScore].
///
/// Skipped entirely if no trips have both smoothness and speeding scores.
class _DetailedScores extends StatelessWidget {
  final TripProvider provider;
  /// Returns the per-car baseline fuel consumption for anticipation scoring.
  final double? Function(Trip) baselineFor;
  const _DetailedScores({required this.provider, required this.baselineFor});

  @override
  Widget build(BuildContext context) {
    final trips = provider.filteredTrips;
    // filter trips that have at least smoothness + speeding scores
    final smoothSpeedScored = trips
        .where((t) => t.smoothnessScore != null && t.speedingScore != null)
        .toList();
    if (smoothSpeedScored.isEmpty) return const SizedBox.shrink();

    final avgSmoothness =
        smoothSpeedScored.fold(0.0, (s, t) => s + t.smoothnessScore!) /
            smoothSpeedScored.length;
    final avgSpeeding =
        smoothSpeedScored.fold(0.0, (s, t) => s + t.speedingScore!) /
            smoothSpeedScored.length;

    // anticipation only for trips with an available baseline and consumption
    final anticipationScores = trips.map((t) {
      return t.anticipationScoreFor(baselineFor(t));
    }).whereType<double>().toList();
    final hasAnticipation = anticipationScores.isNotEmpty;
    final avgAnticipation = hasAnticipation
        ? anticipationScores.fold(0.0, (s, v) => s + v) / anticipationScores.length
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Průměrné hodnocení dovedností',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _SkillBar('Plynulost jízdy', avgSmoothness),
        const SizedBox(height: 8),
        if (hasAnticipation && avgAnticipation != null) ...[
          _SkillBar('Předvídavost', avgAnticipation),
          const SizedBox(height: 8),
        ],
        _SkillBar('Dodržování limitů', avgSpeeding),
      ],
    );
  }
}

/// A labelled horizontal progress bar for a single driving skill score out of 10.
///
/// Bar colour is green (≥8), orange (≥6), or red (<6).
class _SkillBar extends StatelessWidget {
  /// Human-readable skill label.
  final String label;
  /// Score in range [0, 10].
  final double value;
  const _SkillBar(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final color = value >= 8
        ? Colors.green
        : value >= 6
            ? Colors.orange
            : Colors.red;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('${value.toStringAsFixed(1)} / 10',
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 10,
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }
}
