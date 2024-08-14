import 'dart:math';

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

    final PreparedStatement statement =
        PreparedStatementImpl.prepare(connection, "INSERT INTO t1 VALUES (?)");
    for (var i = 0; i < values.length; i++) {
      try {
        statement.bind(values[i], 1);
        statement.execute();
      } catch (e) {
        if (shouldAssert) {
          expect(e, isA<AssertionError>());
        } else {
          rethrow;
        }
      }
    }

    if (shouldAssert) {
      return;
    }

    final rows = connection.query("SELECT * FROM t1;").fetchAll();
    for (var i = 0; i < values.length; i++) {
      expect(rows[i], [values[i]], reason: "comparing the $i value.");
    }
  }

  group('database primitive tests', () {
    test('can round trip bool', () {
      roundTripTest("BOOL", [false, true, null]);
    });

    test('can round trip varchar', () {
      roundTripTest("VARCHAR", ["🦆🦆🦆🦆🦆🦆", "goo\u0000se", null]);
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

    test('can round trip uhugeint', () {
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

  group('decimal tests', () {
    test('can round trip DECIMAL(4,1)', () {
      roundTripTest(
        "DECIMAL(4,1)",
        [Decimal.parse('-999.9'), Decimal.parse('999.9'), Decimal.zero],
      );
    });

    test('can round trip DECIMAL(9,4)', () {
      roundTripTest(
        "DECIMAL(9,4)",
        [Decimal.parse('-99999.9999'), Decimal.parse('99999.9999')],
      );
    });

    test('can round trip DECIMAL(18,6)', () {
      roundTripTest(
        "DECIMAL(18,6)",
        [Decimal.parse('-9999999.99999'), Decimal.parse('9999999.99999')],
      );
    });

    test('can round trip DECIMAL(38,10)', () {
      roundTripTest(
        "DECIMAL(38,10)",
        [
          Decimal.parse('-9999999999999999999999999999.9999999999'),
          Decimal.parse('9999999999999999999999999999.9999999999'),
        ],
      );
    });
  });

  test('can round trip date', () {
    roundTripTest(
      "DATE",
      [Date(DateTime.utc(1992, 9, 20).millisecondsSinceEpoch ~/ 86400000)],
    );
  });

  test('can round trip timestamp', () {
    roundTripTest("TIMESTAMP", [DateTime.parse('1992-09-20 00:00:00Z')]);
  });

  test('can round trip timestamptz with GMT timezone', () {
    connection.execute('Set TimeZone="GMT";');
    roundTripTest(
      "TIMESTAMP WITH TIME ZONE",
      [DateTime.parse('1992-09-20 00:00:00Z')],
    );
  });

  test('can round trip interval', () {
    roundTripTest("INTERVAL", [Interval(months: 1, days: 2, microseconds: 3)]);
  });

  // TODO: Add the timezone package, Dart DateTime doesn't include timezone information.
  // test('can round trip timestamp with non-GMT timezone', () {
  //   roundTripTest(
  //       "TIMESTAMP WITH TIME ZONE", [DateTime.parse('1992-09-20 00:00:00')]);
  // });

  test('can round trip time', () {
    roundTripTest("Time", [
      Time(hour: 0, minute: 0, second: 0, microsecond: 0),
      Time(hour: 12, minute: 30, second: 45, microsecond: 123456),
      null,
    ]);
  });

  test('can round trip lists', () {
    final tigerEyeHaiku = [
      ['Tiger eye', 'gleaming', 'stone'],
      ['Mysterious and bold its hue'],
      ['Captivating', 'sight'],
    ];

    connection.execute("CREATE TABLE t1 (int_list TEXT[]);");
    connection
        .execute("INSERT INTO t1 VALUES (['Tiger eye', 'gleaming', 'stone'])");
    connection
        .execute("INSERT INTO t1 VALUES (['Mysterious and bold its hue'])");
    connection.execute("INSERT INTO t1 VALUES (['Captivating', 'sight'])");
    final result = connection.query("SELECT * FROM t1;");

    for (var i = 0; i < result.rowCount; i++) {
      expect(result[0][i], tigerEyeHaiku[i]);
    }
  });

  group('database parameters tests', () {
    test('can round trip named parameters', () {
      connection.execute("CREATE TABLE t1(col1 TEXT, col2 TEXT, col3 TEXT);");

      final tigerEyeHaiku = [
        {'col_1': 'Tiger eye', 'col2': 'gleaming', 'col3': 'stone'},
        {'col_1': 'Mysterious and bold its hue', 'col2': null, 'col3': null},
        {'col_1': 'Captivating', 'col2': 'sight', 'col3': null},
      ];

      final PreparedStatement statement = PreparedStatementImpl.prepare(
        connection,
        "INSERT INTO t1 VALUES (\$col_1, \$col2, \$col3)",
      );
      for (var i = 0; i < tigerEyeHaiku.length; i++) {
        statement.bindNamedParams(tigerEyeHaiku[i]);
        statement.execute();
      }

      final rows = connection.query("SELECT * FROM t1;").fetchAll();
      for (var i = 0; i < tigerEyeHaiku.length; i++) {
        expect(
          rows[i],
          tigerEyeHaiku[i].values,
          reason: "comparing the $i value.",
        );
      }
    });

    test('can round trip out of order positional parameters', () {
      connection.execute("CREATE TABLE t1(col1 TEXT, col2 TEXT, col3 TEXT);");

      final tigerEyeHaiku = [
        ['Tiger eye', 'gleaming', 'stone'],
        ['Mysterious and bold its hue', null, null],
        ['Captivating', 'sight', null],
      ];
      final PreparedStatement statement = PreparedStatementImpl.prepare(
        connection,
        "INSERT INTO t1 VALUES (\$3, \$2, \$1)",
      );
      for (var i = 0; i < tigerEyeHaiku.length; i++) {
        statement.bindParams(tigerEyeHaiku[i]);
        statement.execute();
      }

      final rows = connection.query("SELECT * FROM t1;").fetchAll();
      for (var i = 0; i < tigerEyeHaiku.length; i++) {
        expect(
          rows[i].reversed,
          tigerEyeHaiku[i],
          reason: "comparing the $i value.",
        );
      }
    });

    test('can round trip ? parameters', () {
      connection.execute("CREATE TABLE t1(col1 TEXT, col2 TEXT, col3 TEXT);");

      final tigerEyeHaiku = [
        ['Tiger eye', 'gleaming', 'stone'],
        ['Mysterious and bold its hue', null, null],
        ['Captivating', 'sight', null],
      ];
      final PreparedStatement statement = PreparedStatementImpl.prepare(
        connection,
        "INSERT INTO t1 VALUES (?,?,?)",
      );
      for (var i = 0; i < tigerEyeHaiku.length; i++) {
        statement.bindParams(tigerEyeHaiku[i]);
        statement.execute();
      }

      final rows = connection.query("SELECT * FROM t1;").fetchAll();
      for (var i = 0; i < tigerEyeHaiku.length; i++) {
        expect(rows[i], tigerEyeHaiku[i], reason: "comparing the $i value.");
      }
    });
  });
}
