import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

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

  test('simple uuid', () {
    const uuidString = '79700043-11eb-1101-80d6-510900000d10';
    final results = connection.query("SELECT '$uuidString'::UUID;").fetchAll();

    final uuid = results[0][0]! as UuidValue;
    expect(uuid, UuidValue.fromString(uuidString));
  });
}
