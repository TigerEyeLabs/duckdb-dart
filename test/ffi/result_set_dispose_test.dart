@TestOn('vm')
library;

import 'dart:io';
import 'dart:isolate';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/src/ffi/impl/implementation.dart';
import 'package:test/test.dart';

void main() {
  late Database database;
  late Connection connection;

  setUp(() async {
    database = await duckdb.open(':memory:');
    connection = await duckdb.connect(database);
  });

  tearDown(() async {
    await connection.dispose();
    await database.dispose();
  });

  test('dispose after reading all rows is idempotent', () async {
    final result = await connection.query('SELECT i FROM range(5000) t(i)');
    expect(result.fetchAll(), hasLength(5000));
    await result.dispose();
    await result.dispose();
  });

  test('dispose after stopping a stream releases cached resources once',
      () async {
    final result = await connection.query('SELECT i FROM range(5000) t(i)')
        as ResultSetImpl;
    expect(
      await result.fetchAllStream().take(1).toList(),
      [
        [0],
      ],
    );
    final chunk = result.dataChunkByIndex(0);
    final type = result.logicalType(0);
    await result.dispose();
    await result.dispose();
    chunk.dispose();
    type.dispose();
  });

  test('dispose handles an unread result', () async {
    final result = await connection.query('SELECT 42');
    await result.dispose();
    await result.dispose();
  });

  test('dispose handles an empty result', () async {
    final result = await connection.query('SELECT 42 WHERE false');
    expect(result.fetchAll(), isEmpty);
    await result.dispose();
    await result.dispose();
  });

  test('disposed results do not accumulate native memory across isolates',
      () async {
    final packageConfig = await Isolate.packageConfig;
    final library = await Isolate.resolvePackageUri(
      Uri.parse('package:dart_duckdb/dart_duckdb.dart'),
    );
    final process = await Process.run(Platform.resolvedExecutable, [
      '--enable-asserts',
      if (packageConfig != null) '--packages=$packageConfig',
      library!
          .resolve('../test/ffi/fixtures/result_set_memory.dart')
          .toFilePath(),
    ]);
    expect(process.exitCode, 0, reason: process.stderr.toString());
    final growth = int.parse(process.stdout.toString().trim());
    expect(growth, lessThan(128 * 1024 * 1024));
  });
}
