import 'dart:async';

import 'package:dart_duckdb/dart_duckdb.dart';
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

  test('fetchAllStream should stream large result sets in batches', () async {
    // Create a large table
    connection.execute('''
      CREATE TABLE numbers AS
      SELECT generate_series AS num
      FROM generate_series(1, 1000);
    ''');

    final result = connection.query('SELECT * FROM numbers');
    var count = 0;

    await for (final row in result.fetchAllStream(batchSize: 100)) {
      expect(row[0], count + 1);
      count++;
    }

    expect(count, 1000);
  });

  test('fetchAllStream should be cancellable mid-stream', () async {
    connection.execute('''
      CREATE TABLE large_table AS
      SELECT generate_series AS num
      FROM generate_series(1, 1000);
    ''');

    final result = connection.query('SELECT * FROM large_table');
    var count = 0;

    await for (final _ in result.fetchAllStream()) {
      count++;
      if (count == 500) break; // Cancel after 500 rows
    }

    expect(count, 500);
  });

  test('fetchAllStream should handle empty result sets', () async {
    connection.execute('CREATE TABLE empty_table (id INTEGER)');

    final result = connection.query('SELECT * FROM empty_table');
    var count = 0;

    await for (final _ in result.fetchAllStream()) {
      count++;
    }

    expect(count, 0);
  });

  test('fetchAllStream should handle multiple column types', () async {
    connection.execute('''
      CREATE TABLE mixed_types (
        id INTEGER,
        name TEXT,
        active BOOLEAN,
        score DOUBLE
      );
      INSERT INTO mixed_types VALUES
        (1, 'Alice', true, 95.5),
        (2, 'Bob', false, 82.3),
        (3, 'Charlie', true, 77.8);
    ''');

    final result = connection.query('SELECT * FROM mixed_types');
    final collected = <List<Object?>>[];

    await for (final row in result.fetchAllStream()) {
      collected.add(row);
    }

    expect(collected.length, 3);
    expect(collected[0], [1, 'Alice', true, 95.5]);
    expect(collected[1], [2, 'Bob', false, 82.3]);
    expect(collected[2], [3, 'Charlie', true, 77.8]);
  });

  test('fetchAllStream should handle NULL values', () async {
    connection.execute('''
      CREATE TABLE nullable_table (
        id INTEGER,
        name TEXT
      );
      INSERT INTO nullable_table VALUES
        (1, NULL),
        (2, 'Bob'),
        (NULL, 'Charlie');
    ''');

    final result = connection.query('SELECT * FROM nullable_table');
    final collected = <List<Object?>>[];

    await for (final row in result.fetchAllStream()) {
      collected.add(row);
    }

    expect(collected.length, 3);
    expect(collected[0], [1, null]);
    expect(collected[1], [2, 'Bob']);
    expect(collected[2], [null, 'Charlie']);
  });

  test('fetchAllStream should handle concurrent streams', () async {
    connection.execute('''
      CREATE TABLE numbers AS
      SELECT generate_series AS num
      FROM generate_series(1, 100);
    ''');

    final result1 = connection.query('SELECT * FROM numbers WHERE num <= 50');
    final result2 = connection.query('SELECT * FROM numbers WHERE num > 50');

    final future1 = result1.fetchAllStream().length;
    final future2 = result2.fetchAllStream().length;

    final results = await Future.wait([future1, future2]);

    expect(results[0], 50); // First query should return 50 rows
    expect(results[1], 50); // Second query should return 50 rows
  });

  test('fetchAllStream should handle errors gracefully', () async {
    connection.execute('CREATE TABLE test (id INTEGER)');

    // Invalid SQL should throw
    expect(
      () => connection
          .query('SELECT invalid_column FROM test')
          .fetchAllStream()
          .listen((_) {}),
      throwsA(anything),
    );
  });

  test(
      'should efficiently stream large result set using executeAsync and fetchAllStream',
      () async {
    // Create a large table with 100k rows
    connection.execute('''
      CREATE TABLE large_table AS
      SELECT
        generate_series as id,
        'Value_' || generate_series as text_value,
        generate_series * 1.5 as float_value
      FROM generate_series(1, 100000);
    ''');

    // Prepare a statement that will return a large result set
    final statement = connection.prepare(
      'SELECT * FROM large_table WHERE id > ? AND id <= ?',
    );

    // Set up progress tracking
    final progressController = StreamController<double>();
    final progressUpdates = <double>[];
    progressController.stream.listen((progress) {
      progressUpdates.add(progress);
    });

    // Process the data in chunks
    const chunkSize = 10000;
    var processedRows = 0;

    // Process multiple chunks asynchronously
    for (var start = 0; start < 100000; start += chunkSize) {
      final end = start + chunkSize;

      // Bind parameters for current chunk
      statement.bindParams([start, end]);

      // Execute asynchronously
      final pendingResult = await statement
          .executeAsync(progressController: progressController)
          .valueOrCancellation();

      if (pendingResult == null) {
        fail('Query was cancelled or failed');
      }

      // Stream the results
      await for (final row in pendingResult.fetchAllStream(batchSize: 1000)) {
        // Verify row structure
        expect(row.length, 3);
        expect(row[0], greaterThan(start));
        expect(row[0], lessThanOrEqualTo(end));
        expect(row[1], equals('Value_${row[0]}'));
        final id = row[0]! as int;
        final actualValue = row[2]! as Decimal;

        // Compare with expected value from database
        final expectedValue = Decimal.parse((id * 1.5).toString());

        // Compare Decimal values directly
        expect(
          actualValue,
          equals(expectedValue),
          reason: 'Row $id: $actualValue should equal $expectedValue',
        );

        processedRows++;
      }
    }

    // Verify results
    expect(processedRows, 100000);
    expect(progressUpdates, contains(1.0));

    // Clean up
    await progressController.close();
  });
}
