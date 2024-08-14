/// Intervals represent a period of time. This period can be measured in a
/// specific unit or combination of units, for example years, days, or seconds.
/// Intervals are generally used to modify timestamps or dates by either adding
/// or substracting them.
///
/// https://duckdb.org/docs/sql/data_types/interval.html
class Interval {
  Interval({this.months = 0, this.days = 0, this.microseconds = 0});

  factory Interval.fromParts({
    int years = 0,
    int months = 0,
    int days = 0,
    int hours = 0,
    int minutes = 0,
    int seconds = 0,
    int milliseconds = 0,
    int microseconds = 0,
  }) {
    return Interval(
      months: years * 12 + months,
      days: days,
      microseconds: hours * Duration.microsecondsPerHour +
          minutes * Duration.microsecondsPerMinute +
          seconds * Duration.microsecondsPerSecond +
          milliseconds * Duration.microsecondsPerMillisecond +
          microseconds,
    );
  }

  /// The total number of months.  May be more than 12.  For the months within
  /// the year, use [monthsPart].
  final int months;

  /// The total number of days -- should be equal to [daysPart] but keep both
  /// for clarity and consistency.
  final int days;

  /// The sub-day interval.  To get the usable parts, use [hoursPart],
  /// [minutesPart], [secondsPart], [millisecondsPart], and [microsecondsPart].
  /// [microseconds] differs from [microsecondsPart] in that it contains a
  /// (potentially large) value including all the other unit parts of a day.
  final int microseconds;

  int get yearsPart => months ~/ 12;
  int get monthsPart => months % 12;
  int get daysPart => days;
  int get hoursPart => microseconds ~/ Duration.microsecondsPerHour;
  int get minutesPart =>
      (microseconds - hoursPart * Duration.microsecondsPerHour) ~/
      Duration.microsecondsPerMinute;
  int get secondsPart =>
      (microseconds -
          hoursPart * Duration.microsecondsPerHour -
          minutesPart * Duration.microsecondsPerMinute) ~/
      Duration.microsecondsPerSecond;
  int get millisecondsPart =>
      (microseconds -
          hoursPart * Duration.microsecondsPerHour -
          minutesPart * Duration.microsecondsPerMinute -
          secondsPart * Duration.microsecondsPerSecond) ~/
      Duration.microsecondsPerMillisecond;
  int get microsecondsPart =>
      microseconds % Duration.microsecondsPerMillisecond;

  @override
  String toString() {
    return 'Interval(months: $months, days: $days, microseconds: $microseconds)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Interval &&
          runtimeType == other.runtimeType &&
          months == other.months &&
          days == other.days &&
          microseconds == other.microseconds;

  @override
  int get hashCode => months.hashCode ^ days.hashCode ^ microseconds.hashCode;
}
