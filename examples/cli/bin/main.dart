import 'dart:ffi';
import 'dart:isolate';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/open.dart';

void printUsersTable(String source, Connection con) {
  print("[$source] RUN QUERY");
  final result = con.query("SELECT * from users");

  result.fetchAll().forEach((item) {
    print("[$source] ${item}");
  });
}

void main(List<String> arguments) async {
  /// replace with your local installation of duckdb
  open.overrideFor(
      OperatingSystem.macOS,
      () =>
          DynamicLibrary.open('../../macos/Libraries/release/libduckdb.dylib'));
  open.overrideFor(OperatingSystem.windows,
      () => DynamicLibrary.open('../../windows/Libraries/release/duckdb.dll'));

  print("[root] OPEN - db");
  final db = duckdb.open(':memory:');

  final con = duckdb.connect(db);

  print("[root] CREATE TABLE");
  con.execute("DROP TABLE IF EXISTS users");
  con.execute(
      "CREATE TABLE users(name VARCHAR, age INTEGER, height DOUBLE, awesome BOOLEAN, bday DATE, time TIMESTAMP)");

  await Isolate.spawn(runExample, (db.transferrable, 'background'));
  runExample((db.transferrable, 'main'));

  printUsersTable("root", con);
  con.dispose();
  db.dispose();
}

void runExample(
    (TransferableDatabase transferableDatabase, String threadName) args) {
  final (transferableDatabase, threadName) = args;

  // get the value from db.handle and create a new Pointer<void> from it.
  final con = duckdb.connectWithTransferred(transferableDatabase);

  print("[$threadName] BEGIN TRANSACTION");
  con.execute("BEGIN TRANSACTION");

  print("[$threadName] PREPARE STATEMENT");
  final epoch = DateTime.fromMicrosecondsSinceEpoch(0).toUtc();
  final statement = con.prepare("INSERT INTO users VALUES(?, ?, ?, ?, ?, ?)");
  statement
      .bindParams(["macgyver-[$threadName]", 70, 1.85, true, Date(0), epoch]);
  statement.execute();

  printUsersTable(threadName, con);

  print("[$threadName] COMMIT");
  con.execute("COMMIT");

  con.dispose();
}
