import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/trip.dart';
import '../database/database_helper.dart';

class TripProvider with ChangeNotifier {
  List<Trip> _trips = [];
  bool _isLoading = true;
  String? _selectedCarId;
  final _uuid = const Uuid();

  /// Cache for baselinePerCar — invalidated on every data change.
  Map<String, double?>? _baselinePerCarCache;

  /// Cache for latestOdometerPerCar — invalidated on every data change.
  Map<String, double>? _latestOdometerCache;

  List<Trip> get trips => _trips;
  bool get isLoading => _isLoading;
  String? get selectedCarId => _selectedCarId;

  List<Trip> get filteredTrips {
    if (_selectedCarId == null) return _trips;
    return _trips.where((t) => t.carId == _selectedCarId).toList();
  }

  /// Returns the highest recorded odometer end value for each car.
  /// Used by ServiceScreen to determine current odometer without recomputing in build().
  Map<String, double> get latestOdometerPerCar {
    if (_latestOdometerCache != null) return _latestOdometerCache!;
    final result = <String, double>{};
    for (final trip in _trips) {
      final cur = result[trip.carId] ?? 0;
      if (trip.odometerEnd > cur) result[trip.carId] = trip.odometerEnd;
    }
    return _latestOdometerCache = result;
  }

  void setCarFilter(String? carId) {
    _selectedCarId = carId;
    notifyListeners();
  }

  Future<void> loadTrips({String? carId}) async {
    _isLoading = true;
    notifyListeners();
    _trips = await DatabaseHelper.instance.getAllTrips(carId: carId);
    _baselinePerCarCache = null;
    _latestOdometerCache = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTrip({
    required String carId,
    required DateTime date,
    required double odometerStart,
    required double odometerEnd,
    double? fuelAdded,
    double? fuelPricePerLiter,
    double? fullTankCost,
    required int drivingDuration,
    required String routeType,
    required String weatherCondition,
    required int trafficLevel,
    double? maxSpeed,
    double? averageSpeed,
    required bool acUsed,
    int? outsideTemp,
    double? tripComputerConsumption,
    bool fullTank = false,
    String? trailerId,
    String? startLocation,
    String? endLocation,
    String? note,
  }) async {
    final trip = Trip(
      id: _uuid.v4(),
      carId: carId,
      date: date,
      odometerStart: odometerStart,
      odometerEnd: odometerEnd,
      fuelAdded: fuelAdded,
      fuelPricePerLiter: fuelPricePerLiter,
      fullTankCost: fullTankCost,
      drivingDuration: drivingDuration,
      routeType: routeType,
      weatherCondition: weatherCondition,
      trafficLevel: trafficLevel,
      maxSpeed: maxSpeed,
      averageSpeed: averageSpeed,
      acUsed: acUsed,
      outsideTemp: outsideTemp,
      tripComputerConsumption: tripComputerConsumption,
      fullTank: fullTank,
      trailerId: trailerId,
      startLocation: startLocation,
      endLocation: endLocation,
      note: note,
    );
    await DatabaseHelper.instance.insertTrip(trip);
    _trips.add(trip);
    _trips.sort((a, b) => b.date.compareTo(a.date));
    _baselinePerCarCache = null;
    _latestOdometerCache = null;
    notifyListeners();
  }

  Future<void> updateTrip(Trip trip) async {
    await DatabaseHelper.instance.updateTrip(trip);
    final index = _trips.indexWhere((t) => t.id == trip.id);
    if (index != -1) {
      _trips[index] = trip;
      _trips.sort((a, b) => b.date.compareTo(a.date));
      _baselinePerCarCache = null;
      _latestOdometerCache = null;
      notifyListeners();
    }
  }

  Future<void> deleteTrip(String id) async {
    await DatabaseHelper.instance.deleteTrip(id);
    _trips.removeWhere((t) => t.id == id);
    _baselinePerCarCache = null;
    _latestOdometerCache = null;
    notifyListeners();
  }

  // --- ANALYTIKA ---

  double? get averageFuelConsumption {
    // Používá fill-to-fill přes všechna auta ve filtru
    if (_selectedCarId != null) {
      return fillToFillAvgConsumption(_selectedCarId!);
    }
    // Pro všechna auta: reuse cached baseline map to avoid O(n²)
    final values = baselinePerCar.values.whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double get totalKilometers {
    return filteredTrips.fold(0.0, (sum, t) => sum + t.distance);
  }

  double get totalCost {
    return filteredTrips.fold(0.0, (sum, t) => sum + (t.fullTankCost ?? 0));
  }

  double? get costPerKmAverage {
    if (totalKilometers <= 0) return null;
    return totalCost / totalKilometers;
  }

  // --- FILL-TO-FILL SPOTŘEBA ---

  /// Fill-to-fill segmenty pro dané auto (v l/100km).
  /// Každý segment = úplné tankovaní → úplné tankovaní.
  List<double> fillToFillSegments(String carId) {
    final carTrips = _trips
        .where((t) => t.carId == carId)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final segments = <double>[];
    double fuelAcc = 0.0;
    double distAcc = 0.0;
    bool seenFirstFull = false;

    for (final trip in carTrips) {
      fuelAcc += trip.fuelAdded ?? 0.0;
      distAcc += trip.distance;
      if (trip.fullTank) {
        if (seenFirstFull && distAcc > 0 && fuelAcc > 0) {
          segments.add(fuelAcc / distAcc * 100);
        }
        seenFirstFull = true;
        fuelAcc = 0.0;
        distAcc = 0.0;
      }
    }
    return segments;
  }

  /// Průměrná spotřeba z fill-to-fill segmentů (l/100km), nebo null.
  double? fillToFillAvgConsumption(String carId) {
    final segs = fillToFillSegments(carId);
    if (segs.isEmpty) return null;
    return segs.reduce((a, b) => a + b) / segs.length;
  }

  /// Precomputed fill-to-fill baseline per carId.
  /// Cached after first computation and invalidated on every data change.
  /// Use this in list/analytics widgets instead of calling
  /// fillToFillAvgConsumption() per trip to avoid O(n²) behaviour.
  Map<String, double?> get baselinePerCar {
    if (_baselinePerCarCache != null) return _baselinePerCarCache!;
    final carIds = _trips.map((t) => t.carId).toSet();
    _baselinePerCarCache = {for (final id in carIds) id: fillToFillAvgConsumption(id)};
    return _baselinePerCarCache!;
  }

  /// Trend skóre s volitelnou baseline (pro předvídavost)
  List<double> getDrivingScoreTrend(
      {int lastN = 20, double? Function(Trip)? baselineFor}) {
    return filteredTrips
        .map((t) => baselineFor != null
            ? t.drivingScoreFor(baselineFor(t))
            : t.drivingScore)
        .whereType<double>()
        .take(lastN)
        .toList()
        .reversed
        .toList();
  }

  /// Průměrné skóre s volitelnou baseline
  double? averageDrivingScoreWith({double? Function(Trip)? baselineFor}) {
    final scores = filteredTrips
        .map((t) => baselineFor != null
            ? t.drivingScoreFor(baselineFor(t))
            : t.drivingScore)
        .whereType<double>()
        .toList();
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  /// Fill-to-fill segmenty (trend) pro aktuální filtr auta.
  List<double> getFuelConsumptionTrend({int lastN = 20}) {
    final carId = _selectedCarId;
    if (carId == null) return [];
    final segs = fillToFillSegments(carId);
    return segs.length > lastN ? segs.sublist(segs.length - lastN) : segs;
  }

  /// Průměrná spotřeba dle typu trasy — aproximace přes fill-to-fill segmenty.
  /// Pozn.: přesné rozdělení dle trasy při fill-to-fill není možné;
  /// vrací vážený průměr pro každý typ trasy z jizd, kde bylo natankované.
  Map<String, double> get consumptionByRouteType {
    final sums = <String, double>{};
    final counts = <String, int>{};
    for (final trip in filteredTrips) {
      if (trip.fuelAdded != null && trip.distance > 0) {
        final val = trip.fuelAdded! / trip.distance * 100;
        sums[trip.routeType] = (sums[trip.routeType] ?? 0) + val;
        counts[trip.routeType] = (counts[trip.routeType] ?? 0) + 1;
      }
    }
    return {for (final key in sums.keys) key: sums[key]! / counts[key]!};
  }
}
