import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:test/test.dart';

void main() {
  group('web cancellation tests', testOn: 'browser', () {
    late Database database;
    late Connection connection;

    setUpAll(() async {
      database = await duckdb.open(':memory:');
      connection = await duckdb.connect(database);
    });

    tearDownAll(() async {
      await connection.dispose();
      await database.dispose();
    });

    test('can complete execution without cancellation', () async {
      final token = DuckDBCancellationToken();
      final result = await connection.query('SELECT 1', token: token);
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

    test('handles pre-cancelled token', () async {
      final token = DuckDBCancellationToken()..cancel();

      await expectLater(
        connection.query('SELECT 1', token: token),
        throwsA(isA<DuckDBException>()),
      );
    });

    test('can cancel long-running query', () async {
      final token = DuckDBCancellationToken();

      // Start a long-running query with cancellation token
      final cancelledQuery = connection.query(
        '''
        SELECT COUNT(*)
        FROM (SELECT * FROM range(100000)) t1
        CROSS JOIN (SELECT * FROM range(1000)) t2;
        ''',
        token: token,
      );

      // Cancel the query immediately
      token.cancel();

      // Expect the query to be cancelled
      await expectLater(
        cancelledQuery,
        throwsA(isA<DuckDBException>()),
      );

      // Verify connection is still usable after cancellation
      final result = await connection.query('SELECT 42');
      expect(result[0][0], 42);
    });

    test('can cancel execute operation', () async {
      final token = DuckDBCancellationToken()..cancel();

      await expectLater(
        connection.execute('SELECT 1', token: token),
        throwsA(isA<DuckDBException>()),
      );
    });

    test('can cancel prepare operation', () async {
      final token = DuckDBCancellationToken()..cancel();

      await expectLater(
        connection.prepare('SELECT 1', token: token),
        throwsA(isA<DuckDBException>()),
      );
    });
  });
}
