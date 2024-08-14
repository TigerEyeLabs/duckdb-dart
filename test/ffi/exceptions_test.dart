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

  test('error should be an exception', () {
    try {
      connection.execute("select error('this is my error')");
    } catch (e) {
      expect(e, isA<DuckDBException>());
      expect(
        (e as DuckDBException).message,
        'Invalid Input Error: this is my error',
      );
    }
  });

  test('conversion error', () {
    try {
      connection.execute("select 'hello'::int");
    } catch (e) {
      expect(e, isA<DuckDBException>());
    }
  });
}
