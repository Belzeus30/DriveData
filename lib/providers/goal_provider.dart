import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/goal.dart';
import '../models/trip.dart';
import '../database/database_helper.dart';

class GoalProvider with ChangeNotifier {
  List<Goal> _goals = [];
  bool _isLoading = false;
  final _uuid = const Uuid();

  List<Goal> get goals => _goals;
  List<Goal> get activeGoals => _goals.where((g) => g.isActive).toList();
  bool get isLoading => _isLoading;

  Future<void> loadGoals() async {
    _isLoading = true;
    notifyListeners();
    _goals = await DatabaseHelper.instance.getAllGoals();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addGoal({
    String? carId,
    required String type,
    required double targetValue,
    DateTime? deadline,
  }) async {
    final goal = Goal(
      id: _uuid.v4(),
      carId: carId,
      type: type,
      targetValue: targetValue,
      createdAt: DateTime.now(),
      deadline: deadline,
    );
    await DatabaseHelper.instance.insertGoal(goal);
    _goals.insert(0, goal);
    notifyListeners();
  }

  Future<void> toggleActive(Goal goal) async {
    final updated = goal.copyWith(isActive: !goal.isActive);
    await DatabaseHelper.instance.updateGoal(updated);
    final index = _goals.indexWhere((g) => g.id == goal.id);
    if (index != -1) {
      _goals[index] = updated;
      notifyListeners();
    }
  }

  Future<void> updateGoal(Goal goal) async {
    await DatabaseHelper.instance.updateGoal(goal);
    final index = _goals.indexWhere((g) => g.id == goal.id);
    if (index != -1) {
      _goals[index] = goal;
      notifyListeners();
    }
  }

  Future<void> deleteGoal(String id) async {
    await DatabaseHelper.instance.deleteGoal(id);
    _goals.removeWhere((g) => g.id == id);
    notifyListeners();
  }

  /// Vypočítá aktuální hodnotu cíle na základě jízd.
  /// Vrací hodnotu mezi 0.0 a 1.0 (progress) + aktuální hodnotu.
  GoalProgress computeProgress(Goal goal, List<Trip> allTrips) {
    final trips = goal.carId != null
        ? allTrips.where((t) => t.carId == goal.carId).toList()
        : allTrips;

    switch (goal.type) {
      case 'fuel':
        // Cíl: snížit průměrnou spotřebu pod targetValue l/100km
        // Vážený součet (SUM litrů / SUM km) — jeden průchod listem
        var totalFuel = 0.0;
        var totalDist = 0.0;
        for (final t in trips) {
          if (t.fuelAdded != null && t.distance > 0) {
            totalFuel += t.fuelAdded!;
            totalDist += t.distance;
          }
        }
        if (totalDist <= 0) return GoalProgress(current: null, progress: 0);
        final avg = totalFuel / totalDist * 100;
        final progress = (goal.targetValue / avg).clamp(0.0, 1.0);
        return GoalProgress(current: avg, progress: progress, isLowerBetter: true);

      case 'score':
        // Cíl: dosáhnout průměrného skóre targetValue
        final withScore = trips.where((t) => t.drivingScore != null).toList();
        if (withScore.isEmpty) return GoalProgress(current: null, progress: 0);
        final avg =
            withScore.fold(0.0, (s, t) => s + t.drivingScore!) / withScore.length;
        return GoalProgress(
            current: avg, progress: (avg / goal.targetValue).clamp(0.0, 1.0));

      case 'km_month':
        // Cíl: ujet alespoň targetValue km tento měsíc
        final now = DateTime.now();
        final monthTrips = trips.where((t) =>
            t.date.year == now.year && t.date.month == now.month);
        final km = monthTrips.fold(0.0, (s, t) => s + t.distance);
        return GoalProgress(
            current: km,
            progress: (km / goal.targetValue).clamp(0.0, 1.0));

      case 'cost_km':
        // Cíl: udržet náklady pod targetValue Kč/km
        final withCost = trips.where((t) => t.costPerKm != null).toList();
        if (withCost.isEmpty) return GoalProgress(current: null, progress: 0);
        final avg =
            withCost.fold(0.0, (s, t) => s + t.costPerKm!) / withCost.length;
        final progress = (goal.targetValue / avg).clamp(0.0, 1.0);
        return GoalProgress(current: avg, progress: progress, isLowerBetter: true);

      case 'trips_month':
        // Cíl: zaznamenat alespoň targetValue jízd tento měsíc
        final now = DateTime.now();
        final count = trips.where((t) =>
            t.date.year == now.year && t.date.month == now.month).length;
        return GoalProgress(
            current: count.toDouble(),
            progress: (count / goal.targetValue).clamp(0.0, 1.0));

      default:
        return GoalProgress(current: null, progress: 0);
    }
  }
}

class GoalProgress {
  final double? current;
  final double progress; // 0.0 – 1.0
  final bool isLowerBetter;

  GoalProgress({
    required this.current,
    required this.progress,
    this.isLowerBetter = false,
  });

  bool get isAchieved => progress >= 1.0;
}
