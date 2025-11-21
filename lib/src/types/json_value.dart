import 'dart:convert';

class JsonValue {
  final Object? value;

  // If is valid is false, the value is the value which failed to decode from
  // json when being retrieved from the db.
  final bool isValid;

  JsonValue(this.value, {this.isValid = true});

  String encode() {
    return jsonEncode(value);
  }

  @override
  String toString() => encode();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JsonValue &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}
