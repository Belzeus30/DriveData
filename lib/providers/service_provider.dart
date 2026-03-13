import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/service_record.dart';
import '../database/database_helper.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

/// Manages [ServiceRecord] entries and calculates upcoming service reminders.
///
/// [getReminders] checks each record against two independent thresholds:
/// - **Date threshold** — how many days ahead to warn (per service type, from
///   [AppConstants.serviceReminderDays])
/// - **Odometer threshold** — how many km ahead to warn (per service type,
///   from [AppConstants.serviceReminderKm])
///
/// A record is flagged `isOverdue` when either threshold has already been
/// exceeded, and `isDueSoon` when either is within the warning window.
class ServiceProvider with ChangeNotifier {
  List<ServiceRecord> _records = [];
  bool _isLoading = false;
  String? _selectedCarId;
  final _uuid = const Uuid();

  List<ServiceRecord> get records => _records;
  bool get isLoading => _isLoading;
  String? get selectedCarId => _selectedCarId;

  Future<void> loadRecords({String? carId}) async {
    _selectedCarId = carId;
    _isLoading = true;
    notifyListeners();
    _records = await DatabaseHelper.instance.getServiceRecords(carId: carId);
    _isLoading = false;
    notifyListeners();
  }

  Future<ServiceRecord> addRecord({
    required String carId,
    required DateTime date,
    required String serviceType,
    required double odometer,
    required double cost,
    String? provider,
    String? note,
    DateTime? nextDueDate,
    double? nextDueOdometer,
    String? attachmentPath,
  }) async {
    final record = ServiceRecord(
      id: _uuid.v4(),
      carId: carId,
      date: date,
      serviceType: serviceType,
      odometer: odometer,
      cost: cost,
      provider: provider,
      note: note,
      nextDueDate: nextDueDate,
      nextDueOdometer: nextDueOdometer,
      attachmentPath: attachmentPath,
    );
    await DatabaseHelper.instance.insertServiceRecord(record);
    _records.add(record);
    _records.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    return record;
  }

  Future<void> updateRecord(ServiceRecord record) async {
    await DatabaseHelper.instance.updateServiceRecord(record);
    final index = _records.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      final dateChanged = _records[index].date != record.date;
      _records[index] = record;
      if (dateChanged) {
        _records.sort((a, b) => b.date.compareTo(a.date));
      }
      notifyListeners();
    }
  }

  Future<void> deleteRecord(String id) async {
    // Delete attachment file if present
    final record = _records.where((r) => r.id == id).firstOrNull;
    if (record?.attachmentPath != null) {
      try {
        final file = File(record!.attachmentPath!);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {
        // Soubor mohl být přesunut nebo smazán externě — ignorujeme
      }
    }
    await DatabaseHelper.instance.deleteServiceRecord(id);
    await NotificationService.instance.cancelServiceReminder(id);
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  double get totalServiceCost =>
      _records.fold(0.0, (sum, r) => sum + r.cost);

  Map<String, double> get costByType {
    final Map<String, double> result = {};
    for (final r in _records) {
      result[r.serviceType] = (result[r.serviceType] ?? 0) + r.cost;
    }
    return result;
  }

  /// Returns service records with an active reminder.
  /// [currentOdometerPerCar] is a map of carId → current odometer reading (km).
  List<({ServiceRecord record, bool isOverdue, bool isDueSoon})>
      getReminders(Map<String, double> currentOdometerPerCar) {
    final now = DateTime.now();
    final result =
        <({ServiceRecord record, bool isOverdue, bool isDueSoon})>[];

    for (final r in _records) {
      if (r.nextDueDate == null && r.nextDueOdometer == null) continue;
      final currentKm = currentOdometerPerCar[r.carId] ?? r.odometer;

      // Per-type reminder thresholds
      final reminderDays =
          AppConstants.serviceReminderDays[r.serviceType] ?? 30;
      final reminderKm =
          AppConstants.serviceReminderKm[r.serviceType] ?? 500.0;
      final soon = now.add(Duration(days: reminderDays));

      final dateOverdue =
          r.nextDueDate != null && r.nextDueDate!.isBefore(now);
      final kmOverdue =
          r.nextDueOdometer != null && currentKm >= r.nextDueOdometer!;
      final dateSoon = r.nextDueDate != null &&
          !dateOverdue &&
          r.nextDueDate!.isBefore(soon);
      final kmSoon = r.nextDueOdometer != null &&
          !kmOverdue &&
          currentKm >= r.nextDueOdometer! - reminderKm;

      final isOverdue = dateOverdue || kmOverdue;
      final isDueSoon = !isOverdue && (dateSoon || kmSoon);

      if (isOverdue || isDueSoon) {
        result.add((record: r, isOverdue: isOverdue, isDueSoon: isDueSoon));
      }
    }

    // Sort: overdue records first
    result.sort((a, b) => a.isOverdue == b.isOverdue ? 0 : a.isOverdue ? -1 : 1);
    return result;
  }
}
