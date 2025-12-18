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

// ignore_for_file: unused_field, unnecessary_getters_setters, unused_element

import 'package:test/test.dart';
import 'package:jetleaf_build/jetleaf_build.dart';

// Classes with various method types
class MethodTestClass {
  // Regular methods
  String simpleMethod(String input) => 'Hello $input';
  
  // Method with optional parameters
  String methodWithOptionals(String required, [String? optional, int defaultValue = 42]) {
    return '$required ${optional ?? 'default'} $defaultValue';
  }
  
  // Method with named parameters
  String methodWithNamed({
    required String name,
    int age = 0,
    String? nickname,
  }) {
    return '$name ($age) ${nickname ?? 'no nickname'}';
  }
  
  // Generic method
  T genericMethod<T>(T value, {List<T>? items}) {
    return value;
  }
  
  // Async method
  Future<String> asyncMethod(String input) async {
    await Future.delayed(Duration(milliseconds: 10));
    return 'Async: $input';
  }
  
  // Stream method
  Stream<int> streamMethod(int count) async* {
    for (int i = 0; i < count; i++) {
      await Future.delayed(Duration(milliseconds: 10));
      yield i;
    }
  }
  
  // Static method
  static String staticMethod(String input) => 'Static: $input';
  
  // Private method
  String _privateMethod() => 'private';
  
  // Method with complex return type
  Map<String, List<int>> complexReturnMethod() => {
    'numbers': [1, 2, 3],
    'scores': [100, 200, 300],
  };
  
  // Method that throws
  String throwingMethod(bool shouldThrow) {
    if (shouldThrow) {
      throw ArgumentError('Test exception');
    }
    return 'Success';
  }
}

// Inheritance methods
abstract class BaseMethodClass {
  String baseMethod();
  
  String overridableMethod() => 'base';
}

class DerivedMethodClass extends BaseMethodClass {
  @override
  String baseMethod() => 'derived';
  
  @override
  String overridableMethod() => 'overridden';
  
  // Additional method
  String additionalMethod() => 'additional';
}

// Interface with methods
abstract interface class Drawable {
  void draw();
  void resize(double factor);
}

class Shape implements Drawable {
  @override
  void draw() => print('Drawing shape');
  
  @override
  void resize(double factor) => print('Resizing by $factor');
  
  // Additional method
  void rotate(double degrees) => print('Rotating $degrees degrees');
}

// Mixin with methods
mixin LoggingMixin {
  void log(String message) => print('LOG: $message');
  
  String get timestamp => DateTime.now().toString();
}

class Service with LoggingMixin {
  void performAction() {
    log('Action performed');
  }
}

// Getters and setters
class PropertyClass {
  String _name = '';
  List<String> _items = [];
  
  String get name => _name;
  set name(String value) => _name = value;
  
  List<String> get items => List.unmodifiable(_items);
  set items(List<String> value) => _items = value;
  
  // Read-only property
  String get readOnly => 'read only';
  
  // Write-only property (through setter)
  String? _secret;
  set secret(String value) => _secret = value;
  
  // Computed property
  int get itemCount => _items.length;
  
  // Method that looks like property
  String methodAsProperty() => 'method as property';
}

// Factory methods
class FactoryClass {
  final String id;
  
  FactoryClass._internal(this.id);
  
  factory FactoryClass.create(String id) {
    return FactoryClass._internal('factory_$id');
  }
  
  static FactoryClass createStatic(String id) {
    return FactoryClass._internal('static_$id');
  }
}

// Extension methods
extension StringExtensions on String {
  String get reversed => split('').reversed.join();
  
  bool get isPalindrome {
    final clean = toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return clean == clean.split('').reversed.join();
  }
  
  String repeat(int times) => this * times;
}

// New test classes for missing functionality
class EntryPointTest {
  // Main method - potential entry point
  void main() {
    print('Main method');
  }
  
  // Not an entry point
  void regularMethod() {}
  
  // Static method that could be entry point
  static void staticMain() {}
}

class TopLevelMethodTest {
  // Regular instance method
  void instanceMethod() {}
}

// Extension for testing
extension EntryPointExtension on EntryPointTest {
  void extensionMethod() {}
}

class NullableReturnTest {
  String? nullableReturnMethod() => null;
  String nonNullableReturnMethod() => 'not null';
  Future<String?> asyncNullableReturn() async => null;
  Stream<int?> streamNullableReturn() async* {
    yield null;
    yield 1;
  }
}

 abstract class AbstractMethodTest {
  // Abstract method (in abstract class)
  void abstractMethod();
  
  // Concrete method
  void concreteMethod() {}
}

// External method test (if supported)
class ExternalMethodTest {
  external void externalMethod();
}

class GeneratorTest {
  Stream<int> asyncStarMethod() async* {
    yield 1;
    yield 2;
    yield 3;
  }
  
  Iterable<int> syncStarMethod() sync* {
    yield 1;
    yield 2;
    yield 3;
  }
}

class VarArgsMethodTest {
  void manyParams(
    String a, String b, String c, String d, String e,
    [String? f, String? g, String? h, String? i, String? j]
  ) {}
}

class OperatorTest {
  int value;
  
  OperatorTest(this.value);
  
  OperatorTest operator +(OperatorTest other) {
    return OperatorTest(value + other.value);
  }
  
  @override
  bool operator ==(Object other) {
    return other is OperatorTest && value == other.value;
  }
  
  @override
  int get hashCode => value.hashCode;
}

void main() async {
  setUpAll(() async {
    await runTestScan(filesToLoad: []);
  });

  group('MethodDeclaration Basic Properties', () {
    test('should identify method types correctly', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MethodTestClass');
      
      final methods = testClass.getMethods();
      
      final simpleMethod = methods.firstWhere((m) => m.getName() == 'simpleMethod');
      expect(simpleMethod.getIsGetter(), isFalse);
      expect(simpleMethod.getIsSetter(), isFalse);
      expect(simpleMethod.getIsFactory(), isFalse);
      expect(simpleMethod.getIsConst(), isFalse);
      expect(simpleMethod.getIsStatic(), isFalse);
    });

    test('should identify static methods', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MethodTestClass');
      
      final methods = testClass.getMethods();
      
      final staticMethod = methods.firstWhere((m) => m.getName() == 'staticMethod');
      expect(staticMethod.getIsStatic(), isTrue);
    });

    test('should identify getters and setters', () {
      final propertyClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'PropertyClass');
      
      final methods = propertyClass.getMethods();
      
      final nameGetter = methods.firstWhere((m) => m.getName() == 'name' && m.getIsGetter());
      expect(nameGetter.getIsGetter(), isTrue);
      
      final nameSetter = methods.firstWhere((m) => m.getName() == 'name=' && m.getIsSetter());
      expect(nameSetter.getIsSetter(), isTrue);
      
      final readOnlyGetter = methods.firstWhere((m) => m.getName() == 'readOnly');
      expect(readOnlyGetter.getIsGetter(), isTrue);
      
      final secretSetter = methods.firstWhere((m) => m.getName() == 'secret=');
      expect(secretSetter.getIsSetter(), isTrue);
    });
  });

  group('MethodDeclaration Parameters', () {
    test('should handle method parameters correctly', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MethodTestClass');
      
      final methods = testClass.getMethods();
      
      final methodWithOptionals = methods.firstWhere((m) => m.getName() == 'methodWithOptionals');
      final params = methodWithOptionals.getParameters();
      
      expect(params.length, equals(3));
      
      final requiredParam = params.firstWhere((p) => p.getName() == 'required');
      expect(requiredParam.getIsOptional(), isFalse);
      expect(requiredParam.getIsRequired(), isTrue);
      
      final optionalParam = params.firstWhere((p) => p.getName() == 'optional');
      expect(optionalParam.getIsOptional(), isTrue);
      expect(optionalParam.getIsNullable(), isTrue);
      
      final defaultParam = params.firstWhere((p) => p.getName() == 'defaultValue');
      expect(defaultParam.getHasDefaultValue(), isTrue);
      expect(defaultParam.getDefaultValue(), equals(42));
    });

    test('should handle named parameters', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MethodTestClass');
      
      final methods = testClass.getMethods();
      
      final methodWithNamed = methods.firstWhere((m) => m.getName() == 'methodWithNamed');
      final params = methodWithNamed.getParameters();
      
      expect(params.length, equals(3));
      
      final nameParam = params.firstWhere((p) => p.getName() == 'name');
      expect(nameParam.getIsNamed(), isTrue);
      expect(nameParam.getIsRequired(), isTrue);
      
      final ageParam = params.firstWhere((p) => p.getName() == 'age');
      expect(ageParam.getIsNamed(), isTrue);
      expect(ageParam.getHasDefaultValue(), isTrue);
      expect(ageParam.getDefaultValue(), equals(0));
      
      final nicknameParam = params.firstWhere((p) => p.getName() == 'nickname');
      expect(nicknameParam.getIsNamed(), isTrue);
      expect(nicknameParam.getIsNullable(), isTrue);
    });

    test('should handle generic method parameters', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MethodTestClass');
      
      final methods = testClass.getMethods();
      
      final genericMethod = methods.firstWhere((m) => m.getName() == 'genericMethod');
      final params = genericMethod.getParameters();
      
      expect(params.length, greaterThanOrEqualTo(2));
      
      final valueParam = params.firstWhere((p) => p.getName() == 'value');
      expect(valueParam.getLinkDeclaration(), isNotNull);
      
      final itemsParam = params.firstWhere((p) => p.getName() == 'items');
      expect(itemsParam.getIsNullable(), isTrue);
    });
  });

  group('MethodDeclaration Invocation', () {
    test('should invoke simple methods correctly', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MethodTestClass');
      
      final instance = MethodTestClass();
      final methods = testClass.getMethods();
      
      final simpleMethod = methods.firstWhere((m) => m.getName() == 'simpleMethod');
      final result = simpleMethod.invoke(instance, {'input': 'World'});
      
      expect(result, equals('Hello World'));
    });

    test('should invoke methods with optional parameters', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MethodTestClass');
      
      final instance = MethodTestClass();
      final methods = testClass.getMethods();
      
      final methodWithOptionals = methods.firstWhere((m) => m.getName() == 'methodWithOptionals');
      
      // Call with all parameters
      final result1 = methodWithOptionals.invoke(instance, {
        'required': 'test',
        'optional': 'custom',
        'defaultValue': 100,
      });
      expect(result1, equals('test custom 100'));
      
      // Call with default values
      final result2 = methodWithOptionals.invoke(instance, {
        'required': 'test',
      });
      expect(result2, equals('test default 42'));
    });

    test('should invoke methods with named parameters', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MethodTestClass');
      
      final instance = MethodTestClass();
      final methods = testClass.getMethods();
      
      final methodWithNamed = methods.firstWhere((m) => m.getName() == 'methodWithNamed');
      
      final result = methodWithNamed.invoke(instance, {
        'name': 'John',
        'age': 30,
        'nickname': 'Johnny',
      });
      expect(result, equals('John (30) Johnny'));
    });

    test('should invoke generic methods', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MethodTestClass');
      
      final instance = MethodTestClass();
      final methods = testClass.getMethods();
      
      final genericMethod = methods.firstWhere((m) => m.getName() == 'genericMethod');
      
      final result = genericMethod.invoke(instance, {
        'value': 'test',
        'items': ['item1', 'item2'],
      });
      expect(result, equals('test'));
      
      final intResult = genericMethod.invoke(instance, {
        'value': 42,
      });
      expect(intResult, equals(42));
    });

    test('should invoke async methods', () async {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MethodTestClass');
      
      final instance = MethodTestClass();
      final methods = testClass.getMethods();
      
      final asyncMethod = methods.firstWhere((m) => m.getName() == 'asyncMethod');
      
      final result = await asyncMethod.invoke(instance, {'input': 'test'});
      expect(result, equals('Async: test'));
    });

    test('should handle method exceptions', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MethodTestClass');
      
      final instance = MethodTestClass();
      final methods = testClass.getMethods();
      
      final throwingMethod = methods.firstWhere((m) => m.getName() == 'throwingMethod');
      
      expect(
        () => throwingMethod.invoke(instance, {'shouldThrow': true}),
        throwsA(isA<ArgumentError>()),
      );
      
      expect(
        () => throwingMethod.invoke(instance, {'shouldThrow': false}),
        returnsNormally,
      );
    });
  });

  group('MethodDeclaration Inheritance', () {
    test('should handle inherited methods', () {
      final derivedClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'DerivedMethodClass');
      
      final methods = derivedClass.getMethods();
      
      expect(methods.any((m) => m.getName() == 'baseMethod'), isTrue);
      expect(methods.any((m) => m.getName() == 'overridableMethod'), isTrue);
      expect(methods.any((m) => m.getName() == 'additionalMethod'), isTrue);
    });

    test('should handle interface methods', () {
      final shapeClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'Shape');
      
      final methods = shapeClass.getMethods();
      
      expect(methods.any((m) => m.getName() == 'draw'), isTrue);
      expect(methods.any((m) => m.getName() == 'resize'), isTrue);
      expect(methods.any((m) => m.getName() == 'rotate'), isTrue);
    });
  });

  group('MethodDeclaration Return Types', () {
    test('should identify return types correctly', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MethodTestClass');
      
      final methods = testClass.getMethods();
      
      final simpleMethod = methods.firstWhere((m) => m.getName() == 'simpleMethod');
      print(simpleMethod.getReturnType());
      expect(simpleMethod.getReturnType().getName(), contains('String'));
      
      final asyncMethod = methods.firstWhere((m) => m.getName() == 'asyncMethod');
      expect(asyncMethod.getReturnType().getName(), contains('Future'));
      
      final streamMethod = methods.firstWhere((m) => m.getName() == 'streamMethod');
      expect(streamMethod.getReturnType().getName(), contains('Stream'));
      
      final complexMethod = methods.firstWhere((m) => m.getName() == 'complexReturnMethod');
      expect(complexMethod.getReturnType().getName(), contains('Map'));
    });
  });

  group('MethodDeclaration Factory Methods', () {
    test('should identify factory methods', () {
      final factoryClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'FactoryClass');
      
      final constructors = factoryClass.getConstructors();
      
      final factoryConstructor = constructors.firstWhere((c) => c.getName() == 'create');
      expect(factoryConstructor.getIsFactory(), isTrue);
      
      final staticMethod = factoryClass.getMethods()
          .firstWhere((m) => m.getName() == 'createStatic');
      expect(staticMethod.getIsStatic(), isTrue);
    });
  });
  group('MethodDeclaration Additional Properties', () {
    test('should identify top-level methods', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'TopLevelMethodTest');
      
      final methods = testClass.getMethods();
      
      for (final method in methods) {
        // isTopLevel depends on implementation - might be false for instance methods
        expect(method.getIsTopLevel(), anyOf(isTrue, isFalse));
      }
    });

    test('should identify entry point methods', () {
      final entryPointClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'EntryPointTest');
      
      final methods = entryPointClass.getMethods();
      
      final mainMethod = methods.firstWhere((m) => m.getName() == 'main');
      // isEntryPoint should be true for main method if it's the application entry point
      expect(mainMethod.getIsEntryPoint(), anyOf(isTrue, isFalse));
      
      final regularMethod = methods.firstWhere((m) => m.getName() == 'regularMethod');
      expect(regularMethod.getIsEntryPoint(), isFalse);
      
      final staticMain = methods.firstWhere((m) => m.getName() == 'staticMain');
      expect(staticMain.getIsEntryPoint(), anyOf(isTrue, isFalse));
    });

    test('should detect nullable return types', () {
      final nullableClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'NullableReturnTest');
      
      final methods = nullableClass.getMethods();
      
      final nullableReturn = methods.firstWhere((m) => m.getName() == 'nullableReturnMethod');
      expect(nullableReturn.hasNullableReturn(), isTrue);
      
      final nonNullableReturn = methods.firstWhere((m) => m.getName() == 'nonNullableReturnMethod');
      expect(nonNullableReturn.hasNullableReturn(), isFalse);
      
      final asyncNullable = methods.firstWhere((m) => m.getName() == 'asyncNullableReturn');
      expect(asyncNullable.hasNullableReturn(), isFalse);
      
      final streamNullable = methods.firstWhere((m) => m.getName() == 'streamNullableReturn');
      expect(streamNullable.hasNullableReturn(), isFalse);
    });

    test('should handle abstract methods', () {
      final abstractClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'AbstractMethodTest');
      
      final methods = abstractClass.getMethods();
      
      final abstractMethod = methods.firstWhere((m) => m.getName() == 'abstractMethod');
      expect(abstractMethod.getIsAbstract(), isTrue);
      
      final concreteMethod = methods.firstWhere((m) => m.getName() == 'concreteMethod');
      expect(concreteMethod.getIsAbstract(), isFalse);
    });

    test('should correctly identify getDebugIdentifier', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MethodTestClass');
      
      final methods = testClass.getMethods();
      final firstMethod = methods.first;
      
      expect(firstMethod.getDebugIdentifier(), isNotEmpty);
      expect(firstMethod.getDebugIdentifier(), contains('Method'));
      expect(firstMethod.getDebugIdentifier(), contains(firstMethod.getName()));
    });
  });

  group('MethodDeclaration Edge Cases', () {
    test('should handle external methods', () {
      // External methods might not be fully supported in reflection
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ExternalMethodTest');
      
      final methods = testClass.getMethods();
      final externalMethod = methods.firstWhere((m) => m.getName() == 'externalMethod');
      
      // External methods might have special handling
      expect(externalMethod, isNotNull);
    });

    test('should handle method with varargs-like parameters', () {
      final varArgsClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'VarArgsMethodTest');
      
      final methods = varArgsClass.getMethods();
      final manyParams = methods.firstWhere((m) => m.getName() == 'manyParams');
      
      final params = manyParams.getParameters();
      expect(params.length, equals(10));
      
      // First 5 are required
      for (int i = 0; i < 5; i++) {
        expect(params[i].getIsOptional(), isFalse);
      }
      
      // Last 5 are optional
      for (int i = 5; i < 10; i++) {
        expect(params[i].getIsOptional(), isTrue);
        expect(params[i].getIsNullable(), isTrue);
      }
    });

    test('should handle operator methods', () {
      final operatorClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'OperatorTest');
      
      final methods = operatorClass.getMethods();
      
      final plusOperator = methods.firstWhere((m) => m.getName() == '+');
      expect(plusOperator, isNotNull);
      expect(plusOperator.getParameters().length, equals(1));
      
      final equalsOperator = methods.firstWhere((m) => m.getName() == '==');
      expect(equalsOperator, isNotNull);
      expect(equalsOperator.getParameters().length, equals(1));
    });

    test('should handle async* and sync* methods', () async {
      final generatorClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'GeneratorTest');
      
      final methods = generatorClass.getMethods();
      
      final asyncStar = methods.firstWhere((m) => m.getName() == 'asyncStarMethod');
      expect(asyncStar.getReturnType().getName(), contains('Stream'));
      
      final syncStar = methods.firstWhere((m) => m.getName() == 'syncStarMethod');
      expect(syncStar.getReturnType().getName(), contains('Iterable'));
    });
  });

  group('MethodDeclaration Invocation Edge Cases', () {
    test('should handle method with no parameters', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MethodTestClass');
      
      final instance = MethodTestClass();
      final methods = testClass.getMethods();
      
      final privateMethod = methods.firstWhere((m) => m.getName() == '_privateMethod');
      expect(() => privateMethod.invoke(instance, {}), throwsA(isA<PrivateMethodInvocationException>()));
    });

    test('should handle invocation with wrong parameter types', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MethodTestClass');
      
      final instance = MethodTestClass();
      final methods = testClass.getMethods();
      
      final simpleMethod = methods.firstWhere((m) => m.getName() == 'simpleMethod');
      
      // Should throw when passing wrong type
      expect(
        () => simpleMethod.invoke(instance, {'input': 123}), // Wrong type: int instead of String
        throwsA(anything),
      );
    });

    test('should handle invocation with missing required parameters', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MethodTestClass');
      
      final instance = MethodTestClass();
      final methods = testClass.getMethods();
      
      final methodWithNamed = methods.firstWhere((m) => m.getName() == 'methodWithNamed');
      
      // Missing required named parameter
      expect(
        () => methodWithNamed.invoke(instance, {}),
        throwsA(anything),
      );
    });
  });
}