const _carCopyWithUnset = Object();

class Car {
  final String id;
  final String make;       // Značka (Škoda, VW, BMW...)
  final String model;      // Model (Octavia, Golf, 3er...)
  final int year;          // Rok výroby
  final String fuelType;   // Typ paliva (benzín, diesel, LPG, elektro)
  final double tankCapacity; // Objem nádrže v litrech
  final double engineVolume; // Objem motoru v litrech
  final int enginePower;   // Výkon motoru v kW
  final double? typicalConsumption; // Typická spotřeba z palubního počítače (l/100km)
  final String? note;      // Poznámka

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
