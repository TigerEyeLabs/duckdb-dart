// ignore_for_file: avoid_dynamic_calls, avoid_print

import 'dart:io';
import 'dart:isolate';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

bool shouldLog = false;
bool memoryOnly = true;

Future<dynamic> runInIsolate(
  TransferableDatabase transferableDb,
  Function(Connection) operation,
  String name,
) async {
  final port = ReceivePort();
  final errorPort = ReceivePort();
  final isolate = await Isolate.spawn(
    (message) async {
      final (transferableDb, sendPort) = message;
      final connection = duckdb.connectWithTransferred(transferableDb);
      try {
        if (shouldLog) print('Isolate: Beginning transaction - $name');
        connection.execute('BEGIN TRANSACTION');
        final result = await operation(connection);
        if (shouldLog) print('Isolate: Operation completed - $name');
        await Future.delayed(const Duration(milliseconds: 100));
        if (shouldLog) print('Isolate: Committing transaction - $name');
        connection.execute('COMMIT');
        if (shouldLog) print('Isolate: Transaction committed - $name');
        sendPort.send(result);
      } catch (e, stackTrace) {
        sendPort.send((e, stackTrace));
      } finally {
        connection.dispose();
      }
    },
    (transferableDb, port.sendPort),
    onError: errorPort.sendPort,
  );

  final result = await port.first;
  errorPort.close();
  isolate.kill();

  if (result is (Object, StackTrace)) {
    final (error, stackTrace) = result;
    Error.throwWithStackTrace(error, stackTrace);
  }

  return result;
}

void main() {
  late Database database;
  late Connection connection;
  late String dbFilePath;

  setUp(() {
    if (memoryOnly) {
      dbFilePath = ':memory:';
    } else {
      // Create a unique file name for each test
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      dbFilePath =
          path.join(Directory.systemTemp.path, 'test_db_$timestamp.db');
    }

    database = duckdb.open(dbFilePath);
    connection = duckdb.connect(database);
    connection.execute('CREATE TABLE test_table (id INTEGER, value TEXT)');
  });

  tearDown(() {
    connection.dispose();
    database.dispose();

    if (memoryOnly) return;

    // Delete the database file
    final file = File(dbFilePath);
    if (file.existsSync()) {
      file.deleteSync();
    }
  });

  test('Concurrent INSERT operations on the same table', () async {
    final isolate1 = runInIsolate(
      database.transferrable,
      (conn) => conn.execute("INSERT INTO test_table VALUES (1, 'isolate1')"),
      "isolate1",
    );
    final isolate2 = runInIsolate(
      database.transferrable,
      (conn) => conn.execute("INSERT INTO test_table VALUES (2, 'isolate2')"),
      "isolate2",
    );

    await Future.wait([isolate1, isolate2]);

    final result =
        connection.query('SELECT * FROM test_table ORDER BY id').fetchAll();
    expect(result.length, 2);
    expect(result[0][0], 1);
    expect(result[0][1], 'isolate1');
    expect(result[1][0], 2);
    expect(result[1][1], 'isolate2');
  });

  test('Concurrent INSERT and UPDATE operations on the same table', () async {
    final isolate1 = runInIsolate(
      database.transferrable,
      (conn) => conn.execute("INSERT INTO test_table VALUES (1, 'isolate1')"),
      "isolate1",
    );
    final isolate2 = runInIsolate(
      database.transferrable,
      (conn) {
        conn.execute("INSERT INTO test_table VALUES (2, 'isolate2')");
        conn.execute(
          "UPDATE test_table SET value = 'isolate2_updated' WHERE id = 2",
        );
        conn.execute("INSERT INTO test_table VALUES (3, 'isolate3')");
        conn.execute("DELETE FROM test_table WHERE id = 3");
      },
      "isolate2",
    );

    await Future.wait([isolate1, isolate2]);

    final result =
        connection.query('SELECT * FROM test_table ORDER BY id').fetchAll();
    expect(result.length, 2);
    expect(result[0][0], 1);
    expect(result[0][1], 'isolate1');
    expect(result[1][0], 2);
    expect(result[1][1], 'isolate2_updated');
  });

  test('Concurrent UPDATE operations on different tables', () async {
    connection.execute('CREATE TABLE another_table (id INTEGER, value TEXT)');
    connection.execute("INSERT INTO test_table VALUES (1, 'old1')");
    connection.execute("INSERT INTO another_table VALUES (1, 'old2')");

    final isolate1 = runInIsolate(
      database.transferrable,
      (conn) =>
          conn.execute("UPDATE test_table SET value = 'new1' WHERE id = 1"),
      "isolate1",
    );
    final isolate2 = runInIsolate(
      database.transferrable,
      (conn) =>
          conn.execute("UPDATE another_table SET value = 'new2' WHERE id = 1"),
      "isolate2",
    );

    await Future.wait([isolate1, isolate2]);

    final result1 = connection
        .query('SELECT value FROM test_table WHERE id = 1')
        .fetchAll();
    final result2 = connection
        .query('SELECT value FROM another_table WHERE id = 1')
        .fetchAll();
    expect(result1[0][0], 'new1');
    expect(result2[0][0], 'new2');
  });

  test('Concurrent UPDATE operations on different rows in the same table',
      () async {
    connection
        .execute("INSERT INTO test_table VALUES (1, 'old1'), (2, 'old2')");

    final isolate1 = runInIsolate(
      database.transferrable,
      (conn) =>
          conn.execute("UPDATE test_table SET value = 'new1' WHERE id = 1"),
      "isolate1",
    );
    final isolate2 = runInIsolate(
      database.transferrable,
      (conn) =>
          conn.execute("UPDATE test_table SET value = 'new2' WHERE id = 2"),
      "isolate2",
    );

    await Future.wait([isolate1, isolate2]);

    final result =
        connection.query('SELECT * FROM test_table ORDER BY id').fetchAll();
    expect(result.length, 2);
    expect(result[0][1], 'new1');
    expect(result[1][1], 'new2');
  });

  test('Concurrent SELECT operations on different rows', () async {
    connection
        .execute("INSERT INTO test_table VALUES (1, 'value1'), (2, 'value2')");

    final isolate1 = runInIsolate(
      database.transferrable,
      (conn) {
        final result =
            conn.query("SELECT * FROM test_table WHERE id = 1").fetchAll();
        return result;
      },
      "isolate1",
    );

    final isolate2 = runInIsolate(
      database.transferrable,
      (conn) {
        final result =
            conn.query("SELECT * FROM test_table WHERE id = 2").fetchAll();
        return result;
      },
      "isolate2",
    );

    final results = await Future.wait([isolate1, isolate2]);

    // Perform assertions in the main test body
    expect(results[0].length, 1);
    expect(results[0][0][1], 'value1');
    expect(results[1].length, 1);
    expect(results[1][0][1], 'value2');
  });

  test('Concurrent DELETE operations on different rows in same table',
      () async {
    connection
        .execute("INSERT INTO test_table VALUES (1, 'value1'), (2, 'value2')");

    final isolate1 = runInIsolate(
      database.transferrable,
      (conn) => conn.execute("DELETE FROM test_table WHERE id = 1"),
      "isolate1",
    );

    final isolate2 = runInIsolate(
      database.transferrable,
      (conn) => conn.execute("DELETE FROM test_table WHERE id = 2"),
      "isolate2",
    );

    await Future.wait([isolate1, isolate2]);

    final result = connection.query('SELECT * FROM test_table').fetchAll();
    expect(result.isEmpty, true);
  });

  test('Concurrent INSERT operations into different tables', () async {
    connection.execute('CREATE TABLE another_table (id INTEGER, value TEXT)');

    final isolate1 = runInIsolate(
      database.transferrable,
      (conn) => conn.execute("INSERT INTO test_table VALUES (1, 'isolate1')"),
      "isolate1",
    );

    final isolate2 = runInIsolate(
      database.transferrable,
      (conn) =>
          conn.execute("INSERT INTO another_table VALUES (2, 'isolate2')"),
      "isolate2",
    );

    await Future.wait([isolate1, isolate2]);

    final result1 = connection.query('SELECT * FROM test_table').fetchAll();
    final result2 = connection.query('SELECT * FROM another_table').fetchAll();

    expect(result1.length, 1);
    expect(result1[0][0], 1);
    expect(result1[0][1], 'isolate1');

    expect(result2.length, 1);
    expect(result2[0][0], 2);
    expect(result2[0][1], 'isolate2');
  });

  test('Concurrent INSERT INTO SELECT operations on same destination table',
      () async {
    connection.execute('CREATE TABLE source_table (id INTEGER, value TEXT)');
    connection.execute(
      "INSERT INTO source_table VALUES (1, 'source1'), (2, 'source2')",
    );
    connection
        .execute('CREATE TABLE destination_table (id INTEGER, value TEXT)');

    final isolate1 = runInIsolate(
      database.transferrable,
      (conn) => conn.execute(
        "INSERT INTO destination_table SELECT * FROM source_table WHERE id = 1",
      ),
      "isolate1",
    );

    final isolate2 = runInIsolate(
      database.transferrable,
      (conn) => conn.execute(
        "INSERT INTO destination_table SELECT * FROM source_table WHERE id = 2",
      ),
      "isolate2",
    );

    await Future.wait([isolate1, isolate2]);

    final result = connection
        .query('SELECT * FROM destination_table ORDER BY id')
        .fetchAll();
    expect(result.length, 2);
    expect(result[0][1], 'source1');
    expect(result[1][1], 'source2');
  });

  test('Concurrent append operations using appenders', () async {
    final isolate1 = runInIsolate(
      database.transferrable,
      (conn) {
        final appender = conn.append('test_table', null);
        for (var i = 0; i < 500; i++) {
          appender.append(i);
          appender.append('isolate1_$i');
          appender.endRow();
        }
        appender.flush();
        appender.dispose();
      },
      "isolate1",
    );

    final isolate2 = runInIsolate(
      database.transferrable,
      (conn) {
        final appender = conn.append('test_table', null);
        for (var i = 500; i < 1000; i++) {
          appender.append(i);
          appender.append('isolate2_$i');
          appender.endRow();
        }
        appender.flush();
        appender.dispose();
      },
      "isolate2",
    );

    await Future.wait([isolate1, isolate2]);

    final result =
        connection.query('SELECT COUNT(*) FROM test_table').fetchAll();
    expect(result[0][0], 1000);

    final sample1 =
        connection.query('SELECT * FROM test_table WHERE id = 250').fetchAll();
    expect(sample1[0][0], 250);
    expect(sample1[0][1], 'isolate1_250');

    final sample2 =
        connection.query('SELECT * FROM test_table WHERE id = 750').fetchAll();
    expect(sample2[0][0], 750);
    expect(sample2[0][1], 'isolate2_750');
  });

  test('Concurrent operations with prepared statements using execute()',
      () async {
    connection.execute(
      'CREATE TABLE prepared_test (id INTEGER, value TEXT, number DOUBLE)',
    );

    final isolate1 = runInIsolate(
      database.transferrable,
      (conn) {
        final stmt = conn.prepare('INSERT INTO prepared_test VALUES (?, ?, ?)');
        for (var i = 0; i < 500; i++) {
          stmt.bindParams([i, 'value_$i', i * 1.5]);
          stmt.execute();
        }
        stmt.dispose();
      },
      "isolate1",
    );

    final isolate2 = runInIsolate(
      database.transferrable,
      (conn) {
        final stmt = conn.prepare('INSERT INTO prepared_test VALUES (?, ?, ?)');
        for (var i = 500; i < 1000; i++) {
          stmt.bindParams([i, 'value_$i', i * 1.5]);
          stmt.execute();
        }
        stmt.dispose();
      },
      "isolate2",
    );

    await Future.wait([isolate1, isolate2]);

    final result =
        connection.query('SELECT COUNT(*) FROM prepared_test').fetchAll();
    expect(result[0][0], 1000);

    final sample1 = connection
        .query('SELECT * FROM prepared_test WHERE id = 250')
        .fetchAll();
    expect(sample1[0][0], 250);
    expect(sample1[0][1], 'value_250');
    expect(sample1[0][2], 375.0);

    final sample2 = connection
        .query('SELECT * FROM prepared_test WHERE id = 750')
        .fetchAll();
    expect(sample2[0][0], 750);
    expect(sample2[0][1], 'value_750');
    expect(sample2[0][2], 1125.0);
  });

  group('conflict scenarios', () {
    test('Concurrent UPDATE operations on the same row', () async {
      connection.execute("INSERT INTO test_table VALUES (1, 'old')");

      final isolate1 = runInIsolate(
        database.transferrable,
        (conn) =>
            conn.execute("UPDATE test_table SET value = 'new1' WHERE id = 1"),
        "isolate1",
      );

      final isolate2 = runInIsolate(
        database.transferrable,
        (conn) =>
            conn.execute("UPDATE test_table SET value = 'new2' WHERE id = 1"),
        "isolate2",
      );

      await expectLater(
        Future.wait([isolate1, isolate2], eagerError: true),
        throwsA(isA<DuckDBException>()),
      );
    });

    test(
        'Concurrent DELETE operations on the same row with conflicting transactions',
        () async {
      connection.execute("INSERT INTO test_table VALUES (1, 'value1')");

      final isolate1 = runInIsolate(
        database.transferrable,
        (conn) => conn.execute("DELETE FROM test_table WHERE id = 1"),
        "isolate1",
      );

      final isolate2 = runInIsolate(
        database.transferrable,
        (conn) => conn.execute("DELETE FROM test_table WHERE id = 1"),
        "isolate2",
      );

      await expectLater(
        Future.wait([isolate1, isolate2], eagerError: true),
        throwsA(isA<DuckDBException>()),
      );
    });

    test('Concurrent ALTER TABLE operations adding new columns', () async {
      final isolate1 = runInIsolate(
        database.transferrable,
        (conn) => conn
            .execute("ALTER TABLE test_table ADD COLUMN new_column INTEGER"),
        "isolate1",
      );

      final isolate2 = runInIsolate(
        database.transferrable,
        (conn) => conn
            .execute("ALTER TABLE test_table ADD COLUMN another_column TEXT"),
        "isolate2",
      );

      await expectLater(
        Future.wait([isolate1, isolate2], eagerError: true),
        throwsA(isA<DuckDBException>()),
      );
    });

    test('Concurrent INSERT operations violating unique primary key constraint',
        () async {
      connection.execute('DROP TABLE IF EXISTS test_table');
      connection.execute(
        'CREATE TABLE test_table (id INTEGER PRIMARY KEY, value TEXT)',
      );

      final isolate1 = runInIsolate(
        database.transferrable,
        (conn) async {
          conn.execute("INSERT INTO test_table VALUES (1, 'isolate1')");
          // Simulate a longer-running transaction
          await Future.delayed(const Duration(seconds: 1));
        },
        "isolate1",
      );

      // Give isolate1 a head start
      await Future.delayed(const Duration(milliseconds: 100));

      final isolate2 = runInIsolate(
        database.transferrable,
        (conn) => conn.execute("INSERT INTO test_table VALUES (1, 'isolate2')"),
        "isolate2",
      );

      await expectLater(
        Future.wait([isolate1, isolate2], eagerError: true),
        throwsA(isA<DuckDBException>()),
      );
    });
  });
}
