export '../ffi/impl/database_type_native.dart'
    if (dart.library.js_interop) '../web/impl/database_type_web.dart'
    show DatabaseTypeFactory, DatabaseTypeNative;

abstract interface class DatabaseType {
  int get value;
  bool get isNumeric;
  bool get isDate;
  bool get isText;
  Type? get dartType;
}
