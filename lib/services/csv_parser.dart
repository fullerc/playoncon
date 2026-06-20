import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../models/event.dart';
import '../models/venue_location.dart';

class CsvScheduleParser {
  final Map<String, VenueLocation> _locationsByName;

  CsvScheduleParser(List<VenueLocation> locations)
      : _locationsByName = {
          for (final loc in locations) loc.displayName.toLowerCase(): loc,
        };

  List<Event> parse(String csvText) {
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(csvText);

    if (rows.length < 2) return [];

    final headers =
        rows.first.map((h) => h.toString().trim()).toList(growable: false);

    final events = <Event>[];
    for (final row in rows.skip(1)) {
      final map = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        if (headers[i].isEmpty) continue;
        map[headers[i]] = i < row.length ? row[i].toString() : '';
      }
      final evt = _toEvent(map);
      if (evt != null) events.add(evt);
    }
    return events;
  }

  Event? _toEvent(Map<String, String> row) {
    final title = _pick(row, ['Title', 'Event', 'Name'])?.trim() ?? '';
    if (title.isEmpty) return null;

    final start = _parseDate(_pick(row, ['Start', 'StartTime', 'Start Time']));
    if (start == null) return null;

    final end = _parseDate(_pick(row, ['End', 'EndTime', 'End Time'])) ??
        start.add(const Duration(hours: 1));

    final locName = _pick(row, ['Location', 'Room', 'Venue'])?.trim();
    final track = _pick(row, ['Track', 'Category', 'Type'])?.trim();
    final presenter =
        _pick(row, ['Presenter', 'Host', 'Speaker', 'GM'])?.trim();
    final details = _pick(row, ['Description', 'Details', 'Notes'])?.trim();

    final providedId = _pick(row, ['ID', 'Id', 'EventID'])?.trim();
    final id = (providedId != null && providedId.isNotEmpty)
        ? providedId
        : _stableId(title, start, locName);

    final locKey = locName != null
        ? _locationsByName[locName.toLowerCase()]?.key
        : null;

    return Event(
      id: id,
      title: title,
      startTime: start,
      endTime: end,
      locationKey: locKey,
      locationDisplayName: locName,
      track: track,
      presenter: presenter,
      details: details,
    );
  }

  String? _pick(Map<String, String> row, List<String> keys) {
    for (final k in keys) {
      final v = row[k];
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  static final List<DateFormat> _dateFormatters = [
    DateFormat('yyyy-MM-dd HH:mm'),
    DateFormat("yyyy-MM-dd'T'HH:mm:ss"),
    DateFormat('M/d/yyyy h:mm a'),
    DateFormat('M/d/yyyy HH:mm'),
    DateFormat('MM/dd/yyyy HH:mm'),
  ];

  DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    for (final fmt in _dateFormatters) {
      try {
        return fmt.parseStrict(s);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  String _stableId(String title, DateTime start, String? location) {
    return '${title.hashCode}_${start.millisecondsSinceEpoch}_${(location ?? '').hashCode}';
  }
}
