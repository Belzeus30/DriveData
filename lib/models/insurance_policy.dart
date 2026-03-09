const _insuranceCopyWithUnset = Object();

/// Data model for an insurance policy.
///
/// Covers all common policy types:
/// - `pov`           — mandatory third-party liability (Czech: povinné ručení)
/// - `comprehensive` — comprehensive/collision cover (Czech: havarijní)
/// - `vignette`      — motorway vignette
/// - `travel`        — travel insurance; optional coverages stored in `covers*` fields
/// - `other`         — any other policy
///
/// A policy can be tied to a specific vehicle ([carId] != null) or personal
/// ([carId] == null, typically travel insurance).
///
/// Expiry reminders are triggered according to [AppConstants.insuranceReminderDays].
///
/// The model is immutable; use [copyWith] to produce modified copies.
class InsurancePolicy {
  final String id;
  final String? carId;         // null = personal policy (not vehicle-bound)
  final String type;           // 'pov' | 'comprehensive' | 'vignette' | 'travel' | 'other'
  final String provider;       // Insurance company name
  final String? policyNumber;
  final DateTime? validFrom;
  final DateTime validTo;
  final double? costPerYear;   // Annual premium in CZK
  final String? phone;         // Emergency / assistance hotline
  final String? notes;

  // --- TRAVEL INSURANCE OPTIONAL COVERAGES ---
  final bool coversMedical;       // Medical expenses abroad
  final bool coversLuggage;       // Luggage loss/damage
  final bool coversDelay;         // Flight/connection delay
  final bool coversLiability;     // Personal liability
  final bool coversCancellation;  // Trip cancellation
  final bool coversSports;        // Sporting activities
  final double? medicalLimitEur;  // Medical expenses coverage limit in EUR
  final String? attachmentPath;   // Local path to the policy PDF or photo

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

  /// `true` when the policy's end date has already passed.
  bool get isExpired => validTo.isBefore(DateTime.now());
  bool get isActive => !isExpired;

  /// Days until expiry (negative = already expired).
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
