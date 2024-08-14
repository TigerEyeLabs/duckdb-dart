import 'dart:math';

/// A number that can be exactly written with a finite number of digits in the
/// decimal system.
class Decimal implements Comparable<Decimal> {
  static final Decimal zero = Decimal(BigInt.zero);

  static final BigInt _bigInt10 = BigInt.from(10);

  late BigInt _number;
  BigInt get number => _number;
  late int _scale;
  int get scale => _scale;

  /// Create a new [Decimal] from a [BigInt] and a [scale] decimal place.
  Decimal(this._number, [this._scale = 0]) {
    if (_number == BigInt.zero) {
      _scale = 0;
      return;
    }

    // remove all trailing zeros, and adjust the scale, if needed.
    while (_number != BigInt.zero && _number % _bigInt10 == BigInt.zero) {
      _number = _number ~/ _bigInt10;
      _scale--;
    }
  }

  static const _dot = 0x2e; // '.'
  static const _zero = 0x30; // '0'
  static const _minus = 0x2d; // '-'
  static const _e = 0x65; // 'e'

  /// Parses [str] as a decimal literal and returns its value as [Decimal].
  /// A number which can be expressed as a decimal number or in scientific notation, both with an optional sign.
  /// The numbers could look like this: 123, +123, -123, 123.456, -123.456, +123.456, 1.23e3, -1.23e3, 1.23e-3, or +1.23e-3.
  ///
  /// inspired by dart sdk's native double.tryParse, note for javascript double parsing dart uses regular expressions.
  factory Decimal.parse(String str) {
    assert(str.isNotEmpty);
    var start = 0;
    final end = str.length;
    var exponent = 0;
    // Set to non-zero if a digit is seen. Avoids accepting ".".
    var digitsSeen = false;
    // Added to exponent for each digit. Set to -1 when seeing '.'.
    var exponentDelta = 0;
    var bigIntValue = BigInt.zero;
    var sign = 1;
    var firstChar = str.codeUnitAt(start);
    if (firstChar == _minus) {
      sign = -1;
      start++;
      if (start == end) {
        throw FormatException('$str is not a valid format');
      }
      firstChar = str.codeUnitAt(start);
    }

    final firstDigit = firstChar ^ _zero;
    if (firstDigit <= 9) {
      start++;
      bigIntValue = BigInt.from(firstDigit);
      digitsSeen = true;
    }
    for (var i = start; i < end; i++) {
      final c = str.codeUnitAt(i);
      final digit = c ^ _zero; // '0'-'9' characters are now 0-9 integers.
      if (digit <= 9) {
        bigIntValue = _bigInt10 * bigIntValue + BigInt.from(digit);
        exponent += exponentDelta;
        digitsSeen = true;
      } else if (c == _dot && exponentDelta == 0) {
        exponentDelta = -1;
      } else if ((c | 0x20) == _e) {
        i++;
        if (i == end) {
          throw FormatException('$str is not a valid format');
        }
        exponent += int.parse(str.substring(i));
        break;
      }
    }

    if (!digitsSeen) {
      throw FormatException('$str is not a valid format');
    }

    // Decimal uses scale not exponent.
    return Decimal(sign.isNegative ? -bigIntValue : bigIntValue, -exponent);
  }

  /// Shift the decimal point on the right for positive [position] or on the left
  /// for negative one.
  ///
  /// ```dart
  /// var x = Decimal.parse('123.4567');
  /// x.shift(1); // 1234.567
  /// x.shift(-1); // 12.34567
  /// ```
  Decimal shift(int position) => Decimal(_number, _scale - position);

  /// If the number is not representable as a [double], an approximation is
  /// returned. For numerically large integers, the approximation may be
  /// infinite.
  double toDouble() => _number.toDouble() / pow(10, _scale);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Decimal &&
        other._number == _number &&
        other._scale == _scale;
  }

  @override
  int get hashCode => _number.hashCode ^ _scale.hashCode;

  @override
  int compareTo(Decimal other) {
    // Compare the numbers when they are scaled to the same level
    final thisScaledNumber = _number * _bigInt10.pow(other._scale.abs());
    final otherScaledNumber = other._number * _bigInt10.pow(_scale.abs());

    return thisScaledNumber.compareTo(otherScaledNumber);
  }

  @override
  String toString() {
    var numStr = _number.toString();
    if (_scale <= 0) {
      return '${numStr}e$_scale';
    } else {
      // calculate the position to insert the decimal point
      var decimalPointPos = numStr.length - _scale;
      if (decimalPointPos <= 0) {
        // add leading zeros
        numStr = '0' * (1 - decimalPointPos) + numStr;
        decimalPointPos = 1;
      }
      // insert the decimal point
      return '${numStr.substring(0, decimalPointPos)}.${numStr.substring(decimalPointPos)}';
    }
  }
}
