part of 'implementation.dart';

final maxValue = BigInt.from(-1 >>> 1);
final minValue = BigInt.from(maxValue.toInt() + 1);

class ResultSetImpl extends ResultSet {
  final bindings.ArrowTable _result;
  final Set<int>? _jsonColumnIndices;

  ResultSetImpl(
    bindings.ArrowTable result, {
    Set<int>? jsonColumnIndices,
  })  : _result = result,
        _jsonColumnIndices = jsonColumnIndices;

  @override
  Column operator [](int index) {
    if (index < 0 || index >= columnCount) {
      throw RangeError('Column index out of range: $index');
    }

    final jsArray = JSArray.withLength(1);
    jsArray.setProperty(0.toJS, (index as Object?)?.jsifyValueStrict());

    // Create a new ArrowTable with only the selected column
    final selectedResult = _result.selectAt(jsArray);

    return ColumnImpl(
      ResultSetImpl(selectedResult),
      0,
    );
  }

  @override
  int get columnCount => _result.numCols;

  @override
  DatabaseType columnDataType(int columnIndex) {
    final fields = _result.schema.getFieldsList();
    if (columnIndex < 0 || columnIndex >= fields.length) {
      throw RangeError('Column index out of range: $columnIndex');
    }
    return DatabaseTypeWeb.fromValue(fields[columnIndex].typeId);
  }

  /// Check if a column is a JSON type based on type information from DESCRIBE
  bool _isJsonColumn(int columnIndex) {
    return _jsonColumnIndices?.contains(columnIndex) ?? false;
  }

  @override
  List<String> get columnNames => _result.schema.getNamesList();

  @override
  List<int> get columnTypes => _result.schema.getColumnTypes();

  @override
  Future<void> dispose() async {}

  Object? dartifyValueStrict(JSAny? value, {DatabaseTypeWeb? type}) {
    if (value == null) {
      return null;
    } else if (value.isA<JSString>()) {
      return (value as JSString).toDart;
    } else if (value.isA<JSNumber>()) {
      if (type == DatabaseTypeWeb.date) {
        return Date(
          (value as JSNumber).toDartNum.toInt() ~/ Duration.millisecondsPerDay,
        );
      } else if (type == DatabaseTypeWeb.timestamp) {
        return DateTime.fromMillisecondsSinceEpoch(
          (value as JSNumber).toDartNum.toInt(),
          isUtc: true,
        );
      } else if (type == DatabaseTypeWeb.date) {
        return DateTime.fromMillisecondsSinceEpoch(
          (value as JSNumber).toDartNum.toInt() * Duration.millisecondsPerDay,
          isUtc: true,
        );
      } else if (type == DatabaseTypeWeb.time) {
        return Time.fromMicrosecondsSinceEpoch(
          BigInt.parse(value.toString()).toInt(),
        );
      }
      return (value as JSNumber).toDartNum;
    } else if (value.isA<JSBigInt>()) {
      final bigInt = BigInt.parse(value.toString());
      if (type == DatabaseTypeWeb.integer) {
        return bigInt.toInt();
      } else if (type == DatabaseTypeWeb.time) {
        return Time.fromMicrosecondsSinceEpoch(
          bigInt.toInt(),
        );
      }
      return bigInt;
    } else if (value.isA<JSBoolean>()) {
      return (value as JSBoolean).toDart;
    } else if (value.isA<JSUint8Array>()) {
      return (value as JSUint8Array).toDart;
    } else if (value.isA<JSArray>()) {
      final list = List.generate(
        (value as JSArray).compatLength,
        (index) =>
            dartifyValueStrict(value.getProperty(index.toJS), type: type),
      );
      return list;
    } else if (value.isA<JSObject>() &&
        (value as JSObject).hasProperty('data'.toJS).toDart &&
        value.hasProperty('length'.toJS).toDart) {
      final vector = bindings.Vector(value);
      return List<Object?>.generate(vector.length, (i) {
        if (!vector.isValid(i).toDart) return null;
        final value = vector.get(i)!;
        return dartifyValueStrict(
          value,
          type: DatabaseTypeWeb.fromValue(vector.type.typeId),
        );
      });
    }

    try {
      final jsObject = value as JSObject;
      final object = <String, Object?>{};
      final keys = jsObjectKeys(jsObject).toDart;
      for (final key in keys) {
        object[(key! as JSString).toDart] =
            dartifyValueStrict(jsObject.getProperty(key));
      }
      return object;
    } catch (e) {
      throw UnsupportedError(
        'Unsupported value: $value (type: ${value.runtimeType}) ($e)',
      );
    }
  }

  Object? decodeValue(bindings.Data data, int offset) {
    final type = DatabaseTypeWeb.fromValue(data.type.typeId);

    // Handle nulls
    if (data.nullCount > 0) {
      final nullBitmap = data.nullBitmap;
      if (nullBitmap != null) {
        final byteOffset = offset ~/ 8;
        final bitOffset = offset % 8;
        final byte = nullBitmap.toDart[byteOffset];
        if ((byte & (1 << bitOffset)) == 0) {
          return null;
        }
      }
    }

    final values = data.values;

    if (data.values == null &&
        type != DatabaseTypeWeb.list &&
        type != DatabaseTypeWeb.struct &&
        type != DatabaseTypeWeb.fixedSizeList &&
        type != DatabaseTypeWeb.union &&
        type != DatabaseTypeWeb.map) {
      return null;
    }

    switch (type) {
      case DatabaseTypeWeb.none:
      case DatabaseTypeWeb.null_:
        return null;

      // Integer types
      case DatabaseTypeWeb.integer:
        final numValue = values!.getProperty(offset.toJS)!;
        return BigInt.parse(numValue.toString()).toInt();
      case DatabaseTypeWeb.int8:
      case DatabaseTypeWeb.int16:
      case DatabaseTypeWeb.int32:
      case DatabaseTypeWeb.uint8:
      case DatabaseTypeWeb.uint16:
      case DatabaseTypeWeb.uint32:
        final numValue = values!.getProperty(offset.toJS)!;
        return (numValue as JSNumber).toDartNum.toInt();

      case DatabaseTypeWeb.int64:
      case DatabaseTypeWeb.uint64:
        final numValue = values!.getProperty(offset.toJS)!;
        if (numValue.isA<JSBigInt>()) {
          return BigInt.parse(numValue.toString());
        }
        return (numValue as JSNumber).toDartNum.toInt();

      // Float types
      case DatabaseTypeWeb.float:
      case DatabaseTypeWeb.float16:
      case DatabaseTypeWeb.float32:
      case DatabaseTypeWeb.float64:
        return (values!.getProperty(offset.toJS)! as JSNumber).toDartNum;

      // Binary types
      case DatabaseTypeWeb.binary:
      case DatabaseTypeWeb.fixedSizeBinary:
      case DatabaseTypeWeb.largeBinary:
        final binOffsets = data.valueOffsets;
        final jsValues = values! as JSUint8Array;
        final start = binOffsets != null
            ? (binOffsets.getProperty(offset.toJS)! as JSNumber)
                .toDartNum
                .toInt()
            : offset;
        final end = binOffsets != null
            ? (binOffsets.getProperty((offset + 1).toJS)! as JSNumber)
                .toDartNum
                .toInt()
            : offset + 1;

        // Convert to Uint8List and use sublist
        final uint8List = jsValues.toDart;
        return uint8List.sublist(start, end);

      // String types
      case DatabaseTypeWeb.utf8:
      case DatabaseTypeWeb.largeUtf8:
        final strOffsets = data.valueOffsets!;
        final strStart = (strOffsets.getProperty(offset.toJS)! as JSNumber)
            .toDartNum
            .toInt();
        final strEnd = (strOffsets.getProperty((offset + 1).toJS)! as JSNumber)
            .toDartNum
            .toInt();
        final jsValues = values! as JSUint8Array;
        final uint8List = jsValues.toDart;
        return utf8.decode(uint8List.sublist(strStart, strEnd));

      case DatabaseTypeWeb.boolean:
        final valuesArray = values! as JSUint8Array;
        final byteIndex = offset ~/ 8;
        final bitIndex = offset % 8;
        final byte = valuesArray.toDart[byteIndex];
        final bitValue = (byte >> bitIndex) & 1;
        return bitValue != 0;

      case DatabaseTypeWeb.decimal:
        final scale = data.type.scale;
        const stride = 4; // 128 bits = 4 x 32 bits
        final base = offset * stride;
        final valuesArray = (values! as JSUint32Array).toDart;

        // Check if the number is negative by looking at the most significant bit
        // of the highest 32-bit chunk
        final isNegative = (valuesArray[base + 3] & 0x80000000) != 0;

        if (isNegative) {
          // For negative numbers, we need to:
          // 1. Flip all bits (XOR with all 1's)
          // 2. Add 1 (two's complement representation)
          // 3. Handle carry bits through all 4 32-bit chunks
          // 4. Finally negate the result

          var carry = BigInt.one; // Starting carry for two's complement

          // Process least significant 32 bits
          var lowBits = BigInt.from(valuesArray[base] ^ 0xFFFFFFFF) + carry;
          carry = lowBits >> 32; // Carry over to next chunk
          lowBits &= BigInt.from(0xFFFFFFFF); // Keep only lower 32 bits

          // Process next 32 bits
          var highLowBits =
              BigInt.from(valuesArray[base + 1] ^ 0xFFFFFFFF) + carry;
          carry = highLowBits >> 32;
          highLowBits &= BigInt.from(0xFFFFFFFF);

          // Process next 32 bits
          var lowHighBits =
              BigInt.from(valuesArray[base + 2] ^ 0xFFFFFFFF) + carry;
          carry = lowHighBits >> 32;
          lowHighBits &= BigInt.from(0xFFFFFFFF);

          // Process most significant 32 bits
          var highHighBits =
              BigInt.from(valuesArray[base + 3] ^ 0xFFFFFFFF) + carry;
          highHighBits &= BigInt.from(0xFFFFFFFF);

          // Combine all parts into final 128-bit value
          // Shifting by 32/64/96 to position each chunk correctly
          final combinedValue = -((highHighBits << 96) +
              (lowHighBits << 64) +
              (highLowBits << 32) +
              lowBits);

          return Decimal(combinedValue, scale);
        } else {
          // For positive numbers, simply combine the 4 32-bit chunks
          final lowBits = BigInt.from(valuesArray[base]) +
              (BigInt.from(valuesArray[base + 1]) << 32);
          final highBits = BigInt.from(valuesArray[base + 2]) +
              (BigInt.from(valuesArray[base + 3]) << 32);
          final combinedValue = lowBits + (highBits << 64);

          return Decimal(combinedValue, scale);
        }

      // Date types
      case DatabaseTypeWeb.date:
      case DatabaseTypeWeb.dateDay:
        final epochMs =
            (values!.getProperty(offset.toJS)! as JSNumber).toDartNum *
                24 *
                60 *
                60 *
                1000;
        return Date.fromDateTime(
          DateTime.fromMillisecondsSinceEpoch(
            epochMs.toInt(),
            isUtc: true,
          ),
        );
      case DatabaseTypeWeb.dateMillisecond:
        final epochMs =
            (values!.getProperty(offset.toJS)! as JSNumber).toDartNum;
        return Date.fromDateTime(
          DateTime.fromMillisecondsSinceEpoch(
            epochMs.toInt(),
            isUtc: true,
          ),
        );

      // Time types
      case DatabaseTypeWeb.time:
      case DatabaseTypeWeb.timeSecond:
        final microseconds = (values! as bindings.JSBigInt64Array)[offset];
        final microsecondsNum = BigInt.parse(microseconds.toString()).toInt();
        return Time.fromMicrosecondsSinceEpoch(microsecondsNum);

      case DatabaseTypeWeb.timeMillisecond:
        final milliseconds = (values! as bindings.JSBigInt64Array)[offset];
        final millisecondsNum = BigInt.parse(milliseconds.toString()).toInt();
        return Time.fromMicrosecondsSinceEpoch(millisecondsNum * 1000);

      case DatabaseTypeWeb.timeMicrosecond:
        final microseconds = (values! as bindings.JSBigInt64Array)[offset];
        final microsecondsNum = BigInt.parse(microseconds.toString()).toInt();
        return Time.fromMicrosecondsSinceEpoch(microsecondsNum);

      case DatabaseTypeWeb.timeNanosecond:
        final nanoseconds = (values! as bindings.JSBigInt64Array)[offset];
        final nanosecondsNum = BigInt.parse(nanoseconds.toString()).toInt();
        return Time.fromMicrosecondsSinceEpoch(nanosecondsNum ~/ 1000);

      // Timestamp types
      case DatabaseTypeWeb.timestamp:
      case DatabaseTypeWeb.timestampSecond:
      case DatabaseTypeWeb.timestampMillisecond:
      case DatabaseTypeWeb.timestampMicrosecond:
      case DatabaseTypeWeb.timestampNanosecond:
        final value = (values! as bindings.JSBigInt64Array)[offset];
        final bigIntValue = BigInt.parse(value.toString());
        final unit = bindings.TimeUnit.fromValue(data.type.unit);

        // Calculate milliseconds and microseconds separately
        final timestampMs = switch (unit) {
          bindings.TimeUnit.second => bigIntValue * BigInt.from(1000),
          bindings.TimeUnit.millisecond => bigIntValue,
          bindings.TimeUnit.microsecond => bigIntValue ~/ BigInt.from(1000),
          bindings.TimeUnit.nanosecond => bigIntValue ~/ BigInt.from(1000000),
        };

        final microseconds = switch (unit) {
          bindings.TimeUnit.microsecond => bigIntValue % BigInt.from(1000),
          bindings.TimeUnit.nanosecond =>
            (bigIntValue ~/ BigInt.from(1000)) % BigInt.from(1000),
          _ => BigInt.zero,
        };

        final datetime = DateTime.fromMillisecondsSinceEpoch(
          timestampMs.toInt(),
          isUtc: true,
        );

        // Add microseconds if present
        return microseconds > BigInt.zero
            ? datetime.add(Duration(microseconds: microseconds.toInt()))
            : datetime;

      // Interval types
      case DatabaseTypeWeb.interval:
      case DatabaseTypeWeb.intervalDayTime:
      case DatabaseTypeWeb.intervalYearMonth:
        const stride = 4;
        final base = offset * stride;
        final months =
            (values!.getProperty(base.toJS)! as JSNumber).toDartNum.toInt();
        final days = (values.getProperty((base + 1).toJS)! as JSNumber)
            .toDartNum
            .toInt();
        final nanosLow = (values.getProperty((base + 2).toJS)! as JSNumber)
            .toDartNum
            .toInt();
        final nanosHigh = (values.getProperty((base + 3).toJS)! as JSNumber)
            .toDartNum
            .toInt();
        // Convert to unsigned 32-bit integer by masking
        final unsignedNanosLow = nanosLow & 0xFFFFFFFF;
        final nanoseconds =
            ((BigInt.from(nanosHigh) << 32) + BigInt.from(unsignedNanosLow))
                .toInt();
        return Interval(
          months: months,
          days: days,
          microseconds: nanoseconds ~/ 1000,
        );

      // List types
      case DatabaseTypeWeb.list:
      case DatabaseTypeWeb.fixedSizeList:
        if (data.children.toDart.isEmpty) {
          return null;
        }
        final childColumn = data.children.toDart[0]! as bindings.Data;
        final listSize = type == DatabaseTypeWeb.fixedSizeList
            ? data.type.listSize!.toJS.toDartInt
            : ((data.valueOffsets!.getProperty((offset + 1).toString().toJS)!
                        as JSNumber)
                    .toDartNum
                    .toInt() -
                (data.valueOffsets!.getProperty(offset.toString().toJS)!
                        as JSNumber)
                    .toDartNum
                    .toInt());

        final start = type == DatabaseTypeWeb.fixedSizeList
            ? offset * listSize
            : (data.valueOffsets!.getProperty(offset.toJS)! as JSNumber)
                .toDartNum
                .toInt();
        final end = type == DatabaseTypeWeb.fixedSizeList
            ? (offset + 1) * listSize
            : (data.valueOffsets!.getProperty((offset + 1).toJS)! as JSNumber)
                .toDartNum
                .toInt();

        return List.generate(
          end - start,
          (i) => decodeValue(childColumn, start + i),
        );

      // Struct type
      case DatabaseTypeWeb.struct:
        final result = <String, Object?>{};
        final children = data.children.toDart.cast<bindings.Data>();
        final fieldNames = data.type.children;

        for (var i = 0; i < children.length; i++) {
          final fieldName = (fieldNames.getProperty(i.toJS)! as JSObject)
              .getProperty('name'.toJS)! as JSString;
          result[fieldName.toDart] = decodeValue(children[i], offset);
        }
        return result;

      case DatabaseTypeWeb.union:
        if (data.children.toDart.isEmpty) return null;

        // Get type ID for this row from typeIds Int8Array
        final typeIds = data.typeIds! as JSInt8Array;
        final typeId = typeIds.toDart[offset];

        // Get corresponding child column and decode using current offset
        final child = data.children.toDart[typeId]! as bindings.Data;

        return decodeValue(child, offset);

      // Map type
      case DatabaseTypeWeb.map:
        if (data.children.toDart.isEmpty) {
          return null;
        }
        final childColumn = data.children.toDart[0]! as bindings.Data;
        final mapOffsets = data.valueOffsets!;
        final start = (mapOffsets.getProperty(offset.toJS)! as JSNumber)
            .toDartNum
            .toInt();
        final end = (mapOffsets.getProperty((offset + 1).toJS)! as JSNumber)
            .toDartNum
            .toInt();

        final result = <dynamic, Object?>{};
        for (var i = start; i < end; i++) {
          final entry = decodeValue(childColumn, i) as Map?;

          if (entry != null) {
            result[entry['key']] = entry['value'];
          }
        }
        return result;

      // Dictionary type
      case DatabaseTypeWeb.dictionary:
        final indices = (values! as JSUint8Array).toDart[offset];

        // Get the Data object from the Vector's data array
        final dictData = data.dictionary!.data.toDart[0];
        return decodeValue(dictData, indices);

      // Duration types
      case DatabaseTypeWeb.duration:
      case DatabaseTypeWeb.durationSecond:
      case DatabaseTypeWeb.durationMillisecond:
      case DatabaseTypeWeb.durationMicrosecond:
      case DatabaseTypeWeb.durationNanosecond:
        final value = values!.getProperty(offset.toJS)!;
        if (value.isA<JSBigInt>()) {
          return BigInt.parse(value.toString());
        }
        return (value as JSNumber).toDartNum;

      default:
        return null;
    }
  }

  List<List<Object?>> toDartArray() {
    final rows = <List<Object?>>[];
    final batches = _result.getBatchesList();

    for (final batch in batches) {
      if (null == batch) continue;
      final batchData = batch.data.children.toDart;
      final schemaColumnCount = _result.schema.getFieldsList().length;

      for (var rowIndex = 0; rowIndex < batch.numRows; rowIndex++) {
        final row = List<Object?>.filled(schemaColumnCount, null);
        for (var colIndex = 0; colIndex < schemaColumnCount; colIndex++) {
          var value = decodeValue(
            batchData[colIndex]! as bindings.Data,
            rowIndex,
          );

          // Parse JSON strings for columns marked as JSON type via Arrow metadata
          if (value is String && _isJsonColumn(colIndex)) {
            try {
              value = JsonValue(jsonDecode(value));
            } catch (_) {
              // If JSON parsing fails, keep as string
              value = JsonValue(value, isValid: false);
            }
          }

          row[colIndex] = value;
        }
        rows.add(row);
      }
    }

    return rows;
  }

  @override
  List<List<Object?>> fetchAll({int? batchSize}) {
    return toDartArray();
  }

  @override
  Stream<List<Object?>> fetchAllStream({int? batchSize}) async* {
    final allRows = fetchAll(batchSize: batchSize);
    for (final row in allRows) {
      yield row;
    }
  }

  @override
  List<Object?>? fetchOne() {
    final array = toDartArray();
    return array.isEmpty ? null : array.first;
  }

  @override
  dynamic get handle => _result;

  @override
  int get rowCount => _result.numRows;
}
