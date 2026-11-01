import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

void main() {
  group('maskEmail', () {
    test('keeps the first 2 characters of longer names', () {
      expect(maskEmail('player@gmail.com'), 'pl***@gmail.com');
      expect(maskEmail('abc@example.com'), 'ab***@example.com');
    });

    test('keeps only the first character of a 2-character name', () {
      expect(maskEmail('ab@example.com'), 'a***@example.com');
    });

    test('hides a 1-character name completely', () {
      expect(maskEmail('a@example.com'), '***@example.com');
    });

    test('returns a value without a usable @ unchanged', () {
      expect(maskEmail('no-at-sign'), 'no-at-sign');
      expect(maskEmail('@example.com'), '@example.com');
      expect(maskEmail(''), '');
    });
  });
}
