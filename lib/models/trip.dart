const _tripCopyWithUnset = Object();

class Trip {
  final String id;
  final String carId;
  final DateTime date;

  // --- VZDÁLENOST ---
  final double odometerStart;
  final double odometerEnd;

  // --- PALIVO ---
  final double? fuelAdded;
  final double? fuelPricePerLiter;
  final double? fullTankCost;

  // --- JÍZDA ---
  final int drivingDuration;
  final String routeType;
  final String weatherCondition;
  final int trafficLevel;
  final double? maxSpeed;
  final double? averageSpeed;

  // --- KLIMATIZACE / KOMFORT ---
  final bool acUsed;
  final int? outsideTemp;

  // --- SPOTŘEBA Z PALUBÁKU ---
  /// Spotřeba naměřená palubním počítačem (l/100 km) — přímý odečet po jízdě
  final double? tripComputerConsumption;

  // --- TANKOVÁNÍ DO PLNA ---
  /// true = při tomto záznamu bylo tankováno DO PLNA (pro fill-to-fill výpočet)
  final bool fullTank;

  // --- VOZÍK ---
  /// ID přívěsu/vozíku, pokud byl při jízdě připojen (null = jela bez vozíku)
  final String? trailerId;

  // --- PŘIDANÉ HODNOTY ---
  final String? startLocation;
  final String? endLocation;
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

  // --- VYPOČÍTANÉ VLASTNOSTI ---

  /// Vzdálenost jízdy v km
  double get distance => odometerEnd - odometerStart;

  /// Spotřeba pro tuto jízdu — preferuje přímý odečet z palubního počítače;
  /// pokud není zadán, odhadne z natankovaného paliva (nepřesné).
  double? get fuelConsumption {
    if (tripComputerConsumption != null) return tripComputerConsumption;
    if (fuelAdded == null || distance <= 0) return null;
    return (fuelAdded! / distance) * 100;
  }

  /// Náklady na km (Kč/km)
  double? get costPerKm {
    if (fullTankCost == null || distance <= 0) return null;
    return fullTankCost! / distance;
  }

  /// Efektivní průměrná rychlost – ze zadaného pole, nebo dopočítaná z km/min
  double? get effectiveAvgSpeed {
    if (averageSpeed != null && averageSpeed! > 0) return averageSpeed;
    if (drivingDuration > 0 && distance > 0) {
      return distance / (drivingDuration / 60.0);
    }
    return null;
  }

  /// Plynulost jízdy (1–10): průměrná / maximální rychlost
  /// Čím vyšší poměr avg/max, tím plynulejší jízda (méně prudkých akcelerací).
  /// Hustota provozu kompenzuje nevyhnutelný stop-go efekt:
  ///   1=volno +0.0, 2=mírný +0.5, 3=střední +1.2, 4=hustý +2.0, 5=zácpa +3.0
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

  /// Dodržování limitů (1–10): max rychlost vs. typický limit pro typ trasy
  /// Každých 8 km/h nad limit = −1 bod
  static const _routeLimits = {
    'city': 50.0,
    'highway': 130.0,
    'mixed': 90.0,
    'offroad': 40.0,
  };

  /// Limity s vozíkem: CZ zákon — max 80 km/h na dálnici/silnici, 50 ve městě, 30 v terénu
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

  /// Předvídavost (1–10): skutečná spotřeba vs. baseline
  /// baseline = historický průměr auta (v4) nebo typická spotřeba z TP.
  /// Hustota provozu zvyšuje toleranci (+5.5 % baseline na stupeň nad 1):
  ///   1=volno ×1.00, 2=mírný ×1.055, 3=střední ×1.11, 4=hustý ×1.165, 5=zácpa ×1.22
  double? anticipationScoreFor(double? baseline) {
    if (fuelConsumption == null || baseline == null || baseline <= 0) return null;
    final trafficMultiplier = 1.0 + (trafficLevel - 1) * 0.055;
    final adjustedBaseline = baseline * trafficMultiplier;
    return (adjustedBaseline / fuelConsumption! * 8.5).clamp(1.0, 10.0);
  }

  /// Celkové skóre: průměr všech 3 složek (požaduje baseline pro předvídavost)
  double? drivingScoreFor(double? baseline) {
    final scores = [
      smoothnessScore,
      anticipationScoreFor(baseline),
      speedingScore,
    ].whereType<double>().toList();
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  /// Celkové skóre bez předvídavosti (pro případy bez baseline)
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
