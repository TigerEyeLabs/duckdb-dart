import 'dart:convert';
import 'dart:ffi';

import 'package:dart_duckdb/src/ffi/duckdb.g.dart';
import 'package:ffi/ffi.dart';

export 'dart:ffi';

export 'duckdb.g.dart';

class BindingsWithLibrary {
  final Bindings bindings;
  final DynamicLibrary library;

  BindingsWithLibrary(this.library) : bindings = Bindings(library);
}

extension Utf8Utils on Pointer<Char> {
  int get _length {
    final asBytes = cast<Uint8>();
    var length = 0;

    for (; asBytes[length] != 0; length++) {}
    return length;
  }

  String readString([int? length]) {
    final resolvedLength = length ??= _length;

    return utf8.decode(cast<Uint8>().asTypedList(resolvedLength));
  }
}

extension PointerUtils on Pointer<NativeType> {
  bool get isNullPointer => address == 0;
}

/// Extension method for converting a string encoded into a [List<int>] to a `Pointer<Utf8>`.
extension ListUtf8Pointer on List<int> {
  /// Creates a zero-terminated [Utf8] code-unit array from this List.
  /// Use Utf8Codec().encode to create this list from a string.
  ///
  /// If this [List] contains NULL characters, converting it back to a string
  /// using [Utf8Pointer.toDartString] will truncate the result if a length is
  /// not passed.
  ///
  /// Unpaired surrogate code points in this [String] will be encoded as
  /// replacement characters (U+FFFD, encoded as the bytes 0xEF 0xBF 0xBD) in
  /// the UTF-8 encoded result. See [Utf8Encoder] for details on encoding.
  Pointer<Utf8> listToNativeUtf8() {
    final result = malloc<Uint8>(length + 1);
    final nativeString = result.asTypedList(length + 1);
    nativeString.setAll(0, this);
    nativeString[length] = 0;
    return result.cast();
  }
}

const allocate = malloc;

extension FreePointerExtension on Pointer {
  void free() => allocate.free(this);
}
