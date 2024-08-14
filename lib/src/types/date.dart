import 'package:intl/intl.dart';

/// A date in the Gregorian calendar
///
/// A date specifies a combination of year, month and day. DuckDB follows the
/// SQL standard’s lead by counting dates exclusively in the Gregorian calendar,
/// even for years before that calendar was in use.
class Date implements Comparable<Date> {
  final int daysSinceEpoch;
  static final _formatter = DateFormat('yyyy-MM-dd');
  static final _unixEpoch = DateTime.utc(1970);

  /// days since the unix date epoch `1970-01-01`
  const Date(this.daysSinceEpoch);

  Date.ymd(int year, int month, int day)
      : daysSinceEpoch =
            DateTime.utc(year, month, day).difference(_unixEpoch).inDays;

  factory Date.fromDateTime(DateTime dateTime) {
    return Date(dateTime.difference(_unixEpoch).inDays);
  }

  /// convert from Date to a DateTime
  DateTime toDateTime() {
    return DateTime.fromMillisecondsSinceEpoch(
      daysSinceEpoch * Duration.millisecondsPerDay,
      isUtc: true,
    );
  }

  @override
  String toString() {
    return _formatter.format(toDateTime());
  }

  @override
  bool operator ==(Object other) {
    if (other is Date) {
      return daysSinceEpoch == other.daysSinceEpoch;
    }
    return false;
  }

  @override
  int get hashCode => daysSinceEpoch.hashCode;

  bool isBefore(Date other) {
    return daysSinceEpoch < other.daysSinceEpoch;
  }

  bool isAfter(Date other) {
    return daysSinceEpoch > other.daysSinceEpoch;
  }

  @override
  int compareTo(Date other) {
    return daysSinceEpoch - other.daysSinceEpoch;
  }
}
