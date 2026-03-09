import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/insurance_policy.dart';
import '../models/service_record.dart';
import '../models/trailer.dart';
import '../utils/constants.dart';

/// Android notification channels
const _kServiceChannelId = 'service_reminders';
const _kInsuranceChannelId = 'insurance_reminders';
const _kTrailerChannelId = 'trailer_tech_reminders';

const _kServiceChannel = AndroidNotificationChannel(
  _kServiceChannelId,
  'Servisní upozornění',
  description: 'Připomínky nadcházejících servisních intervalů',
  importance: Importance.defaultImportance,
);

const _kInsuranceChannel = AndroidNotificationChannel(
  _kInsuranceChannelId,
  'Pojistky – upozornění',
  description: 'Upozornění na blížící se konec platnosti pojistek',
  importance: Importance.high,
);

const _kTrailerChannel = AndroidNotificationChannel(
  _kTrailerChannelId,
  'Vozíky – STK upozornění',
  description: 'Připomínky na přicházející technickou kontrolu přívěsu/vozíku',
  importance: Importance.high,
);

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Init ──────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    // Notifications only work on Android / iOS; skip all other platforms
    if (!Platform.isAndroid && !Platform.isIOS) {
      _initialized = true;
      return;
    }

    // Timezone data for scheduled notifications
    tz_data.initializeTimeZones();
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: initSettings);

    // Create Android 8+ notification channels
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_kServiceChannel);
    await androidPlugin?.createNotificationChannel(_kInsuranceChannel);
    await androidPlugin?.createNotificationChannel(_kTrailerChannel);

    _initialized = true;
  }

  // ── Permissions ───────────────────────────────────────────────

  Future<bool> requestPermissions() async {
    if (!_initialized) return false;
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.requestNotificationsPermission() ?? false;
    }
    if (Platform.isIOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      return await iosPlugin?.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  // ── Service reminders ─────────────────────────────────────────

  Future<void> scheduleServiceReminder(
      ServiceRecord record, String carName) async {
    if (!_initialized) return;
    await cancelServiceReminder(record.id);
    if (record.nextDueDate == null) return;

    final reminderDays =
        AppConstants.serviceReminderDays[record.serviceType] ?? 30;
    final triggerDate =
        record.nextDueDate!.subtract(Duration(days: reminderDays));
    if (triggerDate.isBefore(DateTime.now())) return;

    final label =
        AppConstants.serviceTypeLabels[record.serviceType] ?? record.serviceType;

    await _schedule(
      id: _serviceId(record.id),
      title: 'Připomínka servisu — $carName',
      body: 'Za $reminderDays dní: $label',
      scheduledDate: triggerDate,
      channelId: _kServiceChannelId,
      channelName: _kServiceChannel.name,
    );
  }

  Future<void> cancelServiceReminder(String recordId) async {
    if (!_initialized) return;
    await _plugin.cancel(id: _serviceId(recordId));
  }

  // ── Insurance reminders ───────────────────────────────────────

  Future<void> scheduleInsuranceReminder(
      InsurancePolicy policy, String carOrOwner) async {
    if (!_initialized) return;
    await cancelInsuranceReminder(policy.id);

    final reminderDays =
        AppConstants.insuranceReminderDays[policy.type] ?? 30;
    final triggerDate =
        policy.validTo.subtract(Duration(days: reminderDays));
    if (triggerDate.isBefore(DateTime.now())) return;

    final label =
        AppConstants.insuranceTypeLabels[policy.type] ?? policy.type;

    await _schedule(
      id: _insuranceId(policy.id),
      title: 'Pojistka brzy vyprší — $carOrOwner',
      body: '$label platí do ${_fmtDate(policy.validTo)} (ještě $reminderDays dní)',
      scheduledDate: triggerDate,
      channelId: _kInsuranceChannelId,
      channelName: _kInsuranceChannel.name,
    );
  }

  Future<void> cancelInsuranceReminder(String policyId) async {
    if (!_initialized) return;
    await _plugin.cancel(id: _insuranceId(policyId));
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  // ―― Trailer tech reminders ―――――――――――――――――――――――――――――――――――――――――

  Future<void> scheduleTrailerTechReminder(Trailer trailer) async {
    if (!_initialized) return;
    await cancelTrailerTechReminder(trailer.id);
    if (trailer.nextTechDate == null) return;

    final triggerDate = trailer.nextTechDate!
        .subtract(Duration(days: AppConstants.trailerTechReminderDays));
    if (triggerDate.isBefore(DateTime.now())) return;

    await _schedule(
      id: _trailerId(trailer.id),
      title: 'STK vozíku — ${trailer.name}',
      body:
          'Za ${AppConstants.trailerTechReminderDays} dní: technická kontrola přívěsu',
      scheduledDate: triggerDate,
      channelId: _kTrailerChannelId,
      channelName: _kTrailerChannel.name,
    );
  }

  Future<void> cancelTrailerTechReminder(String trailerId) async {
    if (!_initialized) return;
    await _plugin.cancel(id: _trailerId(trailerId));
  }

  // ── Private helpers ───────────────────────────────────────────

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String channelId,
    required String channelName,
  }) async {
    // Schedule at noon on the target day so it fires at a reasonable time
    final dt = DateTime(
        scheduledDate.year, scheduledDate.month, scheduledDate.day, 12, 0);
    final tzDate = tz.TZDateTime.from(dt, tz.local);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      // Preferred: exact alarm fires even in Doze mode (requires SCHEDULE_EXACT_ALARM)
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // Fallback if exact alarm permission was not granted by the user
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexact,
        );
      } catch (_) {
        // Notifications not supported on this device/platform — silently ignore
      }
    }
  }

  static String _fmtDate(DateTime d) => '${d.day}. ${d.month}. ${d.year}';

  /// Stable positive int ID from a UUID string — service records namespace.
  static int _serviceId(String id) => id.hashCode.abs() % 100000000;

  /// Stable positive int ID from a UUID string — insurance namespace.
  /// XOR with a constant to avoid collisions with service IDs.
  static int _insuranceId(String id) =>
      (id.hashCode ^ 0xA5F3B1).abs() % 100000000;

  /// Stable positive int ID from a UUID string — trailer namespace.
  static int _trailerId(String id) =>
      (id.hashCode ^ 0x3C7F29).abs() % 100000000;
}
