import 'package:collection/collection.dart';
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

  test('query should return map with VARCHAR keys and INTEGER values', () {
    final result = connection
        .query("SELECT MAP {'key1': 10, 'key2': 20, 'key3': 30};")
        .fetchAll();
    expect(
      result[0][0],
      {'key1': 10, 'key2': 20, 'key3': 30},
    );
  });

  test('query should return map with INTEGER keys and NUMERIC values', () {
    final result =
        connection.query("SELECT MAP {1: 42.001, 5: -32.1};").fetchAll();
    expect(
      result[0][0],
      {1: Decimal.fromNum(42.001), 5: Decimal.fromNum(-32.1)},
    );
  });

  test('query should return map created from entries', () {
    final result = connection
        .query(
          "SELECT map_from_entries([('key1', 10), ('key2', 20), ('key3', 30)]);",
        )
        .fetchAll();
    expect(
      result[0][0],
      {'key1': 10, 'key2': 20, 'key3': 30},
    );
  });

  test('query should return map created from two lists', () {
    final result = connection
        .query("SELECT MAP(['key1', 'key2', 'key3'], [10, 20, 30]);")
        .fetchAll();
    expect(
      result[0][0],
      {'key1': 10, 'key2': 20, 'key3': 30},
    );
  });

  test('query should return list when retrieving from map', () {
    final result = connection
        .query("SELECT MAP {'key1': 5, 'key2': 43}['key1'];")
        .fetchAll();
    expect(result[0][0], [5]);
  });

  test('query should return value when retrieving from map with list selection',
      () {
    final result = connection
        .query("SELECT MAP {'key1': 5, 'key2': 43}['key1'][1];")
        .fetchAll();
    expect(result[0][0], 5);
  });

  test('query should return empty list for non-existent key', () {
    final result = connection
        .query("SELECT MAP {'key1': 5, 'key2': 43}['key3'];")
        .fetchAll();
    expect(result[0][0], []);
  });

  test('query should return list when using element_at function', () {
    final result = connection
        .query("SELECT element_at(MAP {'key1': 5, 'key2': 43}, 'key1');")
        .fetchAll();
    expect(result[0][0], [5]);
  });

  test('query should return nested map', () {
    final deepEquals = const DeepCollectionEquality().equals;
    final result = connection
        .query("SELECT MAP {['a', 'b']: [1.1, 2.2], ['c', 'd']: [3.3, 4.4]};")
        .fetchAll();
    final expectedMap = {
      ['a', 'b']: [Decimal.fromNum(1.1), Decimal.fromNum(2.2)],
      ['c', 'd']: [Decimal.fromNum(3.3), Decimal.fromNum(4.4)],
    };
    expect(
      result[0][0],
      predicate((m) => deepEquals(m, expectedMap)),
    );
  });
}
