import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/car.dart';
import '../models/trip.dart';
import '../models/service_record.dart';
import '../models/goal.dart';
import '../models/insurance_policy.dart';
import '../models/trailer.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

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
      // V1 nemělo service_records ani goals — zrekonstruujeme vše od začátku
      await db.execute('DROP TABLE IF EXISTS trips');
      await db.execute('DROP TABLE IF EXISTS service_records');
      await db.execute('DROP TABLE IF EXISTS goals');
      await db.execute('DROP TABLE IF EXISTS cars');
      await _createDB(db, newVersion);
      return; // _createDB již obsahuje všechny sloupce
    }
    if (oldVersion < 3) {
      // V3: přidáno pole typicalConsumption na auto
      await db.execute(
          'ALTER TABLE cars ADD COLUMN typicalConsumption REAL');
    }
    if (oldVersion < 4) {
      // V4: přidána upozornění na příští servis
      await db.execute(
          'ALTER TABLE service_records ADD COLUMN nextDueDate TEXT');
      await db.execute(
          'ALTER TABLE service_records ADD COLUMN nextDueOdometer REAL');
    }
    if (oldVersion < 5) {
      // V5: fill-to-fill spotřeba — přidáno fullTank na jízdy
      await db.execute(
          'ALTER TABLE trips ADD COLUMN fullTank INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 6) {
      // V6: tabulka pojištění a dokladů
      await _createInsurancePoliciesTable(db);
    }
    if (oldVersion < 7) {
      // V7: příloha (PDF / foto) k pojistce
      await db.execute(
          'ALTER TABLE insurance_policies ADD COLUMN attachmentPath TEXT');
    }
    if (oldVersion < 8) {
      // V8: spotřeba z palubního počítače
      await db.execute(
          'ALTER TABLE trips ADD COLUMN tripComputerConsumption REAL');
    }
    if (oldVersion < 9) {
      // V9: příloha k servisnímu záznamu (faktura, fotka...)
      await db.execute(
          'ALTER TABLE service_records ADD COLUMN attachmentPath TEXT');
    }
    if (oldVersion < 10) {
      // V10: přívěsy / vozíky + vazba na jízdu
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
    return await db.update('cars', car.toMap(), where: 'id = ?', whereArgs: [car.id]);
  }

  Future<int> deleteCar(String id) async {
    final db = await database;
    // Cascade-delete all data owned by this car atomically
    return await db.transaction((txn) async {
      await txn.delete('trips', where: 'carId = ?', whereArgs: [id]);
      await txn.delete('service_records', where: 'carId = ?', whereArgs: [id]);
      await txn.delete('goals', where: 'carId = ?', whereArgs: [id]);
      await txn.delete('insurance_policies', where: 'carId = ?', whereArgs: [id]);
      return await txn.delete('cars', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ==================== TRIPS ====================

  Future<String> insertTrip(Trip trip) async {
    final db = await database;
    await db.insert('trips', trip.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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
    return await db.update('trips', trip.toMap(), where: 'id = ?', whereArgs: [trip.id]);
  }

  Future<int> deleteTrip(String id) async {
    final db = await database;
    return await db.delete('trips', where: 'id = ?', whereArgs: [id]);
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

  // ==================== SERVICE RECORDS ====================

  Future<String> insertServiceRecord(ServiceRecord record) async {
    final db = await database;
    await db.insert('service_records', record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
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
    return await db.update('service_records', record.toMap(),
        where: 'id = ?', whereArgs: [record.id]);
  }

  Future<int> deleteServiceRecord(String id) async {
    final db = await database;
    return await db
        .delete('service_records', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== GOALS ====================

  Future<String> insertGoal(Goal goal) async {
    final db = await database;
    await db.insert('goals', goal.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
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
    return await db
        .update('goals', goal.toMap(), where: 'id = ?', whereArgs: [goal.id]);
  }

  Future<int> deleteGoal(String id) async {
    final db = await database;
    return await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== INSURANCE POLICIES ====================

  Future<String> insertInsurancePolicy(InsurancePolicy policy) async {
    final db = await database;
    await db.insert('insurance_policies', policy.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return policy.id;
  }

  Future<List<InsurancePolicy>> getInsurancePolicies({String? carId}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;
    if (carId != null) {
      // Vrátí pro konkrétní auto + osobní (carId IS NULL)
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
    return await db.update('insurance_policies', policy.toMap(),
        where: 'id = ?', whereArgs: [policy.id]);
  }

  Future<int> deleteInsurancePolicy(String id) async {
    final db = await database;
    return await db
        .delete('insurance_policies', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== TRAILERS ====================

  Future<String> insertTrailer(Trailer trailer) async {
    final db = await database;
    await db.insert('trailers', trailer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return trailer.id;
  }

  Future<List<Trailer>> getAllTrailers() async {
    final db = await database;
    final maps = await db.query('trailers', orderBy: 'name ASC');
    return maps.map((m) => Trailer.fromMap(m)).toList();
  }

  Future<int> updateTrailer(Trailer trailer) async {
    final db = await database;
    return await db.update('trailers', trailer.toMap(),
        where: 'id = ?', whereArgs: [trailer.id]);
  }

  Future<int> deleteTrailer(String id) async {
    final db = await database;
    // Odvaž jizdy od vozíku (nemazt je)
    await db.execute(
        'UPDATE trips SET trailerId = NULL WHERE trailerId = ?', [id]);
    return await db.delete('trailers', where: 'id = ?', whereArgs: [id]);
  }
}
