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

// ignore_for_file: unused_field

import 'package:test/test.dart';
import 'package:jetleaf_build/jetleaf_build.dart';

// Test classes for constructor declarations
class SimpleConstructorClass {
  final String name;
  final int? optional;
  
  SimpleConstructorClass(this.name, [this.optional]);
  
  SimpleConstructorClass.named({required this.name, this.optional});
  
  factory SimpleConstructorClass.factory(String name) {
    return SimpleConstructorClass(name);
  }
  
  const SimpleConstructorClass.constant(this.name, [this.optional]);
}

class ComplexConstructorClass {
  final String value;
  final List<int> numbers;
  
  ComplexConstructorClass.withInitializer(String input)
    : value = input.toUpperCase(),
      numbers = List.generate(input.length, (i) => i);
  
  ComplexConstructorClass.withAssert(String input)
    : value = input,
      numbers = []
    {
      assert(input.isNotEmpty, 'Input cannot be empty');
    }
  
  ComplexConstructorClass.redirecting(String value) 
    : this._internal(value, 0);
  
  ComplexConstructorClass._internal(this.value, int count)
    : numbers = List.filled(count, 0);
}

class GenericConstructorClass<T> {
  final T value;
  final List<T> items;
  
  GenericConstructorClass(this.value, {this.items = const []});
  
  factory GenericConstructorClass.create(T value) {
    return GenericConstructorClass(value);
  }
  
  GenericConstructorClass.withDefault() 
    : value = _defaultValue() as T,
      items = [];
  
  static dynamic _defaultValue() => 0;
}

class SealedConstructorClass {
  final String id;
  final DateTime createdAt;
  
  SealedConstructorClass(this.id) : createdAt = DateTime.now();
  
  SealedConstructorClass.withDate(this.id, this.createdAt);
}

class InterfaceConstructorClass implements Comparable<InterfaceConstructorClass> {
  final int priority;
  
  InterfaceConstructorClass(this.priority);
  
  @override
  int compareTo(InterfaceConstructorClass other) => priority.compareTo(other.priority);
}

class RecordConstructorClass {
  final (String, int) tuple;
  final ({String name, int age}) record;
  
  RecordConstructorClass(this.tuple, {required this.record});
}

class ExternalConstructorClass {
  final String data;
  
  ExternalConstructorClass(this.data);
  
  factory ExternalConstructorClass.fromJson(Map<String, dynamic> json) {
    return ExternalConstructorClass(json['data'] as String);
  }
}

class NullableConstructorClass {
  final String? nullableField;
  final String nonNullableField;
  
  NullableConstructorClass(this.nonNullableField, {this.nullableField});
}

class PrivateConstructorClass {
  final String _private;
  final String public;
  
  PrivateConstructorClass._internal(this._private, this.public);
  
  factory PrivateConstructorClass.create(String private, String public) {
    return PrivateConstructorClass._internal(private, public);
  }
}

class AbstractConstructorClass {
  final String base;
  
  AbstractConstructorClass(this.base);
}

class ConcreteConstructorClass extends AbstractConstructorClass {
  final String additional;
  
  ConcreteConstructorClass(super.base, this.additional);
}

void main() async {
  setUpAll(() async {
    await runTestScan(filesToLoad: []);
  });

  group('ConstructorDeclaration Basic Properties', () {
    test('should retrieve all constructors', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'SimpleConstructorClass');
      
      final constructors = testClass.getConstructors();
      expect(constructors.length, equals(4));
    });

    test('should identify constructor types', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'SimpleConstructorClass');
      
      final constructors = testClass.getConstructors();
      
      final defaultConstructor = constructors.firstWhere((c) => c.getName() == '');
      expect(defaultConstructor.getIsFactory(), isFalse);
      expect(defaultConstructor.getIsConst(), isFalse);
      
      final constConstructor = constructors.firstWhere((c) => c.getName() == 'constant');
      expect(constConstructor.getIsConst(), isTrue);
      
      final factoryConstructor = constructors.firstWhere((c) => c.getName() == 'factory');
      expect(factoryConstructor.getIsFactory(), isTrue);
      
      final namedConstructor = constructors.firstWhere((c) => c.getName() == 'named');
      expect(namedConstructor.getName(), equals('named'));
    });

    test('should identify public vs private constructors', () {
      final privateClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'PrivateConstructorClass');
      
      final constructors = privateClass.getConstructors();
      
      final privateConstructor = constructors.firstWhere((c) => c.getName() == '_internal');
      expect(privateConstructor.getIsPublic(), isFalse);
      
      final factoryConstructor = constructors.firstWhere((c) => c.getName() == 'create');
      expect(factoryConstructor.getIsPublic(), isTrue);
    });
  });

  group('ConstructorDeclaration Parameters', () {
    test('should retrieve constructor parameters', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'SimpleConstructorClass');
      
      final constructors = testClass.getConstructors();
      final defaultConstructor = constructors.firstWhere((c) => c.getName() == '');
      
      final params = defaultConstructor.getParameters();
      expect(params.length, equals(2));
      
      final nameParam = params.firstWhere((p) => p.getName() == 'name');
      expect(nameParam.getIsOptional(), isFalse);
      expect(nameParam.getIsNullable(), isFalse);
      
      final optionalParam = params.firstWhere((p) => p.getName() == 'optional');
      expect(optionalParam.getIsOptional(), isTrue);
      expect(optionalParam.getIsNullable(), isTrue);
    });

    test('should handle named parameters in constructors', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'SimpleConstructorClass');
      
      final constructors = testClass.getConstructors();
      final namedConstructor = constructors.firstWhere((c) => c.getName() == 'named');
      
      final params = namedConstructor.getParameters();
      
      final nameParam = params.firstWhere((p) => p.getName() == 'name');
      expect(nameParam.getIsNamed(), isTrue);
      expect(nameParam.getIsRequired(), isTrue);
      
      final optionalParam = params.firstWhere((p) => p.getName() == 'optional');
      expect(optionalParam.getIsNamed(), isTrue);
      expect(optionalParam.getIsNullable(), isTrue);
    });

    test('should handle nullable parameters', () {
      final nullableClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'NullableConstructorClass');
      
      final constructors = nullableClass.getConstructors();
      final defaultConstructor = constructors.firstWhere((c) => c.getName() == '');
      
      final params = defaultConstructor.getParameters();
      
      final nonNullableParam = params.firstWhere((p) => p.getName() == 'nonNullableField');
      expect(nonNullableParam.getIsNullable(), isFalse);
      
      final nullableParam = params.firstWhere((p) => p.getName() == 'nullableField');
      expect(nullableParam.getIsNullable(), isTrue);
      expect(nullableParam.getIsNamed(), isTrue);
    });
  });

  group('ConstructorDeclaration Invocation', () {
    test('should invoke default constructor', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'SimpleConstructorClass');
      
      final constructors = testClass.getConstructors();
      final defaultConstructor = constructors.firstWhere((c) => c.getName() == '');
      
      final instance = defaultConstructor.newInstance<SimpleConstructorClass>({
        'name': 'Test',
        'optional': 42,
      });
      
      expect(instance, isA<SimpleConstructorClass>());
      expect(instance.name, equals('Test'));
      expect(instance.optional, equals(42));
    });

    test('should invoke named constructor', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'SimpleConstructorClass');
      
      final constructors = testClass.getConstructors();
      final namedConstructor = constructors.firstWhere((c) => c.getName() == 'named');
      
      final instance = namedConstructor.newInstance<SimpleConstructorClass>({
        'name': 'NamedTest',
        'optional': 100,
      });
      
      expect(instance, isA<SimpleConstructorClass>());
      expect(instance.name, equals('NamedTest'));
      expect(instance.optional, equals(100));
    });

    test('should invoke factory constructor', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'SimpleConstructorClass');
      
      final constructors = testClass.getConstructors();
      final factoryConstructor = constructors.firstWhere((c) => c.getName() == 'factory');
      
      final instance = factoryConstructor.newInstance<SimpleConstructorClass>({
        'name': 'FactoryTest',
      });
      
      expect(instance, isA<SimpleConstructorClass>());
      expect(instance.name, equals('FactoryTest'));
    });

    test('should invoke const constructor', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'SimpleConstructorClass');
      
      final constructors = testClass.getConstructors();
      final constConstructor = constructors.firstWhere((c) => c.getName() == 'constant');
      
      final instance = constConstructor.newInstance<SimpleConstructorClass>({
        'name': 'ConstTest',
      });
      
      expect(instance, isA<SimpleConstructorClass>());
      expect(instance.name, equals('ConstTest'));
    });
  });

  group('ConstructorDeclaration Edge Cases', () {
    test('should handle redirecting constructors', () {
      final complexClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ComplexConstructorClass');
      
      final constructors = complexClass.getConstructors();
      final redirectingConstructor = constructors.firstWhere((c) => c.getName() == 'redirecting');
      
      expect(redirectingConstructor, isNotNull);
    });

    test('should handle constructors with initializer lists', () {
      final complexClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ComplexConstructorClass');
      
      final constructors = complexClass.getConstructors();
      final initializerConstructor = constructors.firstWhere((c) => c.getName() == 'withInitializer');
      
      expect(initializerConstructor, isNotNull);
    });

    test('should handle generic constructors', () {
      final genericClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'GenericConstructorClass');
      
      final constructors = genericClass.getConstructors();
      expect(constructors.length, equals(3));
      
      final defaultConstructor = constructors.firstWhere((c) => c.getName() == '');
      final factoryConstructor = constructors.firstWhere((c) => c.getName() == 'create');
      
      expect(defaultConstructor, isNotNull);
      expect(factoryConstructor.getIsFactory(), isTrue);
    });

    test('should handle inheritance in constructors', () {
      final concreteClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ConcreteConstructorClass');
      
      final constructors = concreteClass.getConstructors();
      final defaultConstructor = constructors.firstWhere((c) => c.getName() == '');
      
      final instance = defaultConstructor.newInstance<ConcreteConstructorClass>({
        'base': 'baseValue',
        'additional': 'additionalValue',
      });
      
      expect(instance, isA<ConcreteConstructorClass>());
      expect(instance.base, equals('baseValue'));
      expect(instance.additional, equals('additionalValue'));
    });

    test('should handle record parameters in constructors', () {
      final recordClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'RecordConstructorClass');
      
      final constructors = recordClass.getConstructors();
      final defaultConstructor = constructors.firstWhere((c) => c.getName() == '');
      
      final params = defaultConstructor.getParameters();
      expect(params.length, equals(2));
      
      final tupleParam = params.firstWhere((p) => p.getName() == 'tuple');
      final recordParam = params.firstWhere((p) => p.getName() == 'record');
      
      expect(tupleParam, isNotNull);
      expect(recordParam, isNotNull);
      expect(recordParam.getIsNamed(), isTrue);
      expect(recordParam.getIsRequired(), isTrue);
    });
  });
}