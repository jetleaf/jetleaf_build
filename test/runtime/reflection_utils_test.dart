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

import 'package:jetleaf_build/src/utils/reflection_utils.dart';
import 'package:test/test.dart';
import 'dart:mirrors';

/// A dummy class used for testing reflection.
class User {
  final String name;
  User(this.name);
}

/// Another dummy class to verify multiple types.
class Admin extends User {
  Admin(super.name);
}

/// A function for testing.
void testFunction(int x, String y) {}

/// Another function for testing.
int anotherFunction(double d) => d.toInt();

void main() {
  group('ReflectionUtils', () {
    test('findQualifiedName returns a fully qualified name for an instance', () {
      final user = User('Alice');
      final qualifiedName = ReflectionUtils.findQualifiedName(user);

      // Extract mirror information manually for comparison
      final mirror = reflect(user);
      final classMirror = mirror.type;
      final className = MirrorSystem.getName(classMirror.simpleName);
      final libraryUri = classMirror.owner?.location?.sourceUri.toString() ??
          (classMirror.location?.sourceUri.toString() ?? 'unknown');
      final expected = '$libraryUri.$className'.replaceAll('..', '.');

      expect(qualifiedName, equals(expected));
      expect(qualifiedName, contains(className));
      expect(qualifiedName, contains('.User'));
    });

    test('findQualifiedNameFromType returns a fully qualified name for a Type', () {
      final qualifiedName = ReflectionUtils.findQualifiedNameFromType(Admin);

      final typeMirror = reflectType(Admin);
      final typeName = MirrorSystem.getName(typeMirror.simpleName);
      final libraryUri = typeMirror.location?.sourceUri.toString() ?? 'unknown';
      final expected = '$libraryUri.$typeName'.replaceAll('..', '.');

      expect(qualifiedName, equals(expected));
      expect(qualifiedName, contains('.Admin'));
    });

    test('findQualifiedNameFromType for core type (int)', () {
      final qualifiedName = ReflectionUtils.findQualifiedNameFromType(int);

      expect(qualifiedName, contains('dart:core'));
      expect(qualifiedName, endsWith('.int'));
    });

    test('buildQualifiedName formats URIs correctly', () {
      final result = ReflectionUtils.buildQualifiedName('User', 'package:test_app/models/user.dart');
      expect(result, equals('package:test_app/models/user.dart.User'));
    });
  });

  // New tests for isThisARecord
  group('isThisARecord', () {
    test('returns true for Dart records', () {
      // Test with record instances
      final simpleRecord = (42, 'hello');
      final namedRecord = (x: 1, y: 2.0);
      final emptyRecord = ();
      
      expect(ReflectionUtils.isThisARecord(simpleRecord), isTrue);
      expect(ReflectionUtils.isThisARecord(namedRecord), isTrue);
      expect(ReflectionUtils.isThisARecord(emptyRecord), isTrue);
    });

    test('returns true for TypeMirror of Record', () {
      final typeMirror = reflectType(Record);
      expect(ReflectionUtils.isThisARecord(typeMirror), isTrue);
    });

    test('returns false for non-record instances', () {
      final user = User('Alice');
      final string = 'hello';
      final number = 42;
      final list = [1, 2, 3];
      
      expect(ReflectionUtils.isThisARecord(user), isFalse);
      expect(ReflectionUtils.isThisARecord(string), isFalse);
      expect(ReflectionUtils.isThisARecord(number), isFalse);
      expect(ReflectionUtils.isThisARecord(list), isFalse);
    });

    test('returns false for TypeMirror of non-record types', () {
      expect(ReflectionUtils.isThisARecord(reflectType(String)), isFalse);
      expect(ReflectionUtils.isThisARecord(reflectType(List)), isFalse);
      expect(ReflectionUtils.isThisARecord(reflectType(User)), isFalse);
    });

    test('handles nested reflection correctly', () {
      final record = (x: 1, y: 2);
      // This should reflect the instance type and check if it's a record
      expect(ReflectionUtils.isThisARecord(record), isTrue);
    });
  });

  // New tests for isThisAFunction
  group('isThisAFunction', () {
    test('returns true for function instances', () {
      // Test with various function types
      expect(ReflectionUtils.isThisAFunction(testFunction), isTrue);
      expect(ReflectionUtils.isThisAFunction(anotherFunction), isTrue);
      
      // Test with closures
      int closure(int x) => x * 2;
      expect(ReflectionUtils.isThisAFunction(closure), isTrue);
      
      // Test with anonymous functions
      expect(ReflectionUtils.isThisAFunction(() => 42), isTrue);
    });

    test('returns true for FunctionTypeMirror', () {
      // Get FunctionTypeMirror for a function type
      final funcTypeMirror = reflect(testFunction).type;
      expect(ReflectionUtils.isThisAFunction(funcTypeMirror), isTrue);
      
      // Get FunctionTypeMirror for Function type itself
      final functionTypeMirror = reflectType(Function);
      expect(ReflectionUtils.isThisAFunction(functionTypeMirror), isFalse); // this is a class mirror
    });

    test('returns false for non-function instances', () {
      final user = User('Alice');
      final string = 'hello';
      final number = 42;
      final list = [1, 2, 3];
      
      expect(ReflectionUtils.isThisAFunction(user), isFalse);
      expect(ReflectionUtils.isThisAFunction(string), isFalse);
      expect(ReflectionUtils.isThisAFunction(number), isFalse);
      expect(ReflectionUtils.isThisAFunction(list), isFalse);
    });

    test('returns false for TypeMirror of non-function types', () {
      expect(ReflectionUtils.isThisAFunction(reflectType(String)), isFalse);
      expect(ReflectionUtils.isThisAFunction(reflectType(List)), isFalse);
      expect(ReflectionUtils.isThisAFunction(reflectType(User)), isFalse);
      expect(ReflectionUtils.isThisAFunction(reflectType(int)), isFalse);
    });

    test('handles method references', () {
      // Test with a method reference (though it's still a function)
      expect(ReflectionUtils.isThisAFunction(print), isTrue);
    });

    test('handles function-typed variables', () {
      // Create a variable with a function type
      Function myFunc = testFunction;
      expect(ReflectionUtils.isThisAFunction(myFunc), isTrue);
      
      // Create a specific function type
      void Function(int, String) typedFunc = testFunction;
      expect(ReflectionUtils.isThisAFunction(typedFunc), isTrue);
    });
  });
}