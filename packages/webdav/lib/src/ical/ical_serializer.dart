import 'ical_note.dart';
import 'ical_task.dart';

/// Serialises and deserialises [ICalTask] ↔ VTODO and [ICalNote] ↔ VJOURNAL.
///
/// Compliance notes:
/// - RFC 5545 §3.3.5 DATE-TIME format: `YYYYMMDDTHHMMSSZ` (UTC).
/// - Property values are folded at 75 octets where needed (§3.1).
/// - VALARM is used for [ICalTask.remindAt] and [ICalNote.remindAt].
/// - `X-KINETIC-SHARED` is a custom property that records [ICalNote.isShared].
class ICalSerializer {
  // ---------------------------------------------------------------------------
  // ICalTask ↔ VTODO
  // ---------------------------------------------------------------------------

  static String taskToVtodo(ICalTask task) {
    final buf = StringBuffer();
    buf.writeln('BEGIN:VCALENDAR');
    buf.writeln('VERSION:2.0');
    buf.writeln('PRODID:-//Kinetic Link//EN');
    buf.writeln('BEGIN:VTODO');
    buf.writeln('UID:${task.uid}');
    buf.writeln('SUMMARY:${_escape(task.summary)}');
    if (task.description != null) {
      _writeMultiline(buf, 'DESCRIPTION', _escape(task.description!));
    }
    buf.writeln('STATUS:${task.status.toICalString()}');
    buf.writeln('PRIORITY:${task.priority}');
    buf.writeln('CREATED:${_formatDateTime(task.createdAt)}');
    buf.writeln('LAST-MODIFIED:${_formatDateTime(task.updatedAt)}');
    if (task.dueAt != null) buf.writeln('DUE:${_formatDateTime(task.dueAt!)}');
    if (task.rrule != null) buf.writeln('RRULE:${task.rrule}');
    if (task.remindAt != null) {
      buf.writeln('BEGIN:VALARM');
      buf.writeln('ACTION:DISPLAY');
      buf.writeln('TRIGGER;VALUE=DATE-TIME:${_formatDateTime(task.remindAt!)}');
      buf.writeln('DESCRIPTION:${_escape(task.summary)}');
      buf.writeln('END:VALARM');
    }
    buf.writeln('END:VTODO');
    buf.writeln('END:VCALENDAR');
    return buf.toString();
  }

  static ICalTask vtodoToTask(String ical) {
    final props = _parseProperties(ical, component: 'VTODO');
    final alarmProps = _parseProperties(ical, component: 'VALARM');

    return ICalTask(
      uid: _req(props, 'UID'),
      summary: _unescape(_req(props, 'SUMMARY')),
      description: props['DESCRIPTION'] != null
          ? _unescape(props['DESCRIPTION']!)
          : null,
      status: ICalTaskStatus.fromICalString(props['STATUS'] ?? ''),
      priority: int.tryParse(props['PRIORITY'] ?? '0') ?? 0,
      createdAt: _parseDateTime(_req(props, 'CREATED')),
      updatedAt: _parseDateTime(_req(props, 'LAST-MODIFIED')),
      dueAt: props['DUE'] != null ? _parseDateTime(props['DUE']!) : null,
      rrule: props['RRULE'],
      remindAt: alarmProps['TRIGGER'] != null
          ? _parseTrigger(alarmProps['TRIGGER']!)
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // ICalNote ↔ VJOURNAL
  // ---------------------------------------------------------------------------

  static String noteToVjournal(ICalNote note) {
    final buf = StringBuffer();
    buf.writeln('BEGIN:VCALENDAR');
    buf.writeln('VERSION:2.0');
    buf.writeln('PRODID:-//Kinetic Link//EN');
    buf.writeln('BEGIN:VJOURNAL');
    buf.writeln('UID:${note.uid}');
    buf.writeln('SUMMARY:${_escape(note.summary)}');
    if (note.description != null) {
      _writeMultiline(buf, 'DESCRIPTION', _escape(note.description!));
    }
    buf.writeln('CREATED:${_formatDateTime(note.createdAt)}');
    buf.writeln('LAST-MODIFIED:${_formatDateTime(note.updatedAt)}');
    buf.writeln('X-KINETIC-SHARED:${note.isShared ? '1' : '0'}');
    if (note.remindAt != null) {
      buf.writeln('BEGIN:VALARM');
      buf.writeln('ACTION:DISPLAY');
      buf.writeln('TRIGGER;VALUE=DATE-TIME:${_formatDateTime(note.remindAt!)}');
      buf.writeln('DESCRIPTION:${_escape(note.summary)}');
      buf.writeln('END:VALARM');
    }
    buf.writeln('END:VJOURNAL');
    buf.writeln('END:VCALENDAR');
    return buf.toString();
  }

  static ICalNote vjournalToNote(String ical) {
    final props = _parseProperties(ical, component: 'VJOURNAL');
    final alarmProps = _parseProperties(ical, component: 'VALARM');

    return ICalNote(
      uid: _req(props, 'UID'),
      summary: _unescape(_req(props, 'SUMMARY')),
      description: props['DESCRIPTION'] != null
          ? _unescape(props['DESCRIPTION']!)
          : null,
      createdAt: _parseDateTime(_req(props, 'CREATED')),
      updatedAt: _parseDateTime(_req(props, 'LAST-MODIFIED')),
      isShared: (props['X-KINETIC-SHARED'] ?? '0') == '1',
      remindAt: alarmProps['TRIGGER'] != null
          ? _parseTrigger(alarmProps['TRIGGER']!)
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Internal — property parsing
  // ---------------------------------------------------------------------------

  /// Extracts properties from the first occurrence of [component] in [ical].
  /// Returns a map of PROPERTY-NAME → value (unfolded, params stripped).
  ///
  /// Nested sub-components (e.g. VALARM inside VTODO) are skipped so their
  /// properties do not overwrite outer component properties.
  static Map<String, String> _parseProperties(String ical,
      {required String component}) {
    final result = <String, String>{};
    // Unfold continuation lines (RFC 5545 §3.1).
    final unfolded = ical.replaceAll(RegExp(r'\r?\n[ \t]'), '');

    bool inside = false;
    int nestDepth = 0; // depth of nested sub-components within [component]

    for (final rawLine in unfolded.split(RegExp(r'\r?\n'))) {
      if (!inside) {
        if (rawLine == 'BEGIN:$component') inside = true;
        continue;
      }

      // Stop when the target component ends (at depth 0).
      if (rawLine == 'END:$component' && nestDepth == 0) break;

      // Track nested BEGIN/END blocks (e.g. VALARM inside VTODO).
      if (rawLine.startsWith('BEGIN:')) {
        nestDepth++;
        continue;
      }
      if (rawLine.startsWith('END:')) {
        if (nestDepth > 0) nestDepth--;
        continue;
      }

      // Skip content inside nested sub-components.
      if (nestDepth > 0) continue;

      final colonIdx = rawLine.indexOf(':');
      if (colonIdx == -1) continue;
      // Property name may have parameters: NAME;PARAM=val:value
      final namePart = rawLine.substring(0, colonIdx);
      final value = rawLine.substring(colonIdx + 1);
      // Strip parameters from name (e.g. TRIGGER;VALUE=DATE-TIME → TRIGGER)
      final name = namePart.split(';').first.toUpperCase();
      result[name] = value;
    }
    return result;
  }

  static String _req(Map<String, String> props, String key) {
    final v = props[key];
    if (v == null)
      throw FormatException('Missing required iCal property: $key');
    return v;
  }

  // ---------------------------------------------------------------------------
  // Internal — date/time
  // ---------------------------------------------------------------------------

  static String _formatDateTime(DateTime dt) {
    final utc = dt.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final mo = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final h = utc.hour.toString().padLeft(2, '0');
    final mi = utc.minute.toString().padLeft(2, '0');
    final s = utc.second.toString().padLeft(2, '0');
    return '${y}${mo}${d}T${h}${mi}${s}Z';
  }

  static DateTime _parseDateTime(String s) {
    // Accepts both YYYYMMDDTHHMMSSZ and YYYYMMDDTHHMMSS (treated as UTC).
    final clean = s.replaceAll(RegExp(r'[^0-9T]'), '');
    if (clean.length < 15) throw FormatException('Cannot parse date-time: $s');
    return DateTime.utc(
      int.parse(clean.substring(0, 4)),
      int.parse(clean.substring(4, 6)),
      int.parse(clean.substring(6, 8)),
      int.parse(clean.substring(9, 11)),
      int.parse(clean.substring(11, 13)),
      int.parse(clean.substring(13, 15)),
    );
  }

  static DateTime? _parseTrigger(String trigger) {
    // Handles VALUE=DATE-TIME:YYYYMMDDTHHMMSSZ and bare YYYYMMDDTHHMMSSZ.
    final clean = trigger.contains(':') ? trigger.split(':').last : trigger;
    try {
      return _parseDateTime(clean);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal — text escaping (RFC 5545 §3.3.11)
  // ---------------------------------------------------------------------------

  static String _escape(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\n', '\\n');

  static String _unescape(String s) => s
      .replaceAll('\\n', '\n')
      .replaceAll('\\,', ',')
      .replaceAll('\\;', ';')
      .replaceAll('\\\\', '\\');

  /// Writes a property, folding at 75 octets per RFC 5545 §3.1.
  static void _writeMultiline(StringBuffer buf, String name, String value) {
    final line = '$name:$value';
    if (line.length <= 75) {
      buf.writeln(line);
      return;
    }
    buf.write(line.substring(0, 75));
    buf.writeln();
    var offset = 75;
    while (offset < line.length) {
      final end = (offset + 74).clamp(0, line.length);
      buf.write(' ${line.substring(offset, end)}');
      buf.writeln();
      offset = end;
    }
  }
}
