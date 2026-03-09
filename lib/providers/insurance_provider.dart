import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/insurance_policy.dart';
import '../utils/constants.dart';
import '../services/notification_service.dart';

/// Manages [InsurancePolicy] records and calculates expiry reminders.
///
/// [getReminders] returns policies that are already expired (`isOverdue`) or
/// will expire within the per-type threshold defined in
/// [AppConstants.insuranceReminderDays].
///
/// Cost helpers ([annualCostForCar], [monthlyCostForCar]) aggregate premiums
/// for all active policies (vehicle-bound and personal) for a given car.
class InsuranceProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  final _uuid = const Uuid();

  List<InsurancePolicy> _policies = [];
  List<InsurancePolicy> get policies => List.unmodifiable(_policies);

  // ------------------------------------------------------------------- LOAD

  Future<void> loadPolicies({String? carId}) async {
    _policies = await _db.getInsurancePolicies(carId: carId);
    notifyListeners();
  }

  // ------------------------------------------------------------------- CRUD

  Future<InsurancePolicy> addPolicy(InsurancePolicy policy) async {
    final newPolicy = policy.copyWith(id: _uuid.v4());
    await _db.insertInsurancePolicy(newPolicy);
    _policies.add(newPolicy);
    _policies.sort((a, b) => a.validTo.compareTo(b.validTo));
    notifyListeners();
    return newPolicy;
  }

  Future<void> updatePolicy(InsurancePolicy policy) async {
    await _db.updateInsurancePolicy(policy);
    final idx = _policies.indexWhere((p) => p.id == policy.id);
    if (idx >= 0) {
      _policies[idx] = policy;
      _policies.sort((a, b) => a.validTo.compareTo(b.validTo));
      notifyListeners();
    }
  }

  Future<void> deletePolicy(String id) async {
    // Delete attachment file if present
    final policy = _policies.where((p) => p.id == id).firstOrNull;
    if (policy?.attachmentPath != null) {
      final file = File(policy!.attachmentPath!);
      if (file.existsSync()) file.deleteSync();
    }
    await _db.deleteInsurancePolicy(id);
    await NotificationService.instance.cancelInsuranceReminder(id);
    _policies.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  // --------------------------------------------------------------- REMINDERS

  /// Returns policies with an active reminder (expired or expiring soon).
  List<({InsurancePolicy policy, bool isOverdue, bool isDueSoon})>
      getReminders() {
    final now = DateTime.now();
    final result =
        <({InsurancePolicy policy, bool isOverdue, bool isDueSoon})>[];

    for (final p in _policies) {
      final reminderDays =
          AppConstants.insuranceReminderDays[p.type] ?? 30;
      final soon = now.add(Duration(days: reminderDays));

      final isOverdue = p.validTo.isBefore(now);
      final isDueSoon = !isOverdue && p.validTo.isBefore(soon);

      if (isOverdue || isDueSoon) {
        result.add((policy: p, isOverdue: isOverdue, isDueSoon: isDueSoon));
      }
    }

    result.sort((a, b) => a.isOverdue == b.isOverdue ? 0 : a.isOverdue ? -1 : 1);
    return result;
  }

  // ----------------------------------------------------------- COST HELPERS

  /// Total annual premium cost for all active policies associated with [carId].
  double annualCostForCar(String carId) {
    return _policies
        .where((p) => p.isActive && (p.carId == carId || p.carId == null))
        .fold(0.0, (sum, p) => sum + (p.costPerYear ?? 0));
  }

  /// Monthly cost estimate (annual cost ÷ 12) for the given car.
  double monthlyCostForCar(String carId) => annualCostForCar(carId) / 12;
}
