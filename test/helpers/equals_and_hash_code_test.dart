// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
//
// This source file is part of the JetLeaf Framework and is protected
// under copyright law. You may not copy, modify, or distribute this file
// except in compliance with the JetLeaf license.
//
// For licensing terms, see the LICENSE file in the root of this project.
// ---------------------------------------------------------------------------
// 
// 🔧 Powered by Hapnium — the Dart backend engine 🍃

// test/equals_and_hash_code_test.dart
import 'package:jetleaf_build/src/helpers/equals_and_hash_code.dart';
import 'package:test/test.dart';

// Test classes
class SimpleClass with EqualsAndHashCode {
  final String name;
  final int value;

  SimpleClass(this.name, this.value);

  @override
  List<Object?> equalizedProperties() => [name, value];
}

class ComplexClass with EqualsAndHashCode {
  final SimpleClass nested;
  final List<int> numbers;

  ComplexClass(this.nested, this.numbers);

  @override
  List<Object?> equalizedProperties() => [nested, numbers];
}

class EmptyClass with EqualsAndHashCode {
  @override
  List<Object?> equalizedProperties() => [];
}

class NullableClass with EqualsAndHashCode {
  final String? name;
  final int? value;

  NullableClass(this.name, this.value);

  @override
  List<Object?> equalizedProperties() => [name, value];
}

void main() {
  group('EqualsAndHashCode', () {
    test('should implement equality correctly', () {
      final obj1 = SimpleClass('test', 42);
      final obj2 = SimpleClass('test', 42);
      final obj3 = SimpleClass('different', 42);
      final obj4 = SimpleClass('test', 100);

      expect(obj1 == obj2, isTrue);
      expect(obj1 == obj3, isFalse);
      expect(obj1 == obj4, isFalse);
    });

    test('should implement hashCode correctly', () {
      final obj1 = SimpleClass('test', 42);
      final obj2 = SimpleClass('test', 42);
      final obj3 = SimpleClass('different', 42);

      expect(obj1.hashCode, equals(obj2.hashCode));
      expect(obj1.hashCode, isNot(equals(obj3.hashCode)));
    });

    test('should handle nested EqualsAndHashCode objects', () {
      final nested1 = SimpleClass('nested', 1);
      final nested2 = SimpleClass('nested', 1);
      final nested3 = SimpleClass('different', 1);

      final complex1 = ComplexClass(nested1, [1, 2, 3]);
      final complex2 = ComplexClass(nested2, [1, 2, 3]);
      final complex3 = ComplexClass(nested3, [1, 2, 3]);

      expect(complex1 == complex2, isTrue);
      expect(complex1 == complex3, isFalse);
      expect(complex1.hashCode, equals(complex2.hashCode));
    });

    test('should handle empty properties', () {
      final empty1 = EmptyClass();
      final empty2 = EmptyClass();

      expect(empty1 == empty2, isTrue);
      expect(empty1.hashCode, equals(empty2.hashCode));
    });

    test('should handle null values', () {
      final null1 = NullableClass(null, null);
      final null2 = NullableClass(null, null);
      final withValues = NullableClass('test', 42);

      expect(null1 == null2, isTrue);
      expect(null1 == withValues, isFalse);
      expect(null1.hashCode, equals(null2.hashCode));
    });

    test('should handle mixed null and non-null values', () {
      final mixed1 = NullableClass('test', null);
      final mixed2 = NullableClass('test', null);
      final mixed3 = NullableClass(null, 42);

      expect(mixed1 == mixed2, isTrue);
      expect(mixed1 == mixed3, isFalse);
    });

    test('should handle identical objects', () {
      final obj = SimpleClass('test', 42);
      expect(obj == obj, isTrue);
    });

    test('should handle lists in properties', () {
      final list1 = ComplexClass(SimpleClass('test', 1), [1, 2, 3]);
      final list2 = ComplexClass(SimpleClass('test', 1), [1, 2, 3]);
      final list3 = ComplexClass(SimpleClass('test', 1), [1, 2, 4]);

      expect(list1 == list2, isTrue);
      expect(list1 == list3, isFalse);
      expect(list1.hashCode, equals(list2.hashCode));
    });

    test('should handle different list orders', () {
      final list1 = ComplexClass(SimpleClass('test', 1), [1, 2, 3]);
      final list2 = ComplexClass(SimpleClass('test', 1), [3, 2, 1]);

      expect(list1 == list2, isFalse);
    });

    test('toString should work', () {
      final obj = SimpleClass('test', 42);
      final str = obj.toString();

      expect(str, contains('SimpleClass'));
      expect(str, contains('test'));
      expect(str, contains('42'));
    });

    test('should handle complex nested structures', () {
      final nested1 = ComplexClass(SimpleClass('a', 1), [1]);
      final nested2 = ComplexClass(SimpleClass('a', 1), [1]);
      final nested3 = ComplexClass(SimpleClass('b', 1), [1]);

      expect(nested1 == nested2, isTrue);
      expect(nested1 == nested3, isFalse);
    });

    test('should handle large property lists', () {
      final largeList = List.generate(100, (i) => i);
      final obj1 = ComplexClass(SimpleClass('test', 1), largeList);
      final obj2 = ComplexClass(SimpleClass('test', 1), largeList);

      expect(obj1 == obj2, isTrue);
      expect(obj1.hashCode, equals(obj2.hashCode));
    });
  });
}