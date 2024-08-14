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

  test('simple struct', () {
    final results = connection
        .query("SELECT {int_field: 5, varchar_field: 'foo'} as struct")
        .fetchAll();

    final struct = results[0][0] as Map<String, dynamic>;
    expect(struct['int_field'], 5);
    expect(struct['varchar_field'], 'foo');
  });

  test('multiple rows', () {
    final results = connection
        .query(
          "SELECT {int_field: range, varchar_field: 'foo'} as struct FROM RANGE(1, 3)",
        )
        .fetchAll();

    final struct1 = results[0][0] as Map<String, dynamic>;
    final struct2 = results[1][0] as Map<String, dynamic>;
    expect(struct1['int_field'], 1);
    expect(struct1['varchar_field'], 'foo');
    expect(struct2['int_field'], 2);
    expect(struct2['varchar_field'], 'foo');
  });

  test('nested struct', () {
    final results = connection
        .query(
          "SELECT {int_field: 5, nested_struct: {value1: 24, value2: 42}} as struct",
        )
        .fetchAll();

    final struct = results[0][0] as Map<String, dynamic>;
    expect(struct['int_field'], 5);

    final nestedStruct = struct['nested_struct'] as Map<String, dynamic>;
    expect(nestedStruct['value1'], 24);
    expect(nestedStruct['value2'], 42);
  });

  test('Struct of structs with NULL values', () {
    final results = connection.query(
      """
        SELECT {'birds':
            {'yes': 'duck', 'maybe': 'goose', 'huh': NULL, 'no': 'heron'},
        'aliens':
            NULL,
        'amphibians':
            {'yes':'frog', 'maybe': 'salamander', 'huh': 'dragon', 'no':'toad'}
        };
      """,
    ).fetchAll();

    expect(results[0][0], {
      'birds': {
        'yes': 'duck',
        'maybe': 'goose',
        'huh': null,
        'no': 'heron',
      },
      'aliens': null,
      'amphibians': {
        'yes': 'frog',
        'maybe': 'salamander',
        'huh': 'dragon',
        'no': 'toad',
      },
    });
  });
}
