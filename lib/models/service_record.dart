const _serviceRecordUnset = Object();

class ServiceRecord {
  final String id;
  final String carId;
  final DateTime date;
  final String serviceType;  // oil / tires / brakes / inspection / battery / other
  final double odometer;     // Stav km při servisu
  final double cost;         // Cena v Kč
  final String? provider;   // Kde se servisovalo (autoservis, sám...)
  final String? note;
  final DateTime? nextDueDate;     // Kdy je příští servis (datum)
  final double? nextDueOdometer;   // Kdy je příští servis (km)
  final String? attachmentPath;    // Cesta k příloze (faktura, fotka...)

  ServiceRecord({
    required this.id,
    required this.carId,
    required this.date,
    required this.serviceType,
    required this.odometer,
    required this.cost,
    this.provider,
    this.note,
    this.nextDueDate,
    this.nextDueOdometer,
    this.attachmentPath,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'carId': carId,
        'date': date.toIso8601String(),
        'serviceType': serviceType,
        'odometer': odometer,
        'cost': cost,
        'provider': provider,
        'note': note,
        'nextDueDate': nextDueDate?.toIso8601String(),
        'nextDueOdometer': nextDueOdometer,
        'attachmentPath': attachmentPath,
      };

  factory ServiceRecord.fromMap(Map<String, dynamic> map) => ServiceRecord(
        id: map['id'],
        carId: map['carId'],
        date: DateTime.parse(map['date']),
        serviceType: map['serviceType'],
        odometer: (map['odometer'] as num).toDouble(),
        cost: (map['cost'] as num).toDouble(),
        provider: map['provider'],
        note: map['note'],
        nextDueDate: map['nextDueDate'] != null
            ? DateTime.parse(map['nextDueDate'])
            : null,
        nextDueOdometer: (map['nextDueOdometer'] as num?)?.toDouble(),
        attachmentPath: map['attachmentPath'],
      );

  ServiceRecord copyWith({
    String? id,
    String? carId,
    DateTime? date,
    String? serviceType,
    double? odometer,
    double? cost,
    Object? provider = _serviceRecordUnset,
    Object? note = _serviceRecordUnset,
    Object? nextDueDate = _serviceRecordUnset,
    Object? nextDueOdometer = _serviceRecordUnset,
    Object? attachmentPath = _serviceRecordUnset,
  }) =>
      ServiceRecord(
        id: id ?? this.id,
        carId: carId ?? this.carId,
        date: date ?? this.date,
        serviceType: serviceType ?? this.serviceType,
        odometer: odometer ?? this.odometer,
        cost: cost ?? this.cost,
        provider: provider == _serviceRecordUnset ? this.provider : provider as String?,
        note: note == _serviceRecordUnset ? this.note : note as String?,
        nextDueDate: nextDueDate == _serviceRecordUnset ? this.nextDueDate : nextDueDate as DateTime?,
        nextDueOdometer: nextDueOdometer == _serviceRecordUnset ? this.nextDueOdometer : nextDueOdometer as double?,
        attachmentPath: attachmentPath == _serviceRecordUnset ? this.attachmentPath : attachmentPath as String?,
      );
}
