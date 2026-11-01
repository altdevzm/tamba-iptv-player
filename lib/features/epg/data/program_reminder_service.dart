import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ProgramReminder {
  final String id;
  final String channelId;
  final String channelName;
  final String? channelLogo;
  final String? streamUrl;
  final String programTitle;
  final String? programDescription;
  final DateTime startTime; // UTC
  final DateTime stopTime; // UTC
  final int leadMinutes; // 5, 10, 15
  final DateTime createdAt;
  bool isNotified;

  ProgramReminder({
    required this.id,
    required this.channelId,
    required this.channelName,
    this.channelLogo,
    this.streamUrl,
    required this.programTitle,
    this.programDescription,
    required this.startTime,
    required this.stopTime,
    this.leadMinutes = 5,
    DateTime? createdAt,
    this.isNotified = false,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  DateTime get reminderTriggerTime =>
      startTime.subtract(Duration(minutes: leadMinutes));

  Map<String, dynamic> toJson() => {
        'id': id,
        'channelId': channelId,
        'channelName': channelName,
        'channelLogo': channelLogo,
        'streamUrl': streamUrl,
        'programTitle': programTitle,
        'programDescription': programDescription,
        'startTime': startTime.toIso8601String(),
        'stopTime': stopTime.toIso8601String(),
        'leadMinutes': leadMinutes,
        'createdAt': createdAt.toIso8601String(),
        'isNotified': isNotified,
      };

  factory ProgramReminder.fromJson(Map<String, dynamic> json) {
    return ProgramReminder(
      id: json['id'] as String,
      channelId: json['channelId'] as String,
      channelName: json['channelName'] as String,
      channelLogo: json['channelLogo'] as String?,
      streamUrl: json['streamUrl'] as String?,
      programTitle: json['programTitle'] as String,
      programDescription: json['programDescription'] as String?,
      startTime: DateTime.parse(json['startTime'] as String).toUtc(),
      stopTime: DateTime.parse(json['stopTime'] as String).toUtc(),
      leadMinutes: json['leadMinutes'] as int? ?? 5,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String).toUtc()
          : DateTime.now().toUtc(),
      isNotified: json['isNotified'] as bool? ?? false,
    );
  }
}

class ProgramReminderService extends ChangeNotifier {
  File? _file;
  final List<ProgramReminder> _reminders = [];
  Timer? _checkTimer;

  // Stream of triggered notifications for in-app banners/dialogs
  final _notificationController = StreamController<ProgramReminder>.broadcast();
  Stream<ProgramReminder> get onReminderTriggered => _notificationController.stream;

  List<ProgramReminder> get reminders => List.unmodifiable(_reminders);

  ProgramReminderService() {
    _init();
  }

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    _file = File(p.join(dir.path, 'filimu_reminders.json'));
    return _file!;
  }

  Future<void> _init() async {
    await _load();
    _startChecker();
  }

  Future<void> _load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = jsonDecode(content) as List<dynamic>;
        _reminders.clear();
        for (final item in list) {
          _reminders.add(ProgramReminder.fromJson(item as Map<String, dynamic>));
        }
        // Purge expired reminders older than 24 hours past stop time
        final now = DateTime.now().toUtc();
        _reminders.removeWhere((r) => r.stopTime.add(const Duration(hours: 24)).isBefore(now));
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final file = await _getFile();
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      final raw = jsonEncode(_reminders.map((r) => r.toJson()).toList());
      await file.writeAsString(raw);
    } catch (_) {}
  }

  void _startChecker() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _checkDueReminders();
    });
  }

  void _checkDueReminders() {
    final now = DateTime.now().toUtc();
    for (final reminder in _reminders) {
      if (!reminder.isNotified && now.isAfter(reminder.reminderTriggerTime) && now.isBefore(reminder.stopTime)) {
        reminder.isNotified = true;
        _notificationController.add(reminder);
        _save();
        notifyListeners();
      }
    }
  }

  bool isReminderSet(String programTitle, String channelId, DateTime startTime) {
    return _reminders.any((r) =>
        r.channelId == channelId &&
        r.programTitle == programTitle &&
        r.startTime.millisecondsSinceEpoch == startTime.toUtc().millisecondsSinceEpoch);
  }

  Future<bool> addReminder(ProgramReminder reminder) async {
    // Avoid duplicates
    if (isReminderSet(reminder.programTitle, reminder.channelId, reminder.startTime)) {
      return false;
    }
    _reminders.add(reminder);
    // Sort upcoming first
    _reminders.sort((a, b) => a.startTime.compareTo(b.startTime));
    await _save();
    notifyListeners();
    return true;
  }

  Future<void> removeReminder(String id) async {
    _reminders.removeWhere((r) => r.id == id);
    await _save();
    notifyListeners();
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _notificationController.close();
    super.dispose();
  }
}

final programReminderServiceProvider = ChangeNotifierProvider<ProgramReminderService>((ref) {
  return ProgramReminderService();
});

final activeRemindersProvider = Provider<List<ProgramReminder>>((ref) {
  final service = ref.watch(programReminderServiceProvider);
  final now = DateTime.now().toUtc();
  return service.reminders.where((r) => r.stopTime.isAfter(now)).toList();
});

