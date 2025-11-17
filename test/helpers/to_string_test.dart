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

import 'dart:typed_data';
import 'package:jetleaf_build/jetleaf_build.dart';
import 'package:test/test.dart';

/// NOTE:
/// These test classes use the project's EqualsAndHashCode & ToString mixins.
/// The ToString mixin calls `base.toStringWith(this)`, which uses the exact
/// implementation you provided. Tests below assert that exact behavior.

/// Basic model: 3 properties (String, int, String)
class Person with EqualsAndHashCode, ToString {
  final String name;
  final int age;
  final String email;

  Person(this.name, this.age, this.email);

  @override
  List<Object?> equalizedProperties() => [name, age, email];

  // default: inherit ToStringOptions.STANDARD
}

/// Variants overriding toStringOptions()

class PersonStandard extends Person {
  PersonStandard(super.name, super.age, super.email);
  @override
  ToStringOptions toStringOptions() => ToStringOptions.STANDARD;
}

class PersonCompact extends Person {
  PersonCompact(super.name, super.age, super.email);
  @override
  ToStringOptions toStringOptions() => ToStringOptions.COMPACT;
}

class PersonMultiline extends Person {
  PersonMultiline(super.name, super.age, super.email);
  @override
  ToStringOptions toStringOptions() => ToStringOptions.MULTILINE;
}

class PersonCompactMultiline extends Person {
  PersonCompactMultiline(super.name, super.age, super.email);
  @override
  ToStringOptions toStringOptions() => ToStringOptions.COMPACT_MULTILINE;
}

class PersonSmartNames extends Person {
  PersonSmartNames(super.name, super.age, super.email);
  @override
  ToStringOptions toStringOptions() => ToStringOptions.SMART_NAMES;
}

class PersonTypeBased extends Person {
  PersonTypeBased(super.name, super.age, super.email);
  @override
  ToStringOptions toStringOptions() => ToStringOptions.TYPE_BASED_NAMES;
}

class PersonCustomSeparator extends Person {
  PersonCustomSeparator(super.name, super.age, super.email);
  @override
  ToStringOptions toStringOptions() => ToStringOptions(customSeparator: ' | ', includeParameterNames: false);
}

class PersonNoClassName extends Person {
  PersonNoClassName(super.name, super.age, super.email);
  @override
  ToStringOptions toStringOptions() => ToStringOptions(includeClassName: false);
}

class PersonCustomNames extends Person {
  PersonCustomNames(super.name, super.age, super.email);
  @override
  ToStringOptions toStringOptions() => ToStringOptions(customParameterNames: ['first', 'years', 'contact']);
}

class PersonCustomShortNames extends Person {
  PersonCustomShortNames(super.name, super.age, super.email);
  @override
  ToStringOptions toStringOptions() => ToStringOptions(customParameterNames: ['only']);
}

class PersonUseNewlinesAndCustomSep extends Person {
  PersonUseNewlinesAndCustomSep(super.name, super.age, super.email);
  @override
  ToStringOptions toStringOptions() => ToStringOptions(useNewlines: true, customSeparator: ' | ');
}

/// Class with no properties
class EmptyModel with EqualsAndHashCode, ToString {
  @override
  List<Object?> equalizedProperties() => [];

  // default options: STANDARD (include class name)
}

class EmptyModelNoClassName extends EmptyModel {
  @override
  ToStringOptions toStringOptions() => ToStringOptions(includeClassName: false);
}

/// Class that demonstrates custom parameter name generator (simple example)
class CustomGenModel with EqualsAndHashCode, ToString {
  final String a;
  final int b;
  final bool c;

  CustomGenModel(this.a, this.b, this.c);

  @override
  List<Object?> equalizedProperties() => [a, b, c];

  @override
  ToStringOptions toStringOptions() => ToStringOptions(customParameterNameGenerator: (value, index) => 'n$index');
}

/// Class with Uint8List + List + Map + bool (for smart/type-based tests)
class ComplexModel with EqualsAndHashCode, ToString {
  final Uint8List bytes;
  final List<int> numbers;
  final Map<String, dynamic> meta;
  final bool flag;

  ComplexModel(this.bytes, this.numbers, this.meta, this.flag);

  @override
  List<Object?> equalizedProperties() => [bytes, numbers, meta, flag];
  // we'll override toStringOptions in subclass variants
}

class ComplexSmartNames extends ComplexModel {
  ComplexSmartNames(super.bytes, super.numbers, super.meta, super.flag);
  @override
  ToStringOptions toStringOptions() => ToStringOptions.SMART_NAMES;
}

class ComplexTypeBased extends ComplexModel {
  ComplexTypeBased(super.bytes, super.numbers, super.meta, super.flag);
  @override
  ToStringOptions toStringOptions() => ToStringOptions.TYPE_BASED_NAMES;
}

void main() {
  group('toStringWith implementation (exact behavior tests)', () {
    test('STANDARD uses propertyN names and single-line with class name', () {
      final p = PersonStandard('Alice', 25, 'alice@example.com');
      expect(
        p.toString(),
        equals('PersonStandard(property0: Alice, property1: 25, property2: alice@example.com)'),
      );
    });

    test('COMPACT excludes names and is single-line', () {
      final p = PersonCompact('Bob', 30, 'bob@example.com');
      expect(p.toString(), equals('PersonCompact(Bob, 30, bob@example.com)'));
    });

    test('MULTILINE uses propertyN names, newline separator and indentation', () {
      final p = PersonMultiline('Charlie', 40, 'c@example.com');
      expect(
        p.toString(),
        equals('PersonMultiline(\n'
            '  property0: Charlie,\n'
            '  property1: 40,\n'
            '  property2: c@example.com\n'
            ')'),
      );
    });

    test('COMPACT_MULTILINE excludes names but uses newlines + indentation', () {
      final p = PersonCompactMultiline('Dora', 22, 'd@example.com');
      expect(
        p.toString(),
        equals('PersonCompactMultiline(\n'
            '  Dora,\n'
            '  22,\n'
            '  d@example.com\n'
            ')'),
      );
    });

    test('SMART_NAMES uses customParameterNameGenerator logic (semantic names)', () {
      final p = PersonSmartNames('Eve', 28, 'eve@example.com');
      // _smartNameGenerator: first 'Eve' is short string -> 'name'
      // second 28 -> 'age' (0..150), third contains '@' -> 'email'
      expect(
        p.toString(),
        equals('PersonSmartNames(name: Eve, age: 28, email: eve@example.com)'),
      );
    });

    test('TYPE_BASED_NAMES uses runtime types lowercased as names', () {
      final p = PersonTypeBased('Frank', 33, 'f@example.com');
      expect(
        p.toString(),
        equals('PersonTypeBased(string: Frank, int: 33, string: f@example.com)'),
      );
    });

    test('customSeparator used when provided (single-line example)', () {
      final p = PersonCustomSeparator('Grace', 44, 'g@example.com');
      expect(
        p.toString(),
        equals('PersonCustomSeparator(Grace | 44 | g@example.com)'),
      );
    });

    test('exclude class name: output wrapped in parentheses without class name', () {
      final p = PersonNoClassName('Henry', 55, 'h@example.com');
      expect(
        p.toString(),
        equals('(property0: Henry, property1: 55, property2: h@example.com)'),
      );
    });

    test('explicit custom parameter names override defaults', () {
      final p = PersonCustomNames('Ivy', 60, 'ivy@example.com');
      expect(
        p.toString(),
        equals('PersonCustomNames(first: Ivy, years: 60, contact: ivy@example.com)'),
      );
    });

    test('customParameterNames shorter than properties are filled with propertyN', () {
      final p = PersonCustomShortNames('Jill', 66, 'jill@example.com');
      // customParameterNames = ['only'] -> expected names: ['only','property1','property2']
      expect(
        p.toString(),
        equals('PersonCustomShortNames(only: Jill, property1: 66, property2: jill@example.com)'),
      );
    });

    test('useNewlines + customSeparator: custom separator still used but indentation occurs', () {
      final p = PersonUseNewlinesAndCustomSep('Kira', 77, 'k@example.com');
      expect(
        p.toString(),
        equals('PersonUseNewlinesAndCustomSep(\n'
            '  property0: Kira | property1: 77 | property2: k@example.com\n'
            ')'),
      );
    });

    test('empty equalizedProperties -> className() when includeClassName true', () {
      final e = EmptyModel();
      expect(e.toString(), equals('EmptyModel()'));
    });

    test('empty equalizedProperties -> () when includeClassName false', () {
      final e = EmptyModelNoClassName();
      expect(e.toString(), equals('()'));
    });

    test('custom parameter name generator works (n0, n1, ...)', () {
      final c = CustomGenModel('x', 1, true);
      // customParameterNameGenerator returns 'n0','n1','n2'
      expect(c.toString(),
          equals('CustomGenModel(n0: x, n1: 1, n2: true)'));
    });
  });
}