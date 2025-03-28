import 'dart:isolate';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/open.dart';

void printUsersTable(String source, Connection con) async {
  print("[$source] RUN QUERY");
  final result = await con.query("SELECT * from users");

  result.fetchAll().forEach((item) {
    print("[$source] ${item}");
  });
}

void main(List<String> arguments) async {
  /// replace with your local installation of duckdb
  open.overrideFor(
      OperatingSystem.macOS, '../../macos/Libraries/release/libduckdb.dylib');
  open.overrideFor(
      OperatingSystem.windows, '../../windows/Libraries/release/duckdb.dll');

  print("[root] OPEN - db");
  final db = await duckdb.open(':memory:');
  final con = await duckdb.connect(db);

  print("[root] CREATE TABLE");
  await con.execute("DROP TABLE IF EXISTS users");
  await con.execute(
      "CREATE TABLE users(name VARCHAR, age INTEGER, height DOUBLE, awesome BOOLEAN, bday DATE, time TIMESTAMP)");

  await Isolate.spawn(runExample, (db.transferable, 'background'));
  runExample((db.transferable, 'main'));

  printUsersTable("root", con);
  con.dispose();
  db.dispose();
}

void runExample(
    (TransferableDatabase transferableDatabase, String threadName) args) async {
  final (transferableDatabase, threadName) = args;

  // get the value from db.handle and create a new Pointer<void> from it.
  final con = await duckdb.connectWithTransferred(transferableDatabase);

  print("[$threadName] BEGIN TRANSACTION");
  await con.execute("BEGIN TRANSACTION");

  print("[$threadName] PREPARE STATEMENT");
  final epoch = DateTime.fromMicrosecondsSinceEpoch(0).toUtc();
  final statement =
      await con.prepare("INSERT INTO users VALUES(?, ?, ?, ?, ?, ?)");
  statement
      .bindParams(["macgyver-[$threadName]", 70, 1.85, true, Date(0), epoch]);
  await statement.execute();

  printUsersTable(threadName, con);

  print("[$threadName] COMMIT");
  await con.execute("COMMIT");

  con.dispose();
}
