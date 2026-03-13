const _carCopyWithUnset = Object();

/// Data model for a vehicle.
///
/// Stores the technical specifications entered by the user when adding a car.
///
/// [typicalConsumption] is an optional typical consumption from the owner's
/// manual or on-board computer.  It acts as the initial baseline for
/// [Trip.anticipationScoreFor] until enough fill-to-fill data is accumulated.
///
/// The model is immutable; use [copyWith] to produce modified copies.
class Car {
  final String id;
  final String vehicleType;       // 'Auto' | 'Motorka / Skútr'
  final String make;              // Brand (e.g. Škoda, VW, BMW)
  final String model;             // Model name (e.g. Octavia, Golf)
  final int year;                 // Year of manufacture
  final String fuelType;          // 'Benzín' | 'Diesel' | 'LPG' | 'CNG' | 'Elektro' | 'Hybrid'
  final double tankCapacity;      // Fuel tank capacity in litres
  final double engineVolume;      // Engine displacement in litres
  final int enginePower;          // Engine power in kW
  final double? typicalConsumption; // Typical fuel consumption in l/100 km (from specs)
  final String? spz;              // License plate — optional (e.g. old mopeds may not have one)
  final String? note;

  Car({
    required this.id,
    this.vehicleType = 'Auto',
    required this.make,
    required this.model,
    required this.year,
    required this.fuelType,
    required this.tankCapacity,
    required this.engineVolume,
    required this.enginePower,
    this.typicalConsumption,
    this.spz,
    this.note,
  });

  bool get isMotorcycle => vehicleType == 'Motorka / Skútr';

  String get fullName => '$make $model ($year)';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicleType': vehicleType,
      'make': make,
      'model': model,
      'year': year,
      'fuelType': fuelType,
      'tankCapacity': tankCapacity,
      'engineVolume': engineVolume,
      'enginePower': enginePower,
      'typicalConsumption': typicalConsumption,
      'spz': spz,
      'note': note,
    };
  }

  factory Car.fromMap(Map<String, dynamic> map) {
    return Car(
      id: map['id'] as String,
      vehicleType: (map['vehicleType'] as String?) ?? 'Auto',
      make: map['make'] as String,
      model: map['model'] as String,
      year: (map['year'] as num).toInt(),
      fuelType: map['fuelType'] as String,
      tankCapacity: (map['tankCapacity'] as num).toDouble(),
      engineVolume: (map['engineVolume'] as num).toDouble(),
      enginePower: (map['enginePower'] as num).toInt(),
      typicalConsumption: (map['typicalConsumption'] as num?)?.toDouble(),
      spz: map['spz'] as String?,
      note: map['note'] as String?,
    );
  }

  Car copyWith({
    String? id,
    String? vehicleType,
    String? make,
    String? model,
    int? year,
    String? fuelType,
    double? tankCapacity,
    double? engineVolume,
    int? enginePower,
    Object? typicalConsumption = _carCopyWithUnset,
    Object? spz = _carCopyWithUnset,
    Object? note = _carCopyWithUnset,
  }) {
    return Car(
      id: id ?? this.id,
      vehicleType: vehicleType ?? this.vehicleType,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      fuelType: fuelType ?? this.fuelType,
      tankCapacity: tankCapacity ?? this.tankCapacity,
      engineVolume: engineVolume ?? this.engineVolume,
      enginePower: enginePower ?? this.enginePower,
      typicalConsumption: typicalConsumption == _carCopyWithUnset ? this.typicalConsumption : typicalConsumption as double?,
      spz: spz == _carCopyWithUnset ? this.spz : spz as String?,
      note: note == _carCopyWithUnset ? this.note : note as String?,
    );
  }
}
