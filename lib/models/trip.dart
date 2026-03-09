const _tripCopyWithUnset = Object();

/// Data model for a single trip.
///
/// Holds all recorded measurements (odometer readings, fuel, speed, weather, etc.)
/// as well as computed properties (distance, consumption, driver score).
///
/// **Driver score** is composed of three sub-scores:
/// 1. [smoothnessScore] — average-to-max speed ratio, corrected for traffic density
/// 2. [anticipationScoreFor] — fuel consumption vs. the car's historical baseline, corrected for traffic
/// 3. [speedingScore] — max speed vs. the legal limit for the route type (trailer limits applied when applicable)
///
/// The model is immutable; use [copyWith] to produce modified copies.
class Trip {
  final String id;
  final String carId;
  final DateTime date;

  // --- ODOMETER ---
  final double odometerStart; // km at trip start
  final double odometerEnd;   // km at trip end

  // --- FUEL ---
  final double? fuelAdded;          // litres added at refuel (null if not refuelled)
  final double? fuelPricePerLiter;  // price per litre in CZK
  final double? fullTankCost;       // total refuel cost in CZK

  // --- TRIP DETAILS ---
  final int drivingDuration;       // driving time in minutes
  final String routeType;          // 'city' | 'highway' | 'mixed' | 'offroad'
  final String weatherCondition;   // 'clear' | 'rain' | 'snow' | 'fog' | 'wind' | 'hot'
  final int trafficLevel;          // 1 (free) … 5 (traffic jam)
  final double? maxSpeed;          // maximum speed recorded during the trip (km/h)
  final double? averageSpeed;      // average speed from the trip computer (km/h)

  // --- COMFORT ---
  final bool acUsed;     // true = air conditioning was running
  final int? outsideTemp; // outside temperature in °C

  /// Fuel consumption read directly from the on-board computer (l/100 km).
  /// Preferred over the calculated value; see [fuelConsumption].
  final double? tripComputerConsumption;

  /// `true` when the tank was filled to the brim at this refuel.
  /// Required for the fill-to-fill average consumption calculation.
  final bool fullTank;

  /// ID of the attached trailer/caravan, or `null` when towing nothing.
  /// When set, [speedingScore] applies the lower CZ legal speed limits.
  final String? trailerId;

  // --- OPTIONAL METADATA ---
  final String? startLocation; // free-text departure label
  final String? endLocation;   // free-text destination label
  final String? note;

  Trip({
    required this.id,
    required this.carId,
    required this.date,
    required this.odometerStart,
    required this.odometerEnd,
    this.fuelAdded,
    this.fuelPricePerLiter,
    this.fullTankCost,
    required this.drivingDuration,
    required this.routeType,
    required this.weatherCondition,
    required this.trafficLevel,
    this.maxSpeed,
    this.averageSpeed,
    required this.acUsed,
    this.outsideTemp,
    this.tripComputerConsumption,
    this.fullTank = false,
    this.trailerId,
    this.startLocation,
    this.endLocation,
    this.note,
  });

  // --- COMPUTED PROPERTIES ---

  /// Trip distance in km (odometerEnd − odometerStart).
  double get distance => odometerEnd - odometerStart;

  /// Fuel consumption in l/100 km.
  ///
  /// Prefers the on-board computer reading ([tripComputerConsumption]).
  /// Falls back to an estimate from litres added ÷ distance when no direct
  /// reading is available (less accurate because it includes previous trips
  /// between full-tank events).
  double? get fuelConsumption {
    if (tripComputerConsumption != null) return tripComputerConsumption;
    if (fuelAdded == null || distance <= 0) return null;
    return (fuelAdded! / distance) * 100;
  }

  /// Cost per kilometre in CZK/km.
  double? get costPerKm {
    if (fullTankCost == null || distance <= 0) return null;
    return fullTankCost! / distance;
  }

  /// Effective average speed in km/h.
  ///
  /// Uses the recorded [averageSpeed] if available; otherwise derives it from
  /// distance ÷ duration (km ÷ minutes × 60).
  double? get effectiveAvgSpeed {
    if (averageSpeed != null && averageSpeed! > 0) return averageSpeed;
    if (drivingDuration > 0 && distance > 0) {
      return distance / (drivingDuration / 60.0);
    }
    return null;
  }

  /// Driving smoothness score (1–10): average speed ÷ max speed × 10.
  ///
  /// A higher avg/max ratio means fewer harsh accelerations and a smoother
  /// driving style.  A traffic-density bonus compensates for unavoidable
  /// stop-and-go in congestion:
  ///   level 1 (free) +0.0 · level 2 +0.5 · level 3 +1.2 · level 4 +2.0 · level 5 (jam) +3.0
  static const _trafficSmoothnessBonus = [0.0, 0.0, 0.5, 1.2, 2.0, 3.0];

  double? get smoothnessScore {
    final avg = effectiveAvgSpeed;
    if (avg == null || maxSpeed == null || maxSpeed! <= 0) return null;
    final base = avg / maxSpeed! * 10;
    final bonus = (trafficLevel >= 1 && trafficLevel <= 5)
        ? _trafficSmoothnessBonus[trafficLevel]
        : 0.0;
    return (base + bonus).clamp(1.0, 10.0);
  }

  /// Speed-compliance score (1–10): max recorded speed vs. the legal limit
  /// for the route type.  Every 8 km/h over the limit deducts 1 point.
  static const _routeLimits = {
    'city': 50.0,
    'highway': 130.0,
    'mixed': 90.0,
    'offroad': 40.0,
  };

  /// Reduced limits when towing (CZ law): max 80 km/h on motorways/roads,
  /// 50 km/h in urban areas, 30 km/h off-road.
  static const _routeLimitsWithTrailer = {
    'city': 50.0,
    'highway': 80.0,
    'mixed': 80.0,
    'offroad': 30.0,
  };

  double? get speedingScore {
    if (maxSpeed == null) return null;
    final limits =
        trailerId != null ? _routeLimitsWithTrailer : _routeLimits;
    final limit = limits[routeType] ?? 90.0;
    final over = (maxSpeed! - limit).clamp(0.0, double.infinity);
    return (10.0 - over / 8.0).clamp(1.0, 10.0);
  }

  /// Anticipation / eco-driving score (1–10): actual consumption vs. baseline.
  ///
  /// [baseline] is either the fill-to-fill historical average for the car
  /// (computed by [TripProvider.fillToFillAvgConsumption]) or the typical
  /// consumption from the car's specs sheet as a fallback.
  ///
  /// A traffic-density tolerance is applied (+5.5 % per level above 1)
  /// because stop-and-go naturally raises fuel consumption:
  ///   level 1 ×1.00 · level 2 ×1.055 · level 3 ×1.11 · level 4 ×1.165 · level 5 ×1.22
  double? anticipationScoreFor(double? baseline) {
    if (fuelConsumption == null || baseline == null || baseline <= 0) return null;
    final trafficMultiplier = 1.0 + (trafficLevel - 1) * 0.055;
    final adjustedBaseline = baseline * trafficMultiplier;
    return (adjustedBaseline / fuelConsumption! * 8.5).clamp(1.0, 10.0);
  }

  /// Overall driving score (1–10): arithmetic mean of all available
  /// sub-scores ([smoothnessScore], [anticipationScoreFor], [speedingScore]).
  ///
  /// [baseline] is passed to [anticipationScoreFor]; supply `null` to exclude
  /// the anticipation component when no baseline is available yet.
  double? drivingScoreFor(double? baseline) {
    final scores = [
      smoothnessScore,
      anticipationScoreFor(baseline),
      speedingScore,
    ].whereType<double>().toList();
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  /// Overall score without the anticipation component (used when no baseline
  /// is available for a car).
  double? get drivingScore => drivingScoreFor(null);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'carId': carId,
      'date': date.toIso8601String(),
      'odometerStart': odometerStart,
      'odometerEnd': odometerEnd,
      'fuelAdded': fuelAdded,
      'fuelPricePerLiter': fuelPricePerLiter,
      'fullTankCost': fullTankCost,
      'drivingDuration': drivingDuration,
      'routeType': routeType,
      'weatherCondition': weatherCondition,
      'trafficLevel': trafficLevel,
      'maxSpeed': maxSpeed,
      'averageSpeed': averageSpeed,
      'acUsed': acUsed ? 1 : 0,
      'outsideTemp': outsideTemp,
      'tripComputerConsumption': tripComputerConsumption,
      'fullTank': fullTank ? 1 : 0,
      'trailerId': trailerId,
      'startLocation': startLocation,
      'endLocation': endLocation,
      'note': note,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'],
      carId: map['carId'],
      date: DateTime.parse(map['date']),
      odometerStart: (map['odometerStart'] as num).toDouble(),
      odometerEnd: (map['odometerEnd'] as num).toDouble(),
      fuelAdded: (map['fuelAdded'] as num?)?.toDouble(),
      fuelPricePerLiter: (map['fuelPricePerLiter'] as num?)?.toDouble(),
      fullTankCost: (map['fullTankCost'] as num?)?.toDouble(),
      drivingDuration: map['drivingDuration'] as int,
      routeType: map['routeType'],
      weatherCondition: map['weatherCondition'],
      trafficLevel: map['trafficLevel'] as int,
      maxSpeed: (map['maxSpeed'] as num?)?.toDouble(),
      averageSpeed: (map['averageSpeed'] as num?)?.toDouble(),
      acUsed: map['acUsed'] == 1,
      outsideTemp: map['outsideTemp'] as int?,
      tripComputerConsumption: (map['tripComputerConsumption'] as num?)?.toDouble(),
      fullTank: (map['fullTank'] as int?) == 1,
      trailerId: map['trailerId'],
      startLocation: map['startLocation'],
      endLocation: map['endLocation'],
      note: map['note'],
    );
  }

  Trip copyWith({
    String? id,
    String? carId,
    DateTime? date,
    double? odometerStart,
    double? odometerEnd,
    Object? fuelAdded = _tripCopyWithUnset,
    Object? fuelPricePerLiter = _tripCopyWithUnset,
    Object? fullTankCost = _tripCopyWithUnset,
    int? drivingDuration,
    String? routeType,
    String? weatherCondition,
    int? trafficLevel,
    Object? maxSpeed = _tripCopyWithUnset,
    Object? averageSpeed = _tripCopyWithUnset,
    bool? acUsed,
    Object? outsideTemp = _tripCopyWithUnset,
    Object? tripComputerConsumption = _tripCopyWithUnset,
    bool? fullTank,
    Object? trailerId = _tripCopyWithUnset,
    Object? startLocation = _tripCopyWithUnset,
    Object? endLocation = _tripCopyWithUnset,
    Object? note = _tripCopyWithUnset,
  }) {
    return Trip(
      id: id ?? this.id,
      carId: carId ?? this.carId,
      date: date ?? this.date,
      odometerStart: odometerStart ?? this.odometerStart,
      odometerEnd: odometerEnd ?? this.odometerEnd,
      fuelAdded: fuelAdded == _tripCopyWithUnset ? this.fuelAdded : fuelAdded as double?,
      fuelPricePerLiter: fuelPricePerLiter == _tripCopyWithUnset ? this.fuelPricePerLiter : fuelPricePerLiter as double?,
      fullTankCost: fullTankCost == _tripCopyWithUnset ? this.fullTankCost : fullTankCost as double?,
      drivingDuration: drivingDuration ?? this.drivingDuration,
      routeType: routeType ?? this.routeType,
      weatherCondition: weatherCondition ?? this.weatherCondition,
      trafficLevel: trafficLevel ?? this.trafficLevel,
      maxSpeed: maxSpeed == _tripCopyWithUnset ? this.maxSpeed : maxSpeed as double?,
      averageSpeed: averageSpeed == _tripCopyWithUnset ? this.averageSpeed : averageSpeed as double?,
      acUsed: acUsed ?? this.acUsed,
      outsideTemp: outsideTemp == _tripCopyWithUnset ? this.outsideTemp : outsideTemp as int?,
      tripComputerConsumption: tripComputerConsumption == _tripCopyWithUnset ? this.tripComputerConsumption : tripComputerConsumption as double?,
      fullTank: fullTank ?? this.fullTank,
      trailerId: trailerId == _tripCopyWithUnset ? this.trailerId : trailerId as String?,
      startLocation: startLocation == _tripCopyWithUnset ? this.startLocation : startLocation as String?,
      endLocation: endLocation == _tripCopyWithUnset ? this.endLocation : endLocation as String?,
      note: note == _tripCopyWithUnset ? this.note : note as String?,
    );
  }
}
