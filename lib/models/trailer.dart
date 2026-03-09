const _trailerCopyWithUnset = Object();

class Trailer {
  final String id;
  final String name;          // Uživatelský název (např. "Malý přívěs", "Karavan Adria")
  final String? licensePlate; // SPZ přívěsu
  final int? year;            // Rok výroby
  final DateTime? nextTechDate; // Datum příští STK / TP
  final double? maxWeightKg;  // Max celková hmotnost (kg) — přívěsy < 750 kg nepotřebují STK
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

  /// Zbývá dní do STK (záporné = prošlá)
  int get daysUntilTech =>
      nextTechDate?.difference(DateTime.now()).inDays ?? 99999;

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
