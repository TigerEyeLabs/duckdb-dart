export 'src/open_base.dart'
    if (dart.library.io) 'package:dart_duckdb/src/ffi/load_library.dart'
    if (dart.library.js_interop) 'package:dart_duckdb/src/web/load_library.dart';
