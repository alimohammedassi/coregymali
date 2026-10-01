/// One day's attendance for the heatmap — the longest recorded dwell on that
/// calendar date (`gym_attendance` holds one row per user+gym+date, so the
/// max across gyms is the day's representative session).
class AttendanceDay {
  final int minutes;

  const AttendanceDay({required this.minutes});
}

/// One raw `gym_attendance` row for the recent check-ins list.
class AttendanceRecord {
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int minutes;
  final String source;

  const AttendanceRecord({
    required this.date,
    required this.minutes,
    required this.source,
    this.checkIn,
    this.checkOut,
  });
}

