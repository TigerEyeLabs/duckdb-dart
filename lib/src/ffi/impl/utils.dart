// ignore_for_file: unintended_html_in_doc_comment

import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_duckdb/src/ffi/duckdb.g.dart';
import 'package:dart_duckdb/src/ffi/duckdb_ffi.dart';
import 'package:dart_duckdb/src/ffi/impl/implementation.dart';
import 'package:dart_duckdb/src/types/interval.dart';
import 'package:ffi/ffi.dart';

extension DuckdbVector on duckdb_vector {
  LogicalType logicalType() {
    final logicalType = allocate<duckdb_logical_type>();
    logicalType.value = Pointer.fromAddress(
      (duckdb as DuckDB).bindings.duckdb_vector_get_column_type(this).address,
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

extension Utf8Utils on Pointer<Char> {
  int get _length {
    final asBytes = cast<Uint8>();
    var length = 0;

    for (; asBytes[length] != 0; length++) {}
    return length;
  }

  String readString([int? length]) {
    final resolvedLength = length ??= _length;

    return utf8.decode(cast<Uint8>().asTypedList(resolvedLength));
  }
}

extension PointerUtils on Pointer<NativeType> {
  bool get isNullPointer => address == 0;
}

/// Extension method for converting a string encoded into a [List<int>] to a `Pointer<Utf8>`.
extension ListUtf8Pointer on List<int> {
  /// Creates a zero-terminated [Utf8] code-unit array from this List.
  /// Use Utf8Codec().encode to create this list from a string.
  ///
  /// If this [List] contains NULL characters, converting it back to a string
  /// using [Utf8Pointer.toDartString] will truncate the result if a length is
  /// not passed.
  ///
  /// Unpaired surrogate code points in this [String] will be encoded as
  /// replacement characters (U+FFFD, encoded as the bytes 0xEF 0xBF 0xBD) in
  /// the UTF-8 encoded result. See [Utf8Encoder] for details on encoding.
  Pointer<Utf8> listToNativeUtf8() {
    final result = malloc<Uint8>(length + 1);
    final nativeString = result.asTypedList(length + 1);
    nativeString.setAll(0, this);
    nativeString[length] = 0;
    return result.cast();
  }
}

const allocate = malloc;

extension FreePointerExtension on Pointer {
  void free() => allocate.free(this);
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
