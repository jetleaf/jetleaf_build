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

import 'package:jetleaf_build/src/helpers/equals_and_hash_code.dart';
import 'package:test/test.dart';

class TestClass with EqualsAndHashCode {
  final String name;
  final int value;
  final List<String>? items;

  TestClass(this.name, this.value, [this.items]);

  @override
  List<Object?> equalizedProperties() => [name, value, items];
}

void main() {
  group('Equalizer Tests', () {
    test('should return true for identical objects', () {
      final obj = TestClass('test', 42);
      expect(obj == obj, isTrue);
    });

    test('should return true for equal objects', () {
      final obj1 = TestClass('test', 42, ['a', 'b']);
      final obj2 = TestClass('test', 42, ['a', 'b']);
      expect(obj1 == obj2, isTrue);
      expect(obj1.hashCode == obj2.hashCode, isTrue);
    });

    test('should return false for different objects', () {
      final obj1 = TestClass('test', 42);
      final obj2 = TestClass('test', 43);
      expect(obj1 == obj2, isFalse);
    });

    test('should handle null values correctly', () {
      final obj1 = TestClass('test', 42, null);
      final obj2 = TestClass('test', 42, null);
      final obj3 = TestClass('test', 42, []);
      
      expect(obj1 == obj2, isTrue);
      expect(obj1 == obj3, isFalse);
    });

    test('should generate consistent hash codes', () {
      final obj1 = TestClass('test', 42, ['a', 'b']);
      final obj2 = TestClass('test', 42, ['a', 'b']);
      
      expect(obj1.hashCode, equals(obj2.hashCode));
    });

    test('should generate different hash codes for different objects', () {
      final obj1 = TestClass('test', 42);
      final obj2 = TestClass('test', 43);
      
      expect(obj1.hashCode, isNot(equals(obj2.hashCode)));
    });

    test('should handle nested collections in equality', () {
      final obj1 = TestClass('test', 42, ['a', 'b', 'c']);
      final obj2 = TestClass('test', 42, ['a', 'b', 'c']);
      final obj3 = TestClass('test', 42, ['a', 'b', 'd']);
      
      expect(obj1 == obj2, isTrue);
      expect(obj1 == obj3, isFalse);
    });

    test('should generate meaningful toString', () {
      final obj = TestClass('test', 42, ['a', 'b']);
      final str = obj.toString();
      
      expect(str, contains('TestClass'));
      expect(str, contains('test'));
      expect(str, contains('42'));
    });
  });
}