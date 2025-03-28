export '../ffi/impl/database_type_native.dart' show DatabaseTypeFactory;

abstract interface class DatabaseType {
  int get value;
  bool get isNumeric;
  bool get isDate;
  bool get isText;
  Type? get dartType;
}
