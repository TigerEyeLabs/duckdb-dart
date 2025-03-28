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

  test('query should return UNION with INTEGER value', () async {
    final result = (await connection.query(
      "SELECT union_value(num := 42)::UNION(num INTEGER, str VARCHAR, byte BLOB);",
    ))
        .fetchAll();
    expect(result[0][0], 42);
  });

  test('query should return UNION with VARCHAR value', () async {
    final result = (await connection.query(
      "SELECT union_value(str := 'hello')::UNION(num INTEGER, str VARCHAR);",
    ))
        .fetchAll();
    expect(result[0][0], 'hello');
  });

  test('query should return UNION from implicit cast', () async {
    final result = (await connection
            .query("SELECT 'world'::UNION(num INTEGER, str VARCHAR);"))
        .fetchAll();
    expect(result[0][0], 'world');
  });

  test('query should extract value from UNION', () async {
    final result = (await connection.query(
      "SELECT union_extract(union_value(num := 10)::UNION(num INTEGER, str VARCHAR), 'num');",
    ))
        .fetchAll();
    expect(result[0][0], 10);
  });

  test('query should return NULL when extracting non-existent member',
      () async {
    final result = (await connection.query(
      "SELECT union_extract(union_value(num := 10)::UNION(num INTEGER, str VARCHAR), 'str');",
    ))
        .fetchAll();
    expect(result[0][0], null);
  });

  test('query should return tag of UNION as ENUM', () async {
    final result = (await connection.query(
      "SELECT union_tag(union_value(str := 'test')::UNION(num INTEGER, str VARCHAR));",
    ))
        .fetchAll();
    expect(result[0][0], 'str');
  });

  test('query should return tag of UNION as ENUMs', () async {
    await connection.execute("""
      CREATE TABLE tbl1 (u UNION(num INTEGER, str VARCHAR));
      INSERT INTO tbl1 values (1), ('two'), (union_value(str := 'three'));
    """);
    final result = (await connection.query(
      "SELECT union_tag(u) AS t FROM tbl1;",
    ))
        .fetchAll();
    expect(
      result.map((row) => row[0]).toList(),
      [
        'num',
        'str',
        'str',
      ],
    );
  });

  test('query should cast UNION to VARCHAR', () async {
    final result = (await connection.query(
      "SELECT union_value(num := 42)::UNION(num INTEGER, str VARCHAR)::VARCHAR;",
    ))
        .fetchAll();
    expect(result[0][0], '42');
  });

  test('query should order UNIONs', () async {
    final result = (await connection.query(
      "SELECT * FROM (VALUES (union_value(num := 10)::UNION(num INTEGER, str VARCHAR)), (union_value(str := 'a')::UNION(num INTEGER, str VARCHAR))) tbl(u) ORDER BY u;",
    ))
        .fetchAll();
    expect(result[0][0], 10);
    expect(result[1][0], 'a');
  });
}
