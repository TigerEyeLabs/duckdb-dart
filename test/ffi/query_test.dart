import 'package:dart_duckdb/dart_duckdb.dart';
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

  test('query should return all rows', () {
    const count = 100000;
    const query = """
      SELECT range AS value
      FROM range(1, $count + 1)
      ORDER BY value;
    """;

    final result = connection.query(query).fetchAll();
    expect(result, List.generate(count, (i) => [i + 1], growable: false));
  });

  test('query should return uhugeint', () {
    const hexString = 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF';
    final bigIntValue = BigInt.parse(hexString, radix: 16);

    const query =
        "SELECT '340282366920938463463374607431768211455'::UHUGEINT AS uhugeint_value;";

    final result = connection.query(query).fetchAll();
    expect(result[0][0], bigIntValue);
  });

  test('query should return time', () {
    const query = "SELECT TIME '1992-09-20 11:30:00.123456';";
    final result = connection.query(query).fetchAll();
    expect(
      result[0][0],
      Time(hour: 11, minute: 30, second: 0, microsecond: 123456),
    );
  });

  test('query should return timestamp with microsecond precision', () {
    const query = "SELECT TIMESTAMP '1992-09-20 11:30:00.123456789';";
    final result = connection.query(query).fetchAll();
    expect(
      result[0][0],
      DateTime.parse('1992-09-20 11:30:00.123456789Z'),
    );
  });

  test('query should return timestamp with second precision', () {
    const query = "SELECT TIMESTAMP_S '1992-09-20 11:30:00';";
    final result = connection.query(query).fetchAll();
    expect(
      result[0][0],
      DateTime.parse('1992-09-20 11:30:00Z'),
    );
  });

  test('query should return timestamp with millisecond precision', () {
    const query = "SELECT TIMESTAMP_MS '1992-09-20 11:30:00';";
    final result = connection.query(query).fetchAll();
    expect(
      result[0][0],
      DateTime.parse('1992-09-20 11:30:00Z'),
    );
  });

  test('query should return timestamp with nanosecond precision', () {
    const query = "SELECT TIMESTAMP_NS '1992-09-20 11:30:00.123456';";
    final result = connection.query(query).fetchAll();
    expect(
      result[0][0],
      DateTime.parse('1992-09-20 11:30:00.123456Z'),
    );
  });

  test('query should fail since enum mood already exists', () {
    connection.execute("CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy');");
    expect(
      () => connection.execute(
        "CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy', 'anxious');",
      ),
      throwsA(isA<DuckDBException>()),
    );
  });

  test('query should fail since enum values must be unique', () {
    expect(
      () => connection
          .execute("CREATE TYPE breed AS ENUM ('maltese', 'maltese');"),
      throwsA(isA<DuckDBException>()),
    );
  });

  test('query should fail since enum values must not be null', () {
    expect(
      () => connection.execute("CREATE TYPE breed AS ENUM ('maltese', NULL);"),
      throwsA(isA<DuckDBException>()),
    );
  });

  test('query should return enum', () {
    connection.execute("""
CREATE TABLE my_inputs AS
    SELECT 'duck'  AS my_varchar UNION ALL
    SELECT 'duck'  AS my_varchar UNION ALL
    SELECT 'goose' AS my_varchar;
CREATE TYPE birds AS ENUM (SELECT my_varchar FROM my_inputs);
""");

    final result = connection
        .query("SELECT enum_range(NULL::birds) AS my_enum_range;")
        .fetchAll();
    expect(
      result[0][0],
      ["duck", "goose"],
    );
  });

  test('query should return column reference to enum', () {
    connection.execute("""
CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy', 'anxious');
CREATE TABLE person (
    name TEXT,
    current_mood mood
);
INSERT INTO person
VALUES ('Pedro', 'happy'), ('Mark', NULL), ('Pagliacci', 'sad'), ('Mr. Mackey', 'ok');
""");

    final result = connection.query("""
SELECT *
FROM person
WHERE current_mood = 'sad';""").fetchAll();
    expect(
      result[0],
      [
        "Pagliacci",
        ["sad"],
      ],
    );
  });

  test('query should return an array', () {
    const query = "SELECT array_value(1, 2, 3);";
    final result = connection.query(query).fetchAll();
    expect(
      result[0][0],
      [1, 2, 3],
    );
  });

  test('query should return nested arrays', () {
    const query =
        "SELECT array_value(array_value(1, 2), array_value(3, 4), array_value(5, 6));";
    final result = connection.query(query).fetchAll();
    expect(
      result[0][0],
      [
        [1, 2],
        [3, 4],
        [5, 6],
      ],
    );
  });

  test('query should return array of structs', () {
    const query = "SELECT array_value({'a': 1, 'b': 2}, {'a': 3, 'b': 4});";
    final result = connection.query(query).fetchAll();
    expect(
      result[0][0],
      [
        {'a': 1, 'b': 2},
        {'a': 3, 'b': 4},
      ],
    );
  });
}
