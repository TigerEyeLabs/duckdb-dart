import 'dart:io';
import 'dart:isolate';

import 'package:dart_duckdb/dart_duckdb.dart';

Future<void> _readAndDispose() async {
  final database = await duckdb.open(':memory:');
  final connection = await duckdb.connect(database);
  ResultSet? result;
  try {
    result = await connection.query(
      'SELECT i, repeat(md5(i::VARCHAR), 256) AS payload FROM range(2048) t(i)',
    );
    await result.fetchAllStream().drain<void>();
  } finally {
    await result?.dispose();
    await connection.dispose();
    await database.dispose();
  }
}

Future<void> main() async {
  for (var i = 0; i < 4; i++) {
    await Isolate.run(_readAndDispose);
  }
  final before = ProcessInfo.currentRss;
  for (var i = 0; i < 20; i++) {
    await Isolate.run(_readAndDispose);
  }
  stdout.writeln(ProcessInfo.currentRss - before);
}
