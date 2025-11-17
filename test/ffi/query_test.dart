import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/src/types/time.dart';
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

  test('query should return all rows', () async {
    const count = 100000;
    const query = """
      SELECT range AS value
      FROM range(1, $count + 1)
      ORDER BY value;
    """;

    final result = (await connection.query(query)).fetchAll();
    expect(result, List.generate(count, (i) => [i + 1], growable: false));
  });

  test('query should return uhugeint', testOn: 'vm', () async {
    const hexString = 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF';
    final bigIntValue = BigInt.parse(hexString, radix: 16);

    const query =
        "SELECT '340282366920938463463374607431768211455'::UHUGEINT AS uhugeint_value;";

    final result = await connection.query(query);
    expect(result[0][0], bigIntValue);
  });

  test('query should return time', () async {
    const query = "SELECT TIME '1992-09-20 11:30:00.123456';";
    final result = await connection.query(query);
    expect(
      result[0][0],
      Time(hour: 11, minute: 30, second: 0, microsecond: 123456),
    );
  });

  test('query should return timestamp with microsecond precision', () async {
    const query = "SELECT TIMESTAMP '1992-09-20 11:30:00.123456789';";
    final result = await connection.query(query);
    expect(
      result[0][0],
      DateTime.parse('1992-09-20 11:30:00.123456789Z'),
    );
  });

  test('query should return timestamp with second precision', () async {
    const query = "SELECT TIMESTAMP_S '1992-09-20 11:30:00';";
    final result = await connection.query(query);
    expect(
      result[0][0],
      DateTime.parse('1992-09-20 11:30:00Z'),
    );
  });

  test('query should return timestamp with millisecond precision', () async {
    const query = "SELECT TIMESTAMP_MS '1992-09-20 11:30:00';";
    final result = await connection.query(query);
    expect(
      result[0][0],
      DateTime.parse('1992-09-20 11:30:00Z'),
    );
  });

  test('query should return timestamp with nanosecond precision', () async {
    const query = "SELECT TIMESTAMP_NS '1992-09-20 11:30:00.123456';";
    final result = await connection.query(query);
    expect(
      result[0][0],
      DateTime.parse('1992-09-20 11:30:00.123456Z'),
    );
  });

  test('query should fail since enum mood already exists', () async {
    await connection
        .execute("CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy');");
    expect(
      () => connection.execute(
        "CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy', 'anxious');",
      ),
      throwsA(isA<DuckDBException>()),
    );
  });

  test('query should fail since enum values must be unique', () async {
    expect(
      () async => connection
          .execute("CREATE TYPE breed AS ENUM ('maltese', 'maltese');"),
      throwsA(isA<DuckDBException>()),
    );
  });

  test('query should fail since enum values must not be null', () async {
    expect(
      () async =>
          connection.execute("CREATE TYPE breed AS ENUM ('maltese', NULL);"),
      throwsA(isA<DuckDBException>()),
    );
  });

  test('query should return enum', () async {
    await connection.execute("""
CREATE TABLE my_inputs AS
    SELECT 'duck'  AS my_varchar UNION ALL
    SELECT 'duck'  AS my_varchar UNION ALL
    SELECT 'goose' AS my_varchar;
CREATE TYPE birds AS ENUM (SELECT my_varchar FROM my_inputs);
""");

    final result = (await connection
            .query("SELECT enum_range(NULL::birds) AS my_enum_range;"))
        .fetchAll();
    expect(
      result[0][0],
      ["duck", "goose"],
    );
  });

  test('query should return column reference to enum', () async {
    await connection.execute("""
CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy', 'anxious');
CREATE TABLE person (
    name TEXT,
    current_mood mood
);
INSERT INTO person
VALUES ('Pedro', 'happy'), ('Mark', NULL), ('Pagliacci', 'sad'), ('Mr. Mackey', 'ok');
""");

    final result = (await connection.query("""
SELECT *
FROM person
WHERE current_mood = 'sad';""")).fetchAll();
    expect(
      result[0],
      [
        "Pagliacci",
        "sad",
      ],
    );
  });

  test('query should return an array', () async {
    const query = "SELECT array_value(1, 2, 3);";
    final result = (await connection.query(query)).fetchAll();
    expect(
      result[0][0],
      [1, 2, 3],
    );
  });

  test('query should return nested arrays', () async {
    const query =
        "SELECT array_value(array_value(1, 2), array_value(3, 4), array_value(5, 6));";
    final result = (await connection.query(query)).fetchAll();
    expect(
      result[0][0],
      [
        [1, 2],
        [3, 4],
        [5, 6],
      ],
    );
  });

  test('query should return array of structs', () async {
    const query = "SELECT array_value({'a': 1, 'b': 2}, {'a': 3, 'b': 4});";
    final result = (await connection.query(query)).fetchAll();
    expect(
      result[0][0],
      [
        {'a': 1, 'b': 2},
        {'a': 3, 'b': 4},
      ],
    );
  });

  test('query should fail', () async {
    const query = "SELECT 1 as x;";
    final result = await connection.query(query);
    expect(() => result[1][0], throwsA(isA<RangeError>()));
    expect(() => result[0][1], throwsA(isA<RangeError>()));
  });

  test('query should return blob', () async {
    const query = "SELECT '\\xAA\\xAB\\xAC'::BLOB;";
    final result = await connection.query(query);
    expect(result[0][0], [170, 171, 172]);
  });

  test('should handle cancellation of pending queries', testOn: 'vm', () async {
    final results = <Future<ResultSet>>[];

    // First long query
    results.add(
      connection.query('''
        SELECT COUNT(*)
        FROM (SELECT * FROM range(1000000)) t1
        CROSS JOIN (SELECT * FROM range(1000)) t2;
      '''),
    );

    // Second query with cancellation
    final token = DuckDBCancellationToken();

    // Start the query but don't await it yet
    final cancelledQuery = connection.query(
      'SELECT COUNT(*) FROM (SELECT * FROM range(1000000)) t3;',
      token: token,
    );

    // Cancel the query immediately
    token.cancel();

    // Now expect the exception
    await expectLater(
      cancelledQuery,
      throwsA(isA<DuckDBException>()),
    );

    // Third query should still work
    final result3 = await connection.query('SELECT 42');
    expect(result3[0][0], 42);

    // First query should complete normally
    expect(await results[0], isA<ResultSet>());
  });

  test('should handle cancellation of running query', testOn: 'vm', () async {
    final token = DuckDBCancellationToken();

    // Start a long-running query with cancellation token
    final cancelledQuery = connection.query(
      '''
      SELECT COUNT(*)
      FROM (SELECT generate_series FROM generate_series(1, 100000000)) t1
      WHERE generate_series % 2 = 0;
      ''',
      token: token,
    );

    // Give query time to start
    await Future.delayed(const Duration(milliseconds: 100));

    // Cancel the running query
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

  test('interrupt should affect results after gathering', testOn: 'vm',
      () async {
    final operation = connection.query('''
      WITH RECURSIVE t(n) AS (
        SELECT 1
        UNION ALL
        SELECT n + 1 FROM t WHERE n < 1000000
      )
      SELECT n FROM t;
    ''');

    // Give query time to start
    await Future.delayed(const Duration(milliseconds: 100));

    // Interrupt while query is running
    await connection.interrupt();

    // Expect the operation to throw an interrupt exception
    await expectLater(operation, throwsA(isA<DuckDBException>()));

    // Verify connection is still usable after interrupt
    final result = await connection.query('SELECT 42');
    expect(result[0][0], 42);
  });

  test('should continue processing queue after interrupt', testOn: 'vm',
      () async {
    // First query - will be interrupted
    final interruptedQuery = connection.query('''
      SELECT COUNT(*)
      FROM (SELECT * FROM range(10000000)) t1
      CROSS JOIN (SELECT * FROM range(10000000)) t2;
    ''');

    // Queue up some follow-up queries immediately
    final followUpQuery1 = connection.query('SELECT 42');
    final followUpQuery2 = connection.query('SELECT 43');

    // Give first query time to start
    await Future.delayed(const Duration(milliseconds: 100));

    // Interrupt the running query
    await connection.interrupt();

    // Verify interrupted query fails
    await expectLater(
      interruptedQuery,
      throwsA(isA<DuckDBException>()),
    );

    // Verify subsequent queries succeed
    final result1 = await followUpQuery1;
    expect(result1[0][0], 42);

    final result2 = await followUpQuery2;
    expect(result2[0][0], 43);
  });
}
