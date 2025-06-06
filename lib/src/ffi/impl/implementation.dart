import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_duckdb/src/api/appender.dart';
import 'package:dart_duckdb/src/api/cancellation_token.dart';
import 'package:dart_duckdb/src/api/column.dart';
import 'package:dart_duckdb/src/api/connection.dart';
import 'package:dart_duckdb/src/api/database.dart';
import 'package:dart_duckdb/src/api/database_type.dart';
import 'package:dart_duckdb/src/api/exception.dart';
import 'package:dart_duckdb/src/api/prepared_statement.dart';
import 'package:dart_duckdb/src/api/result_set.dart';
import 'package:dart_duckdb/src/ffi/duckdb.g.dart';
import 'package:dart_duckdb/src/ffi/duckdb_ffi.dart';
import 'package:dart_duckdb/src/ffi/impl/database_type_native.dart';
import 'package:dart_duckdb/src/ffi/impl/finalizer.dart';
import 'package:dart_duckdb/src/ffi/impl/utils.dart';
import 'package:dart_duckdb/src/ffi/impl/value/value_factory.dart';
import 'package:dart_duckdb/src/ffi/impl/vector/transformer_registry.dart';
import 'package:dart_duckdb/src/types/date.dart';
import 'package:dart_duckdb/src/types/decimal.dart';
import 'package:dart_duckdb/src/types/interval.dart';
import 'package:dart_duckdb/src/types/time.dart';
import 'package:dart_duckdb/src/types/time_with_offset.dart';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

part 'appender.dart';
part 'column.dart';
part 'connection.dart';
part 'data_chunk.dart';
part 'database.dart';
part 'connection_isolate.dart';
part 'database_operation_cancellation.dart';
part 'logical_type.dart';
part 'pending_result.dart';
part 'prepared_statement.dart';
part 'result_set.dart';
part 'value.dart';
part 'vector.dart';

final BigInt hugeIntMin = BigInt.from(-1) << 127;
final BigInt hugeIntMax = (BigInt.from(1) << 127) - BigInt.one;
final BigInt uHugeIntMax = (BigInt.from(1) << 128) - BigInt.one;
