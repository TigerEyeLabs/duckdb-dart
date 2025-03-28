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

  test('query should return ENUM from hardcoded values', () async {
    await connection.execute("CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy')");
    final result = (await connection.query("SELECT 'happy'::mood;")).fetchAll();
    expect(result[0][0], 'happy');
  });

  test('query should return ENUM from select statement', () async {
    await connection.execute("""
      CREATE TABLE my_inputs AS
        SELECT 'duck' AS my_varchar UNION ALL
        SELECT 'duck' AS my_varchar UNION ALL
        SELECT 'goose' AS my_varchar;
      CREATE TYPE birds AS ENUM (SELECT my_varchar FROM my_inputs);
    """);

    final result =
        (await connection.query("SELECT enum_range(NULL::birds);")).fetchAll();
    expect(result[0][0], ['duck', 'goose']);
  });

  test('query should handle table with enum column', () async {
    await connection.execute("""
      CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy');
      CREATE TABLE person (name TEXT, current_mood mood);
      INSERT INTO person VALUES
        ('Pedro', 'happy'),
        ('Mark', NULL),
        ('Pagliacci', 'sad'),
        ('Mr. Mackey', 'ok');
    """);

    final result = (await connection
            .query("SELECT * FROM person WHERE current_mood = 'sad';"))
        .fetchAll();
    expect(result[0][0], 'Pagliacci');
    expect(result[0][1], 'sad');
  });

  test('query should handle enum comparison', () async {
    await connection.execute("""
      CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy');
      SELECT 'sad'::mood < 'ok'::mood AS comp;
    """);

    final result = (await connection.query(
      "SELECT unnest(['ok'::mood, 'happy'::mood, 'sad'::mood]) AS m ORDER BY m;",
    ))
        .fetchAll();
    expect(result.map((r) => r[0]).toList(), ['sad', 'ok', 'happy']);
  });

  test('query should handle enum in string functions', () async {
    await connection.execute("""
      CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy');
      CREATE TABLE person (name TEXT, current_mood mood);
      INSERT INTO person VALUES
        ('Pedro', 'happy'),
        ('Mark', NULL),
        ('Pagliacci', 'sad'),
        ('Mr. Mackey', 'ok');
    """);

    final result = (await connection.query(
      "SELECT regexp_matches(current_mood, '.*a.*') AS contains_a FROM person;",
    ))
        .fetchAll();
    expect(result.map((r) => r[0]).toList(), [true, null, true, false]);
  });

  test('query should handle comparison between different enum types', () async {
    await connection.execute("""
      CREATE TYPE mood1 AS ENUM ('happy', 'sad');
      CREATE TYPE mood2 AS ENUM ('happy', 'anxious');
      CREATE TABLE person (
        name text,
        current_mood mood1,
        future_mood mood2
      );
      INSERT INTO person VALUES
        ('Pedro', 'happy', 'happy'),
        ('Mark', 'sad', 'anxious');
    """);

    final result = (await connection.query(
      "SELECT * FROM person WHERE current_mood::varchar = future_mood::varchar;",
    ))
        .fetchAll();
    expect(result.length, 1);
    expect(result[0][0], 'Pedro');
  });

  test('query should handle enum to varchar casting', () async {
    await connection.execute("""
      CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy');
      CREATE TABLE person (name TEXT, mood_enum mood, mood_varchar VARCHAR);
      INSERT INTO person VALUES
        ('Pedro', 'happy', 'happy'),
        ('Mark', 'sad', 'sad');
    """);

    final result = (await connection.query(
      "SELECT * FROM person WHERE mood_enum::varchar = mood_varchar;",
    ))
        .fetchAll();
    expect(result.length, 2);
  });

  test('query should handle dropping enum type', () async {
    await connection.execute("""
      CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy');
      DROP TYPE mood;
    """);

    // Verify the enum type no longer exists by trying to create it again
    // (should succeed since the original was dropped)
    final result = await connection.query(
      "CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy');",
    );
    expect(result, isNotNull);
  });
}
