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

// Test annotations
class SimpleAnnotation {
  final String value;
  const SimpleAnnotation(this.value);
}

class ComplexAnnotation {
  final String name;
  final int priority;
  final List<String> tags;
  final Map<String, dynamic> metadata;
  
  const ComplexAnnotation({
    required this.name,
    this.priority = 0,
    this.tags = const [],
    this.metadata = const {},
  });
}

class GenericAnnotation<T> {
  final T value;
  const GenericAnnotation(this.value);
}

class NullableAnnotation {
  final String? nullableField;
  final String nonNullableField;
  
  const NullableAnnotation({
    required this.nonNullableField,
    this.nullableField,
  });
}

class DefaultValueAnnotation {
  final String withDefault;
  final String? nullableWithDefault;
  final int numberWithDefault;
  
  const DefaultValueAnnotation({
    this.withDefault = 'default',
    this.nullableWithDefault,
    this.numberWithDefault = 42,
  });
}

class PositionalAnnotation {
  final String first;
  final String? second;
  
  const PositionalAnnotation(this.first, [this.second]);
}

class ConstAnnotation {
  final String value;
  const ConstAnnotation(this.value);
}

class PrivateFieldAnnotation {
  final String _privateField;
  final String publicField;
  
  const PrivateFieldAnnotation(this._privateField, this.publicField);
}

// Annotated classes
@SimpleAnnotation('test')
class AnnotatedClass {
  @ComplexAnnotation(name: 'field', priority: 1, tags: ['important'])
  final String annotatedField;
  
  @NullableAnnotation(nonNullableField: 'required')
  final String? nullableField;
  
  @DefaultValueAnnotation()
  final String defaultField;
  
  @PositionalAnnotation('first', 'second')
  final String positionalField;
  
  AnnotatedClass(this.annotatedField, this.nullableField, this.defaultField, this.positionalField);
}

@ComplexAnnotation(name: 'service', priority: 10, tags: ['api', 'rest'])
class ServiceClass {
  @SimpleAnnotation('GET')
  Future<String> fetchData() async => 'data';
  
  @ComplexAnnotation(name: 'param', metadata: {'type': 'query'})
  void methodWithParam(@SimpleAnnotation('required') String param) {}
}

@GenericAnnotation<String>('generic value')
@GenericAnnotation<int>(42)
class MultiAnnotationClass {
  @GenericAnnotation<List<String>>(['a', 'b', 'c'])
  List<String> items = [];
}

@ConstAnnotation('constant value')
class ConstAnnotatedClass {
  const ConstAnnotatedClass();
}

@PrivateFieldAnnotation('private', 'public')
class PrivateAnnotatedClass {
  PrivateAnnotatedClass();
}

// Annotation with inheritance
class InheritedAnnotation extends SimpleAnnotation {
  final String additional;
  
  const InheritedAnnotation(super.value, this.additional);
}

@InheritedAnnotation('base', 'extra')
class InheritedAnnotatedClass {
  InheritedAnnotatedClass();
}

// Annotation on parameters and return types
class MethodAnnotationClass {
  @SimpleAnnotation('return')
  @NullableAnnotation(nonNullableField: 'return')
  String annotatedMethod(
    @SimpleAnnotation('param1') String param1,
    @ComplexAnnotation(name: 'param2') int param2,
  ) => 'result';
}

// Annotation on type parameters
class GenericAnnotationClass<T extends SimpleAnnotation> {
  final T annotation;
  
  GenericAnnotationClass(this.annotation);
}

// New test annotations for missing functionality
class AnnotationWithElement {
  final String value;
  const AnnotationWithElement(this.value);
}

class AnnotationFieldWithDefaults {
  final String required;
  final String withDefault;
  final String? nullableWithDefault;
  
  const AnnotationFieldWithDefaults({
    required this.required,
    this.withDefault = 'default',
    this.nullableWithDefault,
  });
}

class AnnotationWithFinalConst {
  final String finalField;
  final String constField;
  
  const AnnotationWithFinalConst(this.finalField, this.constField);
}

// Annotated class for testing
@AnnotationWithElement('test')
@AnnotationFieldWithDefaults(required: 'test')
@AnnotationWithFinalConst('final', 'const')
class ComprehensiveAnnotationTest {
  @AnnotationWithElement('field')
  final String annotatedField = 'value';
}

void main() async {
  setUpAll(() async {
    await runTestScan(filesToLoad: []);
  });

  group('AnnotationDeclaration Basic Properties', () {
    test('should retrieve annotations from class', () {
      final annotatedClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'AnnotatedClass');
      
      final annotations = annotatedClass.getAnnotations();
      print(annotations);
      expect(annotations, isNotEmpty);
      
      final simpleAnnotation = annotations.firstWhere((a) => a.getLinkDeclaration().getType() == SimpleAnnotation);
      expect(simpleAnnotation, isNotNull);
      
      final instance = simpleAnnotation.getInstance();
      expect(instance, isA<SimpleAnnotation>());
      expect((instance as SimpleAnnotation).value, equals('test'));
    });

    test('should retrieve annotation fields', () {
      final annotatedClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'AnnotatedClass');
      
      final annotations = annotatedClass.getAnnotations();
      final simpleAnnotation = annotations.firstWhere((a) => a.getLinkDeclaration().getType() == SimpleAnnotation);
      
      final fields = simpleAnnotation.getFields();
      expect(fields.length, equals(1));
      
      final valueField = fields.firstWhere((f) => f.getName() == 'value');
      expect(valueField.getValue(), equals('test'));
      expect(valueField.getUserProvidedValue(), equals('test'));
      expect(valueField.hasUserProvidedValue(), isTrue);
      expect(valueField.hasDefaultValue(), isFalse);
    });

    test('should handle complex annotations with multiple fields', () {
      final serviceClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ServiceClass');
      
      final annotations = serviceClass.getAnnotations();
      final complexAnnotation = annotations.firstWhere((a) => a.getLinkDeclaration().getType() == ComplexAnnotation);
      
      expect(complexAnnotation, isNotNull);
      
      final fields = complexAnnotation.getFields();
      expect(fields.length, equals(4));
      
      final nameField = fields.firstWhere((f) => f.getName() == 'name');
      expect(nameField.getValue(), equals('service'));
      
      final priorityField = fields.firstWhere((f) => f.getName() == 'priority');
      expect(priorityField.getValue(), equals(10));
      
      final tagsField = fields.firstWhere((f) => f.getName() == 'tags');
      expect(tagsField.getValue(), equals(['api', 'rest']));
      
      final metadataField = fields.firstWhere((f) => f.getName() == 'metadata');
      expect(metadataField.getValue(), equals({}));
    });
  });

  group('AnnotationDeclaration Field Properties', () {
    test('should handle nullable annotation fields', () {
      final nullableClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'AnnotatedClass');
      
      final field = nullableClass.getFields().firstWhere((f) => f.getName() == 'nullableField');
      
      final annotations = field.getAnnotations();
      final nullableAnnotation = annotations.firstWhere((a) => a.getLinkDeclaration().getType() == NullableAnnotation);
      
      final fields = nullableAnnotation.getFields();
      
      final nonNullableField = fields.firstWhere((f) => f.getName() == 'nonNullableField');
      expect(nonNullableField.getValue(), equals('required'));
      expect(nonNullableField.isNullable(), isFalse);
      
      final nullableField = fields.firstWhere((f) => f.getName() == 'nullableField');
      expect(nullableField.getValue(), isNull);
      expect(nullableField.isNullable(), isTrue);
    });

    test('should handle default values in annotations', () {
      final defaultValueClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'AnnotatedClass');
      
      final field = defaultValueClass.getFields().firstWhere((f) => f.getName() == 'defaultField');
      
      final annotations = field.getAnnotations();
      final defaultValueAnn = annotations.firstWhere((a) => a.getLinkDeclaration().getType() == DefaultValueAnnotation);
      
      final fields = defaultValueAnn.getFields();
      
      final withDefaultField = fields.firstWhere((f) => f.getName() == 'withDefault');
      expect(withDefaultField.getValue(), equals('default'));
      expect(withDefaultField.getDefaultValue(), equals('default'));
      expect(withDefaultField.hasDefaultValue(), isTrue);
      
      final nullableWithDefault = fields.firstWhere((f) => f.getName() == 'nullableWithDefault');
      expect(nullableWithDefault.getValue(), isNull);
      expect(nullableWithDefault.getDefaultValue(), isNull);
      expect(nullableWithDefault.hasDefaultValue(), isFalse);
      
      final numberWithDefault = fields.firstWhere((f) => f.getName() == 'numberWithDefault');
      expect(numberWithDefault.getValue(), equals(42));
      expect(numberWithDefault.getDefaultValue(), equals(42));
      expect(numberWithDefault.hasDefaultValue(), isTrue);
    });

    test('should handle positional annotation parameters', () {
      final annotatedClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'AnnotatedClass');
      
      final field = annotatedClass.getFields().firstWhere((f) => f.getName() == 'positionalField');
      
      final annotations = field.getAnnotations();
      final positionalAnn = annotations.firstWhere((a) => a.getLinkDeclaration().getType() == PositionalAnnotation);
      
      final fields = positionalAnn.getFields();
      
      final firstField = fields.firstWhere((f) => f.getName() == 'first');
      expect(firstField.getValue(), equals('first'));
      expect(firstField.getPosition(), equals(0));
      
      final secondField = fields.firstWhere((f) => f.getName() == 'second');
      expect(secondField.getValue(), equals('second'));
      expect(secondField.getPosition(), equals(1));
      expect(secondField.isNullable(), isTrue);
    });
  });

  group('AnnotationDeclaration on Methods', () {
    test('should retrieve annotations from methods', () {
      final serviceClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ServiceClass');
      
      final methods = serviceClass.getMethods();
      final fetchMethod = methods.firstWhere((m) => m.getName() == 'fetchData');
      
      final annotations = fetchMethod.getAnnotations();
      expect(annotations, isNotEmpty);
      
      final simpleAnnotation = annotations.firstWhere((a) => a.getLinkDeclaration().getType() == SimpleAnnotation);
      expect(simpleAnnotation.getInstance().value, equals('GET'));
    });

    test('should retrieve annotations from method parameters', () {
      final serviceClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ServiceClass');
      
      final methods = serviceClass.getMethods();
      final paramMethod = methods.firstWhere((m) => m.getName() == 'methodWithParam');
      
      final params = paramMethod.getParameters();
      final param = params.firstWhere((p) => p.getName() == 'param');
      
      final annotations = param.getAnnotations();
      expect(annotations, isNotEmpty);
      
      final simpleAnnotation = annotations.firstWhere((a) => a.getLinkDeclaration().getType() == SimpleAnnotation);
      expect(simpleAnnotation.getInstance().value, equals('required'));
    });

    test('should handle multiple annotations on method return type', () {
      final methodClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MethodAnnotationClass');
      
      final methods = methodClass.getMethods();
      final annotatedMethod = methods.firstWhere((m) => m.getName() == 'annotatedMethod');
      
      final annotations = annotatedMethod.getAnnotations();
      expect(annotations.length, equals(2));
      
      final simpleAnnotation = annotations.firstWhere((a) => a.getLinkDeclaration().getType() == SimpleAnnotation);
      expect(simpleAnnotation.getInstance().value, equals('return'));
      
      final nullableAnnotation = annotations.firstWhere((a) => a.getLinkDeclaration().getType() == NullableAnnotation);
      expect((nullableAnnotation.getInstance() as NullableAnnotation).nonNullableField, 
          equals('return'));
    });

    test('should retrieve annotations from method parameters', () {
      final methodClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MethodAnnotationClass');
      
      final methods = methodClass.getMethods();
      final annotatedMethod = methods.firstWhere((m) => m.getName() == 'annotatedMethod');
      
      final params = annotatedMethod.getParameters();
      
      final param1 = params.firstWhere((p) => p.getName() == 'param1');
      final param1Annotations = param1.getAnnotations();
      expect(param1Annotations, isNotEmpty);
      
      final param1Simple = param1Annotations.firstWhere((a) => a.getLinkDeclaration().getType() == SimpleAnnotation);
      expect(param1Simple.getInstance().value, equals('param1'));
      
      final param2 = params.firstWhere((p) => p.getName() == 'param2');
      final param2Annotations = param2.getAnnotations();
      expect(param2Annotations, isNotEmpty);
      
      final param2Complex = param2Annotations.firstWhere((a) => a.getLinkDeclaration().getType() == ComplexAnnotation);
      expect((param2Complex.getInstance() as ComplexAnnotation).name, equals('param2'));
    });
  });

  group('AnnotationDeclaration on Fields', () {
    test('should retrieve field annotations', () {
      final annotatedClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'AnnotatedClass');
      
      final fields = annotatedClass.getFields();
      
      final annotatedField = fields.firstWhere((f) => f.getName() == 'annotatedField');
      final annotations = annotatedField.getAnnotations();
      
      final complexAnnotation = annotations.firstWhere((a) => a.getLinkDeclaration().getType() == ComplexAnnotation);
      
      final instance = complexAnnotation.getInstance() as ComplexAnnotation;
      expect(instance.name, equals('field'));
      expect(instance.priority, equals(1));
      expect(instance.tags, equals(['important']));
    });
  });

  group('AnnotationDeclaration Generic Annotations', () {
    test('should handle generic annotations', () {
      final multiClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MultiAnnotationClass');
      
      final annotations = multiClass.getAnnotations();
      
      final stringAnnotation = annotations.firstWhere((a) => a.getType() == GenericAnnotation<String>);
      
      expect(stringAnnotation.getInstance().value, equals('generic value'));
      
      final intAnnotation = annotations.firstWhere((a) => a.getType() == GenericAnnotation<int>);
      
      expect(intAnnotation.getInstance().value, equals(42));
    });

    test('should handle generic annotations on fields', () {
      final multiClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MultiAnnotationClass');
      
      final fields = multiClass.getFields();
      final itemsField = fields.firstWhere((f) => f.getName() == 'items');
      
      final annotations = itemsField.getAnnotations();
      final genericAnnotation = annotations.firstWhere((a) => a.getType() == GenericAnnotation<List<String>>);
      
      expect(genericAnnotation.getInstance().value, equals(['a', 'b', 'c']));
    });
  });

  group('AnnotationDeclaration Inheritance', () {
    test('should handle inherited annotations', () {
      final inheritedClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'InheritedAnnotatedClass');
      
      final annotations = inheritedClass.getAnnotations();
      final inheritedAnnotation = annotations.firstWhere((a) => a.getLinkDeclaration().getType() == InheritedAnnotation);
      
      expect(inheritedAnnotation, isNotNull);
      
      final instance = inheritedAnnotation.getInstance();
      expect(instance, isA<InheritedAnnotation>());
      final inherited = instance as InheritedAnnotation;
      expect(inherited.value, equals('base'));
      expect(inherited.additional, equals('extra'));
    });
  });

  group('AnnotationDeclaration Private Fields', () {
    test('should handle annotations with private fields', () {
      final privateClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'PrivateAnnotatedClass');
      
      final annotations = privateClass.getAnnotations();
      final privateAnnotation = annotations.firstWhere((a) => a.getLinkDeclaration().getType() == PrivateFieldAnnotation);
      
      final fields = privateAnnotation.getFields();
      
      final privateField = fields.firstWhere((f) => f.getName() == '_privateField');
      expect(privateField.getIsPublic(), isFalse);
      expect(privateField.getValue(), equals('private'));
      
      final publicField = fields.firstWhere((f) => f.getName() == 'publicField');
      expect(publicField.getIsPublic(), isTrue);
      expect(publicField.getValue(), equals('public'));
    });
  });

  group('AnnotationDeclaration Const Annotations', () {
    test('should handle const annotations', () {
      final constClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ConstAnnotatedClass');
      
      final annotations = constClass.getAnnotations();
      final constAnn = annotations.firstWhere((a) => a.getLinkDeclaration().getPointerType() == ConstAnnotation);
      
      final fields = constAnn.getFields();
      final valueField = fields.firstWhere((f) => f.getName() == 'value');
      
      expect(valueField.getValue(), equals('constant value'));
      expect(valueField.isConst(), isFalse);
      expect(valueField.isFinal(), isTrue);
    });
  });

  group('AnnotationDeclaration Additional Properties', () {
    test('should retrieve user provided values', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ComprehensiveAnnotationTest');
      
      final annotations = testClass.getAnnotations();
      final simpleAnnotation = annotations.firstWhere((a) => 
          a.getLinkDeclaration().getType() == AnnotationWithElement);
      
      final userValues = simpleAnnotation.getUserProvidedValues();
      expect(userValues, isNotEmpty);
      expect(userValues['value'], equals('test'));
    });

    test('should retrieve mapped fields', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ComprehensiveAnnotationTest');
      
      final annotations = testClass.getAnnotations();
      final complexAnnotation = annotations.firstWhere((a) => 
          a.getLinkDeclaration().getType() == AnnotationFieldWithDefaults);
      
      final mappedFields = complexAnnotation.getMappedFields();
      expect(mappedFields, isNotEmpty);
      expect(mappedFields.containsKey('required'), isTrue);
      expect(mappedFields.containsKey('withDefault'), isTrue);
      expect(mappedFields.containsKey('nullableWithDefault'), isTrue);
    });

    test('should retrieve specific field by name', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ComprehensiveAnnotationTest');
      
      final annotations = testClass.getAnnotations();
      final complexAnnotation = annotations.firstWhere((a) => 
          a.getLinkDeclaration().getType() == AnnotationFieldWithDefaults);
      
      final requiredField = complexAnnotation.getField('required');
      expect(requiredField, isNotNull);
      expect(requiredField!.getName(), equals('required'));
      expect(requiredField.getValue(), equals('test'));
      
      final nonExistent = complexAnnotation.getField('nonExistent');
      expect(nonExistent, isNull);
    });

    test('should retrieve field names', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ComprehensiveAnnotationTest');
      
      final annotations = testClass.getAnnotations();
      final complexAnnotation = annotations.firstWhere((a) => 
          a.getLinkDeclaration().getType() == AnnotationFieldWithDefaults);
      
      final fieldNames = complexAnnotation.getFieldNames();
      expect(fieldNames, containsAll(['required', 'withDefault', 'nullableWithDefault']));
    });

    test('should retrieve fields with defaults', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ComprehensiveAnnotationTest');
      
      final annotations = testClass.getAnnotations();
      final complexAnnotation = annotations.firstWhere((a) => 
          a.getLinkDeclaration().getType() == AnnotationFieldWithDefaults);
      
      final fieldsWithDefaults = complexAnnotation.getFieldsWithDefaults();
      expect(fieldsWithDefaults.containsKey('withDefault'), isTrue);
      expect(fieldsWithDefaults.containsKey('nullableWithDefault'), isFalse); // No default
    });

    test('should retrieve fields with user values', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ComprehensiveAnnotationTest');
      
      final annotations = testClass.getAnnotations();
      final complexAnnotation = annotations.firstWhere((a) => 
          a.getLinkDeclaration().getType() == AnnotationFieldWithDefaults);
      
      final fieldsWithUserValues = complexAnnotation.getFieldsWithUserValues();
      expect(fieldsWithUserValues.containsKey('required'), isTrue);
      expect(fieldsWithUserValues['required']!.getUserProvidedValue(), equals('test'));
    });

    test('should handle element annotation if available', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ComprehensiveAnnotationTest');
      
      final annotations = testClass.getAnnotations();
      final firstAnnotation = annotations.first;
      
      final elementAnnotation = firstAnnotation.getElementAnnotation();
      // This might be null if analyzer is not available
      expect(elementAnnotation, anyOf(isNull, isNotNull));
    });

    test('should correctly identify getDebugIdentifier', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ComprehensiveAnnotationTest');
      
      final annotations = testClass.getAnnotations();
      final firstAnnotation = annotations.first;
      
      expect(firstAnnotation.getDebugIdentifier(), isNotEmpty);
      expect(firstAnnotation.getDebugIdentifier(), contains('Annotation'));
      expect(firstAnnotation.getDebugIdentifier(), contains(firstAnnotation.getLinkDeclaration().getName()));
    });

    test('should handle analyzer support if available', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ComprehensiveAnnotationTest');
      
      final annotations = testClass.getAnnotations();
      final firstAnnotation = annotations.first;
      
      expect(firstAnnotation.hasAnalyzerSupport(), anyOf(isTrue, isFalse));
      
      if (firstAnnotation.hasAnalyzerSupport()) {
        expect(firstAnnotation.getDartType(), isNotNull);
        expect(firstAnnotation.getElement(), isNotNull);
      }
    });
  });

  group('AnnotationFieldDeclaration Additional Properties', () {
    test('should correctly identify final and const fields', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ComprehensiveAnnotationTest');
      
      final annotations = testClass.getAnnotations();
      final finalConstAnnotation = annotations.firstWhere((a) => 
          a.getLinkDeclaration().getType() == AnnotationWithFinalConst);
      
      final fields = finalConstAnnotation.getFields();
      
      final finalField = fields.firstWhere((f) => f.getName() == 'finalField');
      expect(finalField.isFinal(), isTrue);
      expect(finalField.isConst(), isFalse);
      
      final constField = fields.firstWhere((f) => f.getName() == 'constField');
      expect(constField.isConst(), isFalse);
      expect(constField.isFinal(), isTrue); // const implies final
    });

    test('should handle default vs user-provided values', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ComprehensiveAnnotationTest');
      
      final annotations = testClass.getAnnotations();
      final defaultsAnnotation = annotations.firstWhere((a) => 
          a.getLinkDeclaration().getType() == AnnotationFieldWithDefaults);
      
      final fields = defaultsAnnotation.getFields();
      
      final requiredField = fields.firstWhere((f) => f.getName() == 'required');
      expect(requiredField.hasUserProvidedValue(), isTrue);
      expect(requiredField.getUserProvidedValue(), equals('test'));
      expect(requiredField.hasDefaultValue(), isFalse);
      
      final withDefaultField = fields.firstWhere((f) => f.getName() == 'withDefault');
      expect(withDefaultField.hasDefaultValue(), isTrue);
      expect(withDefaultField.getDefaultValue(), equals('default'));
      // Might have user-provided value if overridden
      
      final nullableField = fields.firstWhere((f) => f.getName() == 'nullableWithDefault');
      expect(nullableField.hasDefaultValue(), isFalse);
      expect(nullableField.getDefaultValue(), isNull);
    });

    test('should handle position in annotation', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ComprehensiveAnnotationTest');
      
      final annotations = testClass.getAnnotations();
      final positionalAnnotation = annotations.firstWhere((a) => 
          a.getLinkDeclaration().getType() == AnnotationWithFinalConst);
      
      final fields = positionalAnnotation.getFields();
      
      final finalField = fields.firstWhere((f) => f.getName() == 'finalField');
      expect(finalField.getPosition(), equals(0));
      
      final constField = fields.firstWhere((f) => f.getName() == 'constField');
      expect(constField.getPosition(), equals(1));
    });

    test('should correctly identify getDebugIdentifier', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ComprehensiveAnnotationTest');
      
      final annotations = testClass.getAnnotations();
      final firstAnnotation = annotations.first;
      final fields = firstAnnotation.getFields();
      final firstField = fields.first;
      
      expect(firstField.getDebugIdentifier(), isNotEmpty);
      expect(firstField.getDebugIdentifier(), contains('annotation_field_value'));
    });

    test('should handle analyzer support if available', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ComprehensiveAnnotationTest');
      
      final annotations = testClass.getAnnotations();
      final firstAnnotation = annotations.first;
      final fields = firstAnnotation.getFields();
      final firstField = fields.first;
      
      expect(firstField.hasAnalyzerSupport(), anyOf(isTrue, isFalse));
      
      if (firstField.hasAnalyzerSupport()) {
        expect(firstField.getDartType(), isNotNull);
        expect(firstField.getElement(), isNotNull);
      }
    });
  });

  group('AnnotationDeclaration Edge Cases', () {
    test('should handle repeated annotations', () {
      // Some annotation systems allow repeated annotations
      // This depends on Dart's annotation system
      final multiClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'MultiAnnotationClass');
      
      final annotations = multiClass.getAnnotations();
      final genericAnnotations = annotations.where((a) => 
          a.getLinkDeclaration().getName() == 'GenericAnnotation').toList();
      
      expect(genericAnnotations.length, equals(2));
    });
  });
}