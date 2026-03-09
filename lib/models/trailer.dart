const _trailerCopyWithUnset = Object();

/// Data model for a trailer or caravan.
///
/// Trailers can be attached to trips.  When a trip has a [trailerId], the
/// [Trip.speedingScore] automatically applies the lower CZ legal speed limits:
/// - Motorway / road: 80 km/h
/// - Urban: 50 km/h
/// - Off-road: 30 km/h
///
/// Trailers with [maxWeightKg] < 750 kg are not subject to mandatory MOT.
/// Upcoming MOT dates ([nextTechDate]) are monitored with push notifications.
///
/// The model is immutable; use [copyWith] to produce modified copies.
class Trailer {
  final String id;
  final String name;            // User-defined label (e.g. 'Small trailer', 'Adria caravan')
  final String? licensePlate;   // Trailer registration plate
  final int? year;              // Year of manufacture
  final DateTime? nextTechDate; // Next MOT / road-worthiness check date
  final double? maxWeightKg;    // Max total weight (kg) — trailers < 750 kg are MOT-exempt
  final String? note;

  Trailer({
    required this.id,
    required this.name,
    this.licensePlate,
    this.year,
    this.nextTechDate,
    this.maxWeightKg,
    this.note,
  });

  /// Days remaining until the next MOT (negative = already overdue).
  int get daysUntilTech =>
      nextTechDate?.difference(DateTime.now()).inDays ?? 99999;

  /// `true` when [nextTechDate] has already passed.
  bool get isTechExpired =>
      nextTechDate != null && nextTechDate!.isBefore(DateTime.now());

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'licensePlate': licensePlate,
        'year': year,
        'nextTechDate': nextTechDate?.toIso8601String(),
        'maxWeightKg': maxWeightKg,
        'note': note,
      };

  factory Trailer.fromMap(Map<String, dynamic> map) => Trailer(
        id: map['id'],
        name: map['name'],
        licensePlate: map['licensePlate'],
        year: map['year'] as int?,
        nextTechDate: map['nextTechDate'] != null
            ? DateTime.parse(map['nextTechDate'])
            : null,
        maxWeightKg: (map['maxWeightKg'] as num?)?.toDouble(),
        note: map['note'],
      );

  Trailer copyWith({
    String? id,
    String? name,
    Object? licensePlate = _trailerCopyWithUnset,
    Object? year = _trailerCopyWithUnset,
    Object? nextTechDate = _trailerCopyWithUnset,
    Object? maxWeightKg = _trailerCopyWithUnset,
    Object? note = _trailerCopyWithUnset,
  }) =>
      Trailer(
        id: id ?? this.id,
        name: name ?? this.name,
        licensePlate: licensePlate == _trailerCopyWithUnset
            ? this.licensePlate
            : licensePlate as String?,
        year: year == _trailerCopyWithUnset ? this.year : year as int?,
        nextTechDate: nextTechDate == _trailerCopyWithUnset
            ? this.nextTechDate
            : nextTechDate as DateTime?,
        maxWeightKg: maxWeightKg == _trailerCopyWithUnset
            ? this.maxWeightKg
            : maxWeightKg as double?,
        note: note == _trailerCopyWithUnset ? this.note : note as String?,
      );
}
