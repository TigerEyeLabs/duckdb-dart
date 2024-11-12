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

  test('create bitstring from string', () {
    final result =
        connection.query("SELECT '101010'::BITSTRING AS b;").fetchAll();
    expect(result[0][0], '101010');
  });

  test('create bitstring with predefined length', () {
    final result =
        connection.query("SELECT bitstring('0101011', 12) AS b;").fetchAll();
    expect(result[0][0], '000000101011');
  });

  test('convert integer to bitstring', () {
    final result = connection.query("SELECT 123::BITSTRING AS b;").fetchAll();
    expect(result[0][0], '00000000000000000000000001111011');
  });

  test('bitstring length', () {
    final result = connection
        .query("SELECT length('101010'::BITSTRING) AS len;")
        .fetchAll();
    expect(result[0][0], 6);
  });
}
