// The TIME type should only be used in rare cases, where the date part of the timestamp can be disregarded.
// Most applications should use the TIMESTAMP types to represent their timestamps.
// // https://duckdb.org/docs/sql/data_types/time
class Time {
  final int hour;
  final int minute;
  final int second;
  final int microsecond;

  static const _microsecondsPerSecond = 1000000;
  static const _secondsPerMinute = 60;
  static const _minutesPerHour = 60;
  static const _secondsPerHour = _secondsPerMinute * _minutesPerHour;
  static const _secondsPerDay = _secondsPerHour * 24;

  Time({
    required this.hour,
    required this.minute,
    required this.second,
    required this.microsecond,
  })  : assert(hour >= 0 && hour < 24),
        assert(minute >= 0 && minute < 60),
        assert(second >= 0 && second < 60),
        assert(microsecond >= 0);

  factory Time.fromMicrosecondsSinceEpoch(int microsecondsSinceEpoch) {
    // Calculate total seconds and remaining microseconds
    final totalSeconds = microsecondsSinceEpoch ~/ _microsecondsPerSecond;
    final microseconds = microsecondsSinceEpoch % _microsecondsPerSecond;

    // Calculate hours, minutes, and seconds
    final hours = (totalSeconds % _secondsPerDay) ~/ _secondsPerHour;
    final minutes = (totalSeconds % _secondsPerHour) ~/ _secondsPerMinute;
    final seconds = totalSeconds % _secondsPerMinute;

    return Time(
      hour: hours,
      minute: minutes,
      second: seconds,
      microsecond: microseconds,
    );
  }

  @override
  String toString() =>
      '$hour:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}.${microsecond.toString().padLeft(6, '0')}';

  int toMicrosecondsSinceEpoch() {
    final totalSeconds =
        hour * _secondsPerHour + minute * _secondsPerMinute + second;
    final microsecondsSinceEpoch =
        totalSeconds * _microsecondsPerSecond + microsecond;
    return microsecondsSinceEpoch;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Time &&
          runtimeType == other.runtimeType &&
          hour == other.hour &&
          minute == other.minute &&
          second == other.second &&
          microsecond == other.microsecond;

  @override
  int get hashCode =>
      hour.hashCode ^ minute.hashCode ^ second.hashCode ^ microsecond.hashCode;

  int compareTo(Time other) {
    if (hour != other.hour) return hour.compareTo(other.hour);
    if (minute != other.minute) return minute.compareTo(other.minute);
    if (second != other.second) return second.compareTo(other.second);
    return microsecond.compareTo(other.microsecond);
  }
}
