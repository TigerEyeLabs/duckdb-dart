import 'package:dart_duckdb/src/types/time.dart';

// Add the timezone offset to the [Time] type, to match duckdb's TIMETZ type.
// https://duckdb.org/docs/sql/data_types/time
class TimeWithOffset extends Time {
  final int offsetSeconds;

  TimeWithOffset({
    required super.hour,
    required super.minute,
    required super.second,
    required super.microsecond,
    required this.offsetSeconds,
  });

  factory TimeWithOffset.fromMicrosecondsSinceEpoch(
    int microsecondsSinceMidnightUtc,
    int offsetSeconds,
  ) {
    final timeUtc =
        Time.fromMicrosecondsSinceEpoch(microsecondsSinceMidnightUtc);
    return TimeWithOffset(
      hour: timeUtc.hour,
      minute: timeUtc.minute,
      second: timeUtc.second,
      microsecond: timeUtc.microsecond,
      offsetSeconds: offsetSeconds,
    );
  }

  @override
  String toString() {
    final totalMicroseconds =
        toMicrosecondsSinceEpoch() - offsetSeconds * 1000000;

    return '${Time.fromMicrosecondsSinceEpoch(totalMicroseconds)}+00';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is TimeWithOffset &&
          runtimeType == other.runtimeType &&
          offsetSeconds == other.offsetSeconds;

  @override
  int get hashCode => super.hashCode ^ offsetSeconds.hashCode;

  TimeWithOffset toUtc() {
    return TimeWithOffset(
      hour: hour,
      minute: minute,
      second: second,
      microsecond: microsecond,
      offsetSeconds: 0,
    );
  }
}
