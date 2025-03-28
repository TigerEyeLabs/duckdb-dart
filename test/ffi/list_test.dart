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

  test('List of integers', () async {
    const query = """
      SELECT [1, 2, 3];
    """;

    final result = (await connection.query(query)).fetchAll();
    expect(result[0][0], [1, 2, 3]);
  });

  test('List of strings with a NULL value', () async {
    const query = """
      SELECT ['duck', 'goose', NULL, 'heron'];
    """;

    final result = (await connection.query(query)).fetchAll();
    expect(result[0][0], ['duck', 'goose', null, 'heron']);
  });

  test('List of lists with NULL values', () async {
    const query = """
      SELECT [['duck', 'goose', 'heron'], NULL, ['frog', 'toad'], []];
    """;

    final result = (await connection.query(query)).fetchAll();
    expect(result[0][0], [
      ['duck', 'goose', 'heron'],
      null,
      ['frog', 'toad'],
      [],
    ]);
  });

  test('Create a list with the list_value function', () async {
    const query = """
      SELECT list_value(1, 2, 3);
    """;

    final result = (await connection.query(query)).fetchAll();
    expect(result[0][0], [1, 2, 3]);
  });

  test('Create a table with an integer list column and a varchar list column',
      () async {
    const create = """
      CREATE TABLE list_table (int_list INTEGER[], varchar_list VARCHAR[]);
    """;
    await connection.execute(create);

    const insert = """
      INSERT INTO list_table VALUES ([1, 2, 3], ['duck', NULL, 'heron']);
    """;
    await connection.execute(insert);

    const select = """
      SELECT * FROM list_table;
    """;
    final result = (await connection.query(select)).fetchAll();
    expect(result, [
      [
        [1, 2, 3],
        ['duck', null, 'heron'],
      ]
    ]);
  });

  test('query should return items in the right order', () async {
    const query = """
      SELECT arr, list_concat(list_reverse(arr), arr) FROM (SELECT [1,2,3]) AS _(arr);
    """;

    final result = (await connection.query(query)).fetchAll();
    expect(result, [
      [
        [1, 2, 3],
        [3, 2, 1, 1, 2, 3],
      ]
    ]);
  });
}
