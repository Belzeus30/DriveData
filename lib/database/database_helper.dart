import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/car.dart';
import '../models/trip.dart';
import '../models/service_record.dart';
import '../models/goal.dart';
import '../models/insurance_policy.dart';
import '../models/trailer.dart';

/// SQLite database helper — singleton wrapper around the `sqflite` database.
///
/// **Tables:** `cars`, `trips`, `service_records`, `goals`,
/// `insurance_policies`, `trailers`.
///
/// **Schema version:** 10 (see [_upgradeDB] for migration history).
/// All migrations are additive (ALTER TABLE or CREATE TABLE); a full
/// drop-and-recreate is only performed for upgrades from v1, which predated
/// `service_records` and `goals`.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  /// Incremented on every insert / update / delete so listeners (e.g. the
  /// backup-warning banner in HomeScreen) can react without polling.
  static final dataVersion = ValueNotifier<int>(0);

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('drivedata.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
        path, version: 10, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 had no service_records or goals — safest to recreate everything
      await db.execute('DROP TABLE IF EXISTS trips');
      await db.execute('DROP TABLE IF EXISTS service_records');
      await db.execute('DROP TABLE IF EXISTS goals');
      await db.execute('DROP TABLE IF EXISTS cars');
      await _createDB(db, newVersion);
      return; // _createDB already has all columns
    }
    if (oldVersion < 3) {
      // v3: added typicalConsumption to cars
      await db.execute(
          'ALTER TABLE cars ADD COLUMN typicalConsumption REAL');
    }
    if (oldVersion < 4) {
      // v4: added next-service reminder fields to service_records
      await db.execute(
          'ALTER TABLE service_records ADD COLUMN nextDueDate TEXT');
      await db.execute(
          'ALTER TABLE service_records ADD COLUMN nextDueOdometer REAL');
    }
    if (oldVersion < 5) {
      // v5: fill-to-fill consumption — added fullTank flag to trips
      await db.execute(
          'ALTER TABLE trips ADD COLUMN fullTank INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 6) {
      // v6: insurance & documents table
      await _createInsurancePoliciesTable(db);
    }
    if (oldVersion < 7) {
      // v7: attachment (PDF / photo) on insurance policies
      await db.execute(
          'ALTER TABLE insurance_policies ADD COLUMN attachmentPath TEXT');
    }
    if (oldVersion < 8) {
      // v8: on-board computer consumption reading on trips
      await db.execute(
          'ALTER TABLE trips ADD COLUMN tripComputerConsumption REAL');
    }
    if (oldVersion < 9) {
      // v9: attachment (invoice / photo) on service records
      await db.execute(
          'ALTER TABLE service_records ADD COLUMN attachmentPath TEXT');
    }
    if (oldVersion < 10) {
      // v10: trailers table + trailerId foreign key on trips
      await _createTrailersTable(db);
      await db.execute(
          'ALTER TABLE trips ADD COLUMN trailerId TEXT');
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cars (
        id TEXT PRIMARY KEY,
        make TEXT NOT NULL,
        model TEXT NOT NULL,
        year INTEGER NOT NULL,
        fuelType TEXT NOT NULL,
        tankCapacity REAL NOT NULL,
        engineVolume REAL NOT NULL,
        enginePower INTEGER NOT NULL,
        typicalConsumption REAL,
        note TEXT
      )
    ''');

    await _createTripsTable(db);

    await db.execute('''
      CREATE TABLE service_records (
        id TEXT PRIMARY KEY,
        carId TEXT NOT NULL,
        date TEXT NOT NULL,
        serviceType TEXT NOT NULL,
        odometer REAL NOT NULL,
        cost REAL NOT NULL,
        provider TEXT,
        note TEXT,
        nextDueDate TEXT,
        nextDueOdometer REAL,
        attachmentPath TEXT,
        FOREIGN KEY (carId) REFERENCES cars (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE goals (
        id TEXT PRIMARY KEY,
        carId TEXT,
        type TEXT NOT NULL,
        targetValue REAL NOT NULL,
        createdAt TEXT NOT NULL,
        deadline TEXT,
        isActive INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await _createInsurancePoliciesTable(db);
    await _createTrailersTable(db);
  }

  Future _createInsurancePoliciesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS insurance_policies (
        id TEXT PRIMARY KEY,
        carId TEXT,
        type TEXT NOT NULL,
        provider TEXT NOT NULL,
        policyNumber TEXT,
        validFrom TEXT,
        validTo TEXT NOT NULL,
        costPerYear REAL,
        phone TEXT,
        notes TEXT,
        coversMedical INTEGER NOT NULL DEFAULT 0,
        coversLuggage INTEGER NOT NULL DEFAULT 0,
        coversDelay INTEGER NOT NULL DEFAULT 0,
        coversLiability INTEGER NOT NULL DEFAULT 0,
        coversCancellation INTEGER NOT NULL DEFAULT 0,
        coversSports INTEGER NOT NULL DEFAULT 0,
        medicalLimitEur REAL,
        attachmentPath TEXT
      )
    ''');
  }

  Future _createTripsTable(Database db) async {
    await db.execute('''
      CREATE TABLE trips (
        id TEXT PRIMARY KEY,
        carId TEXT NOT NULL,
        date TEXT NOT NULL,
        odometerStart REAL NOT NULL,
        odometerEnd REAL NOT NULL,
        fuelAdded REAL,
        fuelPricePerLiter REAL,
        fullTankCost REAL,
        drivingDuration INTEGER NOT NULL,
        routeType TEXT NOT NULL,
        weatherCondition TEXT NOT NULL,
        trafficLevel INTEGER NOT NULL,
        maxSpeed REAL,
        averageSpeed REAL,
        acUsed INTEGER NOT NULL,
        outsideTemp INTEGER,
        tripComputerConsumption REAL,
        fullTank INTEGER NOT NULL DEFAULT 0,
        trailerId TEXT,
        startLocation TEXT,
        endLocation TEXT,
        note TEXT,
        FOREIGN KEY (carId) REFERENCES cars (id)
      )
    ''');
  }

  Future _createTrailersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trailers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        licensePlate TEXT,
        year INTEGER,
        nextTechDate TEXT,
        maxWeightKg REAL,
        note TEXT
      )
    ''');
  }

  // ==================== CARS ====================

  Future<String> insertCar(Car car) async {
    final db = await database;
    await db.insert('cars', car.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await _markChanged();
    return car.id;
  }

  Future<List<Car>> getAllCars() async {
    final db = await database;
    final maps = await db.query('cars', orderBy: 'make ASC, model ASC');
    return maps.map((m) => Car.fromMap(m)).toList();
  }

  Future<Car?> getCar(String id) async {
    final db = await database;
    final maps = await db.query('cars', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Car.fromMap(maps.first);
  }

  Future<int> updateCar(Car car) async {
    final db = await database;
    final result = await db.update('cars', car.toMap(), where: 'id = ?', whereArgs: [car.id]);
    await _markChanged();
    return result;
  }

  Future<int> deleteCar(String id) async {
    final db = await database;
    // Cascade-delete all data owned by this car atomically
    final result = await db.transaction((txn) async {
      await txn.delete('trips', where: 'carId = ?', whereArgs: [id]);
      await txn.delete('service_records', where: 'carId = ?', whereArgs: [id]);
      await txn.delete('goals', where: 'carId = ?', whereArgs: [id]);
      await txn.delete('insurance_policies', where: 'carId = ?', whereArgs: [id]);
      return await txn.delete('cars', where: 'id = ?', whereArgs: [id]);
    });
    await _markChanged();
    return result;
  }

  // ==================== TRIPS ====================

  Future<String> insertTrip(Trip trip) async {
    final db = await database;
    await db.insert('trips', trip.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await _markChanged();
    return trip.id;
  }

  Future<List<Trip>> getAllTrips({String? carId}) async {
    final db = await database;
    final maps = await db.query(
      'trips',
      where: carId != null ? 'carId = ?' : null,
      whereArgs: carId != null ? [carId] : null,
      orderBy: 'date DESC',
    );
    return maps.map((m) => Trip.fromMap(m)).toList();
  }

  Future<List<Trip>> getTripsInRange(DateTime from, DateTime to, {String? carId}) async {
    final db = await database;
    final maps = await db.query(
      'trips',
      where: carId != null
          ? 'date >= ? AND date <= ? AND carId = ?'
          : 'date >= ? AND date <= ?',
      whereArgs: carId != null
          ? [from.toIso8601String(), to.toIso8601String(), carId]
          : [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'date DESC',
    );
    return maps.map((m) => Trip.fromMap(m)).toList();
  }

  Future<int> updateTrip(Trip trip) async {
    final db = await database;
    final result = await db.update('trips', trip.toMap(), where: 'id = ?', whereArgs: [trip.id]);
    await _markChanged();
    return result;
  }

  Future<int> deleteTrip(String id) async {
    final db = await database;
    final result = await db.delete('trips', where: 'id = ?', whereArgs: [id]);
    await _markChanged();
    return result;
  }

  // ==================== STATISTIKY ====================

  Future<Map<String, dynamic>> getCarStats(String carId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as tripCount,
        SUM(odometerEnd - odometerStart) as totalKm,
        SUM(fuelAdded) as totalFuel,
        SUM(fullTankCost) as totalCost,
        AVG(drivingDuration) as avgDuration
      FROM trips
      WHERE carId = ?
    ''', [carId]);
    return result.first;
  }

  Future<List<Map<String, dynamic>>> getMonthlyStats(String carId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        strftime('%Y-%m', date) as month,
        COUNT(*) as tripCount,
        SUM(odometerEnd - odometerStart) as totalKm,
        SUM(fuelAdded) as totalFuel,
        SUM(fullTankCost) as totalCost
      FROM trips
      WHERE carId = ?
      GROUP BY strftime('%Y-%m', date)
      ORDER BY month DESC
    ''', [carId]);
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }

  /// Saves the current timestamp to SharedPreferences so the UI can detect
  /// unsaved changes and prompt the user to back up.
  Future<void> _markChanged() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastDataChangeAt', DateTime.now().toIso8601String());
    dataVersion.value++;
  }

  // ==================== SERVICE RECORDS ====================

  Future<String> insertServiceRecord(ServiceRecord record) async {
    final db = await database;
    await db.insert('service_records', record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _markChanged();
    return record.id;
  }

  Future<List<ServiceRecord>> getServiceRecords({String? carId}) async {
    final db = await database;
    final maps = await db.query(
      'service_records',
      where: carId != null ? 'carId = ?' : null,
      whereArgs: carId != null ? [carId] : null,
      orderBy: 'date DESC',
    );
    return maps.map((m) => ServiceRecord.fromMap(m)).toList();
  }

  Future<int> updateServiceRecord(ServiceRecord record) async {
    final db = await database;
    final result = await db.update('service_records', record.toMap(),
        where: 'id = ?', whereArgs: [record.id]);
    await _markChanged();
    return result;
  }

  Future<int> deleteServiceRecord(String id) async {
    final db = await database;
    final result = await db
        .delete('service_records', where: 'id = ?', whereArgs: [id]);
    await _markChanged();
    return result;
  }

  // ==================== GOALS ====================

  Future<String> insertGoal(Goal goal) async {
    final db = await database;
    await db.insert('goals', goal.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _markChanged();
    return goal.id;
  }

  Future<List<Goal>> getAllGoals({bool activeOnly = false}) async {
    final db = await database;
    final maps = await db.query(
      'goals',
      where: activeOnly ? 'isActive = 1' : null,
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => Goal.fromMap(m)).toList();
  }

  Future<int> updateGoal(Goal goal) async {
    final db = await database;
    final result = await db
        .update('goals', goal.toMap(), where: 'id = ?', whereArgs: [goal.id]);
    await _markChanged();
    return result;
  }

  Future<int> deleteGoal(String id) async {
    final db = await database;
    final result = await db.delete('goals', where: 'id = ?', whereArgs: [id]);
    await _markChanged();
    return result;
  }

  // ==================== INSURANCE POLICIES ====================

  Future<String> insertInsurancePolicy(InsurancePolicy policy) async {
    final db = await database;
    await db.insert('insurance_policies', policy.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _markChanged();
    return policy.id;
  }

  Future<List<InsurancePolicy>> getInsurancePolicies({String? carId}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;
    if (carId != null) {
      // Returns policies for a specific car plus personal policies (carId IS NULL)
      maps = await db.rawQuery(
          'SELECT * FROM insurance_policies WHERE carId = ? OR carId IS NULL ORDER BY validTo ASC',
          [carId]);
    } else {
      maps = await db.query('insurance_policies', orderBy: 'validTo ASC');
    }
    return maps.map((m) => InsurancePolicy.fromMap(m)).toList();
  }

  Future<int> updateInsurancePolicy(InsurancePolicy policy) async {
    final db = await database;
    final result = await db.update('insurance_policies', policy.toMap(),
        where: 'id = ?', whereArgs: [policy.id]);
    await _markChanged();
    return result;
  }

  Future<int> deleteInsurancePolicy(String id) async {
    final db = await database;
    final result = await db
        .delete('insurance_policies', where: 'id = ?', whereArgs: [id]);
    await _markChanged();
    return result;
  }

  // ==================== TRAILERS ====================

  Future<String> insertTrailer(Trailer trailer) async {
    final db = await database;
    await db.insert('trailers', trailer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _markChanged();
    return trailer.id;
  }

  Future<List<Trailer>> getAllTrailers() async {
    final db = await database;
    final maps = await db.query('trailers', orderBy: 'name ASC');
    return maps.map((m) => Trailer.fromMap(m)).toList();
  }

  Future<int> updateTrailer(Trailer trailer) async {
    final db = await database;
    final result = await db.update('trailers', trailer.toMap(),
        where: 'id = ?', whereArgs: [trailer.id]);
    await _markChanged();
    return result;
  }

  Future<int> deleteTrailer(String id) async {
    final db = await database;
    // Detach trips from the trailer without deleting them
    await db.execute(
        'UPDATE trips SET trailerId = NULL WHERE trailerId = ?', [id]);
    final result = await db.delete('trailers', where: 'id = ?', whereArgs: [id]);
    await _markChanged();
    return result;
  }
}
