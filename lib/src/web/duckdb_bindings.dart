import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:dart_duckdb/src/web/impl/js_utils.dart';

/// Inititialize DuckDB Wasm bindings
@JS('duckdbduckdbWasm')
external JSObject? get _duckdbduckdbWasm;

@JS('duckdbduckdbWasmReady')
external JSPromise<JSAny>? get _duckdbWasmReady;

DuckDBWasm get duckdbWasm => DuckDBWasm(_duckdbduckdbWasm!);

// Static version bindings that don't require any instance
@JS('duckdbduckdbWasm.PACKAGE_NAME')
external String get duckdbPackageName;

@JS('duckdbduckdbWasm.PACKAGE_VERSION')
external String get duckdbPackageVersion;

@JS('duckdbduckdbWasm.PACKAGE_VERSION_MAJOR')
external String get duckdbPackageVersionMajor;

@JS('duckdbduckdbWasm.PACKAGE_VERSION_MINOR')
external String get duckdbPackageVersionMinor;

@JS('duckdbduckdbWasm.PACKAGE_VERSION_PATCH')
external String get duckdbPackageVersionPatch;

// Convenience function for getting version
String getDuckDBVersion() => duckdbPackageVersion;

/// wait for DuckDB Wasm to be loaded
Future<void> waitForDuckdbWasmReady() async {
  await _duckdbWasmReady?.toDart;
}

const duckDBAccessMode = {
  'UNDEFINED': 0,
  'AUTOMATIC': 1,
  'READ_ONLY': 2,
  'READ_WRITE': 3,
};

extension type AsyncDuckDB._(JSObject _) implements JSObject {
  external factory AsyncDuckDB(JSObject obj);

  /// Initialize DuckDB instance
  external JSPromise<JSAny?> instantiate(
    String mainModule, [
    String? pthreadWorker,
  ]);

  /// Open a database with the specified configuration
  external JSPromise<JSAny?> open(DuckDBConfig config);

  /// Create a new database connection
  external JSPromise<Connection> connect();

  /// Register a file URL for DuckDB to access
  external JSPromise<JSAny?> registerFileURL(
    String name,
    String url,
    int protocol,
    bool directIO,
  );

  /// Register a file buffer
  external JSPromise<JSAny?> registerFileBuffer(
    String name,
    JSUint8Array buffer,
  );

  /// Register a file handle
  external JSPromise<JSAny?> registerFileHandle(
    String name,
    JSAny? handle,
    int protocol,
    bool directIO,
  );

  /// Copy file to specified path
  external JSPromise<JSAny?> copyFileToPath(String name, String out);

  /// Copy file to buffer
  external JSPromise<JSUint8Array> copyFileToBuffer(String name);
}

/// DuckDB configuration options
extension type DuckDBConfig._(JSObject _) implements JSObject {
  external factory DuckDBConfig({
    String? path,
    @JS('access_mode') int? accessMode,
    @JS('max_threads') int? maxThreads,
    @JS('use_threads') bool? useThreads,
    JSObject? options,
  });
}

extension type Connection._(JSObject _) implements JSObject {
  /// Run a query directly and return results
  external JSPromise<ArrowTable> query(String sql);

  /// Send a query asynchronously and return a stream reader
  external JSPromise<AsyncRecordBatchStreamReader> send(
    String text, [
    bool allowStreamResult,
  ]);

  /// Cancel a query that was sent earlier
  external JSPromise<JSBoolean> cancelSent();

  /// Start an asynchronous query
  external JSPromise<JSUint8Array?> startPendingQuery(
    String text,
    bool allowStreamResult,
  );

  /// Poll for results of pending query
  external JSPromise<JSUint8Array?> pollPendingQuery();

  /// Cancel ongoing query
  external JSPromise<JSBoolean> cancelPendingQuery();

  /// Get table names for a query
  external JSPromise<JSArray> getTableNames(String query);

  /// Prepare a SQL statement
  external JSPromise<PreparedStatement> prepare(String query);

  /// Close the connection
  external JSPromise<JSAny?> close();
}

extension type PreparedStatement._(JSObject _) implements JSObject {
  /// No variadic arguments in Dart -> JS, so we need to use optional JSAny params
  @JS('query')
  external JSPromise<ArrowTable> _queryJs([
    JSAny? arg0,
    JSAny? arg1,
    JSAny? arg2,
    JSAny? arg3,
    JSAny? arg4,
    JSAny? arg5,
    JSAny? arg6,
    JSAny? arg7,
    JSAny? arg8,
    JSAny? arg9,
  ]);

  /// Dart-friendly query method that accepts a List
  JSPromise<ArrowTable> query([List<JSAny?>? params]) {
    if (params == null || params.isEmpty) return _queryJs();
    return switch (params.length) {
      1 => _queryJs(params[0]),
      2 => _queryJs(params[0], params[1]),
      3 => _queryJs(params[0], params[1], params[2]),
      4 => _queryJs(params[0], params[1], params[2], params[3]),
      5 => _queryJs(params[0], params[1], params[2], params[3], params[4]),
      6 => _queryJs(
          params[0],
          params[1],
          params[2],
          params[3],
          params[4],
          params[5],
        ),
      7 => _queryJs(
          params[0],
          params[1],
          params[2],
          params[3],
          params[4],
          params[5],
          params[6],
        ),
      8 => _queryJs(
          params[0],
          params[1],
          params[2],
          params[3],
          params[4],
          params[5],
          params[6],
          params[7],
        ),
      9 => _queryJs(
          params[0],
          params[1],
          params[2],
          params[3],
          params[4],
          params[5],
          params[6],
          params[7],
          params[8],
        ),
      10 => _queryJs(
          params[0],
          params[1],
          params[2],
          params[3],
          params[4],
          params[5],
          params[6],
          params[7],
          params[8],
          params[9],
        ),
      _ => throw ArgumentError('Too many parameters: ${params.length}'),
    };
  }

  /// Close prepared statement
  external JSPromise<JSAny?> close();
}

extension type RecordBatch._(JSObject _) implements JSObject {
  /// Constructor to wrap JavaScript RecordBatch
  external factory RecordBatch(JSObject obj);

  /// The schema of the RecordBatch
  external Schema get schema;

  /// The underlying data
  external Data get data;

  /// Number of columns
  external int get numCols;

  /// Number of rows
  external int get numRows;

  /// Number of null rows
  external int get nullCount;

  /// Check if a row is valid at given index
  external JSBoolean isValid(int index);

  /// Get a row by position
  external JSAny get(int index);

  /// Convert to JavaScript array
  external JSArray toArray();
}

/// Data structure binding for Arrow's Data class
extension type Data._(JSObject _) implements JSObject {
  /// Constructor to wrap JSObject
  external factory Data(JSObject obj);

  /// The data type
  external DataType get type;

  /// Number of elements in the array
  external int get length;

  /// Starting index offset
  external int get offset;

  /// Stride of the type
  external int get stride;

  /// Child data arrays
  external JSArray get children;

  /// Dictionary for dictionary-encoded data
  external Vector? get dictionary;

  /// Values buffer - keep as JSObject to avoid conversion attempts
  external JSObject? get values;

  /// Type IDs buffer for union types
  external JSTypedArray? get typeIds;

  /// Validity (null) bitmap
  external JSUint8Array? get nullBitmap;

  /// Value offsets for variable-width types
  external JSTypedArray? get valueOffsets;

  /// Number of null values
  external int get nullCount;

  /// Get validity of value at index
  external JSBoolean getValid(int index);

  /// Set validity of value at index
  external JSBoolean setValid(int index, JSBoolean value);
}

/// Vector bindings for DuckDB's Vector class
extension type Vector(JSObject _) implements JSObject {
  /// The underlying data
  external JSArray<Data> get data;

  /// Length of the vector
  external int get length;

  /// Get value at index
  external JSAny? get(int index);

  external JSBoolean isValid(int index);

  /// Type metadata
  external DataType get type;

  /// Whether values can be null
  external bool get nullable;

  /// Number of null values
  external int get nullCount;
}

/// AsyncRecordBatchStreamReader bindings for Arrow's AsyncRecordBatchStreamReader
extension type AsyncRecordBatchStreamReader._(JSObject jsObject)
    implements JSObject {
  external factory AsyncRecordBatchStreamReader(JSObject obj);

  external Schema get schema;

  /// Open the stream reader
  external JSPromise<AsyncRecordBatchStreamReader> open([JSObject? options]);

  /// Read all batches from the stream
  external JSPromise<JSArray<RecordBatch>> readAll();
}

/// Arrow Table bindings
extension type ArrowTable._(JSObject _) implements JSObject {
  /// Constructor to create a new Arrow Table from record batches
  external factory ArrowTable(JSArray<RecordBatch> batches);

  /// The schema of the table
  external Schema get schema;

  /// The record batches containing the actual data
  external JSArray get batches;

  /// Convert to array representation
  external JSArray toArray();

  /// Get number of rows
  external int get numRows;

  /// Get number of columns
  external int get numCols;

  /// Select columns at specified indices
  external ArrowTable selectAt(JSArray columnIndices);
}

extension ArrowTableHelpers on ArrowTable {
  // Note: When working with JS interop extension types, use direct casting
  // (e.g., 'jsObj as Type') rather than construction (Type(jsObj))
  // because the JS objects already have the correct shape and just need
  // to be viewed through our Dart interface
  List<RecordBatch?> getBatchesList() {
    final jsArray = batches;
    final batchesList = List.generate(
      jsArray.compatLength,
      (index) {
        final item = jsArray.getProperty(index.toJS);
        return item as RecordBatch?;
      },
    );

    return batchesList;
  }
}

extension type IteratorResult<T extends JSAny?>(JSObject _)
    implements JSObject {
  external JSBoolean? get done;
  external T? get value;
}

extension type AsyncIterator<T extends JSAny?>(JSObject _) implements JSObject {
  external JSPromise<IteratorResult<T>> next();
}

/// DataType bindings
extension type DataType._(JSObject _) implements JSObject {
  external int get typeId;
  external bool get nullable;
}

extension DecimalDataTypeProperties on DataType {
  external int get scale;
  external int get precision;
}

extension FixedListDataTypeProperties on DataType {
  external int? get listSize;
}

extension StructDataTypeProperties on DataType {
  external JSArray<Field> get children;
}

/// Time units matching Arrow's TimeUnit enum
enum TimeUnit {
  second(0),
  millisecond(1),
  microsecond(2),
  nanosecond(3);

  final int value;
  const TimeUnit(this.value);

  static TimeUnit fromValue(int value) {
    return TimeUnit.values.firstWhere(
      (unit) => unit.value == value,
      orElse: () => throw ArgumentError('Invalid TimeUnit value: $value'),
    );
  }
}

extension TimeDataTypeProperties on DataType {
  external int get unit;
  TimeUnit get timeUnit => TimeUnit.fromValue(unit);
  external int get timezone;
}

/// Schema bindings matching Arrow's Schema class
extension type Schema._(JSObject _) implements JSObject {
  /// List of fields in the schema
  external JSArray get fields;

  /// Schema metadata
  external JSObject get metadata;

  /// Dictionary mappings
  external JSObject get dictionaries;

  /// Metadata version
  external int get metadataVersion;

  /// Create a new Schema
  external factory Schema(
    JSArray fields, [
    JSObject? metadata,
    JSObject? dictionaries,
    int? metadataVersion,
  ]);

  /// Get field names
  external JSArray get names;

  /// Create new Schema with only specified fields
  external Schema select(JSArray fieldNames);

  /// Create new Schema with only fields at specified indices
  external Schema selectAt(JSArray fieldIndices);

  /// Merge with another schema
  external Schema assign(Schema other);
}

/// Field bindings matching Arrow's Field class
extension type Field._(JSObject _) implements JSObject {
  /// Field name
  external String get name;

  /// Whether field can be null
  external bool get nullable;

  /// Field metadata
  external JSObject get metadata;

  /// Field type ID
  external int get typeId;

  /// Field data type
  external DataType get type;
}

/// Helper extensions for Schema
extension SchemaHelpers on Schema {
  /// Get fields as Dart List
  List<Field> getFieldsList() {
    return fields.toDart.cast<Field>().toList();
  }

  /// Get field names as Dart List
  List<String> getNamesList() {
    return names.toDart.cast<String>().toList();
  }

  List<int> getColumnTypes() {
    return getFieldsList().map((field) => field.typeId).toList();
  }
}

extension type ConsoleLogger._(JSObject _) implements JSObject {
  external factory ConsoleLogger();
}

extension type DuckDBWasm(JSObject _) implements JSObject {
  @JS('ConsoleLogger')
  external JSFunction get consoleLogger;
  @JS('VoidLogger')
  external JSFunction get voidLogger;
  @JS('AsyncDuckDB')
  external JSFunction get asyncDuckDB;
  external JSObject getJsDelivrBundles();
  external JSPromise<JSAny> selectBundle(JSAny bundles);
}

extension type DuckDBBundle(JSObject _obj) implements JSObject {
  external JSAny get mainModule;
  external JSAny get mainWorker;
  external JSAny? get pthreadWorker;
}

@JS('BigInt64Array')
extension type JSBigInt64Array._(JSObject _) implements JSObject {
  external factory JSBigInt64Array(JSAny source);
  external factory JSBigInt64Array.withLength(int length);

  external int get length;
  external JSAny operator [](int index);
}

/// Global Arrow library binding
@JS('apache-arrow')
external JSObject get arrow;

/// Arrow Table constructor - try to get it from DuckDB WASM first, then fallback to global
@JS('ArrowTable')
external JSFunction get arrowTable;
