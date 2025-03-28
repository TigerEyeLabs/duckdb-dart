import 'dart:ffi';
import 'dart:io' show File;

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/open.dart';

/*
D describe c5;
┌─────────────┬───────────────┬─────────┬─────────┬─────────┬───────┐
│ column_name │  column_type  │  null   │   key   │ default │ extra │
│   varchar   │    varchar    │ varchar │ varchar │ varchar │ int32 │
├─────────────┼───────────────┼─────────┼─────────┼─────────┼───────┤
│ ts          │ TIMESTAMP     │ YES     │         │         │       │
│ x           │ BIGINT        │ YES     │         │         │       │
│ y           │ BIGINT        │ YES     │         │         │       │
│ z           │ DECIMAL(21,1) │ YES     │         │         │       │
│ text_x      │ VARCHAR       │ YES     │         │         │       │
└─────────────┴───────────────┴─────────┴─────────┴─────────┴───────┘
*/

final wideSql = '''
with t0 as (
  select unnest(range(?::bigint)) as x
), t1 as (
  select x,
  base64(
    md5(x::varchar)::blob||md5(x::varchar)::blob||md5(x::varchar)::blob||md5(x::varchar)::blob||md5(x::varchar)::blob||
    md5(x::varchar)::blob||md5(x::varchar)::blob||md5(x::varchar)::blob||md5(x::varchar)::blob||md5(x::varchar)::blob||
    md5(x::varchar)::blob||md5(x::varchar)::blob||md5(x::varchar)::blob||md5(x::varchar)::blob||md5(x::varchar)::blob||
    md5(x::varchar)::blob||md5(x::varchar)::blob||md5(x::varchar)::blob||md5(x::varchar)::blob||md5(x::varchar)::blob
  ) as xtext
  from t0
)
  select
    x*1 as xint1,
    x*2 as xint2,
    x*3 as xint3,
    x*4 as xint4,
    x*5 as xint5,
    x*6 as xint6,
    x*7 as xint7,
    x*8 as xint8,
    x*1.1::double as xdouble1,
    x*2.2::double as xdouble2,
    x*3.3::double as xdouble3,
    x*4.4::double as xdouble4,
    x*5.5::double as xdouble5,
    x*6.6::double as xdouble6,
    x*7.7::double as xdouble7,
    x*8.8::double as xdouble8,
    x*1.1::double as ydouble1,
    x*2.2::double as ydouble2,
    x*3.3::double as ydouble3,
    x*4.4::double as ydouble4,
    x*5.5::double as ydouble5,
    x*6.6::double as ydouble6,
    x*7.7::double as ydouble7,
    x*8.8::double as ydouble8,
    xtext as xtext1,
    xtext as xtext2,
    xtext as xtext3,
    xtext as xtext4,
    xtext as xtext5,
    xtext as xtext6,
    xtext as xtext7,
    xtext as xtext8,
    length(xtext)*8 as xlen
  from  t1
''';

Future<void> runSample(Connection con) async {
  var stopwatch = Stopwatch();
  stopwatch.start();
  final PreparedStatement statement =
      await con.prepare("select ts,x,y,z::double,text_x from c5 limit ?");
  statement.bindParams([10]);
  final List<List> rows = (await statement.execute()).fetchAll();
  stopwatch.stop();
  print(rows);
  var elapsedMicroseconds = stopwatch.elapsedMicroseconds;
  print('Elapsed time in microseconds: $elapsedMicroseconds');
}

Future<void> runNoRead(Connection con) async {
  final PreparedStatement statement =
      await con.prepare("select ts,x,y,z::double,text_x from c5");
  for (var i = 0; i < 5; i++) {
    var t0 = DateTime.now();
    await statement.execute();
    var t1 = DateTime.now();
    var elapsed = t1.difference(t0).inMicroseconds / 1000000.0;
    print('no_read,dart,$i,$elapsed');
  }
}

Future<void> runNarrowC5FetchOne(Connection con) async {
  final PreparedStatement statement =
      await con.prepare("select ts,x,y,z::double,text_x from c5");
  for (var i = 0; i < 5; i++) {
    var t0 = DateTime.now();
    List? row = (await statement.execute()).fetchOne();
    var t1 = DateTime.now();
    var elapsed = t1.difference(t0).inMicroseconds / 1000000.0;
    print('narrow_c5_fetchone,dart,$i,$elapsed');
  }
}

Future<void> runNarrowC5NoFetch(Connection con) async {
  final PreparedStatement statement =
      await con.prepare("select ts,x,y,z::double,text_x from c5 limit ?");
  List<int> counts = [1, 10, 100, 1000, 10000, 100000];
  for (var count in counts) {
    var t0 = DateTime.now();
    statement.bindParams([count]);
    await statement.execute();
    var t1 = DateTime.now();
    var elapsed = t1.difference(t0).inMicroseconds / 1000000.0;
    print('narrow_c5_nofetch,dart,$count,$elapsed');
  }
}

Future<void> runNarrowC5FetchAll(Connection con) async {
  final PreparedStatement statement =
      await con.prepare("select ts,x,y,z::double,text_x from c5 limit ?");
  List<int> counts = [1, 10, 100, 1000, 10000, 100000];
  for (var count in counts) {
    var t0 = DateTime.now();
    statement.bindParams([count]);
    final List<List> rows = (await statement.execute()).fetchAll();
    var t1 = DateTime.now();
    var elapsed = t1.difference(t0).inMicroseconds / 1000000.0;
    print('narrow_c5_fetchall,dart,$count,$elapsed');
  }
}

Future<void> runWideFetchAll(Connection con) async {
  final PreparedStatement statement = await con.prepare(wideSql);
  List<int> counts = [1, 10, 100, 1000, 10000, 100000, 1000000];
  for (var count in counts) {
    var t0 = DateTime.now();
    statement.bindParams([count]);
    final List<List> rows = (await statement.execute()).fetchAll();
    var t1 = DateTime.now();
    var elapsed = t1.difference(t0).inMicroseconds / 1000000.0;
    assert(rows.length == count);
    print('wide_fetchall,dart,$count,$elapsed');
  }
}

Future<void> runtests(Connection con) async {
  await runNoRead(con);
  await runNarrowC5FetchOne(con);
  await runNarrowC5NoFetch(con);
  await runNarrowC5FetchAll(con);
  await runWideFetchAll(con);
}

void main(List<String> arguments) async {
  // Delete existing database file if it exists
  var file = File('../perfdata.ddb');
  if (file.existsSync()) {
    file.deleteSync();
  }

  // Open DuckDB
  open.overrideFor(
      OperatingSystem.macOS, '../../macos/Libraries/release/libduckdb.dylib');

  // Create and connect to database
  final db = await duckdb.open(':memory:');
  final con = await duckdb.connect(db);

  // Generate test data
  await con.execute('''
    CREATE TABLE c5 AS
    WITH RECURSIVE t(ts, x, y, z, text_x) AS (
      SELECT
        timestamp '2000-01-01 00:00:00' + interval (random() * 1000000) minute,
        (random() * 1000000)::bigint,
        (random() * 1000000)::bigint,
        (random() * 1000000)::decimal(21,1),
        repeat(chr((random() * 26 + 65)::int), (random() * 100)::int)
      FROM range(1000000)
    )
    SELECT * FROM t;
  ''');

  // Run the performance tests
  await runtests(con);
}
