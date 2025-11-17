import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:test/test.dart';

void main() {
  group('boolean tests', testOn: 'browser', () {
    late Database database;
    late Connection connection;

    setUpAll(() async {
      database = await duckdb.open(':memory:');
      connection = await duckdb.connect(database);
    });

    tearDownAll(() async {
      await connection.dispose();
      await database.dispose();
    });

    test('can handle multiple boolean values in same column', () async {
      await connection.execute('''
        CREATE TABLE boolean_test (
          id INTEGER,
          flag BOOLEAN
        );
        INSERT INTO boolean_test VALUES
          (1, true),
          (2, false),
          (3, true),
          (4, false),
          (5, true),
          (6, false),
          (7, true),
          (8, false);
      ''');

      final result =
          await connection.query('SELECT * FROM boolean_test ORDER BY id');
      final rows = result.fetchAll();

      expect(rows.length, equals(8));

      expect(rows[0][0], equals(1));
      expect(rows[0][1], equals(true));

      expect(rows[1][0], equals(2));
      expect(rows[1][1], equals(false));

      expect(rows[2][0], equals(3));
      expect(rows[2][1], equals(true));

      expect(rows[3][0], equals(4));
      expect(rows[3][1], equals(false));

      expect(rows[4][0], equals(5));
      expect(rows[4][1], equals(true));

      expect(rows[5][0], equals(6));
      expect(rows[5][1], equals(false));

      expect(rows[6][0], equals(7));
      expect(rows[6][1], equals(true));

      expect(rows[7][0], equals(8));
      expect(rows[7][1], equals(false));
    });

    test('can handle boolean array with alternating pattern', () async {
      await connection.execute('''
        CREATE TABLE alternating_bools (
          row_num INTEGER,
          bool_val BOOLEAN
        );
      ''');

      // Insert alternating true/false pattern
      for (var i = 0; i < 20; i++) {
        final boolVal = i.isEven;
        await connection
            .execute('INSERT INTO alternating_bools VALUES ($i, $boolVal)');
      }

      final result = await connection
          .query('SELECT * FROM alternating_bools ORDER BY row_num');
      final rows = result.fetchAll();

      expect(rows.length, equals(20));

      for (var i = 0; i < 20; i++) {
        final expectedBool = i.isEven;
        expect(rows[i][0], equals(i));
        expect(rows[i][1], equals(expectedBool));
      }
    });

    test('can handle boolean null values mixed with true/false', () async {
      await connection.execute('''
        CREATE TABLE mixed_bools (
          id INTEGER,
          flag BOOLEAN
        );
        INSERT INTO mixed_bools VALUES
          (1, true),
          (2, null),
          (3, false),
          (4, null),
          (5, true),
          (6, false),
          (7, null),
          (8, true);
      ''');

      final result =
          await connection.query('SELECT * FROM mixed_bools ORDER BY id');
      final rows = result.fetchAll();

      expect(rows.length, equals(8));

      final expectedValues = [true, null, false, null, true, false, null, true];

      for (var i = 0; i < 8; i++) {
        expect(rows[i][0], equals(i + 1));
        expect(rows[i][1], equals(expectedValues[i]));
      }
    });

    test('can handle large boolean dataset', () async {
      await connection.execute('''
        CREATE TABLE large_boolean_test (
          id INTEGER,
          flag BOOLEAN
        );
      ''');

      final expectedValues = <bool>[];
      for (var i = 0; i < 100; i++) {
        final boolVal = (i % 3) == 0;
        expectedValues.add(boolVal);
        await connection
            .execute('INSERT INTO large_boolean_test VALUES ($i, $boolVal)');
      }

      final result = await connection
          .query('SELECT * FROM large_boolean_test ORDER BY id');
      final rows = result.fetchAll();

      expect(rows.length, equals(100));

      for (var i = 0; i < 100; i++) {
        expect(rows[i][0], equals(i));
        expect(rows[i][1], equals(expectedValues[i]));
      }
    });

    test('can handle boolean columns with direct SQL', () async {
      await connection.execute('''
        CREATE TABLE direct_bools (
          id INTEGER,
          flag BOOLEAN
        );
      ''');

      final testData = [
        [1, true],
        [2, false],
        [3, null],
        [4, true],
        [5, false],
        [6, true],
        [7, null],
        [8, false],
      ];

      for (final row in testData) {
        final id = row[0];
        final flag = row[1];
        await connection
            .execute('INSERT INTO direct_bools VALUES ($id, $flag)');
      }

      final result =
          await connection.query('SELECT * FROM direct_bools ORDER BY id');
      final rows = result.fetchAll();

      expect(rows.length, equals(8));

      for (var i = 0; i < 8; i++) {
        expect(rows[i][0], equals(testData[i][0]));
        expect(rows[i][1], equals(testData[i][1]));
      }
    });

    test('can handle boolean aggregations', () async {
      await connection.execute('''
        CREATE TABLE bool_aggregation (
          group_id INTEGER,
          flag BOOLEAN
        );
        INSERT INTO bool_aggregation VALUES
          (1, true),
          (1, false),
          (1, true),
          (2, false),
          (2, false),
          (2, true),
          (3, true),
          (3, true),
          (3, false);
      ''');

      final result = await connection.query('''
        SELECT
          group_id,
          COUNT(*) as total_count,
          COUNT(CASE WHEN flag = true THEN 1 END) as true_count,
          COUNT(CASE WHEN flag = false THEN 1 END) as false_count
        FROM bool_aggregation
        GROUP BY group_id
        ORDER BY group_id
      ''');

      final rows = result.fetchAll();

      expect(rows.length, equals(3));

      expect(rows[0][0], equals(1));
      expect(rows[0][1], equals(3));
      expect(rows[0][2], equals(2));
      expect(rows[0][3], equals(1));

      expect(rows[1][0], equals(2));
      expect(rows[1][1], equals(3));
      expect(rows[1][2], equals(1));
      expect(rows[1][3], equals(2));

      expect(rows[2][0], equals(3));
      expect(rows[2][1], equals(3));
      expect(rows[2][2], equals(2));
      expect(rows[2][3], equals(1));
    });
  });
}
