import 'dart:async';
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
    bool Function(dynamic actual, dynamic expected)? compare,
  }) async {
    await connection.execute("CREATE TABLE t1(i $datatype);");

    final statement = await connection.prepare("INSERT INTO t1 VALUES (?)");
    for (var i = 0; i < values.length; i++) {
      try {
        statement.bind(values[i], 1);
        await statement.execute();
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

    final rows = (await connection.query("SELECT * FROM t1;")).fetchAll();
    for (var i = 0; i < values.length; i++) {
      if (compare != null) {
        expect(
          compare(rows[i][0], values[i]),
          isTrue,
          reason: "comparing the $i value.",
        );
      } else {
        expect(rows[i], [values[i]], reason: "comparing the $i value.");
      }
    }
  }

  group('prepared statement cancellation tests', testOn: 'vm', () {
    test('can complete execution without cancellation', () async {
      final statement = await connection.prepare('SELECT 1');
      final token = DuckDBCancellationToken();

      final result = await statement.execute(token: token);
      final rows = result.fetchAll();

      expect(rows.first.first, equals(1));
    });

    test('cancellation token can be reused', () async {
      final statement = await connection.prepare('SELECT 1');
      final token = DuckDBCancellationToken();

      // First execution
      final result1 = await statement.execute(token: token);
      expect(result1.fetchAll().first.first, equals(1));

      // Cancel token
      token.cancel();

      // Second execution should fail
      await expectLater(
        statement.execute(token: token),
        throwsA(isA<DuckDBException>()),
      );
    });

    test('cancelled statement can be reused with new token', () async {
      final statement = await connection.prepare('SELECT 1');

      // First execution with a token that gets cancelled
      final token1 = DuckDBCancellationToken();
      token1.cancel();
      await expectLater(
        statement.execute(token: token1),
        throwsA(isA<DuckDBException>()),
      );

      // Should be able to execute with a new token
      final token2 = DuckDBCancellationToken();
      final result = await statement.execute(token: token2);
      expect(result.fetchAll().first.first, equals(1));
    });

    test('handles pre-cancelled token', () async {
      final statement = await connection.prepare('SELECT 1');
      final token = DuckDBCancellationToken()..cancel();

      await expectLater(
        statement.execute(token: token),
        throwsA(isA<DuckDBException>()),
      );
    });
  });

  group('database primitive tests', () {
    test('can round trip bool', () async {
      await roundTripTest("BOOL", [false, true, null]);
    });

    test('can round trip varchar', () async {
      await roundTripTest("VARCHAR", ["🦆🦆🦆🦆🦆🦆", "goo\u0000se", null]);
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

    test('can round trip ubigint', testOn: 'vm', () async {
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
      await roundTripTest(
        "HUGEINT",
        [
          hugeIntMax,
          hugeIntMin,
          null,
        ],
        compare: (actual, expected) {
          if (actual is Decimal && expected is BigInt) {
            return actual.toBigInt() == expected;
          }
          return actual == expected;
        },
      );
    });

    test('can round trip uhugeint', testOn: 'vm', () async {
      await roundTripTest(
        "UHUGEINT",
        [
          BigInt.zero,
          uHugeIntMax,
          null,
        ],
        compare: (actual, expected) {
          if (actual is Decimal && expected is BigInt) {
            return actual.toBigInt() == expected;
          }
          return actual == expected;
        },
      );
    });

    test('can catch out of bounds uhugeint', testOn: 'vm', () async {
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

  group('decimal tests', () {
    test('can round trip DECIMAL(4,1)', () async {
      await roundTripTest(
        "DECIMAL(4,1)",
        [Decimal.parse('-999.9'), Decimal.parse('999.9'), Decimal.zero],
      );
    });

    test('can round trip DECIMAL(9,4)', () async {
      await roundTripTest(
        "DECIMAL(9,4)",
        [Decimal.parse('-99999.9999'), Decimal.parse('99999.9999')],
      );
    });

    test('can round trip DECIMAL(18,6)', () async {
      await roundTripTest(
        "DECIMAL(18,6)",
        [Decimal.parse('-9999999.99999'), Decimal.parse('9999999.99999')],
      );
    });

    test('can round trip DECIMAL(38,10)', () async {
      await roundTripTest(
        "DECIMAL(38,10)",
        [
          Decimal.parse('-9999999999999999999999999999.9999999999'),
          Decimal.parse('9999999999999999999999999999.9999999999'),
        ],
      );
    });
  });

  test('can round trip date', () async {
    await roundTripTest(
      "DATE",
      [Date(DateTime.utc(1992, 9, 20).millisecondsSinceEpoch ~/ 86400000)],
    );
  });

  test('can round trip timestamp', () async {
    await roundTripTest("TIMESTAMP", [DateTime.parse('1992-09-20 00:00:00Z')]);
  });

  test('can round trip timestamptz with GMT timezone', () async {
    await connection.execute('Set TimeZone="GMT";');
    await roundTripTest(
      "TIMESTAMP WITH TIME ZONE",
      [DateTime.parse('1992-09-20 00:00:00Z')],
    );
  });

  test('can round trip interval', testOn: 'vm', () async {
    await roundTripTest(
      "INTERVAL",
      [Interval(months: 1, days: 2, microseconds: 3)],
    );
  });

  test('can round trip time', () async {
    await roundTripTest("Time", [
      Time(hour: 0, minute: 0, second: 0, microsecond: 0),
      Time(hour: 12, minute: 30, second: 45, microsecond: 123456),
      null,
    ]);
  });

  group('database parameters tests', testOn: 'vm', () {
    test('can round trip named parameters', () async {
      await connection
          .execute("CREATE TABLE t1(col1 TEXT, col2 TEXT, col3 TEXT);");

      final tigerEyeHaiku = [
        {'col_1': 'Tiger eye', 'col2': 'gleaming', 'col3': 'stone'},
        {'col_1': 'Mysterious and bold its hue', 'col2': null, 'col3': null},
        {'col_1': 'Captivating', 'col2': 'sight', 'col3': null},
      ];

      final statement = await connection.prepare(
        "INSERT INTO t1 VALUES (\$col_1, \$col2, \$col3)",
      );
      for (var i = 0; i < tigerEyeHaiku.length; i++) {
        statement.bindNamedParams(tigerEyeHaiku[i]);
        await statement.execute();
      }

      final rows = (await connection.query("SELECT * FROM t1;")).fetchAll();
      for (var i = 0; i < tigerEyeHaiku.length; i++) {
        expect(
          rows[i],
          tigerEyeHaiku[i].values,
          reason: "comparing the $i value.",
        );
      }
    });

    test('can round trip out of order positional parameters', () async {
      await connection
          .execute("CREATE TABLE t1(col1 TEXT, col2 TEXT, col3 TEXT);");

      final tigerEyeHaiku = [
        ['Tiger eye', 'gleaming', 'stone'],
        ['Mysterious and bold its hue', null, null],
        ['Captivating', 'sight', null],
      ];
      final statement = await connection.prepare(
        "INSERT INTO t1 VALUES (\$3, \$2, \$1)",
      );
      for (var i = 0; i < tigerEyeHaiku.length; i++) {
        statement.bindParams(tigerEyeHaiku[i]);
        await statement.execute();
      }

      final rows = (await connection.query("SELECT * FROM t1;")).fetchAll();
      for (var i = 0; i < tigerEyeHaiku.length; i++) {
        expect(
          rows[i].reversed,
          tigerEyeHaiku[i],
          reason: "comparing the $i value.",
        );
      }
    });

    test('can round trip ? parameters', () async {
      await connection
          .execute("CREATE TABLE t1(col1 TEXT, col2 TEXT, col3 TEXT);");

      final tigerEyeHaiku = [
        ['Tiger eye', 'gleaming', 'stone'],
        ['Mysterious and bold its hue', null, null],
        ['Captivating', 'sight', null],
      ];
      final statement = await connection.prepare(
        "INSERT INTO t1 VALUES (?,?,?)",
      );
      for (var i = 0; i < tigerEyeHaiku.length; i++) {
        statement.bindParams(tigerEyeHaiku[i]);
        await statement.execute();
      }

      final rows = (await connection.query("SELECT * FROM t1;")).fetchAll();
      for (var i = 0; i < tigerEyeHaiku.length; i++) {
        expect(rows[i], tigerEyeHaiku[i], reason: "comparing the $i value.");
      }
    });
  });

  test('can round trip BLOBS', testOn: 'vm', () async {
    await roundTripTest(
      "BLOB",
      [
        Uint8List.fromList([1, 2, 3, 4, 5]),
        Uint8List.fromList([6, 7, 8, 9, 10]),
        null,
      ],
    );
  });

  group('nested structures', testOn: 'vm', () {
    test('can round trip List<double>', () async {
      await roundTripTest(
        "DOUBLE[]",
        <List<double>?>[
          <double>[1, 2, 3, 4, 5],
          <double>[6, 7, 8, 9, 10],
          [],
          null,
        ],
      );
    });

    test('can round trip List<String>', () async {
      await roundTripTest(
        "VARCHAR[]",
        <List<String>?>[
          ['Tiger eye', 'gleaming', 'stone'],
          ['Mysterious and bold its hue'],
          ['Captivating', 'sight'],
          [],
          null,
        ],
      );
    });

    test('can round trip Map<String, Object>', () async {
      await roundTripTest(
        "STRUCT(v VARCHAR, i INTEGER)",
        <Map<String, Object>>[
          {'v': 'a', 'i': 42},
        ],
      );
    });

    test('can round trip Map<String, Object> with lists', () async {
      await roundTripTest(
        "STRUCT(v VARCHAR, i INTEGER[])",
        <Map<String, Object>>[
          {
            'v': 'a',
            'i': [42],
          },
        ],
      );
    });

    test('can round trip Map<String, Object> with nested structs', () async {
      await roundTripTest(
        "STRUCT(name VARCHAR, address STRUCT(street VARCHAR, city VARCHAR))",
        <Map<String, Object>>[
          {
            'name': 'John',
            'address': {
              'street': '123 Main St',
              'city': 'Anytown',
            },
          },
        ],
      );
    });
  });

  group('pending result tests', testOn: 'vm', () {
    test('can execute pending result', () async {
      final statement = await connection.prepare("SELECT 1");
      final result = await statement.executePending();
      expect(result?.fetchAll().first.first, equals(1));
    });

    test('can cancel pending result execution', () async {
      // Create a query that will run for a while without heavy data generation
      final statement = await connection.prepare("""
            SELECT SUM(a.range + b.range)
            FROM range(20000) AS a
            CROSS JOIN range(30000) AS b;
          """);

      final token = DuckDBCancellationToken();

      // Create a completer to track when cancellation is done
      final cancellationCompleter = Completer<void>();

      // Schedule the cancellation to occur after a short delay
      Future.delayed(const Duration(milliseconds: 5), () async {
        token.cancel();
        cancellationCompleter.complete();
      });

      // Execute and expect CancelledException
      await expectLater(
        statement.executePending(token: token),
        throwsA(isA<DuckDBException>()),
      );

      // Wait for cancellation to complete
      await cancellationCompleter.future;
    });

    test('can timeout pending result execution', () async {
      final statement = await connection.prepare("""
            SELECT SUM(a.range + b.range)
            FROM range(20000) AS a
            CROSS JOIN range(30000) AS b;
          """);

      final token = DuckDBCancellationToken();

      final queryFuture = statement.executePending(token: token);
      await Future.delayed(const Duration(milliseconds: 5), () {
        token.cancel();
      });

      // Use Future.any but make sure to handle cleanup of the losing future
      await expectLater(
        Future.any([queryFuture]),
        throwsA(isA<DuckDBException>()),
      );

      // Give a small delay to ensure cancellation is processed
      await Future.delayed(const Duration(milliseconds: 10));
    });
  });
}
