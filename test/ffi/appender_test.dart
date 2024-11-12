import 'dart:math';
import 'dart:typed_data';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/src/impl/implementation.dart';
import 'package:dart_duckdb/src/impl/utils.dart';
import 'package:dart_duckdb/src/types/time.dart';
import 'package:test/test.dart';

void main() {
  late Database database;
  late Connection connection;

  setUp(() {
    database = duckdb.open(":memory:");
    connection = duckdb.connect(database);
  });

  tearDown(() {
    connection.dispose();
    database.dispose();
  });

  void roundTripTest(
    String datatype,
    List<dynamic> values, {
    bool shouldAssert = false,
  }) {
    connection.execute("CREATE TABLE t1(i $datatype);");

    final Appender appender =
        AppenderImpl.withConnection(connection, "t1", null);
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

    final result = connection.query("SELECT * FROM t1;");
    for (var i = 0; i < values.length; i++) {
      expect(result.fetchOne(), [values[i]], reason: "comparing the $i value.");
    }
  }

  group('database primitive tests', () {
    test('can round trip bool', () {
      roundTripTest("BOOL", [false, true, null]);
    });

    test('can round trip varchar', () {
      roundTripTest("VARCHAR", ["🦆🦆🦆🦆🦆🦆", "goose", null]);
    });
  });

  group('numeric tests', () {
    test('can round trip utinyint', () {
      roundTripTest("UTINYINT", [pow(2, 8) - 1, 0, null]);
    });

    test('can round trip usmallint', () {
      roundTripTest("USMALLINT", [pow(2, 16) - 1, 0, null]);
    });

    test('can round trip uint', () {
      roundTripTest("UINTEGER", [pow(2, 32) - 1, 0, null]);
    });

    test('can round trip ubigint', () {
      roundTripTest(
        "UBIGINT",
        [BigInt.from(pow(2, 64) - 1).toUnsigned(64), BigInt.from(0), null],
      );
    });

    test('can round trip tinyint', () {
      roundTripTest(
        "TINYINT",
        [(pow(2, 8) ~/ 2) - 1, (-1 * pow(2, 8) ~/ 2), null],
      );
    });

    test('can round trip smallint', () {
      roundTripTest(
        "SMALLINT",
        [(pow(2, 16) ~/ 2) - 1, (-1 * pow(2, 16) ~/ 2), null],
      );
    });

    test('can round trip int', () {
      roundTripTest(
        "INTEGER",
        [(pow(2, 32) ~/ 2) - 1, (-1 * pow(2, 32) ~/ 2), null],
      );
    });

    test('can round trip bigint', () {
      roundTripTest("BIGINT", [1 << 63, (1 << 63) - 1, null]);
    });

    test('can round trip hugeint', () {
      roundTripTest("HUGEINT", [
        hugeIntMax,
        hugeIntMin,
        null,
      ]);
    });

    test('can round trip hugeint', () {
      roundTripTest("UHUGEINT", [
        BigInt.zero,
        uHugeIntMax,
        null,
      ]);
    });

    test('can catch out of bounds uhugeint', () {
      roundTripTest(
        "UHUGEINT",
        [
          uHugeIntMax + BigInt.one,
          hugeIntMin - BigInt.one,
        ],
        shouldAssert: true,
      );
    });

    test('can round trip double', () {
      roundTripTest("DOUBLE", [double.maxFinite, -double.maxFinite, null]);
    });

    test('can round trip float', () {
      roundTripTest("REAL", [(pow(2, 32) / 2), (-1 * pow(2, 32) / 2), null]);
    });
  });

  test('can round trip date', () {
    roundTripTest(
      "DATE",
      [Date(DateTime.utc(1992, 9, 20).millisecondsSinceEpoch ~/ 86400000)],
    );
  });

  test('can round trip pre-unix epoch date', () {
    roundTripTest(
      "DATE",
      [Date(DateTime.utc(1900, 9, 20).millisecondsSinceEpoch ~/ 86400000)],
    );
  });

  test('can round trip timestamp', () {
    roundTripTest("TIMESTAMP", [DateTime.parse('1992-09-20 00:00:00+03')]);
  });

  test('can round trip time', () {
    roundTripTest("Time", [
      Time(hour: 0, minute: 0, second: 0, microsecond: 0),
      Time(hour: 12, minute: 30, second: 45, microsecond: 123456),
      null,
    ]);
  });

  test('can round trip interval', () {
    roundTripTest("INTERVAL", [Interval(months: 1, days: 2, microseconds: 3)]);
  });

  test('can round trip BLOBS', () {
    roundTripTest(
      "BLOB",
      [
        Uint8List.fromList([1, 2, 3, 4, 5]),
        Uint8List.fromList([6, 7, 8, 9, 10]),
        null,
      ],
    );
  });
}
