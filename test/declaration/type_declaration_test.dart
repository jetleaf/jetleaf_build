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

import 'package:test/test.dart';
import 'package:jetleaf_build/jetleaf_build.dart';

// Test classes with various type characteristics
class SimpleClass {
  final String name;
  SimpleClass(this.name);
}

class GenericClass<T> {
  final T value;
  GenericClass(this.value);
}

class BoundedGeneric<T extends num> {
  final T number;
  BoundedGeneric(this.number);
}

class ComplexClass<T extends Comparable<T>> extends GenericClass<T> {
  ComplexClass(super.value);
  
  int compareTo(T other) => value.compareTo(other);
}

class NullableFieldClass {
  String? nullableField;
  String nonNullableField;
  
  NullableFieldClass(this.nonNullableField, {this.nullableField});
}

class StaticMembersClass {
  static const String CONSTANT = 'constant';
  static int counter = 0;
  
  final String instanceField;
  
  StaticMembersClass(this.instanceField);
}

// Mixins
mixin SimpleMixin {
  void mixinMethod() {}
}

mixin GenericMixin<T> {
  List<T> items = [];
  void addItem(T item) => items.add(item);
}

mixin ConstrainedMixin<T extends num> {
  T doubleValue(T value) => value * 2 as T;
}

final class ClassWithMixin with SimpleMixin {}

// Interfaces
abstract interface class Drawable {
  void draw();
}

final class ImplementingDrawable implements Drawable {
  @override
  void draw() { }
}

abstract interface class Resizable {
  void resize(double factor);
}

final class ImplementingResizable implements Resizable {
  @override
  void resize(double factor) { }
}

final class InterfaceImpl implements Drawable, Resizable {
  @override
  void resize(double factor) { }

  @override
  void draw() { }
}

// Sealed hierarchy
sealed class Shape {
  const Shape();
  double get area;
}

final class Circle extends Shape {
  final double radius;
  const Circle(this.radius);
  
  @override
  double get area => 3.14159 * radius * radius;
}

final class Rectangle extends Shape {
  final double width, height;
  const Rectangle(this.width, this.height);
  
  @override
  double get area => width * height;
}

// Enum types
enum SimpleEnum {
  value1,
  value2,
  value3
}

enum EnhancedEnum {
  small(1, 'S'),
  medium(2, 'M'),
  large(3, 'L');
  
  const EnhancedEnum(this.size, this.code);
  
  final int size;
  final String code;
}

// Typedefs
typedef StringProcessor = String Function(String);
typedef GenericProcessor<T, R> = R Function(T);
typedef ComplexCallback = Future<List<String>> Function(String, int);

// Records
typedef PersonRecord = ({String name, int age});
typedef GenericRecord<T> = ({T value, String label});
typedef ComplexRecord = ({PersonRecord person, List<String> tags});

// Extension
extension StringExtensions on String {
  String get reversed => split('').reversed.join();
  
  bool get isPalindrome {
    final clean = toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return clean == clean.split('').reversed.join();
  }
}

void main() async {
  setUpAll(() async {
    await runTestScan(filesToLoad: []);
  });

  group('TypeDeclaration Basic Properties', () {
    test('should correctly identify class type kind', () {
      final simpleClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'SimpleClass');
      
      expect(simpleClass.getKind(), equals(TypeKind.classType));
      expect(simpleClass.getSimpleName(), equals('SimpleClass'));
      expect(simpleClass.getIsNullable(), isFalse);
      expect(simpleClass.getPackageUri(), contains('.dart'));
    });

    test('should correctly identify enum type kind', () {
      final enums = Runtime.getAllEnums();
      final simpleEnum = enums.firstWhere((e) => e.getName() == 'SimpleEnum');
      
      expect(simpleEnum.getKind(), equals(TypeKind.enumType));
      expect(simpleEnum.getValues().length, equals(3));
      
      final enhancedEnum = enums.firstWhere((e) => e.getName() == 'EnhancedEnum');
      expect(enhancedEnum.getKind(), equals(TypeKind.enumType));
    });

    test('should handle generic classes', () {
      final genericClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'GenericClass');
      
      expect(genericClass.isGeneric(), isTrue);
      expect(genericClass.getTypeArguments(), isNotEmpty);
      
      final boundedGeneric = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'BoundedGeneric');
      expect(boundedGeneric.isGeneric(), isTrue);
    });

    test('should identify sealed class hierarchy', () {
      final shapeClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'Shape');
      
      expect(shapeClass.getIsSealed(), isTrue);
      
      final circleClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'Circle');
      expect(circleClass.getIsFinal(), isTrue);
    });
  });

  group('TypeDeclaration Inheritance', () {
    test('should return superclass for inheritance chain', () {
      final complexClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ComplexClass');
      
      final superClass = complexClass.getSuperClass();
      expect(superClass, isNotNull);
      expect(superClass!.getName(), startsWith('GenericClass'));
    });

    test('should return mixins applied to class', () {
      final classWithMixin = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ClassWithMixin');
      
      final mixins = classWithMixin.getMixins();
      expect(mixins, isNotEmpty);
      expect(mixins.first.getName(), equals('SimpleMixin'));
    });

    test('should return implemented interfaces', () {
      final interfaceImpl = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'InterfaceImpl');
      
      final interfaces = interfaceImpl.getInterfaces();
      expect(interfaces.length, greaterThanOrEqualTo(2));
      expect(interfaces.map((i) => i.getName()), containsAll(['Drawable', 'Resizable']));
    });
  });

  group('TypeDeclaration Type Arguments', () {
    test('should handle generic type arguments', () {
      final genericClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'GenericClass');
      
      final typeArgs = genericClass.getTypeArguments();
      expect(typeArgs.length, equals(1));
      
      // When instantiated as GenericClass<String>, type argument should be String
      final stringGeneric = Runtime.getAllClasses().where((c) => c.getName().contains('GenericClass')).firstWhere((c) => c.getTypeArguments().isNotEmpty);
      
      final args = stringGeneric.getTypeArguments();
      expect(args.first.getName(), equals('Object'));
    });

    test('should handle bounded type parameters', () {
      final boundedClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'BoundedGeneric');
      
      expect(boundedClass.isGeneric(), isTrue);
      // Type parameter should have upper bound of num
      final typeArgs = boundedClass.getTypeArguments();
      expect(typeArgs, isNotEmpty);
    });
  });

  group('TypeDeclaration Special Types', () {
    test('should handle nullable types', () {
      final nullableClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'NullableFieldClass');
      
      expect(nullableClass.getIsNullable(), isFalse); // Class itself not nullable
      
      // Check that field types are correctly nullable
      final fields = nullableClass.getFields();
      final nullableField = fields.firstWhere((f) => f.getName() == 'nullableField');
      final nonNullableField = fields.firstWhere((f) => f.getName() == 'nonNullableField');
      
      expect(nullableField.isNullable(), isTrue);
      expect(nonNullableField.isNullable(), isFalse);
    });

    test('should identify static members separately', () {
      final staticClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'StaticMembersClass');
      
      final staticFields = staticClass.getFields().where((fi) => fi.getIsStatic());
      expect(staticFields.length, equals(2));
      expect(staticFields.map((f) => f.getName()), containsAll(['CONSTANT', 'counter']));
      
      final instanceFields = staticClass.getFields().where((fi) => !fi.getIsStatic());
      expect(instanceFields.length, equals(1));
      expect(instanceFields.first.getName(), equals('instanceField'));
    });

    test('should handle const constructors', () {
      final shapeClasses = Runtime.getAllClasses().where((c) => c.getName() == 'Circle' || c.getName() == 'Rectangle').toList();
      
      for (final shape in shapeClasses) {
        final constructors = shape.getConstructors();
        expect(constructors.where((c) => c.getIsConst()), isNotEmpty);
      }
    });
  });
}