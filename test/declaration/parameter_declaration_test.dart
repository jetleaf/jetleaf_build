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

// ignore_for_file: unused_element, empty_constructor_bodies, avoid_shadowing_type_parameters

import 'package:test/test.dart';
import 'package:jetleaf_build/jetleaf_build.dart';

typedef WhenChecked = Map<String, bool>;
final record = (String, bool);
typedef Rrec = ({String name, int age});

// Classes with various parameter configurations
class SimpleParamClass {
  SimpleParamClass(this.requiredParam, [this.optionalPositional]);
  
  final String requiredParam;
  final String? optionalPositional;
  
  void methodWithDefaults(String required, {String? optional, int defaultValue = 42}) {}
}

class NullableParamClass {
  NullableParamClass(this.nonNullable, this.nullableField);
  
  final String nonNullable;
  final String? nullableField;
  
  void methodWithNullableParams(String? param1, String param2) {}
  
  void methodWithComplexNullability(List<String?> items, Map<String, int?>? data) {}
}

class GenericParamClass<T> {
  GenericParamClass(T value, {List<T>? items}) {}
  
  U genericMethod<U>(T input, U? nullableGeneric) => nullableGeneric!;
  
  void boundedGenericMethod<T extends Comparable<T>>(T value) {}
}

class SuperParamClass extends SimpleParamClass {
  SuperParamClass(super.requiredParam, [super.optionalPositional, this.additional]);
  
  final int? additional;
  
  void overriddenMethod(String required, {String? optional, int defaultValue = 100}) {}
}

class ComplexParamClass {
  ComplexParamClass({
    required this.requiredNamed,
    this.optionalNamed,
    this.namedWithDefault = 'default',
    List<String>? listParam,
    Map<String, dynamic>? mapParam,
    Future<List<int>>? futureParam,
  })  : listParam = listParam ?? [],
        futureParam = futureParam ?? Future(() => []),
        mapParam = mapParam ?? {};
  
  final String requiredNamed;
  final String? optionalNamed;
  final String namedWithDefault;
  final List<String> listParam;
  final Map<String, dynamic> mapParam;
  final Future<List<int>>? futureParam;
  
  void methodWithAllParamTypes(
    String positional,
    {
      String? optionalPositional = 'opt',
      required String requiredNamed,
      String optionalNamed = 'default',
      String? nullableNamed,
    }
  ) {}
}

class RecordParamClass {
  RecordParamClass((String, int) positionalRecord, {required ({String name, int age}) namedRecord}) {}
  
  ({String label, List<int> values}) methodReturningRecord() => (label: 'test', values: [1, 2, 3]);
  ({String label, List<int> values}) methodReturning({String name = ""}) => (label: 'test', values: [1, 2, 3]);
}

class FunctionParamClass {
  FunctionParamClass(String Function(String) transformer, {void Function()? callback}) {}
  
  Future<T> processAsync<T>(Future<T> Function(T input) processor, T value) async {
    return await processor(value);
  }
}

class FunctionParamClasse {
  FunctionParamClasse(String Function(String) transformer, {void Function()? callback}) {}
  
  Future<T> processAsync<T>(Future<T> Function(T input) processor, T value, String Function(String user, bool come) cme) async {
    return await processor(value);
  }

  Future<T> process<T>(Future<T> Function(T input) processor, T value, List<String> Function(Map<String, bool> user, bool come) cme) async {
    return await processor(value);
  }
}

class VarArgsParamClass {
  VarArgsParamClass(String first, String second, [String? third, String? fourth]) {}
  
  void methodWithManyParams(
    String a, String b, String c, String d, String e,
    [String? f, String? g, String? h, String? i, String? j]
  ) {}
}

class InterfaceParamClass implements Comparable<InterfaceParamClass> {
  final int value;
  
  InterfaceParamClass(this.value);
  
  @override
  int compareTo(InterfaceParamClass other) => value.compareTo(other.value);
  
  bool operator >(InterfaceParamClass other) => value > other.value;
  bool operator <(InterfaceParamClass other) => value < other.value;
}

class MixinParamClass with ComparableMixin<MixinParamClass> {
  final int priority;
  
  MixinParamClass(this.priority);
  
  @override
  int compareTo(MixinParamClass other) => priority.compareTo(other.priority);
}

mixin ComparableMixin<T> implements Comparable<T> {
  @override
  int compareTo(covariant T other);
}

class ConstructorParamVariations {
  // Default constructor
  ConstructorParamVariations(this.normalParam, this.additional);
  
  // Named constructor
  ConstructorParamVariations.named({required this.normalParam, this.additional});
  
  // Factory constructor
  factory ConstructorParamVariations.factory(String param) {
    return ConstructorParamVariations(param, "");
  }
  
  // Const constructor
  const ConstructorParamVariations.constant(this.normalParam, [this.additional]);
  
  // Private constructor
  ConstructorParamVariations._private(this.normalParam, this.additional);
  
  final String normalParam;
  final String? additional;
}

class LateInitParamClass {
  late final String lateField;
  final String normalField;
  
  LateInitParamClass(String value) : normalField = value {
    lateField = 'late_$value';
  }
}

class SuperConstructorParamClass extends SimpleParamClass {
  SuperConstructorParamClass(super.param1, super.param2, this.extra);
  
  final String extra;
}

void main() async {
  setUpAll(() async {
    await runTestScan(filesToLoad: []);
  });

  group('ParameterDeclaration Basic Properties', () {
    test('should correctly identify nullable vs non-nullable parameters', () {
      final nullableClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'NullableParamClass');
      
      final constructor = nullableClass.getConstructors().first;
      final params = constructor.getParameters();
      
      final nonNullableParam = params.firstWhere((p) => p.getName() == 'nonNullable');
      expect(nonNullableParam.getIsNullable(), isFalse);
      expect(nonNullableParam.getIsRequired(), isTrue);
      
      final nullableFieldParam = params.firstWhere((p) => p.getName() == 'nullableField');
      expect(nullableFieldParam.getIsNullable(), isTrue);
      expect(nullableFieldParam.getIsRequired(), isTrue);
    });

    test('should handle optional positional parameters', () {
      final simpleClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'SimpleParamClass');
      
      final constructor = simpleClass.getConstructors().first;
      final params = constructor.getParameters();
      
      final requiredParam = params.firstWhere((p) => p.getName() == 'requiredParam');
      expect(requiredParam.getIsOptional(), isFalse);
      expect(!requiredParam.getIsNamed(), isTrue);
      expect(requiredParam.getIsNamed(), isFalse);
      
      final optionalParam = params.firstWhere((p) => p.getName() == 'optionalPositional');
      expect(optionalParam.getIsOptional(), isTrue);
      expect(optionalParam.getIsNullable(), isTrue);
      expect(!optionalParam.getIsNamed(), isTrue);
      expect(optionalParam.getIndex(), equals(1));
    });

    test('should handle named parameters correctly', () {
      final complexClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ComplexParamClass');
      
      final constructor = complexClass.getConstructors().first;
      final params = constructor.getParameters();
      
      final requiredNamed = params.firstWhere((p) => p.getName() == 'requiredNamed');
      expect(requiredNamed.getIsNamed(), isTrue);
      expect(requiredNamed.getIsRequired(), isTrue);
      expect(requiredNamed.getIsOptional(), isFalse);
      
      final optionalNamed = params.firstWhere((p) => p.getName() == 'optionalNamed');
      expect(optionalNamed.getIsNamed(), isTrue);
      expect(optionalNamed.getIsNullable(), isTrue);
      expect(optionalNamed.getIsOptional(), isTrue);
      
      final namedWithDefault = params.firstWhere((p) => p.getName() == 'namedWithDefault');
      expect(namedWithDefault.getIsNamed(), isTrue);
      expect(namedWithDefault.getHasDefaultValue(), isTrue);
      expect(namedWithDefault.getDefaultValue(), equals('default'));
    });
  });

  group('ParameterDeclaration Type Information', () {
    test('should handle generic type parameters', () {
      final genericClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'GenericParamClass');
      
      final constructor = genericClass.getConstructors().first;
      final params = constructor.getParameters();
      
      final valueParam = params.firstWhere((p) => p.getName() == 'value');
      expect(valueParam.getLinkDeclaration(), isNotNull);
      
      final itemsParam = params.firstWhere((p) => p.getName() == 'items');
      expect(itemsParam.getIsNullable(), isTrue);
      expect(itemsParam.getLinkDeclaration().getName(), contains('List'));
    });

    test('should handle complex nested types', () {
      final nullableClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'NullableParamClass');
      
      final methods = nullableClass.getMethods();
      final complexMethod = methods.firstWhere((m) => m.getName() == 'methodWithComplexNullability');
      final params = complexMethod.getParameters();
      
      final itemsParam = params.firstWhere((p) => p.getName() == 'items');
      expect(itemsParam.getLinkDeclaration().getName(), contains('List'));
      
      final dataParam = params.firstWhere((p) => p.getName() == 'data');
      expect(dataParam.getLinkDeclaration().getName(), contains('Map'));
      expect(dataParam.getIsNullable(), isTrue);
    });

    test('should handle function type parameters', () {
      final functionClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'FunctionParamClass');
      
      final constructor = functionClass.getConstructors().first;
      final params = constructor.getParameters();
      
      final transformerParam = params.firstWhere((p) => p.getName() == 'transformer');
      expect(transformerParam.getLinkDeclaration().getName(), contains('Function'));
      
      final callbackParam = params.firstWhere((p) => p.getName() == 'callback');
      expect(callbackParam.getIsNullable(), isTrue);
      expect(callbackParam.getLinkDeclaration().getName(), contains('Function'));
    });

    test('should handle record type parameters', () {
      final recordClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'RecordParamClass');
      
      final constructor = recordClass.getConstructors().first;
      final params = constructor.getParameters();
      
      final positionalRecord = params.firstWhere((p) => p.getName() == 'positionalRecord');
      expect(positionalRecord.getLinkDeclaration().getName(), equals('(String, int)'));
      
      final namedRecord = params.firstWhere((p) => p.getName() == 'namedRecord');
      expect(namedRecord.getIsNamed(), isTrue);
      expect(namedRecord.getIsRequired(), isTrue);
    });
  });

  group('ParameterDeclaration Default Values', () {
    test('should detect default values in parameters', () {
      final simpleClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'SimpleParamClass');
      
      final methods = simpleClass.getMethods();
      final method = methods.firstWhere((m) => m.getName() == 'methodWithDefaults');
      final params = method.getParameters();
      
      final defaultValueParam = params.firstWhere((p) => p.getName() == 'defaultValue');
      expect(defaultValueParam.getHasDefaultValue(), isTrue);
      expect(defaultValueParam.getDefaultValue(), equals(42));
      
      final optionalParam = params.firstWhere((p) => p.getName() == 'optional');
      expect(optionalParam.getHasDefaultValue(), isFalse);
      expect(optionalParam.getDefaultValue(), isNull);
    });

    test('should handle complex default values', () {
      final complexClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ComplexParamClass');
      
      final constructor = complexClass.getConstructors().first;
      final params = constructor.getParameters();
      
      final listParam = params.firstWhere((p) => p.getName() == 'listParam');
      expect(listParam.getIsNullable(), isTrue);
      // Note: Default value might be handled in initializer list, not as parameter default
    });
  });

  group('ParameterDeclaration Inheritance', () {
    test('should handle parameters in inheritance chain', () {
      final superClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'SuperParamClass');
      
      final constructor = superClass.getConstructors().first;
      final params = constructor.getParameters();
      
      // Should have parameters from parent and child
      expect(params.any((p) => p.getName() == 'requiredParam'), isTrue);
      expect(params.any((p) => p.getName() == 'optionalPositional'), isTrue);
      expect(params.any((p) => p.getName() == 'additional'), isTrue);
      
      final additionalParam = params.firstWhere((p) => p.getName() == 'additional');
      expect(additionalParam.getIsNullable(), isTrue);
      expect(additionalParam.getIsOptional(), isTrue);
    });

    test('should handle super constructor parameters', () {
      final superConstructorClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'SuperConstructorParamClass');
      
      final constructor = superConstructorClass.getConstructors().first;
      final params = constructor.getParameters();
      
      expect(params.length, equals(3));
      expect(params.any((p) => p.getName() == 'param1'), isTrue);
      expect(params.any((p) => p.getName() == 'param2'), isTrue);
      expect(params.any((p) => p.getName() == 'extra'), isTrue);
    });
  });

  group('ParameterDeclaration Constructor Variations', () {
    test('should handle different constructor types', () {
      final variationsClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ConstructorParamVariations');
      
      final constructors = variationsClass.getConstructors();
      expect(constructors.length, equals(5));
      
      // Default constructor
      final defaultConstructor = constructors.firstWhere((c) => c.getName() == '');
      final defaultParams = defaultConstructor.getParameters();
      expect(defaultParams.length, equals(2));
      
      // Named constructor
      final namedConstructor = constructors.firstWhere((c) => c.getName() == 'named');
      final namedParams = namedConstructor.getParameters();
      expect(namedParams.length, equals(2));
      expect(namedParams.every((p) => p.getIsNamed()), isTrue);
      
      // Factory constructor
      final factoryConstructor = constructors.firstWhere((c) => c.getName() == 'factory');
      expect(factoryConstructor.getIsFactory(), isTrue);
      
      // Const constructor
      final constConstructor = constructors.firstWhere((c) => c.getName() == 'constant');
      expect(constConstructor.getIsConst(), isTrue);
      
      // Private constructor (might not be accessible)
      final privateConstructors = constructors.where((c) => c.getName().startsWith('_'));
      expect(privateConstructors.isNotEmpty, isTrue);
    });
  });

  group('ParameterDeclaration Complex Scenarios', () {
    test('should handle varargs-like parameters', () {
      final varArgsClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'VarArgsParamClass');
      
      final constructor = varArgsClass.getConstructors().first;
      final params = constructor.getParameters();
      
      expect(params.length, equals(4));
      
      // First two are required
      final first = params.firstWhere((p) => p.getName() == 'first');
      final second = params.firstWhere((p) => p.getName() == 'second');
      expect(first.getIsOptional(), isFalse);
      expect(second.getIsOptional(), isFalse);
      
      // Last two are optional
      final third = params.firstWhere((p) => p.getName() == 'third');
      final fourth = params.firstWhere((p) => p.getName() == 'fourth');
      expect(third.getIsOptional(), isTrue);
      expect(fourth.getIsOptional(), isTrue);
      expect(third.getIsNullable(), isTrue);
      expect(fourth.getIsNullable(), isTrue);
    });

    test('should handle interface implementation parameters', () {
      final interfaceClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'InterfaceParamClass');
      
      final methods = interfaceClass.getMethods();
      final compareToMethod = methods.firstWhere((m) => m.getName() == 'compareTo');
      final params = compareToMethod.getParameters();
      
      expect(params.length, equals(1));
      final otherParam = params.first;
      expect(otherParam.getLinkDeclaration().getName(), contains('InterfaceParamClass'));
    });

    test('should handle operator parameters', () {
      final interfaceClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'InterfaceParamClass');
      
      final methods = interfaceClass.getMethods();
      final greaterMethod = methods.firstWhere((m) => m.getName() == '>');
      final params = greaterMethod.getParameters();
      
      expect(params.length, equals(1));
      final otherParam = params.first;
      expect(otherParam.getLinkDeclaration().getName(), contains('InterfaceParamClass'));
    });
  });
}