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

  group('JSON type support', () {
    test('query should return JSON object as map', () async {
      final result = (await connection.query(
        "SELECT '{\"name\": \"Alice\", \"age\": 30}'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(
        jsonResult.value,
        {'name': 'Alice', 'age': 30},
      );
    });

    test('query should return nested JSON object', () async {
      final result = (await connection.query(
        "SELECT '{\"user\": {\"name\": \"Bob\", \"id\": 123}, \"active\": true}'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(
        jsonResult.value,
        {
          'user': {'name': 'Bob', 'id': 123},
          'active': true,
        },
      );
    });

    test('query should return JSON array', () async {
      final result = (await connection.query(
        "SELECT '[1, 2, 3, 4, 5]'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(jsonResult.value, [1, 2, 3, 4, 5]);
    });

    test('query should return JSON array of objects', () async {
      final result = (await connection.query(
        "SELECT '[{\"name\": \"Alice\"}, {\"name\": \"Bob\"}]'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(
        jsonResult.value,
        [
          {'name': 'Alice'},
          {'name': 'Bob'},
        ],
      );
    });

    test('query should return null for NULL JSON value', () async {
      final result =
          (await connection.query("SELECT CAST(NULL AS JSON);")).fetchAll();
      expect(result[0][0], null);
    });

    test('query should return empty JSON object', () async {
      final result = (await connection.query("SELECT '{}'::JSON;")).fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(jsonResult.value, {});
    });

    test('query should return empty JSON array', () async {
      final result = (await connection.query("SELECT '[]'::JSON;")).fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(jsonResult.value, []);
    });

    test('query should handle JSON with mixed types', () async {
      final result = (await connection.query(
        "SELECT '{\"string\": \"hello\", \"number\": 42, \"float\": 3.14, \"bool\": true, \"null\": null}'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(
        jsonResult.value,
        {
          'string': 'hello',
          'number': 42,
          'float': 3.14,
          'bool': true,
          'null': null,
        },
      );
    });

    test('query should handle deeply nested JSON', () async {
      final result = (await connection.query(
        "SELECT '{\"a\": {\"b\": {\"c\": {\"d\": \"deep\"}}}}'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(
        jsonResult.value,
        {
          'a': {
            'b': {
              'c': {'d': 'deep'},
            },
          },
        },
      );
    });

    test('query should handle JSON with arrays in objects', () async {
      final result = (await connection.query(
        "SELECT '{\"name\": \"Alice\", \"scores\": [95, 87, 92]}'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(
        jsonResult.value,
        {
          'name': 'Alice',
          'scores': [95, 87, 92],
        },
      );
    });

    test('query should handle multiple JSON columns', () async {
      final result = (await connection.query(
        "SELECT '{\"a\": 1}'::JSON as col1, '{\"b\": 2}'::JSON as col2;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(jsonResult.value, {'a': 1});
      final jsonResult2 = result[0][1]! as JsonValue;
      expect(jsonResult2.value, {'b': 2});
    });

    test('query should handle JSON in table', () async {
      await connection.execute(
        "CREATE TABLE json_test (id INTEGER, data VARCHAR);",
      );
      await connection.execute(
        "INSERT INTO json_test VALUES (1, '{\"name\": \"test\"}');",
      );

      final result = (await connection.query(
        "SELECT id, data::JSON as json_data FROM json_test;",
      ))
          .fetchAll();

      expect(result[0][0], 1);
      final jsonResult = result[0][1]! as JsonValue;
      expect(jsonResult.value, {'name': 'test'});

      await connection.execute("DROP TABLE json_test;");
    });
  });

  group('JSON with basic value types', () {
    test('should handle JSON string values', () async {
      final result = (await connection.query(
        "SELECT '\"hello world\"'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(jsonResult.value, 'hello world');
    });

    test('should handle JSON string with special characters', () async {
      final result = (await connection.query(
        "SELECT '\"hello\\nworld\\t\\\"escaped\\\"\"'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(jsonResult.value, 'hello\nworld\t"escaped"');
    });

    test('should handle JSON integer values', () async {
      final result = (await connection.query(
        "SELECT '42'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(jsonResult.value, 42);
    });

    test('should handle JSON negative integer', () async {
      final result = (await connection.query(
        "SELECT '-123'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(jsonResult.value, -123);
    });

    test('should handle JSON float values', () async {
      final result = (await connection.query(
        "SELECT '3.14159'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(jsonResult.value, 3.14159);
    });

    test('should handle JSON negative float', () async {
      final result = (await connection.query(
        "SELECT '-2.718'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(jsonResult.value, -2.718);
    });

    test('should handle JSON scientific notation', () async {
      final result = (await connection.query(
        "SELECT '1.23e10'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(jsonResult.value, 1.23e10);
    });

    test('should handle JSON boolean true', () async {
      final result = (await connection.query(
        "SELECT 'true'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(jsonResult.value, true);
    });

    test('should handle JSON boolean false', () async {
      final result = (await connection.query(
        "SELECT 'false'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(jsonResult.value, false);
    });

    test('should handle JSON null value', () async {
      final result = (await connection.query(
        "SELECT 'null'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(jsonResult.value, null);
    });

    test('should handle JSON zero', () async {
      final result = (await connection.query(
        "SELECT '0'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(jsonResult.value, 0);
    });

    test('should handle JSON array of strings', () async {
      final result = (await connection.query(
        "SELECT '[\"apple\", \"banana\", \"cherry\"]'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(jsonResult.value, ['apple', 'banana', 'cherry']);
    });

    test('should handle JSON array of numbers', () async {
      final result = (await connection.query(
        "SELECT '[1, 2.5, -3, 4.0]'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(jsonResult.value, [1, 2.5, -3, 4.0]);
    });

    test('should handle JSON array of booleans', () async {
      final result = (await connection.query(
        "SELECT '[true, false, true]'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(jsonResult.value, [true, false, true]);
    });

    test('should handle JSON array with mixed types', () async {
      final result = (await connection.query(
        "SELECT '[1, \"text\", true, null, 3.14]'::JSON;",
      ))
          .fetchAll();
      final jsonResult = result[0][0]! as JsonValue;
      expect(jsonResult.value, [1, 'text', true, null, 3.14]);
    });
  });
}
