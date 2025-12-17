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

// ignore_for_file: unused_local_variable, deprecated_member_use_from_same_package

import 'package:test/test.dart';
import 'package:jetleaf_build/jetleaf_build.dart';
import 'runtime_hint_implementations.dart';

void main() async {
  setUpAll(() async {
    await runTestScan(filesToLoad: []);
  });

  group('RuntimeHint Discovery and Registration', () {
    test('should discover RuntimeHintProvider implementations', () {
      final classes = Runtime.getAllClasses().toList();
      
      final providerClasses = classes.where((c) {
        final cls = c.asClass();
        if (cls == null) return false;
        
        final methods = cls.getMethods();
        return methods.any((m) => m.getName() == 'createHint');
      }).toList();
      
      expect(providerClasses.length, greaterThanOrEqualTo(2)); // ComplexRuntimeHintProvider and DiscoverableRuntimeHintProvider
    });

    test('should find annotations that are RuntimeHints', () {
      final annotatedClass = Runtime.getAllClasses()
          .firstWhere((c) => c.getName() == 'AnnotatedStringUser');
      
      final annotations = annotatedClass.getAnnotations();
      
      // Should find StringRuntimeHintAnnotation annotation
      final hintAnnotations = annotations.where((a) {
        final instance = a.getInstance();
        return instance is RuntimeHint;
      }).toList();
      
      expect(hintAnnotations, isNotEmpty);
      expect(hintAnnotations.first.getInstance(), isA<StringRuntimeHintAnnotation>());
    });

    test('should find annotations that are RuntimeHintProviders', () {
      final annotatedClass = Runtime.getAllClasses()
          .firstWhere((c) => c.getName() == 'AnnotatedIntUser');
      
      final annotations = annotatedClass.getAnnotations();
      
      final providerAnnotations = annotations.where((a) {
        final instance = a.getInstance();
        return instance is RuntimeHintProvider;
      }).toList();
      
      expect(providerAnnotations, isNotEmpty);
      expect(providerAnnotations.first.getInstance(), isA<IntRuntimeHintProviderAnnotation>());
    });
  });

  group('RuntimeHintDescriptor Resolution', () {
    test('should not instantiate abstract RuntimeHint classes', () {
      final abstractClass = Runtime.getAllClasses()
          .firstWhere((c) => c.getName() == 'AbstractRuntimeHintClass');
      
      expect(abstractClass.getIsAbstract(), isTrue);
    });
  });

  group('RuntimeHint Integration with ClassDeclaration', () {
    test('ClassDeclaration.newInstance should use RuntimeHint if available', () {
      final userClass = Runtime.getAllClasses()
          .firstWhere((c) => c.getName() == 'User');
      
      // Create a User instance through reflection
      final instance = userClass.newInstance({
        'name': 'John',
        'age': 30,
      });
      
      expect(instance, isA<User>());
      final user = instance as User;
      expect(user.name, equals('John'));
      expect(user.age, equals(30));
    });

    test('MethodDeclaration.invoke should use RuntimeHint for method calls', () {
      final userClass = Runtime.getAllClasses()
          .firstWhere((c) => c.getName() == 'User');
      
      final instance = User('Alice', 25);
      final methods = userClass.getMethods();
      
      final greetingMethod = methods.firstWhere((m) => m.getName() == 'greeting');
      final result = greetingMethod.invoke(instance, {});
      
      expect(result, equals('Hello, Alice!'));
    });

    test('FieldDeclaration.getValue should use RuntimeHint for field access', () {
      final userClass = Runtime.getAllClasses()
          .firstWhere((c) => c.getName() == 'User');
      
      final instance = User('Bob', 35);
      final fields = userClass.getFields();
      
      final nameField = fields.firstWhere((f) => f.getName() == 'name');
      final nameValue = nameField.getValue(instance);
      
      expect(nameValue, equals('Bob'));
      
      final ageField = fields.firstWhere((f) => f.getName() == 'age');
      final ageValue = ageField.getValue(instance);
      
      expect(ageValue, equals(35));
    });

    test('should handle String operations with RuntimeHint', () {
      final stringClass = Runtime.getAllClasses()
          .firstWhere((c) => c.getName() == 'String');
      
      final instance = 'Hello World';
      final methods = stringClass.getMethods();
      
      // Test method invocation
      final toUpperCaseMethod = methods.firstWhere((m) => m.getName() == 'toUpperCase');
      final result = toUpperCaseMethod.invoke(instance, {});
      
      expect(result, equals('HELLO WORLD'));
    });

    test('should handle int operations with RuntimeHint', () {
      final intClass = Runtime.getAllClasses()
          .firstWhere((c) => c.getName() == 'int');
      
      final instance = 42;
      final methods = intClass.getMethods();
      
      final absMethod = methods.firstWhere((m) => m.getName() == 'abs');
      final result = absMethod.invoke(instance, {});
      
      expect(result, equals(42));
      
      final toStringMethod = methods.firstWhere((m) => m.getName() == 'toString');
      final stringResult = toStringMethod.invoke(instance, {});
      
      expect(stringResult, equals('42'));
    });
  });

  group('RuntimeHint Edge Cases', () {
    test('should handle RuntimeHintProvider creating RuntimeHint', () {
      final provider = ComplexRuntimeHintProvider();
      final hint = provider.createHint();
      
      expect(hint, isA<ComplexRuntimeHint>());
      expect(hint.obtainTypeOfRuntimeHint(), equals(Map));
    });

    test('should handle annotation-based RuntimeHintProvider', () {
      final provider = IntRuntimeHintProviderAnnotation();
      final hint = provider.createHint();
      
      expect(hint, isA<VerboseIntRuntimeHint>());
    });
  });

  group('RuntimeHint Execution Flow', () {
    test('should demonstrate hint execution chain', () {
      // Create a hint descriptor and add our hints
      final descriptor = DefaultRuntimeHintDescriptor();
      descriptor.addHint(const StringRuntimeHint());
      descriptor.addHint(const IntRuntimeHint());
      descriptor.addHint(const UserRuntimeHint());
      
      // Get hints from descriptor
      final stringHint = descriptor.getHint<String>();
      expect(stringHint, isNotNull);
      expect(stringHint!.obtainTypeOfRuntimeHint(), equals(String));
      
      final intHint = descriptor.getHint<int>();
      expect(intHint, isNotNull);
      expect(intHint!.obtainTypeOfRuntimeHint(), equals(int));
      
      final userHint = descriptor.getHint<User>();
      expect(userHint, isNotNull);
      expect(userHint!.obtainTypeOfRuntimeHint(), equals(User));
    });

    test('should show hint iteration', () {
      final descriptor = DefaultRuntimeHintDescriptor();
      descriptor.addHint(const StringRuntimeHint());
      descriptor.addHint(const IntRuntimeHint());
      descriptor.addHint(const UserRuntimeHint());
      
      final hints = descriptor.toList();
      expect(hints.length, equals(3));
      
      final hintTypes = hints.map((h) => h.obtainTypeOfRuntimeHint()).toList();
      expect(hintTypes, contains(String));
      expect(hintTypes, contains(int));
      expect(hintTypes, contains(User));
    });
  });

  group('RuntimeHint Performance and Integration', () {
    test('should demonstrate mixed hint sources working together', () {
      // Test that we can discover all types of hints:
      // 1. Direct RuntimeHint implementations
      // 2. RuntimeHintProvider implementations  
      // 3. Annotation-based RuntimeHints
      // 4. Annotation-based RuntimeHintProviders
      
      final classes = Runtime.getAllClasses().toList();
      
      // Count different types of hint-related classes
      int directHints = 0;
      int hintProviders = 0;
      int abstractHints = 0;
      
      for (final cls in classes) {
        final classDecl = cls.asClass();
        if (classDecl == null) continue;
        
        if (classDecl.getIsAbstract() && classDecl.getName().contains('RuntimeHint')) {
          abstractHints++;
        }
        
        final methods = classDecl.getMethods();
        final hasObtainType = methods.any((m) => m.getName() == 'obtainTypeOfRuntimeHint');
        final hasCreateHint = methods.any((m) => m.getName() == 'createHint');
        
        if (hasObtainType && !classDecl.getIsAbstract()) {
          directHints++;
        }
        
        if (hasCreateHint && !classDecl.getIsAbstract()) {
          hintProviders++;
        }
      }
      
      expect(directHints, greaterThanOrEqualTo(4));
      expect(hintProviders, greaterThanOrEqualTo(2));
    });
  });
}