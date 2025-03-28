import 'dart:ffi';
import 'dart:io';

import 'package:dart_duckdb/src/api/open.dart';
import 'package:meta/meta.dart';

/// Signature responsible for loading the dynamic DuckDB library.
typedef OpenLibraryLoader = DynamicLibrary Function();

/// Default open method for duckdb bundled in an application
DynamicLibrary _defaultOpen() {
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libduckdb.so');
  } else if (Platform.isIOS) {
    return DynamicLibrary.open('duckdb.framework/duckdb');
  } else if (Platform.isMacOS) {
    DynamicLibrary result;
    result = DynamicLibrary.process();

    if (_duckDbIsLoaded(result)) {
      return result;
    }
  } else if (Platform.isWindows) {
    return DynamicLibrary.open('duckdb.dll');
  } else if (Platform.isLinux) {
    // Will look in LD_LIBRARY_PATH
    final result = DynamicLibrary.open('libduckdb.so');
    if (_duckDbIsLoaded(result)) {
      return result;
    }
  }

  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}

bool _isTestEnvironment() {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return true;
  }

  var inTest = false;

  // Assert changes the value in test mode (debug mode)
  assert(() {
    inTest = true;
    return true;
  }());

  return inTest;
}

bool _duckDbIsLoaded(DynamicLibrary lib) =>
    lib.providesSymbol('duckdb_library_version');

/// Manages functions that define how to load the [DynamicLibrary] for DuckDB.
///
/// The default behavior will use `DynamicLibrary.open('libduckdb.so')` on
/// Linux and Android, `DynamicLibrary.open('libduckdb.dylib')` on iOS and
/// macOS and `DynamicLibrary.open('duckdb.dll')` on Windows.
///
/// The default behavior can be overridden for a specific OS by using
/// [overrideFor]. To override the behavior on all platforms, use
/// [overrideForAll].
class OpenDynamicLibrary extends OpenLibrary {
  final Map<OperatingSystem, OpenLibraryLoader> _overriddenPlatforms = {};

  OpenDynamicLibrary._();

  /// Returns the current [OperatingSystem] as read from the [Platform] getters.
  OperatingSystem? get os {
    if (Platform.isAndroid) return OperatingSystem.android;
    if (Platform.isIOS) return OperatingSystem.iOS;
    if (Platform.isLinux) return OperatingSystem.linux;
    if (Platform.isMacOS) return OperatingSystem.macOS;
    if (Platform.isWindows) return OperatingSystem.windows;
    return null;
  }

  /// Opens the [DynamicLibrary] from which `duckdb.dart` is going to
  /// [DynamicLibrary.lookup] duckdb's methods that will be used. This method is
  /// meant to be called by `duckdb.dart` only.
  DynamicLibrary openDuckDB() {
    /// If the process already provides has the symbol, we can use it directly.
    /// This is useful when we have loaded the library and are now on an isolate.
    final process = DynamicLibrary.process();
    if (process.providesSymbol('duckdb_open')) {
      return process;
    }

    /// If we are in a test environment, we will load the library from the package.
    if (_isTestEnvironment()) {
      final prefix = '${Directory.current.path}/../duckdb';

      if (_overriddenPlatforms[OperatingSystem.windows] == null) {
        _overriddenPlatforms[OperatingSystem.windows] =
            () => DynamicLibrary.open(
                  '$prefix/windows/Libraries/release/duckdb.dll',
                );
      }

      if (_overriddenPlatforms[OperatingSystem.macOS] == null) {
        _overriddenPlatforms[OperatingSystem.macOS] = () => DynamicLibrary.open(
              '$prefix/macos/Libraries/release/libduckdb.dylib',
            );
      }

      if (_overriddenPlatforms[OperatingSystem.linux] == null) {
        _overriddenPlatforms[OperatingSystem.linux] = () => DynamicLibrary.open(
              '$prefix/linux/Libraries/release/libduckdb.so',
            );
      }
    }

    try {
      final forPlatform = _overriddenPlatforms[os];
      if (forPlatform != null) {
        return forPlatform();
      }
    } catch (error) {
      // ignore
    }

    return _defaultOpen();
  }

  /// Makes `duckdb.dart` use the [open] function when running on the specified
  /// [os]. This can be used to override the loading behavior on some platforms.
  /// To override that behavior on all platforms, consider using
  /// [overrideForAll].
  /// This method must be called before opening any database.
  ///
  /// When using the asynchronous API over isolates, [open] __must be__ a top-
  /// level function or a static method.
  @override
  void overrideFor(OperatingSystem os, String path) {
    _overriddenPlatforms[os] = () => DynamicLibrary.open(path);
  }

  /// Clears all associated open helpers for all platforms.
  @visibleForTesting
  @override
  void reset() {
    _overriddenPlatforms.clear();
  }
}

/// The instance managing different approaches to load the [DynamicLibrary] for
/// duckdb when needed. See the documentation for [OpenDynamicLibrary] to learn
/// how the default opening behavior can be overridden.
final OpenLibrary open = OpenDynamicLibrary._();
