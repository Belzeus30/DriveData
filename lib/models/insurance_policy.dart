const _insuranceCopyWithUnset = Object();

class InsurancePolicy {
  final String id;
  final String? carId; // null = osobní pojistka (cestovní), ne vázaná na auto
  final String type; // 'pov', 'comprehensive', 'vignette', 'travel', 'other'
  final String provider; // název pojišťovny
  final String? policyNumber;
  final DateTime? validFrom;
  final DateTime validTo;
  final double? costPerYear; // cena v Kč
  final String? phone; // asistenční linka
  final String? notes;

  // Cestovní pojištění — volitelné
  final bool coversMedical; // léčebné výlohy
  final bool coversLuggage; // zavazadla
  final bool coversDelay; // zpoždění / zmeškaný spoj
  final bool coversLiability; // odpovědnost
  final bool coversCancellation; // storno
  final bool coversSports; // sportovní aktivity
  final double? medicalLimitEur; // krytí léčebných výloh v EUR
  final String? attachmentPath; // cesta k uloženému PDF / fotu dokladu

  InsurancePolicy({
    required this.id,
    this.carId,
    required this.type,
    required this.provider,
    this.policyNumber,
    this.validFrom,
    required this.validTo,
    this.costPerYear,
    this.phone,
    this.notes,
    this.coversMedical = false,
    this.coversLuggage = false,
    this.coversDelay = false,
    this.coversLiability = false,
    this.coversCancellation = false,
    this.coversSports = false,
    this.medicalLimitEur,
    this.attachmentPath,
  });

  bool get isExpired => validTo.isBefore(DateTime.now());
  bool get isActive => !isExpired;

  /// Zbývá dní do konce platnosti (záporné = již propadlá)
  int get daysUntilExpiry =>
      validTo.difference(DateTime.now()).inDays;

  Map<String, dynamic> toMap() => {
        'id': id,
        'carId': carId,
        'type': type,
        'provider': provider,
        'policyNumber': policyNumber,
        'validFrom': validFrom?.toIso8601String(),
        'validTo': validTo.toIso8601String(),
        'costPerYear': costPerYear,
        'phone': phone,
        'notes': notes,
        'coversMedical': coversMedical ? 1 : 0,
        'coversLuggage': coversLuggage ? 1 : 0,
        'coversDelay': coversDelay ? 1 : 0,
        'coversLiability': coversLiability ? 1 : 0,
        'coversCancellation': coversCancellation ? 1 : 0,
        'coversSports': coversSports ? 1 : 0,
        'medicalLimitEur': medicalLimitEur,
        'attachmentPath': attachmentPath,
      };

  factory InsurancePolicy.fromMap(Map<String, dynamic> map) => InsurancePolicy(
        id: map['id'],
        carId: map['carId'],
        type: map['type'],
        provider: map['provider'],
        policyNumber: map['policyNumber'],
        validFrom: map['validFrom'] != null
            ? DateTime.parse(map['validFrom'])
            : null,
        validTo: DateTime.parse(map['validTo']),
        costPerYear: (map['costPerYear'] as num?)?.toDouble(),
        phone: map['phone'],
        notes: map['notes'],
        coversMedical: (map['coversMedical'] ?? 0) == 1,
        coversLuggage: (map['coversLuggage'] ?? 0) == 1,
        coversDelay: (map['coversDelay'] ?? 0) == 1,
        coversLiability: (map['coversLiability'] ?? 0) == 1,
        coversCancellation: (map['coversCancellation'] ?? 0) == 1,
        coversSports: (map['coversSports'] ?? 0) == 1,
        medicalLimitEur: (map['medicalLimitEur'] as num?)?.toDouble(),
        attachmentPath: map['attachmentPath'],
      );

  InsurancePolicy copyWith({
    String? id,
    String? carId,
    String? type,
    String? provider,
    String? policyNumber,
    DateTime? validFrom,
    DateTime? validTo,
    double? costPerYear,
    String? phone,
    String? notes,
    bool? coversMedical,
    bool? coversLuggage,
    bool? coversDelay,
    bool? coversLiability,
    bool? coversCancellation,
    bool? coversSports,
    double? medicalLimitEur,
    Object? attachmentPath = _insuranceCopyWithUnset,
  }) =>
      InsurancePolicy(
        id: id ?? this.id,
        carId: carId ?? this.carId,
        type: type ?? this.type,
        provider: provider ?? this.provider,
        policyNumber: policyNumber ?? this.policyNumber,
        validFrom: validFrom ?? this.validFrom,
        validTo: validTo ?? this.validTo,
        costPerYear: costPerYear ?? this.costPerYear,
        phone: phone ?? this.phone,
        notes: notes ?? this.notes,
        coversMedical: coversMedical ?? this.coversMedical,
        coversLuggage: coversLuggage ?? this.coversLuggage,
        coversDelay: coversDelay ?? this.coversDelay,
        coversLiability: coversLiability ?? this.coversLiability,
        coversCancellation: coversCancellation ?? this.coversCancellation,
        coversSports: coversSports ?? this.coversSports,
        medicalLimitEur: medicalLimitEur ?? this.medicalLimitEur,
        attachmentPath: attachmentPath == _insuranceCopyWithUnset ? this.attachmentPath : attachmentPath as String?,
      );
}
