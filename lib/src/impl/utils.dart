import 'dart:collection';
import 'dart:typed_data';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/src/ffi/ffi.dart';
import 'package:dart_duckdb/src/impl/implementation.dart';

final BigInt hugeIntMin = BigInt.from(-1) << 127;
final BigInt hugeIntMax = (BigInt.from(1) << 127) - BigInt.one;
final BigInt uHugeIntMax = (BigInt.from(1) << 128) - BigInt.one;

extension DuckdbVector on duckdb_vector {
  LogicalType logicalType() {
    final logicalType = allocate<duckdb_logical_type>();
    logicalType.value = Pointer.fromAddress(
      duckdb.bindings.duckdb_vector_get_column_type(this).address,
    );
    return LogicalType.withLogicalType(logicalType);
  }
}

extension HugeInt on BigInt {
  Pointer<duckdb_hugeint> toHugeInt() {
    assert(
      this >= hugeIntMin,
      'Value is less than the minimum signed 128-bit integer.',
    );

    final hugeInt = allocate<duckdb_hugeint>();

    hugeInt.ref.lower = toSigned(64).toInt();
    hugeInt.ref.upper = (toSigned(128) >> 64).toInt();

    return hugeInt;
  }
}

extension UHugeInt on BigInt {
  // Converts BigInt to Uint64 through a raw byte sequence,
  // we can't use BigInt.toInt because it will clamp the data
  int _bigIntToUint64(BigInt bigInt) {
    var unsignedBigInt = bigInt.toUnsigned(64);

    final byteData = ByteData(8);
    for (var i = 0; i < 8; i++) {
      byteData.setUint8(7 - i, (unsignedBigInt & BigInt.from(255)).toInt());
      unsignedBigInt = unsignedBigInt >> 8;
    }

    return byteData.getUint64(0);
  }

  Pointer<duckdb_uhugeint> toUHugeInt() {
    assert(
      this <= uHugeIntMax,
      'Value exceeds the maximum unsigned 128-bit integer.',
    );

    // Allocate memory for the duckdb_uhugeint structure
    final uhugeInt = allocate<duckdb_uhugeint>();
    // Get the lower 64 bits
    uhugeInt.ref.lower = _bigIntToUint64(this);
    // Get the upper 64 bits
    uhugeInt.ref.upper = _bigIntToUint64(toUnsigned(128) >> 64);
    return uhugeInt;
  }
}

extension Timestamp on DateTime {
  Pointer<duckdb_timestamp> toTimestamp() {
    final timestamp = allocate<duckdb_timestamp>();
    timestamp.ref.micros = microsecondsSinceEpoch;
    return timestamp;
  }
}

extension IntervalPointer on Interval {
  Pointer<duckdb_interval> toDuckDbInterval() {
    final interval = allocate<duckdb_interval>();
    interval.ref.months = months;
    interval.ref.days = days;
    interval.ref.micros = microseconds;
    return interval;
  }
}

extension SqlString on String {
  bool get isAlphaNumeric {
    if (isEmpty) {
      return false;
    }
    final codeUnit = codeUnitAt(0);
    return (codeUnit >= 48 && codeUnit <= 57) ||
        (codeUnit >= 65 && codeUnit <= 90) ||
        (codeUnit >= 97 && codeUnit <= 122);
  }

  bool get isAlpha {
    if (isEmpty) {
      return false;
    }
    final codeUnit = codeUnitAt(0);
    return (codeUnit >= 65 && codeUnit <= 90) ||
        (codeUnit >= 97 && codeUnit <= 122);
  }

  List<String> getNamedParameters() {
    final params = <String>[];
    var currentParam = '';
    var inQuotes = false;
    var inParam = false;

    for (var i = 0; i < length; i++) {
      final ch = this[i];

      if (ch == "'" || ch == '"') {
        inQuotes = !inQuotes;
      }

      if (!inQuotes &&
          ch == '\$' &&
          ((i + 1) < length && this[i + 1].isAlpha)) {
        inParam = true;
        currentParam += ch;
      } else if (inParam && (ch.isAlphaNumeric || ch == '_')) {
        currentParam += ch;
      } else if (inParam && !ch.isAlphaNumeric) {
        params.add(currentParam);
        currentParam = '';
        inParam = false;
      }
    }

    // Add the last parameter if it ended with the SQL string
    if (currentParam.isNotEmpty) {
      params.add(currentParam);
    }

    return params;
  }
}

extension DuckdbValuePointerExtension on Pointer<duckdb_value> {
  /// Creates a List-like view of the allocated duckdb_value array.
  /// [length] specifies the number of elements in the array.
  List<duckdb_value> asTypedList(int length) {
    if (length <= 0) {
      throw ArgumentError('Length must be positive');
    }
    return _DuckdbValueList(this, length);
  }
}

/// A List-like wrapper around Pointer<duckdb_value>.
class _DuckdbValueList extends ListBase<duckdb_value> {
  final Pointer<duckdb_value> _pointer;
  @override
  final int length;

  _DuckdbValueList(this._pointer, this.length);

  @override
  duckdb_value operator [](int index) {
    if (index < 0 || index >= length) {
      throw RangeError.index(index, this, 'index', null, length);
    }
    return (_pointer + index).value;
  }

  @override
  void operator []=(int index, duckdb_value value) {
    if (index < 0 || index >= length) {
      throw RangeError.index(index, this, 'index', null, length);
    }
    (_pointer + index).value = value;
  }

  @override
  set length(int newLength) {
    throw UnsupportedError('Cannot change the length of a fixed-length list');
  }
}

extension ValidityMask on Pointer<Uint64> {
  bool isElementNull(int offsetIndex) {
    if (isNullPointer) {
      return false;
    }

    final validityEntryIndex = offsetIndex ~/ 64;
    final validityBitIndex = offsetIndex % 64;
    final validityMask = this[validityEntryIndex];
    final validityBit = 1 << validityBitIndex;
    return (validityMask & validityBit) == 0;
  }
}
