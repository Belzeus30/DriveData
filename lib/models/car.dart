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
  final String make;              // Brand (e.g. Škoda, VW, BMW)
  final String model;             // Model name (e.g. Octavia, Golf)
  final int year;                 // Year of manufacture
  final String fuelType;          // 'Benzín' | 'Diesel' | 'LPG' | 'CNG' | 'Elektro' | 'Hybrid'
  final double tankCapacity;      // Fuel tank capacity in litres
  final double engineVolume;      // Engine displacement in litres
  final int enginePower;          // Engine power in kW
  final double? typicalConsumption; // Typical fuel consumption in l/100 km (from specs)
  final String? note;

  Car({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.fuelType,
    required this.tankCapacity,
    required this.engineVolume,
    required this.enginePower,
    this.typicalConsumption,
    this.note,
  });

  String get fullName => '$make $model ($year)';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'make': make,
      'model': model,
      'year': year,
      'fuelType': fuelType,
      'tankCapacity': tankCapacity,
      'engineVolume': engineVolume,
      'enginePower': enginePower,
      'typicalConsumption': typicalConsumption,
      'note': note,
    };
  }

  factory Car.fromMap(Map<String, dynamic> map) {
    return Car(
      id: map['id'],
      make: map['make'],
      model: map['model'],
      year: map['year'],
      fuelType: map['fuelType'],
      tankCapacity: map['tankCapacity'],
      engineVolume: map['engineVolume'],
      enginePower: map['enginePower'],
      typicalConsumption: (map['typicalConsumption'] as num?)?.toDouble(),
      note: map['note'],
    );
  }

  Car copyWith({
    String? id,
    String? make,
    String? model,
    int? year,
    String? fuelType,
    double? tankCapacity,
    double? engineVolume,
    int? enginePower,
    Object? typicalConsumption = _carCopyWithUnset,
    Object? note = _carCopyWithUnset,
  }) {
    return Car(
      id: id ?? this.id,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      fuelType: fuelType ?? this.fuelType,
      tankCapacity: tankCapacity ?? this.tankCapacity,
      engineVolume: engineVolume ?? this.engineVolume,
      enginePower: enginePower ?? this.enginePower,
      typicalConsumption: typicalConsumption == _carCopyWithUnset ? this.typicalConsumption : typicalConsumption as double?,
      note: note == _carCopyWithUnset ? this.note : note as String?,
    );
  }
}
