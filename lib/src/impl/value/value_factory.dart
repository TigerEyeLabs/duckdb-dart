import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/src/ffi/ffi.dart';
import 'package:dart_duckdb/src/impl/utils.dart';
import 'package:dart_duckdb/src/impl/value/list_value_creator.dart';
import 'package:dart_duckdb/src/impl/value/scalar_value_creator.dart';
import 'package:dart_duckdb/src/impl/value/struct_value_creator.dart';
import 'package:dart_duckdb/src/impl/value/value_creator.dart';
import 'package:dart_duckdb/src/types/time.dart';
import 'package:dart_duckdb/src/types/time_with_offset.dart';

class ValueFactory {
  // Scalar type handlers
  static final intCreator = ScalarValueCreators.intCreator;
  static final boolCreator = ScalarValueCreators.boolCreator;
  static final doubleCreator = ScalarValueCreators.doubleCreator;
  static final stringCreator = ScalarValueCreators.stringCreator;
  static final bigIntCreator = ScalarValueCreators.bigIntCreator;
  static final dateTimeCreator = ScalarValueCreators.dateTimeCreator;
  static final dateCreator = ScalarValueCreators.dateCreator;
  static final timeCreator = ScalarValueCreators.timeCreator;
  static final timeWithOffsetCreator =
      ScalarValueCreators.timeWithOffsetCreator;
  static final intervalCreator = ScalarValueCreators.intervalCreator;
  static final blobCreator = ScalarValueCreators.blobCreator;

  // List type handlers
  static final listOfInt = ListValueCreator(intCreator);
  static final listOfString = ListValueCreator(stringCreator);
  static final listOfBool = ListValueCreator(boolCreator);
  static final listOfDouble = ListValueCreator(doubleCreator);
  static final listOfBigInt = ListValueCreator(bigIntCreator);
  static final listOfDateTime = ListValueCreator(dateTimeCreator);
  static final listOfDate = ListValueCreator(dateCreator);
  static final listOfTime = ListValueCreator(timeCreator);
  static final listOfTimeWithOffset = ListValueCreator(timeWithOffsetCreator);
  static final listOfInterval = ListValueCreator(intervalCreator);
  static final listOfBlob = ListValueCreator(blobCreator);

  // Struct type handler
  static const structCreator = StructValueCreator();

  static ValueCreator<T> getCreator<T>() {
    return switch (T) {
      int => intCreator as ValueCreator<T>,
      bool => boolCreator as ValueCreator<T>,
      double => doubleCreator as ValueCreator<T>,
      String => stringCreator as ValueCreator<T>,
      BigInt => bigIntCreator as ValueCreator<T>,
      DateTime => dateTimeCreator as ValueCreator<T>,
      Date => dateCreator as ValueCreator<T>,
      Time => timeCreator as ValueCreator<T>,
      TimeWithOffset => timeWithOffsetCreator as ValueCreator<T>,
      Interval => intervalCreator as ValueCreator<T>,
      Uint8List => blobCreator as ValueCreator<T>,
      const (List<int>) => listOfInt as ValueCreator<T>,
      const (List<bool>) => listOfBool as ValueCreator<T>,
      const (List<double>) => listOfDouble as ValueCreator<T>,
      const (List<String>) => listOfString as ValueCreator<T>,
      const (List<BigInt>) => listOfBigInt as ValueCreator<T>,
      const (List<DateTime>) => listOfDateTime as ValueCreator<T>,
      const (List<Date>) => listOfDate as ValueCreator<T>,
      const (List<Time>) => listOfTime as ValueCreator<T>,
      const (List<TimeWithOffset>) => listOfTimeWithOffset as ValueCreator<T>,
      const (List<Interval>) => listOfInterval as ValueCreator<T>,
      const (List<Uint8List>) => listOfBlob as ValueCreator<T>,
      const (Map<String, Object>) => structCreator as ValueCreator<T>,
      _ => throw Exception('Unsupported type: $T'),
    };
  }
}

class ScalarValueCreators {
  static final intCreator = ScalarValueCreator<int>(
    DatabaseType.integer,
    (bindings, value) => value.isNegative
        ? bindings.duckdb_create_int64(value)
        : bindings.duckdb_create_uint64(value),
  );

  static final boolCreator = ScalarValueCreator<bool>(
    DatabaseType.boolean,
    (bindings, value) => bindings.duckdb_create_bool(value),
  );

  static final doubleCreator = ScalarValueCreator<double>(
    DatabaseType.double,
    (bindings, value) => bindings.duckdb_create_double(value),
  );

  static final stringCreator = ScalarValueCreator<String>(
    DatabaseType.varchar,
    (bindings, value) {
      final bytes = utf8.encode(value);
      final nativeString = allocate<Uint8>(bytes.length);
      final nativeList = nativeString.asTypedList(bytes.length);
      nativeList.setAll(0, bytes);
      final handle = bindings.duckdb_create_varchar_length(
        nativeString.cast(),
        bytes.length,
      );
      nativeString.free();
      return handle;
    },
  );

  static final bigIntCreator = ScalarValueCreator<BigInt>(
    DatabaseType.hugeInt,
    (bindings, value) {
      if (value <= hugeIntMax) {
        final hugeint = value.toHugeInt();
        final handle = bindings.duckdb_create_hugeint(hugeint.ref);
        hugeint.free();
        return handle;
      } else {
        final uhugeint = value.toUHugeInt();
        final handle = bindings.duckdb_create_uhugeint(uhugeint.ref);
        uhugeint.free();
        return handle;
      }
    },
  );

  static final dateTimeCreator = ScalarValueCreator<DateTime>(
    DatabaseType.timestamp,
    (bindings, value) {
      final timestamp = value.toTimestamp();
      final handle = bindings.duckdb_create_timestamp(timestamp.ref);
      timestamp.free();
      return handle;
    },
  );

  static final dateCreator = ScalarValueCreator<Date>(
    DatabaseType.date,
    (bindings, value) {
      final date = allocate<duckdb_date>();
      date.ref.days = value.daysSinceEpoch;
      final handle = bindings.duckdb_create_date(date.ref);
      date.free();
      return handle;
    },
  );

  static final timeCreator = ScalarValueCreator<Time>(
    DatabaseType.time,
    (bindings, value) {
      final time = allocate<duckdb_time>();
      time.ref.micros = value.toMicrosecondsSinceEpoch();
      final handle = bindings.duckdb_create_time(time.ref);
      time.free();
      return handle;
    },
  );

  static final timeWithOffsetCreator = ScalarValueCreator<TimeWithOffset>(
    DatabaseType.timeTz,
    (bindings, value) {
      final timeTz = allocate<duckdb_time_tz>();
      const maxOffset = 16 * 60 * 60 - 1;
      final microsUint = value.toMicrosecondsSinceEpoch().toUnsigned(64) << 24;
      final offsetUint = (maxOffset - value.offsetSeconds) & 0xFFFFFF;
      timeTz.ref.bits = microsUint | offsetUint;
      final handle = bindings.duckdb_create_time_tz_value(timeTz.ref);
      timeTz.free();
      return handle;
    },
  );

  static final intervalCreator = ScalarValueCreator<Interval>(
    DatabaseType.interval,
    (bindings, value) {
      final interval = value.toDuckDbInterval();
      final handle = bindings.duckdb_create_interval(interval.ref);
      interval.free();
      return handle;
    },
  );

  static final blobCreator = ScalarValueCreator<Uint8List>(
    DatabaseType.blob,
    (bindings, value) {
      final nativeBlob = allocate<Uint8>(value.length);
      nativeBlob.asTypedList(value.length).setAll(0, value);
      final handle = bindings.duckdb_create_blob(
        nativeBlob.cast(),
        value.length,
      );
      nativeBlob.free();
      return handle;
    },
  );
}
