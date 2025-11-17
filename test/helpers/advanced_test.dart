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

class Point with EqualsAndHashCode {
  final int x, y;

  Point(this.x, this.y);

  @override
  List<Object?> equalizedProperties() => [x, y];
}

class Point3D extends Point {
  final int z;
  Point3D(super.x, super.y, this.z);

  @override
  List<Object?> equalizedProperties() => [x, y, z];
}

void main() {
  group('EqualsAndHashCode (Advanced)', () {
    test('hashCode stability across calls', () {
      final p = Point(2, 3);
      final first = p.hashCode;
      final second = p.hashCode;
      expect(first, equals(second)); // stable
    });

    test('collections with equals', () {
      final set = {Point(1, 2)};
      expect(set.contains(Point(1, 2)), isTrue);
      expect(set.contains(Point(2, 1)), isFalse);
    });

    test('subclasses can extend equality', () {
      final a = Point3D(1, 2, 3);
      final b = Point3D(1, 2, 3);
      final c = Point3D(1, 2, 4);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('different property order affects hash', () {
      // Same values, but intentionally different equalized property order
      final a = _Weird(1, 2);
      final b = _WeirdReversed(1, 2);

      // They are NOT equal because property order matters
      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('handles large number of equalized properties', () {
      final big1 = _Big([for (int i = 0; i < 1000; i++) i]);
      final big2 = _Big([for (int i = 0; i < 1000; i++) i]);
      final big3 = _Big([for (int i = 0; i < 1000; i++) i + 1]);

      expect(big1, equals(big2));
      expect(big1.hashCode, equals(big2.hashCode));
      expect(big1, isNot(equals(big3)));
    });
  });
}

/// Helper class with reversed property order
class _Weird with EqualsAndHashCode {
  final int a, b;
  _Weird(this.a, this.b);
  @override
  List<Object?> equalizedProperties() => [a, b];
}

class _WeirdReversed with EqualsAndHashCode {
  final int a, b;
  _WeirdReversed(this.a, this.b);
  @override
  List<Object?> equalizedProperties() => [b, a];
}

/// Large object with many equalized properties
class _Big with EqualsAndHashCode {
  final List<int> values;
  _Big(this.values);

  @override
  List<Object?> equalizedProperties() => values;
}