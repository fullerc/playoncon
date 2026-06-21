import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// A saved event's reminder choice, expressed as minutes before the start.
///
/// - [leadMinutes] == null  → no reminder
/// - [leadMinutes] == 0      → at start time
/// - [leadMinutes]  > 0      → that many minutes before start (custom, 1–120)
class Reminder {
  final int? leadMinutes;
  const Reminder(this.leadMinutes);
  const Reminder.none() : leadMinutes = null;
  const Reminder.atStart() : leadMinutes = 0;
  const Reminder.minutes(int minutes) : leadMinutes = minutes;

  bool get isNone => leadMinutes == null;

  /// JSON value stored per event (`null` or an int).
  Object? toJsonValue() => leadMinutes;

  /// Tolerant decode: current int form, legacy enum-name strings, or null.
  static Reminder fromJsonValue(Object? v) {
    if (v == null) return const Reminder.none();
    if (v is int) return Reminder(v);
    if (v is String) {
      switch (v) {
        case 'none':
          return const Reminder.none();
        case 'atStart':
          return const Reminder.atStart();
        case 'fifteenMinutesBefore':
          return const Reminder.minutes(15);
      }
      final n = int.tryParse(v);
      if (n != null) return Reminder(n);
    }
    return const Reminder.none();
  }

  @override
  bool operator ==(Object other) =>
      other is Reminder && other.leadMinutes == leadMinutes;

  @override
  int get hashCode => leadMinutes.hashCode;
}

/// Persists the user's "My Schedule" as a map of event ID → [Reminder].
///
/// Offline-first, same pattern as the schedule cache: source of truth is
/// `<appDocs>/saved_events.json`. An event is "saved" iff its ID is a key
/// (even with a none reminder). IDs are the parser's stable
/// `title|start|location` hash, so saves survive a re-sync unless the cell
/// text/time/venue changes.
class SavedEventsStore extends StateNotifier<Map<String, Reminder>> {
  SavedEventsStore() : super(const {}) {
    _load();
  }

  static const _fileName = 'saved_events.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> _load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is Map) {
        state = decoded.map(
          (k, v) => MapEntry(k as String, Reminder.fromJsonValue(v)),
        );
      } else if (decoded is List) {
        // Legacy format (array of IDs, pre-reminders) → no reminder.
        state = {for (final id in decoded) id as String: const Reminder.none()};
      }
    } catch (_) {
      // Corrupt/missing → empty.
    }
  }

  Future<void> _persist() async {
    try {
      final f = await _file();
      await f.writeAsString(
        jsonEncode(state.map((k, v) => MapEntry(k, v.toJsonValue()))),
      );
    } catch (_) {
      // Non-fatal; in-memory state still reflects the user's choice.
    }
  }

  bool isSaved(String id) => state.containsKey(id);

  Reminder reminderFor(String id) => state[id] ?? const Reminder.none();

  void save(String id, Reminder reminder) {
    state = {...state, id: reminder};
    _persist();
  }

  void remove(String id) {
    if (!state.containsKey(id)) return;
    state = Map<String, Reminder>.of(state)..remove(id);
    _persist();
  }
}

final savedEventsProvider =
    StateNotifierProvider<SavedEventsStore, Map<String, Reminder>>(
        (_) => SavedEventsStore());

/// Remembers the last custom reminder lead time (in minutes) the user picked,
/// so it can be offered as a one-tap option when saving future events.
/// `null` until the user has chosen a custom time at least once.
class LastCustomReminderStore extends StateNotifier<int?> {
  LastCustomReminderStore() : super(null) {
    _load();
  }

  static const _fileName = 'last_custom_reminder.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> _load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final v = jsonDecode(await f.readAsString());
      if (v is int) state = v;
    } catch (_) {
      // ignore
    }
  }

  Future<void> set(int minutes) async {
    state = minutes;
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode(minutes));
    } catch (_) {
      // Non-fatal.
    }
  }
}

final lastCustomReminderProvider =
    StateNotifierProvider<LastCustomReminderStore, int?>(
        (_) => LastCustomReminderStore());
