@TestOn('vm')
library;

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/src/ffi/impl/implementation.dart';
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

  group('Logical Type Alias Support', () {
    test('JSON type should have JSON alias', () async {
      final result = await connection.query(
        "SELECT '{\"test\": 1}'::JSON as json_col;",
      );

      final resultImpl = result as ResultSetImpl;
      final logicalType = resultImpl.logicalType(0);

      expect(logicalType.alias, 'JSON');
      expect(logicalType.isJson, true);
      expect(logicalType.hasCustomAlias, false);

      await result.dispose();
    });

    test('VARCHAR type should have no alias', () async {
      final result = await connection.query(
        "SELECT 'test'::VARCHAR as text_col;",
      );

      final resultImpl = result as ResultSetImpl;
      final logicalType = resultImpl.logicalType(0);

      expect(logicalType.alias, null);
      expect(logicalType.isJson, false);
      expect(logicalType.hasCustomAlias, false);

      await result.dispose();
    });

    test('INTEGER type should have no alias', () async {
      final result = await connection.query(
        "SELECT 42::INTEGER as int_col;",
      );

      final resultImpl = result as ResultSetImpl;
      final logicalType = resultImpl.logicalType(0);

      expect(logicalType.alias, null);
      expect(logicalType.isJson, false);
      expect(logicalType.hasCustomAlias, false);

      await result.dispose();
    });

    test('user-defined types may not preserve aliases via C API', () async {
      // Note: Currently, DuckDB's C API doesn't preserve UDT aliases the same way
      // it does for JSON. This test documents the current behavior.
      await connection.execute("CREATE TYPE email AS VARCHAR;");
      final result = await connection.query(
        "SELECT 'test@example.com'::email as email_col;",
      );

      final resultImpl = result as ResultSetImpl;
      final logicalType = resultImpl.logicalType(0);

      // UDT aliases are not currently preserved through C API
      expect(logicalType.alias, null);
      expect(logicalType.isJson, false);
      expect(logicalType.hasCustomAlias, false);

      // Should still return as VARCHAR (base type)
      expect(result[0][0], 'test@example.com');

      await result.dispose();
    });

    test('multiple columns with JSON alias', () async {
      final result = await connection.query(
        "SELECT "
        "'{\"id\": 1}'::JSON as json_col, "
        "'plain text' as text_col;",
      );

      final resultImpl = result as ResultSetImpl;

      // Column 0: JSON (known alias)
      final col0Type = resultImpl.logicalType(0);
      expect(col0Type.alias, 'JSON');
      expect(col0Type.isJson, true);
      expect(col0Type.hasCustomAlias, false);

      // Column 1: plain VARCHAR (no alias)
      final col1Type = resultImpl.logicalType(1);
      expect(col1Type.alias, null);
      expect(col1Type.isJson, false);
      expect(col1Type.hasCustomAlias, false);

      await result.dispose();
    });

    test('STRUCT type should have no alias', () async {
      final result = await connection.query(
        "SELECT {'name': 'Alice', 'age': 30} as struct_col;",
      );

      final resultImpl = result as ResultSetImpl;
      final logicalType = resultImpl.logicalType(0);

      expect(logicalType.alias, null);
      expect(logicalType.isJson, false);
      expect(logicalType.hasCustomAlias, false);

      // Should return as Map
      expect(result[0][0], {'name': 'Alice', 'age': 30});

      await result.dispose();
    });

    test('LIST type should have no alias', () async {
      final result = await connection.query(
        "SELECT [1, 2, 3] as list_col;",
      );

      final resultImpl = result as ResultSetImpl;
      final logicalType = resultImpl.logicalType(0);

      expect(logicalType.alias, null);
      expect(logicalType.isJson, false);
      expect(logicalType.hasCustomAlias, false);

      // Should return as List
      expect(result[0][0], [1, 2, 3]);

      await result.dispose();
    });

    test('JSON vs STRUCT behavior difference', () async {
      final result = await connection.query(
        "SELECT "
        "'{\"name\": \"Alice\", \"age\": 30}'::JSON as json_col, "
        "{'name': 'Bob', 'age': 25} as struct_col;",
      );

      final rows = result.fetchAll();

      // Both should return as maps, but JSON is parsed from string
      expect((rows[0][0]! as JsonValue).value, {'name': 'Alice', 'age': 30});
      expect(rows[0][1], {'name': 'Bob', 'age': 25});

      // But their logical types are different
      final resultImpl = result as ResultSetImpl;
      final jsonType = resultImpl.logicalType(0);
      final structType = resultImpl.logicalType(1);

      expect(jsonType.isJson, true);
      expect(structType.isJson, false);

      await result.dispose();
    });

    test('case insensitive JSON alias detection', () async {
      // DuckDB might return 'json', 'JSON', or 'Json'
      final result = await connection.query(
        "SELECT '{\"test\": 1}'::JSON as col;",
      );

      final resultImpl = result as ResultSetImpl;
      final logicalType = resultImpl.logicalType(0);

      // Should detect JSON regardless of case
      expect(logicalType.isJson, true);

      await result.dispose();
    });
  });

  group('Alias Integration Tests', () {
    test('table with JSON column', () async {
      await connection.execute(
        "CREATE TABLE events (id INTEGER, data VARCHAR);",
      );
      await connection.execute(
        "INSERT INTO events VALUES (1, '{\"event\": \"login\"}');",
      );

      final result = await connection.query(
        "SELECT id, data::JSON as json_data FROM events;",
      );

      final resultImpl = result as ResultSetImpl;

      // Column 0: id (no alias)
      expect(resultImpl.logicalType(0).alias, null);

      // Column 1: json_data (JSON alias)
      expect(resultImpl.logicalType(1).alias, 'JSON');
      expect(resultImpl.logicalType(1).isJson, true);

      // JSON should be auto-parsed
      final row = result.fetchAll()[0];
      expect(row[0], 1);
      expect((row[1]! as JsonValue).value, {'event': 'login'});

      await result.dispose();
    });
  });
}
