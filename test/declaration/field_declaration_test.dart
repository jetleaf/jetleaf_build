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

// Classes with various field types
class FieldTestClass {
  // Various field modifiers
  final String finalField;
  late String lateField;
  static String staticField = 'static';
  static const String constField = 'const';
  String? nullableField;
  String normalField;
  
  // Complex field types
  final List<String> stringList;
  final Map<String, dynamic> dataMap;
  final Set<int> numberSet;
  
  // Generic field
  final Comparable<dynamic> comparableField;
  
  FieldTestClass(
    this.finalField,
    this.normalField,
    this.stringList,
    this.dataMap,
    this.numberSet,
    this.comparableField,
  ) {
    lateField = 'initialized';
  }
  
  // Named constructor with different initialization
  FieldTestClass.named() 
    : finalField = 'named',
      normalField = '',
      stringList = [],
      dataMap = {},
      numberSet = {},
      comparableField = 0;
}

class InheritanceFieldClass extends FieldTestClass {
  final String inheritedField;
  
  InheritanceFieldClass(
    super.finalField,
    super.normalField,
    super.stringList,
    super.dataMap,
    super.numberSet,
    super.comparableField,
    this.inheritedField,
  );
}

class PrivateFieldClass {
  final String _privateField;
  final String publicField;
  
  PrivateFieldClass(this._privateField, this.publicField);
}

class GenericFieldClass<T> {
  final T genericField;
  final List<T> genericList;
  
  GenericFieldClass(this.genericField, this.genericList);
}

class DefaultValueClass {
  final String fieldWithDefault;
  final String? nullableWithDefault;
  
  DefaultValueClass({
    this.fieldWithDefault = 'default',
    this.nullableWithDefault,
  });
}

class LateInitClass {
  late String lateInitField;
  late final String lateFinalField;
  
  LateInitClass() {
    lateInitField = 'init';
    lateFinalField = 'final';
  }
}

class ComplexTypeFieldClass {
  final Map<String, List<Map<String, int>>> complexField;
  final Future<List<String>> futureListField;
  final Stream<int> streamField;
  
  ComplexTypeFieldClass(
    this.complexField,
    this.futureListField,
    this.streamField,
  );
}

void main() async {
  setUpAll(() async {
    await runTestScan(filesToLoad: []);
  });

  group('FieldDeclaration Basic Properties', () {
    test('should correctly identify field modifiers', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'FieldTestClass');
      
      final fields = testClass.getFields();
      
      final finalField = fields.firstWhere((f) => f.getName() == 'finalField');
      expect(finalField.getIsFinal(), isTrue);
      expect(finalField.getIsStatic(), isFalse);
      expect(finalField.getIsConst(), isFalse);
      expect(finalField.getIsLate(), isFalse);
      
      final lateField = fields.firstWhere((f) => f.getName() == 'lateField');
      expect(lateField.getIsLate(), isTrue);
      expect(lateField.getIsFinal(), isFalse);
      
      final staticField = fields.firstWhere((f) => f.getName() == 'staticField');
      expect(staticField.getIsStatic(), isTrue);
      expect(staticField.getIsFinal(), isFalse);
      
      final constField = fields.firstWhere((f) => f.getName() == 'constField');
      expect(constField.getIsConst(), isTrue);
      expect(constField.getIsStatic(), isTrue);
      expect(constField.getIsFinal(), isTrue);
    });

    test('should correctly identify nullable fields', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'FieldTestClass');
      
      final fields = testClass.getFields();
      
      final nullableField = fields.firstWhere((f) => f.getName() == 'nullableField');
      expect(nullableField.isNullable(), isTrue);
      
      final normalField = fields.firstWhere((f) => f.getName() == 'normalField');
      expect(normalField.isNullable(), isFalse);
      
      final finalField = fields.firstWhere((f) => f.getName() == 'finalField');
      expect(finalField.isNullable(), isFalse);
    });
  });

  group('FieldDeclaration Access Control', () {
    test('should identify public vs private fields', () {
      final privateClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'PrivateFieldClass');
      
      final fields = privateClass.getFields();
      
      final privateField = fields.firstWhere((f) => f.getName() == '_privateField');
      expect(privateField.getIsPublic(), isFalse);
      
      final publicField = fields.firstWhere((f) => f.getName() == 'publicField');
      expect(publicField.getIsPublic(), isTrue);
    });

    test('should not include inherited fields directly', () {
      final inheritedClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'InheritanceFieldClass');
      
      final fields = inheritedClass.getFields();
      
      // Should have both inherited and own fields
      expect(fields.any((f) => f.getName() == 'inheritedField'), isTrue);
      expect(fields.any((f) => f.getName() == 'finalField'), isFalse);
      expect(fields.any((f) => f.getName() == 'normalField'), isFalse);
    });

    test('should include inherited fields directly', () {
      final inheritedClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'InheritanceFieldClass');
      final superClass = Runtime.getAllClasses().firstWhere((c) => c.getQualifiedName() == inheritedClass.getSuperClass()?.getPointerQualifiedName());
      
      final fields = [...inheritedClass.getFields(), ...superClass.getFields()];
      
      // Should have both inherited and own fields
      expect(fields.any((f) => f.getName() == 'inheritedField'), isTrue);
      expect(fields.any((f) => f.getName() == 'finalField'), isTrue);
      expect(fields.any((f) => f.getName() == 'normalField'), isTrue);
    });
  });

  group('FieldDeclaration Type Information', () {
    test('should handle generic field types', () {
      final genericClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'GenericFieldClass');
      
      final fields = genericClass.getFields();
      
      final genericField = fields.firstWhere((f) => f.getName() == 'genericField');
      expect(genericField.getLinkDeclaration(), isNotNull);
      
      final genericList = fields.firstWhere((f) => f.getName() == 'genericList');
      expect(genericList.getLinkDeclaration(), isNotNull);
    });

    test('should handle complex nested types', () {
      final complexClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'ComplexTypeFieldClass');
      
      final fields = complexClass.getFields();
      
      final complexField = fields.firstWhere((f) => f.getName() == 'complexField');
      final type = complexField.getLinkDeclaration();
      expect(type, isNotNull);
      
      final futureField = fields.firstWhere((f) => f.getName() == 'futureListField');
      expect(futureField.getLinkDeclaration(), isNotNull);
      
      final streamField = fields.firstWhere((f) => f.getName() == 'streamField');
      expect(streamField.getLinkDeclaration(), isNotNull);
    });

    test('should handle collection field types', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'FieldTestClass');
      
      final fields = testClass.getFields();
      
      final listField = fields.firstWhere((f) => f.getName() == 'stringList');
      expect(listField.getLinkDeclaration().getName(), contains('List'));
      
      final mapField = fields.firstWhere((f) => f.getName() == 'dataMap');
      expect(mapField.getLinkDeclaration().getName(), contains('Map'));
      
      final setField = fields.firstWhere((f) => f.getName() == 'numberSet');
      expect(setField.getLinkDeclaration().getName(), contains('Set'));
    });
  });

  group('FieldDeclaration Value Access', () {
    test('should be able to read field values', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'FieldTestClass');
      
      final instance = FieldTestClass(
        'finalValue',
        'normalValue',
        ['item1', 'item2'],
        {'key': 'value'},
        {1, 2, 3},
        42,
      );
      
      final fields = testClass.getFields();
      
      final finalField = fields.firstWhere((f) => f.getName() == 'finalField');
      expect(finalField.getValue(instance), equals('finalValue'));
      
      final normalField = fields.firstWhere((f) => f.getName() == 'normalField');
      expect(normalField.getValue(instance), equals('normalValue'));
      
      final listField = fields.firstWhere((f) => f.getName() == 'stringList');
      expect(listField.getValue(instance), equals(['item1', 'item2']));
    });

    test('should be able to write to mutable fields', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'FieldTestClass');
      
      final instance = FieldTestClass(
        'finalValue',
        'normalValue',
        [],
        {},
        {},
        0,
      );
      
      final fields = testClass.getFields();
      
      final normalField = fields.firstWhere((f) => f.getName() == 'normalField');
      expect(() => normalField.setValue(instance, 'newValue'), returnsNormally);
      expect(instance.normalField, equals('newValue'));
      
      final nullableField = fields.firstWhere((f) => f.getName() == 'nullableField');
      expect(() => nullableField.setValue(instance, null), returnsNormally);
      expect(instance.nullableField, isNull);
    });

    test('should not allow writing to final fields', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'FieldTestClass');
      
      final instance = FieldTestClass(
        'finalValue',
        'normalValue',
        [],
        {},
        {},
        0,
      );
      
      final fields = testClass.getFields();
      
      final finalField = fields.firstWhere((f) => f.getName() == 'finalField');
      expect(
        () => finalField.setValue(instance, 'newValue'),
        throwsA(isA<FieldMutationException>()),
      );
    });
  });

  group('FieldDeclaration Static Fields', () {
    test('should handle static field access', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'FieldTestClass');
      
      final staticFields = testClass.getFields().where((field) => field.getIsStatic());
      expect(staticFields.length, equals(2));
      
      final staticField = staticFields.firstWhere((f) => f.getName() == 'staticField');
      expect(staticField.getValue(FieldTestClass), equals('static'));
      
      expect(() => staticField.setValue(FieldTestClass, 'newStatic'), returnsNormally);
      expect(FieldTestClass.staticField, equals('newStatic'));
    });

    test('should handle const static fields', () {
      final testClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'FieldTestClass');
      
      final staticFields = testClass.getFields().where((field) => field.getIsStatic());
      final constField = staticFields.firstWhere((f) => f.getName() == 'constField');
      
      expect(constField.getValue(FieldTestClass), equals('const'));
      expect(constField.getIsConst(), isTrue);
      expect(() => constField.setValue(FieldTestClass, 'newValue'), throwsA(anything));
    });
  });

  group('FieldDeclaration Late Fields', () {
    test('should handle late initialization', () {
      final lateClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'LateInitClass');
      
      final instance = LateInitClass();
      final fields = lateClass.getFields();
      
      final lateField = fields.firstWhere((f) => f.getName() == 'lateInitField');
      expect(lateField.getValue(instance), equals('init'));
      
      final lateFinalField = fields.firstWhere((f) => f.getName() == 'lateFinalField');
      expect(lateFinalField.getValue(instance), equals('final'));
      expect(lateFinalField.getIsFinal(), isTrue);
    });
  });

  group('FieldDeclaration Default Values', () {
    test('should handle fields with default values', () {
      final defaultValueClass = Runtime.getAllClasses().firstWhere((c) => c.getName() == 'DefaultValueClass');
      
      final instance = DefaultValueClass();
      final fields = defaultValueClass.getFields();
      
      final fieldWithDefault = fields.firstWhere((f) => f.getName() == 'fieldWithDefault');
      expect(fieldWithDefault.getValue(instance), equals('default'));
      
      final nullableField = fields.firstWhere((f) => f.getName() == 'nullableWithDefault');
      expect(nullableField.getValue(instance), isNull);
    });
  });
}