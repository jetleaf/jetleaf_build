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

// ignore_for_file: unused_element, unused_field

import 'package:test/test.dart';
import 'package:jetleaf_build/jetleaf_build.dart';
import 'dart:io';

// Test classes for class declarations
abstract class AbstractBaseClass {
  String get name;
  void doSomething();
}

class ConcreteClass extends AbstractBaseClass {
  @override
  final String name;
  final int value;
  
  ConcreteClass(this.name, this.value);
  
  @override
  void doSomething() {
    print('Doing something with $name');
  }
  
  void additionalMethod() {
    print('Additional method');
  }
}

sealed class SealedBaseClass {
  const SealedBaseClass();
  
  String get description;
}

final class FirstSealedClass extends SealedBaseClass {
  @override
  String get description => 'First sealed class';
}

final class SecondSealedClass extends SealedBaseClass {
  final int count;
  
  const SecondSealedClass(this.count);
  
  @override
  String get description => 'Second sealed class with count $count';
}

base class BaseClass {
  final String id;
  
  BaseClass(this.id);
}

abstract interface class InterfaceClass {
  void interfaceMethod();
}

final class FinalClass {
  final String data;
  
  FinalClass(this.data);
}

class GenericClass<T> {
  final T value;
  final List<T> items;
  
  GenericClass(this.value, {this.items = const []});
  
  T process(T input) => input;
}

@Generic(ResolvedGenericClass)
class ResolvedGenericClass<T> {
  final T value;
  final List<T> items;
  
  ResolvedGenericClass(this.value, {this.items = const []});
  
  T process(T input) => input;
}

class BoundedGenericClass<T extends Comparable<T>> {
  final List<T> sortedItems;
  
  BoundedGenericClass(this.sortedItems);
  
  T? get max => sortedItems.isEmpty ? null : sortedItems.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
}

class ComplexClass<T extends AbstractBaseClass> implements InterfaceClass {
  final List<T> items;
  
  ComplexClass(this.items);
  
  @override
  void interfaceMethod() {
    print('Interface method with ${items.length} items');
  }
}

mixin class ComparableMixin {}

base class MixedClass extends BaseClass with ComparableMixin {
  final int priority;
  
  MixedClass(super.id, this.priority);
  
  int compareTo(MixedClass other) => priority.compareTo(other.priority);
}

class RecordClass {
  final (String, int) tuple;
  final ({String name, int age}) record;
  
  RecordClass(this.tuple, {required this.record});
}

class AnnotatedClass {
  @Deprecated('Use newMethod instead')
  void oldMethod() {}
  
  @override
  String toString() => 'AnnotatedClass';
}

class NullableFieldClass {
  final String? nullableField;
  final String nonNullableField;
  
  NullableFieldClass(this.nonNullableField, {this.nullableField});
}

class StaticMemberClass {
  static int instanceCount = 0;
  static const String DEFAULT_NAME = 'default';
  
  final String name;
  
  StaticMemberClass(this.name) {
    instanceCount++;
  }
  
  static void resetCount() {
    instanceCount = 0;
  }
}

class PrivateMemberClass {
  final String _privateField;
  String publicField;
  
  PrivateMemberClass(this._privateField, this.publicField);
  
  String _privateMethod() => 'private';
  
  void publicMethod() => print('public');
}

class InheritanceChain {
  final String base;
  
  InheritanceChain(this.base);
}

class MiddleClass extends InheritanceChain {
  final int middle;
  
  MiddleClass(super.base, this.middle);
}

class DerivedClass extends MiddleClass {
  final bool derived;
  
  DerivedClass(super.base, super.middle, this.derived);
}

void main() async {
  setUpAll(() async {
    await runTestScan(filesToLoad: []);
  });

  group('ClassDeclaration Basic Properties', () {
    test('should identify class type kind', () {
      final concreteClass = Runtime.findClass<ConcreteClass>();
      
      expect(concreteClass.getKind(), equals(TypeKind.classType));
      expect(concreteClass.getSimpleName(), equals('ConcreteClass'));
    });

    test('should identify abstract classes', () {
      final abstractClass = Runtime.findClassByType(AbstractBaseClass);
      
      expect(abstractClass.getIsAbstract(), isTrue);
    });

    test('should identify sealed classes', () {
      final sealedClass = Runtime.findClass<SealedBaseClass>();
      
      expect(sealedClass.getIsSealed(), isTrue);
    });

    test('should identify base classes', () {
      final baseClass = Runtime.findClassByType(BaseClass);
      
      expect(baseClass.getIsBase(), isTrue);
    });

    test('should identify interface classes', () {
      final interfaceClass = Runtime.findClassByType(InterfaceClass);
      
      expect(interfaceClass.getIsInterface(), isTrue);
    });

    test('should identify final classes', () {
      final finalClass = Runtime.findClassByType(FinalClass);
      
      expect(finalClass.getIsFinal(), isTrue);
    });
  });

  group('ClassDeclaration Inheritance', () {
    test('should retrieve superclass', () {
      final concreteClass = Runtime.findClass<ConcreteClass>();
      
      final superClass = concreteClass.getSuperClass();
      expect(superClass, isNotNull);
      expect(superClass!.getName(), equals('AbstractBaseClass'));
    });

    test('should retrieve mixins', () {
      final mixedClass = Runtime.findClassByType(MixedClass);
      
      final mixins = mixedClass.getMixins();
      expect(mixins, isNotEmpty);
    });

    test('should retrieve implemented interfaces', () {
      final complexClass = Runtime.findClassByType(ComplexClass);
      
      final interfaces = complexClass.getInterfaces();
      expect(interfaces, isNotEmpty);
      expect(interfaces.any((i) => i.getName() == 'InterfaceClass'), isTrue);
    });

    test('should handle deep inheritance chain', () {
      final derivedClass = Runtime.findClassByType(DerivedClass);
      
      final superClass = derivedClass.getSuperClass();
      expect(superClass, isNotNull);
      expect(superClass!.getName(), equals('MiddleClass'));
    });
  });

  group('ClassDeclaration Members', () {
    test('should retrieve all members', () {
      final concreteClass = Runtime.findClass<ConcreteClass>();
      
      final members = concreteClass.getMembers();
      expect(members.length, greaterThanOrEqualTo(3)); // name getter, doSomething, additionalMethod
    });

    test('should retrieve constructors', () {
      final concreteClass = Runtime.findClass<ConcreteClass>();
      
      final constructors = concreteClass.getConstructors();
      expect(constructors.length, equals(1));
      expect(constructors.first.getName(), equals(''));
    });

    test('should retrieve fields', () {
      final concreteClass = Runtime.findClass<ConcreteClass>();
      
      final fields = concreteClass.getFields();
      expect(fields.length, equals(2));
      expect(fields.any((f) => f.getName() == 'name'), isTrue);
      expect(fields.any((f) => f.getName() == 'value'), isTrue);
    });

    test('should retrieve methods', () {
      final concreteClass = Runtime.findClass<ConcreteClass>();
      
      final methods = concreteClass.getMethods();
      expect(methods.length, greaterThanOrEqualTo(2));
      expect(methods.any((m) => m.getName() == 'doSomething'), isTrue);
      expect(methods.any((m) => m.getName() == 'additionalMethod'), isTrue);
    });

    test('should handle static members', () {
      final staticClass = Runtime.findClassByType(StaticMemberClass);
      
      final staticFields = staticClass.getFields().where((field) => field.getIsStatic());
      expect(staticFields.length, equals(2));
      expect(staticFields.any((f) => f.getName() == 'instanceCount'), isTrue);
      expect(staticFields.any((f) => f.getName() == 'DEFAULT_NAME'), isTrue);
      
      final staticMethods = staticClass.getMethods().where((method) => method.getIsStatic());
      expect(staticMethods.any((m) => m.getName() == 'resetCount'), isTrue);
    });
  });

  group('ClassDeclaration Generic Types', () {
    test('should identify generic classes', () {
      final genericClass = Runtime.findClass<GenericClass>();
      
      expect(genericClass.isGeneric(), isTrue);
      expect(genericClass.getTypeArguments(), isNotEmpty);
    });

    test('should handle bounded generic types', () {
      final boundedClass = Runtime.findClass<BoundedGenericClass>();
      
      expect(boundedClass.isGeneric(), isTrue);
      // Type parameter should have upper bound of Comparable
    });

    test('should handle complex generic constraints', () {
      final complexClass = Runtime.findClassByType(ComplexClass);
      
      expect(complexClass.isGeneric(), isTrue);
      // Type parameter should have upper bound of AbstractBaseClass
    });
  });

  group('ClassDeclaration Instantiation', () {
    test('should instantiate class with default constructor', () {
      final concreteClass = Runtime.findClass<ConcreteClass>();
      
      final instance = concreteClass.newInstance({
        'name': 'Test',
        'value': 42,
      });
      
      expect(instance, isA<ConcreteClass>());
      final concrete = instance as ConcreteClass;
      expect(concrete.name, equals('Test'));
      expect(concrete.value, equals(42));
    });

    test('should not instantiate unresolved generic class', () {
      final genericClass = Runtime.findClass<GenericClass>();
      
      expect(() => genericClass.newInstance({
        'value': 'Test',
        'items': ['item1', 'item2'],
      }), throwsA(isA<UnresolvedTypeInstantiationException>()));
    });

    test('should instantiate resolved generic class', () {
      final genericClass = Runtime.findClassByType(ResolvedGenericClass);
      
      final instance = genericClass.newInstance({
        'value': 'Test',
        'items': ['item1', 'item2'],
      });
      
      expect(instance, isA<ResolvedGenericClass>());
      expect(instance.value, equals('Test'));
      expect(instance.items, equals(['item1', 'item2']));
    });

    test('should instantiate class with nullable fields', () {
      final nullableClass = Runtime.findClass<NullableFieldClass>();
      
      final instance = nullableClass.newInstance({
        'nonNullableField': 'required',
        'nullableField': null,
      });
      
      expect(instance, isA<NullableFieldClass>());
      final nullable = instance as NullableFieldClass;
      expect(nullable.nonNullableField, equals('required'));
      expect(nullable.nullableField, isNull);
    });
  });

  group('ClassDeclaration Edge Cases', () {
    test('should handle private members', () {
      final privateClass = Runtime.findClass<PrivateMemberClass>();
      
      final fields = privateClass.getFields();
      expect(fields.any((f) => f.getName() == '_privateField'), isTrue);
      expect(fields.any((f) => f.getName() == 'publicField'), isTrue);
      
      final privateField = fields.firstWhere((f) => f.getName() == '_privateField');
      expect(privateField.getIsPublic(), isFalse);
      
      final publicField = fields.firstWhere((f) => f.getName() == 'publicField');
      expect(publicField.getIsPublic(), isTrue);
    });

    test('should handle annotations on class', () {
      final annotatedClass = Runtime.findClass<AnnotatedClass>();
      
      final annotations = annotatedClass.getAnnotations();
      // Note: Might not find @override annotation
      expect(annotations, isNotNull);
    });
  });

  group('ClassDeclaration Subclass Retrieval', () {
    test('getSubClasses should return all subclasses of a base class', () {
      final baseClass = Runtime.findClassByType(BaseClass);
      
      final subclasses = Runtime.getSubClasses(baseClass).toList();
      
      // There should be at least MixedClass which extends BaseClass
      expect(subclasses.any((c) => c.getSimpleName() == 'MixedClass'), isTrue);

      // Ensure that no subclass is the base class itself
      expect(subclasses.any((c) => c.getSimpleName() == 'BaseClass'), isFalse);
    });

    test('getSubClasses should handle abstract base classes', () {
      final abstractBase = Runtime.findClassByType(AbstractBaseClass);
      
      final subclasses = Runtime.getSubClasses(abstractBase).toList();

      // ConcreteClass should be a subclass
      expect(subclasses.any((c) => c.getSimpleName() == 'ConcreteClass'), isTrue);
    });

    test('getSubClassReferences should return lightweight references', () {
      final subclassRefs = Runtime.getSubClassReferences(Runtime.findClass<BaseClass>().getQualifiedName()).toList();

      // There should be at least one subclass reference
      expect(subclassRefs.isNotEmpty, isTrue);

      // The references should contain MixedClass
      expect(subclassRefs.any((r) => r.getQualifiedName().endsWith('MixedClass')), isTrue);
    });

    test('subclass references should match getSubClasses results', () {
      final baseClass = Runtime.findClassByType(BaseClass);
      
      final subclasses = Runtime.getSubClasses(baseClass).map((c) => c.getQualifiedName()).toSet();
      final subclassRefs = Runtime.getSubClassReferences(baseClass.getQualifiedName()).map((r) => r.getQualifiedName()).toSet();

      // The sets of qualified names should match
      expect(subclassRefs.difference(subclasses), isEmpty);
      expect(subclasses.difference(subclassRefs), isEmpty);
    });

    test('getSubClassReferences should handle classes with no subclasses', () {
      final finalClass = Runtime.findClassByType(FinalClass);

      final subclassRefs = Runtime.getSubClassReferences(finalClass.getQualifiedName()).toList();

      // FinalClass should not have any subclasses
      expect(subclassRefs.isEmpty, isTrue);
    });
  });

  group('ClassDeclaration Performance', () {
    late ClassDeclaration baseClassDecl;

    setUpAll(() {
      baseClassDecl = Runtime.findClassByType(BaseClass);
    });

    void measure(String label, int iterations, void Function() fn) {
      // warm up
      for (int i = 0; i < 10; i++) {
        fn();
      }

      final sw = Stopwatch()..start();
      for (int i = 0; i < iterations; i++) {
        fn();
      }
      sw.stop();

      final totalUs = sw.elapsedMicroseconds;
      final avgUs = totalUs / iterations;
      print('✅ PERF $label — iterations: $iterations, total: ${totalUs / 1000.0}ms, avg: ${avgUs.toStringAsFixed(2)}μs');

      final envThreshold = Platform.environment['JETLEAF_MAX_AVG_US'];
      if (envThreshold != null) {
        final threshold = int.tryParse(envThreshold) ?? -1;
        if (threshold > 0) {
          expect(avgUs, lessThanOrEqualTo(threshold), reason: 'Average $avgUsμs exceeded threshold $threshold μs for $label.');
        }
      }
    }

    test('find class by type — repeated lookups', () {
      measure('findClassByType<ConcreteClass>', 10000, () {
        Runtime.findClassByType(ConcreteClass);
      });
    });

    test('find class by name — repeated lookups', () {
      measure('findClassByName ConcreteClass', 10000, () {
        Runtime.findClassByName('ConcreteClass');
      });
    });

    test('obtainClassDeclaration from instance — repeated', () {
      measure('obtainClassDeclaration(instance)', 5000, () {
        Runtime.obtainClassDeclaration(ConcreteClass('x', 1));
      });
    });

    test('getSubClasses — repeated', () {
      measure('getSubClasses(BaseClass)', 2000, () {
        Runtime.getSubClasses(baseClassDecl).toList();
      });
    });

    test('getSubClassReferences — repeated', () {
      measure('getSubClassReferences(BaseClass)', 2000, () {
        Runtime.getSubClassReferences(baseClassDecl.getQualifiedName()).toList();
      });
    });

    test('cold vs warm lookup', () {
      // Try to clear caches if API available
      try {
        Runtime.cleanup();
      } catch (_) {}

      // cold measurement (single)
      final swCold = Stopwatch()..start();
      Runtime.findClassByType(ConcreteClass);
      swCold.stop();
      print('🔁 PERF cold lookup findClassByType<ConcreteClass>: ${swCold.elapsedMicroseconds}μs');

      // warm measurement (averaged)
      measure('warm findClassByType<ConcreteClass>', 10000, () {
        Runtime.findClassByType(ConcreteClass);
      });
    });
  });
}
