const _goalUnset = Object();

class Goal {
  final String id;
  final String? carId;       // null = všechna auta
  final String type;         // fuel / score / km_month / cost_km / trips_month
  final double targetValue;  // Cílová hodnota
  final DateTime createdAt;
  final DateTime? deadline;
  final bool isActive;

  Goal({
    required this.id,
    this.carId,
    required this.type,
    required this.targetValue,
    required this.createdAt,
    this.deadline,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'carId': carId,
        'type': type,
        'targetValue': targetValue,
        'createdAt': createdAt.toIso8601String(),
        'deadline': deadline?.toIso8601String(),
        'isActive': isActive ? 1 : 0,
      };

  factory Goal.fromMap(Map<String, dynamic> map) => Goal(
        id: map['id'],
        carId: map['carId'],
        type: map['type'],
        targetValue: (map['targetValue'] as num).toDouble(),
        createdAt: DateTime.parse(map['createdAt']),
        deadline:
            map['deadline'] != null ? DateTime.parse(map['deadline']) : null,
        isActive: map['isActive'] == 1,
      );

  Goal copyWith({
    String? id,
    Object? carId = _goalUnset,
    String? type,
    double? targetValue,
    DateTime? createdAt,
    Object? deadline = _goalUnset,
    bool? isActive,
  }) =>
      Goal(
        id: id ?? this.id,
        carId: carId == _goalUnset ? this.carId : carId as String?,
        type: type ?? this.type,
        targetValue: targetValue ?? this.targetValue,
        createdAt: createdAt ?? this.createdAt,
        deadline: deadline == _goalUnset ? this.deadline : deadline as DateTime?,
        isActive: isActive ?? this.isActive,
      );
}
