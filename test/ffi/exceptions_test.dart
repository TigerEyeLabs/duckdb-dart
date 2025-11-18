import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:test/test.dart';

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

  test('error should be an exception', () async {
    try {
      await connection.execute("select error('this is my error')");
    } catch (e) {
      expect(e, isA<DuckDBException>());
      expect(
        (e as DuckDBException).message,
        'Invalid Input Error: this is my error',
      );
    }
  });

  test('conversion error', () async {
    try {
      await connection.execute("select 'hello'::int");
    } catch (e) {
      expect(e, isA<DuckDBException>());
    }
  });

  test('cancellation exception has isCancelled set to true', () async {
    final token = DuckDBCancellationToken();
    token.cancel();

    try {
      await connection.query('SELECT 1', token: token);
    } catch (e) {
      expect(e, isA<DuckDBCancelledException>());
      final exception = e as DuckDBCancelledException;
      expect(exception.message, equals('Operation cancelled'));
    }
  });
}
