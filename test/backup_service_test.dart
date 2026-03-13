import 'dart:convert';

import 'package:drivedata/database/database_helper.dart';
import 'package:drivedata/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await DatabaseHelper.instance.database;
    await _clearDatabase(db);
  });

  test('exportBackupJson includes all tables and backup metadata', () async {
    await _seedDatabase(db);

    final json = await BackupService.instance.exportBackupJson();
    final payload = jsonDecode(json) as Map<String, dynamic>;

    expect(payload['version'], BackupService.backupVersion);
    expect(payload['exportedAt'], isA<String>());
    expect((payload['cars'] as List).single['vehicleType'], 'Motorka / Skútr');
    expect((payload['cars'] as List).single['spz'], isNull);
    expect((payload['trips'] as List), hasLength(1));
    expect((payload['service_records'] as List), hasLength(1));
    expect((payload['goals'] as List), hasLength(1));
    expect((payload['insurance_policies'] as List), hasLength(1));
    expect((payload['trailers'] as List), hasLength(1));
  });

  test('importBackupJson rejects payloads missing required tables', () async {
    final invalidPayload = jsonEncode({
      'version': BackupService.backupVersion,
      'cars': [],
    });

    expect(
      () => BackupService.instance.importBackupJson(invalidPayload),
      throwsA(isA<Exception>()),
    );
  });

  test('importBackupJson restores a full round-trip backup', () async {
    await _seedDatabase(db);
    final json = await BackupService.instance.exportBackupJson();

    await _clearDatabase(db);
    await db.insert('cars', {
      'id': 'temporary-car',
      'vehicleType': 'Auto',
      'make': 'Temp',
      'model': 'Car',
      'year': 2000,
      'fuelType': 'Benzín',
      'tankCapacity': 45.0,
      'engineVolume': 1.0,
      'enginePower': 50,
    });

    final summary = await BackupService.instance.importBackupJson(json);

    expect(summary, contains('1 cars'));
    expect(summary, contains('1 trips'));
    expect(summary, contains('1 service records'));
    expect(summary, contains('1 policies'));
    expect(summary, contains('1 trailers'));

    final cars = await db.query('cars');
    final trips = await db.query('trips');
    final serviceRecords = await db.query('service_records');
    final goals = await db.query('goals');
    final policies = await db.query('insurance_policies');
    final trailers = await db.query('trailers');

    expect(cars, hasLength(1));
    expect(cars.single['id'], 'car-1');
    expect(cars.single['vehicleType'], 'Motorka / Skútr');
    expect(cars.single['spz'], isNull);
    expect(trips, hasLength(1));
    expect(serviceRecords, hasLength(1));
    expect(goals, hasLength(1));
    expect(policies, hasLength(1));
    expect(trailers, hasLength(1));
  });
}

Future<void> _clearDatabase(Database db) async {
  await db.delete('insurance_policies');
  await db.delete('trailers');
  await db.delete('goals');
  await db.delete('service_records');
  await db.delete('trips');
  await db.delete('cars');
}

Future<void> _seedDatabase(Database db) async {
  await db.insert('cars', {
    'id': 'car-1',
    'vehicleType': 'Motorka / Skútr',
    'make': 'Jawa',
    'model': '50 Pionyr',
    'year': 1980,
    'fuelType': 'Benzín',
    'tankCapacity': 8.0,
    'engineVolume': 0.05,
    'enginePower': 3,
    'typicalConsumption': 2.8,
    'spz': null,
    'note': 'Veteran bez SPZ',
  });

  await db.insert('trips', {
    'id': 'trip-1',
    'carId': 'car-1',
    'date': DateTime(2026, 3, 10).toIso8601String(),
    'odometerStart': 1000.0,
    'odometerEnd': 1025.0,
    'fuelAdded': 1.5,
    'fuelPricePerLiter': 38.5,
    'fullTankCost': 57.75,
    'drivingDuration': 45,
    'routeType': 'mixed',
    'weatherCondition': 'clear',
    'trafficLevel': 2,
    'maxSpeed': 60.0,
    'averageSpeed': 35.0,
    'acUsed': 0,
    'outsideTemp': 14,
    'tripComputerConsumption': 2.7,
    'fullTank': 1,
    'trailerId': 'trailer-1',
    'startLocation': 'A',
    'endLocation': 'B',
    'note': 'Test trip',
  });

  await db.insert('service_records', {
    'id': 'service-1',
    'carId': 'car-1',
    'date': DateTime(2026, 3, 1).toIso8601String(),
    'serviceType': 'oil',
    'odometer': 995.0,
    'cost': 350.0,
    'provider': 'Garage',
    'note': 'Oil change',
    'nextDueDate': DateTime(2026, 9, 1).toIso8601String(),
    'nextDueOdometer': 2000.0,
    'attachmentPath': null,
  });

  await db.insert('goals', {
    'id': 'goal-1',
    'carId': 'car-1',
    'type': 'fuel',
    'targetValue': 3.0,
    'createdAt': DateTime(2026, 3, 1).toIso8601String(),
    'deadline': DateTime(2026, 12, 31).toIso8601String(),
    'isActive': 1,
  });

  await db.insert('insurance_policies', {
    'id': 'policy-1',
    'carId': 'car-1',
    'type': 'pov',
    'provider': 'Kooperativa',
    'policyNumber': '12345',
    'validFrom': DateTime(2026, 1, 1).toIso8601String(),
    'validTo': DateTime(2026, 12, 31).toIso8601String(),
    'costPerYear': 1200.0,
    'phone': '123456789',
    'notes': 'Active',
    'coversMedical': 0,
    'coversLuggage': 0,
    'coversDelay': 0,
    'coversLiability': 0,
    'coversCancellation': 0,
    'coversSports': 0,
    'medicalLimitEur': null,
    'attachmentPath': null,
  });

  await db.insert('trailers', {
    'id': 'trailer-1',
    'name': 'Maly vozik',
    'licensePlate': '1AB2345',
    'year': 2015,
    'nextTechDate': DateTime(2026, 6, 1).toIso8601String(),
    'maxWeightKg': 500.0,
    'note': 'Test trailer',
  });
}