const _serviceRecordUnset = Object();

/// Data model for a single service record.
///
/// Captures one maintenance event (oil change, tyres, MOT, etc.) including
/// cost, service provider and an optional file attachment (invoice or photo).
///
/// Reminders are driven by two independent thresholds:
/// - [nextDueDate] — calendar date of the next service
/// - [nextDueOdometer] — odometer reading at which service is next due
///
/// How far in advance to warn is configured per service type via
/// [AppConstants.serviceReminderDays] and [AppConstants.serviceReminderKm].
///
/// The model is immutable; use [copyWith] to produce modified copies.
class ServiceRecord {
  final String id;
  final String carId;
  final DateTime date;
  final String serviceType;        // 'oil' | 'tires' | 'brakes' | 'inspection' | 'battery' | 'filters' | 'belts' | 'other'
  final double odometer;           // Odometer reading at time of service (km)
  final double cost;               // Service cost in CZK
  final String? provider;          // Workshop name or 'DIY'
  final String? note;
  final DateTime? nextDueDate;     // Scheduled date for the next service
  final double? nextDueOdometer;   // Odometer target for the next service (km)
  final String? attachmentPath;    // Local path to an invoice PDF or photo

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
