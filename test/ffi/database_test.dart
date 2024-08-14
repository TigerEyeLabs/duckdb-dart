import 'dart:isolate';
import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:test/test.dart';

void main() {
  late Database database;
  late Connection connection;

  setUp(() {
    database = duckdb.open(":memory:");
    connection = duckdb.connect(database);
    connection.execute("CREATE TABLE users (name VARCHAR, age INTEGER)");
  });

  tearDown(() {
    connection.dispose();
    database.dispose();
  });

  test('Database transaction via main thread', () {
    connection.execute("INSERT INTO users VALUES ('John', 30)");
    final result = connection.query("SELECT * FROM users").fetchAll();
    expect(result.length, 1);
    expect(result[0][0], 'John');
    expect(result[0][1], 30);
  });

  test('Database transaction via isolate with transferable database', () async {
    // Function to run in the isolate
    void isolateFunction(TransferableDatabase transferableDatabase) {
      final isolatedCon = duckdb.connectWithTransferred(transferableDatabase);
      isolatedCon.execute("INSERT INTO users VALUES ('Jane', 25)");
      isolatedCon.dispose();
    }

    // Transfer database to the isolate
    final receivePort = ReceivePort();
    await Isolate.spawn(isolateFunction, database.transferrable);
    receivePort
        .close(); // Close the port after use, assuming no data needs to be sent back.

    // Delay to allow the isolate to complete the transaction
    await Future.delayed(const Duration(seconds: 1));

    // Query in the main thread to check the results of the isolate's work
    final results =
        connection.query("SELECT * FROM users WHERE name = 'Jane'").fetchAll();
    expect(results.length, 1);
    expect(results[0][0], 'Jane');
    expect(results[0][1], 25);
  });
}
