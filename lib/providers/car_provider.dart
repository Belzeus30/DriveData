import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/car.dart';
import '../database/database_helper.dart';
import '../services/notification_service.dart';

/// Manages the list of [Car] records.
///
/// [deleteCar] performs a cascading cleanup before removing the database row:
/// it cancels all scheduled service and insurance notifications for the car,
/// then deletes any locally stored attachment files (invoices, photos).
///
/// [getCarById] uses an internal `Map<String, Car>` for O(1) look-up.
class CarProvider with ChangeNotifier {
  List<Car> _cars = [];
  Map<String, Car> _carMap = {};
  bool _isLoading = true;
  final _uuid = const Uuid();

  List<Car> get cars => _cars;
  bool get isLoading => _isLoading;

  Future<void> loadCars() async {
    _isLoading = true;
    notifyListeners();
    _cars = await DatabaseHelper.instance.getAllCars();
    _carMap = {for (final c in _cars) c.id: c};
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCar({
    required String make,
    required String model,
    required int year,
    required String fuelType,
    required double tankCapacity,
    required double engineVolume,
    required int enginePower,
    String vehicleType = 'Auto',
    double? typicalConsumption,
    String? spz,
    String? note,
  }) async {
    final car = Car(
      id: _uuid.v4(),
      vehicleType: vehicleType,
      make: make,
      model: model,
      year: year,
      fuelType: fuelType,
      tankCapacity: tankCapacity,
      engineVolume: engineVolume,
      enginePower: enginePower,
      typicalConsumption: typicalConsumption,
      spz: spz,
      note: note,
    );
    await DatabaseHelper.instance.insertCar(car);
    _cars.add(car);
    _carMap[car.id] = car;
    notifyListeners();
  }

  Future<void> updateCar(Car car) async {
    await DatabaseHelper.instance.updateCar(car);
    final index = _cars.indexWhere((c) => c.id == car.id);
    if (index != -1) {
      _cars[index] = car;
      _carMap[car.id] = car;
      notifyListeners();
    }
  }

  Future<void> deleteCar(String id) async {
    // Cancel scheduled notifications and clean up attachments before cascade-deleting
    final db = DatabaseHelper.instance;
    final serviceRecords = await db.getServiceRecords(carId: id);
    for (final r in serviceRecords) {
      await NotificationService.instance.cancelServiceReminder(r.id);
      if (r.attachmentPath != null) {
        final f = File(r.attachmentPath!);
        if (f.existsSync()) f.deleteSync();
      }
    }
    final insurancePolicies = await db.getInsurancePolicies(carId: id);
    for (final p in insurancePolicies) {
      await NotificationService.instance.cancelInsuranceReminder(p.id);
      if (p.attachmentPath != null) {
        final f = File(p.attachmentPath!);
        if (f.existsSync()) f.deleteSync();
      }
    }
    await db.deleteCar(id);
    _cars.removeWhere((c) => c.id == id);
    _carMap.remove(id);
    notifyListeners();
  }

  Car? getCarById(String id) => _carMap[id];
}
