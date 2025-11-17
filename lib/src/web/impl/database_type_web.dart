import 'dart:typed_data';

import 'package:dart_duckdb/dart_duckdb.dart';

/// from apache-arrow
enum DatabaseTypeWeb implements DatabaseType {
  none(0),
  null_(1),
  integer(2),
  float(3),
  binary(4),
  utf8(5),
  boolean(6),
  decimal(7),
  date(8),
  time(9),
  timestamp(10),
  interval(11),
  list(12),
  struct(13),
  union(14),
  fixedSizeBinary(15),
  fixedSizeList(16),
  map(17),
  duration(18),
  largeBinary(19),
  largeUtf8(20),

  // Specialized types with negative values
  dictionary(-1),
  int8(-2),
  int16(-3),
  int32(-4),
  int64(-5),
  uint8(-6),
  uint16(-7),
  uint32(-8),
  uint64(-9),
  float16(-10),
  float32(-11),
  float64(-12),
  dateDay(-13),
  dateMillisecond(-14),
  timestampSecond(-15),
  timestampMillisecond(-16),
  timestampMicrosecond(-17),
  timestampNanosecond(-18),
  timeSecond(-19),
  timeMillisecond(-20),
  timeMicrosecond(-21),
  timeNanosecond(-22),
  denseUnion(-23),
  sparseUnion(-24),
  intervalDayTime(-25),
  intervalYearMonth(-26),
  durationSecond(-27),
  durationMillisecond(-28),
  durationMicrosecond(-29),
  durationNanosecond(-30);

  final int _value;
  const DatabaseTypeWeb(this._value);

  factory DatabaseTypeWeb.fromValue(int value) {
    return DatabaseTypeWeb.values.firstWhere(
      (type) => type.value == value,
      orElse: () => DatabaseTypeWeb.none,
    );
  }

  @override
  Type? get dartType {
    return switch (this) {
      DatabaseTypeWeb.boolean => bool,
      DatabaseTypeWeb.integer ||
      DatabaseTypeWeb.int32 ||
      DatabaseTypeWeb.int16 ||
      DatabaseTypeWeb.int8 ||
      DatabaseTypeWeb.uint8 ||
      DatabaseTypeWeb.uint16 ||
      DatabaseTypeWeb.uint32 =>
        int,
      DatabaseTypeWeb.int64 || DatabaseTypeWeb.uint64 => BigInt,
      DatabaseTypeWeb.float ||
      DatabaseTypeWeb.float32 ||
      DatabaseTypeWeb.float64 =>
        double,
      DatabaseTypeWeb.utf8 || DatabaseTypeWeb.largeUtf8 => String,
      DatabaseTypeWeb.binary ||
      DatabaseTypeWeb.largeBinary ||
      DatabaseTypeWeb.fixedSizeBinary =>
        Uint8List,
      DatabaseTypeWeb.date ||
      DatabaseTypeWeb.dateDay ||
      DatabaseTypeWeb.dateMillisecond =>
        DateTime,
      DatabaseTypeWeb.timestamp ||
      DatabaseTypeWeb.timestampSecond ||
      DatabaseTypeWeb.timestampMillisecond ||
      DatabaseTypeWeb.timestampMicrosecond ||
      DatabaseTypeWeb.timestampNanosecond =>
        DateTime,
      DatabaseTypeWeb.list || DatabaseTypeWeb.fixedSizeList => List,
      DatabaseTypeWeb.struct => Map<String, Object>,
      _ => null,
    };
  }

  @override
  bool get isDate => this == date || this == dateDay || this == dateMillisecond;

  @override
  bool get isNumeric =>
      this == integer ||
      this == float ||
      this == int8 ||
      this == int16 ||
      this == int32 ||
      this == int64 ||
      this == uint8 ||
      this == uint16 ||
      this == uint32 ||
      this == uint64 ||
      this == float16 ||
      this == float32 ||
      this == float64;

  @override
  bool get isText => this == utf8 || this == largeUtf8;

  bool get isTime =>
      this == time ||
      this == timeSecond ||
      this == timeMillisecond ||
      this == timeMicrosecond ||
      this == timeNanosecond;

  bool get isTimestamp =>
      this == timestamp ||
      this == timestampSecond ||
      this == timestampMillisecond ||
      this == timestampMicrosecond ||
      this == timestampNanosecond;

  @override
  int get value => _value;
}

class DatabaseTypeFactory {
  static DatabaseType fromValue(int value) {
    return DatabaseTypeWeb.fromValue(value);
  }
}
