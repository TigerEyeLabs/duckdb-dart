// ignore: library_annotations
@TestOn('vm')

import 'dart:math';
import 'dart:typed_data';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/src/types/time.dart';
import 'package:test/test.dart';

final BigInt hugeIntMin = BigInt.from(-1) << 127;
final BigInt hugeIntMax = (BigInt.from(1) << 127) - BigInt.one;
final BigInt uHugeIntMax = (BigInt.from(1) << 128) - BigInt.one;

void main() {
  late Database database;
  late Connection connection;

  setUp(() async {
    database = await duckdb.open(":memory:");
    connection = await duckdb.connect(database);
  });

  tearDown(() async {
    await connection.dispose();
    await database.dispose();
  });

  Future<void> roundTripTest(
    String datatype,
    List<dynamic> values, {
    bool shouldAssert = false,
  }) async {
    await connection.execute("CREATE TABLE t1(i $datatype);");

    final appender = await connection.append("t1", null);
    try {
      for (var i = 0; i < values.length; i++) {
        appender.append(values[i]);
        appender.endRow();
      }
    } catch (e) {
      if (shouldAssert) {
        expect(e, isA<AssertionError>());
      } else {
        rethrow;
      }
    }

    if (shouldAssert) {
      return;
    }

    appender.flush();

    final result = await connection.query("SELECT * FROM t1;");
    for (var i = 0; i < values.length; i++) {
      expect(result.fetchOne(), [values[i]], reason: "comparing the $i value.");
    }
  }

  group('database primitive tests', () {
    test('can round trip bool', () async {
      await roundTripTest("BOOL", [false, true, null]);
    });

    test('can round trip varchar', () async {
      await roundTripTest("VARCHAR", ["🦆🦆🦆🦆🦆🦆", "goose", null]);
    });
  });

  group('numeric tests', () {
    test('can round trip utinyint', () async {
      await roundTripTest("UTINYINT", [pow(2, 8) - 1, 0, null]);
    });

    test('can round trip usmallint', () async {
      await roundTripTest("USMALLINT", [pow(2, 16) - 1, 0, null]);
    });

    test('can round trip uint', () async {
      await roundTripTest("UINTEGER", [pow(2, 32) - 1, 0, null]);
    });

    test('can round trip ubigint', () async {
      await roundTripTest(
        "UBIGINT",
        [BigInt.from(pow(2, 64) - 1).toUnsigned(64), BigInt.from(0), null],
      );
    });

    test('can round trip tinyint', () async {
      await roundTripTest(
        "TINYINT",
        [(pow(2, 8) ~/ 2) - 1, (-1 * pow(2, 8) ~/ 2), null],
      );
    });

    test('can round trip smallint', () async {
      await roundTripTest(
        "SMALLINT",
        [(pow(2, 16) ~/ 2) - 1, (-1 * pow(2, 16) ~/ 2), null],
      );
    });

    test('can round trip int', () async {
      await roundTripTest(
        "INTEGER",
        [(pow(2, 32) ~/ 2) - 1, (-1 * pow(2, 32) ~/ 2), null],
      );
    });

    test('can round trip bigint', () async {
      await roundTripTest("BIGINT", [1 << 63, (1 << 63) - 1, null]);
    });

    test('can round trip hugeint', () async {
      await roundTripTest("HUGEINT", [
        hugeIntMax,
        hugeIntMin,
        null,
      ]);
    });

    test('can round trip hugeint', () async {
      await roundTripTest("UHUGEINT", [
        BigInt.zero,
        uHugeIntMax,
        null,
      ]);
    });

    test('can catch out of bounds uhugeint', () async {
      await roundTripTest(
        "UHUGEINT",
        [
          uHugeIntMax + BigInt.one,
          hugeIntMin - BigInt.one,
        ],
        shouldAssert: true,
      );
    });

    test('can round trip double', () async {
      await roundTripTest(
        "DOUBLE",
        [double.maxFinite, -double.maxFinite, null],
      );
    });

    test('can round trip float', () async {
      await roundTripTest(
        "REAL",
        [(pow(2, 32) / 2), (-1 * pow(2, 32) / 2), null],
      );
    });
  });

  test('can round trip date', () async {
    await roundTripTest(
      "DATE",
      [Date(DateTime.utc(1992, 9, 20).millisecondsSinceEpoch ~/ 86400000)],
    );
  });

  test('can round trip pre-unix epoch date', () async {
    await roundTripTest(
      "DATE",
      [Date(DateTime.utc(1900, 9, 20).millisecondsSinceEpoch ~/ 86400000)],
    );
  });

  test('can round trip timestamp', () async {
    await roundTripTest(
      "TIMESTAMP",
      [DateTime.parse('1992-09-20 00:00:00+03')],
    );
  });

  test('can round trip time', () async {
    await roundTripTest("Time", [
      Time(hour: 0, minute: 0, second: 0, microsecond: 0),
      Time(hour: 12, minute: 30, second: 45, microsecond: 123456),
      null,
    ]);
  });

  test('can round trip interval', () async {
    await roundTripTest(
      "INTERVAL",
      [Interval(months: 1, days: 2, microseconds: 3)],
    );
  });

  test('can round trip BLOBS', () async {
    await roundTripTest(
      "BLOB",
      [
        Uint8List.fromList([1, 2, 3, 4, 5]),
        Uint8List.fromList([6, 7, 8, 9, 10]),
        null,
      ],
    );
  });
}
