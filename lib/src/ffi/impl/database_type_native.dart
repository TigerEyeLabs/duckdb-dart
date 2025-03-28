import 'dart:typed_data';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/src/ffi/duckdb.g.dart';

typedef _Double = double;

/// Enhanced enum to make type identification easier on dart, maps duckdb types to dart types.
/// Order must match DUCKDB_TYPEs. This allows us to create these using their values[index]
enum DatabaseTypeNative implements DatabaseType {
  invalid(DUCKDB_TYPE.DUCKDB_TYPE_INVALID, null),
  boolean(DUCKDB_TYPE.DUCKDB_TYPE_BOOLEAN, bool),
  tinyInt(DUCKDB_TYPE.DUCKDB_TYPE_TINYINT, int),
  smallInt(DUCKDB_TYPE.DUCKDB_TYPE_SMALLINT, int),
  integer(DUCKDB_TYPE.DUCKDB_TYPE_INTEGER, int),
  bigInt(DUCKDB_TYPE.DUCKDB_TYPE_BIGINT, int),
  uTinyInt(DUCKDB_TYPE.DUCKDB_TYPE_UTINYINT, int),
  uSmallInt(DUCKDB_TYPE.DUCKDB_TYPE_USMALLINT, int),
  uInteger(DUCKDB_TYPE.DUCKDB_TYPE_UINTEGER, int),
  uBigInt(DUCKDB_TYPE.DUCKDB_TYPE_UBIGINT, BigInt),
  float(DUCKDB_TYPE.DUCKDB_TYPE_FLOAT, _Double),
  double(DUCKDB_TYPE.DUCKDB_TYPE_DOUBLE, _Double),
  timestamp(DUCKDB_TYPE.DUCKDB_TYPE_TIMESTAMP, DateTime),
  date(DUCKDB_TYPE.DUCKDB_TYPE_DATE, Date),
  time(DUCKDB_TYPE.DUCKDB_TYPE_TIME, null),
  interval(DUCKDB_TYPE.DUCKDB_TYPE_INTERVAL, Interval),
  hugeInt(DUCKDB_TYPE.DUCKDB_TYPE_HUGEINT, BigInt),
  varchar(DUCKDB_TYPE.DUCKDB_TYPE_VARCHAR, String),
  blob(DUCKDB_TYPE.DUCKDB_TYPE_BLOB, Uint8List),
  decimal(DUCKDB_TYPE.DUCKDB_TYPE_DECIMAL, Decimal),
  timestampS(DUCKDB_TYPE.DUCKDB_TYPE_TIMESTAMP_S, DateTime),
  timestampMS(DUCKDB_TYPE.DUCKDB_TYPE_TIMESTAMP_MS, DateTime),
  timestampNS(DUCKDB_TYPE.DUCKDB_TYPE_TIMESTAMP_NS, DateTime),
  enumeration(DUCKDB_TYPE.DUCKDB_TYPE_ENUM, null),
  list(DUCKDB_TYPE.DUCKDB_TYPE_LIST, List),
  structure(DUCKDB_TYPE.DUCKDB_TYPE_STRUCT, Map<String, Object>),
  map(DUCKDB_TYPE.DUCKDB_TYPE_MAP, null),
  uuid(DUCKDB_TYPE.DUCKDB_TYPE_UUID, null),
  union(DUCKDB_TYPE.DUCKDB_TYPE_UNION, null),
  bitString(DUCKDB_TYPE.DUCKDB_TYPE_BIT, String),
  timeTz(DUCKDB_TYPE.DUCKDB_TYPE_TIME_TZ, null),
  timestampTz(DUCKDB_TYPE.DUCKDB_TYPE_TIMESTAMP_TZ, DateTime),
  uHugeInt(DUCKDB_TYPE.DUCKDB_TYPE_UHUGEINT, BigInt),
  array(DUCKDB_TYPE.DUCKDB_TYPE_ARRAY, null),
  any(DUCKDB_TYPE.DUCKDB_TYPE_ANY, null),
  varInt(DUCKDB_TYPE.DUCKDB_TYPE_VARINT, null);

  final DUCKDB_TYPE _value;

  final Type? _dartType;

  const DatabaseTypeNative(this._value, this._dartType);

  factory DatabaseTypeNative.fromValue(int value) {
    return DatabaseTypeNative.values.firstWhere(
      (type) => type._value.value == value,
      orElse: () => DatabaseTypeNative.invalid,
    );
  }

  @override
  Type? get dartType => _dartType;
  DUCKDB_TYPE get duckDbType => _value;

  @override
  bool get isDate =>
      this == date ||
      this == timestamp ||
      this == timestampS ||
      this == timestampMS ||
      this == timestampNS ||
      this == timestampTz;

  @override
  bool get isNumeric =>
      this == float ||
      this == double ||
      this == integer ||
      this == bigInt ||
      this == uInteger ||
      this == uHugeInt ||
      this == hugeInt ||
      this == uBigInt ||
      this == tinyInt ||
      this == smallInt ||
      this == uTinyInt ||
      this == uSmallInt;

  @override
  bool get isText => this == varchar || this == bitString;

  @override
  int get value => _value.value;
}

class DatabaseTypeFactory {
  static DatabaseType fromValue(int value) {
    return DatabaseTypeNative.fromValue(value);
  }
}
