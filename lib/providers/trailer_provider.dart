import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/trailer.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class TrailerProvider with ChangeNotifier {
  List<Trailer> _trailers = [];
  Map<String, Trailer> _trailerMap = {};
  bool _isLoading = false;
  final _uuid = const Uuid();

  List<Trailer> get trailers => _trailers;
  bool get isLoading => _isLoading;

  // ------------------------------------------------------------------- LOAD

  Future<void> loadTrailers() async {
    _isLoading = true;
    notifyListeners();
    _trailers = await DatabaseHelper.instance.getAllTrailers();
    _trailerMap = {for (final t in _trailers) t.id: t};
    _isLoading = false;
    notifyListeners();
  }

  // ------------------------------------------------------------------- CRUD

  Future<Trailer> addTrailer({
    required String name,
    String? licensePlate,
    int? year,
    DateTime? nextTechDate,
    double? maxWeightKg,
    String? note,
  }) async {
    final trailer = Trailer(
      id: _uuid.v4(),
      name: name,
      licensePlate: licensePlate,
      year: year,
      nextTechDate: nextTechDate,
      maxWeightKg: maxWeightKg,
      note: note,
    );
    await DatabaseHelper.instance.insertTrailer(trailer);
    _trailers.add(trailer);
    _trailerMap[trailer.id] = trailer;
    _trailers.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    // Naplánuj notifikaci pokud je STK zadáno
    if (nextTechDate != null) {
      await NotificationService.instance.scheduleTrailerTechReminder(trailer);
    }
    return trailer;
  }

  Future<void> updateTrailer(Trailer trailer) async {
    await DatabaseHelper.instance.updateTrailer(trailer);
    final idx = _trailers.indexWhere((t) => t.id == trailer.id);
    if (idx >= 0) {
      _trailers[idx] = trailer;
      _trailerMap[trailer.id] = trailer;
      _trailers.sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    }
    await NotificationService.instance.scheduleTrailerTechReminder(trailer);
  }

  Future<void> deleteTrailer(String id) async {
    await DatabaseHelper.instance.deleteTrailer(id);
    await NotificationService.instance.cancelTrailerTechReminder(id);
    _trailers.removeWhere((t) => t.id == id);
    _trailerMap.remove(id);
    notifyListeners();
  }

  Trailer? getById(String id) => _trailerMap[id];

  // --------------------------------------------------------------- REMINDERS

  /// Vrátí vozíky s aktivním STK upozorněním (propadlé nebo brzy vyprší).
  List<({Trailer trailer, bool isOverdue, bool isDueSoon})> getReminders() {
    final now = DateTime.now();
    final result = <({Trailer trailer, bool isOverdue, bool isDueSoon})>[];
    for (final t in _trailers) {
      if (t.nextTechDate == null) continue;
      final isOverdue = t.nextTechDate!.isBefore(now);
      final isDueSoon = !isOverdue &&
          t.daysUntilTech <= AppConstants.trailerTechReminderDays;
      if (isOverdue || isDueSoon) {
        result.add((trailer: t, isOverdue: isOverdue, isDueSoon: isDueSoon));
      }
    }
    result.sort((a, b) => a.isOverdue == b.isOverdue ? 0 : a.isOverdue ? -1 : 1);
    return result;
  }
}
