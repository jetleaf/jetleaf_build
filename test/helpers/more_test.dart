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

class User with EqualsAndHashCode {
  final String id;
  final String? name;

  User(this.id, this.name);

  @override
  List<Object?> equalizedProperties() => [id, name];
}

void main() {
  group('EqualsAndHashCode (User basics)', () {
    test('two identical objects are equal', () {
      final a = User('1', 'Alice');
      final b = User('1', 'Alice');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a.toString(), contains('User'));
    });

    test('different property makes objects unequal', () {
      final a = User('1', 'Alice');
      final b = User('1', 'Bob');

      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('null properties are respected', () {
      final a = User('1', null);
      final b = User('1', null);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}