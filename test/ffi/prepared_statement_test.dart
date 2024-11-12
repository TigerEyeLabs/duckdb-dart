import 'dart:async';
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

  test('can round trip time', () {
    roundTripTest("Time", [
      Time(hour: 0, minute: 0, second: 0, microsecond: 0),
      Time(hour: 12, minute: 30, second: 45, microsecond: 123456),
      null,
    ]);
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

  test('can round trip List<double>', () {
    roundTripTest(
      "DOUBLE[]",
      <List<double>?>[
        <double>[1, 2, 3, 4, 5],
        <double>[6, 7, 8, 9, 10],
        [],
        null,
      ],
    );
  });

  test('can round trip List<String>', () {
    roundTripTest(
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

  test('can round trip Map<String, Object>', () {
    roundTripTest(
      "STRUCT(v VARCHAR, i INTEGER)",
      <Map<String, Object>>[
        {'v': 'a', 'i': 42},
      ],
    );
  });

  test('can round trip Map<String, Object> with lists', () {
    roundTripTest(
      "STRUCT(v VARCHAR, i INTEGER[])",
      <Map<String, Object>>[
        {
          'v': 'a',
          'i': [42],
        },
      ],
    );
  });

  test('can round trip Map<String, Object> with nested structs', () {
    roundTripTest(
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

  group('pending result tests', () {
    test('can execute pending result', () async {
      final statement = PreparedStatementImpl.prepare(connection, "SELECT 1");
      await expectLater(
        statement
            .executeAsync()
            .value
            .then((resultSet) => resultSet?.fetchAll().first.first),
        completion(equals(1)),
      );
    });

    test('can execute pending result with a time-consuming query', () async {
      final statement = PreparedStatementImpl.prepare(connection, """
            SELECT SUM(a.range + b.range)
            FROM range(20000) AS a
            CROSS JOIN range(30000) AS b;
          """);

      // Set up a StreamController for progress updates
      final progressController = StreamController<double>();
      final progressUpdates = <double>[];

      // Listen to the progress updates
      progressController.stream.listen(
        (progress) {
          progressUpdates.add(progress);
        },
      );

      // Execute the statement asynchronously with progress reporting
      final result = await statement
          .executeAsync(progressController: progressController)
          .valueOrCancellation();

      final row = result?.fetchAll().first;

      // Verify the actual result values
      expect(row, hasLength(1));
      expect(row?[0], equals(BigInt.from(14999400000000)));
      expect(progressUpdates, contains(1.0));

      // Clean up
      await progressController.close();
    });

    test('can cancel pending result execution mid-await', () async {
      // Create a query that will run for a while without heavy data generation
      final statement = PreparedStatementImpl.prepare(connection, """
            SELECT SUM(a.range + b.range)
            FROM range(20000) AS a
            CROSS JOIN range(30000) AS b;
          """);

      // Start the async execution
      final operation = statement.executeAsync();

      // Schedule the cancellation to occur after a short delay
      Future.delayed(const Duration(milliseconds: 5), () {
        operation.cancel();
      });

      // Wait for the operation to complete or be cancelled
      final result = await operation.valueOrCancellation();

      // Verify that the operation was cancelled
      expect(operation.isCanceled, true);
      expect(result, isNull);
    });

    test('can timeout pending result execution', () async {
      final statement = PreparedStatementImpl.prepare(connection, """
            SELECT SUM(a.range + b.range)
            FROM range(20000) AS a
            CROSS JOIN range(30000) AS b;
          """);
      final operation = statement.executeAsync();
      await operation.valueOrCancellation();

      // Execute the statement asynchronously with a short timeout
      await expectLater(
        () => statement.executeAsync().valueOrCancellation().timeout(
              const Duration(milliseconds: 100),
              onTimeout: () => throw TimeoutException('Query timed out'),
            ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
