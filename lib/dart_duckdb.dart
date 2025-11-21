export 'src/api/appender.dart';
export 'src/api/cancellation_token.dart';
export 'src/api/connection.dart';
export 'src/api/database.dart';
export 'src/api/database_type.dart';
export 'src/api/exception.dart';
export 'src/api/open.dart';
export 'src/api/prepared_statement.dart';
export 'src/api/result_set.dart';
export 'src/duckdb_base.dart' // Export the base implementation
    if (dart.library.io) 'src/ffi/duckdb_ffi.dart' // Override for Native platforms
    if (dart.library.js_interop) 'src/web/duckdb_web.dart'; // Override for Web platforms
export 'src/types/date.dart';
export 'src/types/decimal.dart';
export 'src/types/interval.dart';
export 'src/types/json_value.dart';
export 'src/types/protocol.dart';
