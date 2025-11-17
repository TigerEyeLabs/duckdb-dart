import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/src/web/duckdb_bindings.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart';

class Bindings {
  final Worker worker;
  final dynamic logger;
  final DuckDBBundle bundle;
  final String workerUrl;

  static final _urlFinalizer = Finalizer<String>((url) {
    URL.revokeObjectURL(url);
  });

  Bindings(this.worker, this.logger, this.bundle, this.workerUrl) {
    _urlFinalizer.attach(this, workerUrl, detach: this);
  }
}

/// Implementation of [DuckDBLoaderInterface] for web platforms using Wasm.
class OpenWasmLibrary extends OpenLibrary {
  factory OpenWasmLibrary() {
    return _instance;
  }
  OpenWasmLibrary._();

  Bindings? _cachedBindings;

  static final OpenWasmLibrary _instance = OpenWasmLibrary._();

  Future<Bindings> initializeDuckDB() async {
    if (_cachedBindings != null) {
      return _cachedBindings!;
    }

    await waitForDuckdbWasmReady();
    final jsDelivrBundles = duckdbWasm.getJsDelivrBundles();
    final jsBundle = await duckdbWasm.selectBundle(jsDelivrBundles).toDart;
    final bundle = DuckDBBundle(jsBundle as JSObject);

    final log = Logger('duckdb');
    log.severe('duckdb-wasm loaded ${jsDelivrBundles.dartify()} bundles');

    // Muting the logs via [VoidLogger], to enable them use [ConsoleLogger].
    final logger = duckdbWasm.voidLogger.callAsConstructor();

    final workerScript = 'importScripts("${bundle.mainWorker}");';
    final jsArray = [workerScript.toJS].toJS;
    final blobOptions = BlobPropertyBag(type: 'text/javascript');
    final blob = Blob(jsArray, blobOptions);
    final workerUrl = URL.createObjectURL(blob);

    final worker = Worker(workerUrl.toJS);

    _cachedBindings = Bindings(worker, logger, bundle, workerUrl);
    return _cachedBindings!;
  }

  @override
  void overrideFor(OperatingSystem os, String path) {
    // No-op for Wasm implementation
  }

  @override
  void reset() {
    // No-op for Wasm implementation
  }
}

/// The instance managing different approaches to load the library for
/// duckdb when needed.
final OpenLibrary open = OpenWasmLibrary._();
