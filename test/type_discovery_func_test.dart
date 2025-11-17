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

import 'package:jetleaf_build/jetleaf_build.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() async {
    TypeDiscovery.clearCaches();
    await runTestScan();
    return Future<void>.value();
  });

  group('TypeDiscovery - Core Functionality', () {
    test('should find String class by type', () {
      final declaration = TypeDiscovery.findByType(String);
      expect(declaration, isNotNull);
      expect(declaration!.getSimpleName(), equals('String'));
      expect(declaration.getType(), equals(String));
    });

    test('should find int class by type', () {
      final declaration = TypeDiscovery.findByType(int);
      expect(declaration, isNotNull);
      expect(declaration!.getSimpleName(), equals('int'));
      expect(declaration.getType(), equals(int));
    });

    test('should find double class by type', () {
      final declaration = TypeDiscovery.findByType(double);
      expect(declaration, isNotNull);
      expect(declaration!.getSimpleName(), equals('double'));
      expect(declaration.getType(), equals(double));
    });

    test('should find bool class by type', () {
      final declaration = TypeDiscovery.findByType(bool);
      expect(declaration, isNotNull);
      expect(declaration!.getSimpleName(), equals('bool'));
      expect(declaration.getType(), equals(bool));
    });

    test('should find num class by type', () {
      final declaration = TypeDiscovery.findByType(num);
      expect(declaration, isNotNull);
      expect(declaration!.getSimpleName(), equals('num'));
      expect(declaration.getType(), equals(num));
    });

    test('should find List class by type', () {
      final declaration = TypeDiscovery.findByType(List);
      expect(declaration, isNotNull);
      expect(declaration!.getSimpleName(), equals('List'));
      expect(declaration.getType(), equals(List));
    });

    test('should find Map class by type', () {
      final declaration = TypeDiscovery.findByType(Map);
      expect(declaration, isNotNull);
      expect(declaration!.getSimpleName(), equals('Map'));
      expect(declaration.getType(), equals(Map));
    });

    test('should find Map<dynamic, dynamic> class by type', () {
      final declaration = TypeDiscovery.findByType(Map<dynamic, dynamic>);
      expect(declaration, isNotNull);
      expect(declaration!.getName(), equals('Map'));
      expect(declaration.getType(), equals(Map<dynamic, dynamic>));
    });

    test('should find Function class by type', () {
      final declaration = TypeDiscovery.findByType(Function);
      expect(declaration, isNotNull);
      expect(declaration!.getSimpleName(), equals('Function'));
      expect(declaration.getType(), equals(Function));
    });
  });

  group('TypeDiscovery - Generic Types', () {
    test('should handle List<T> types', () {
      final listDecl = TypeDiscovery.findByType(List);
      expect(listDecl, isNotNull);
      expect(listDecl!.isGeneric(), isTrue);
      expect(listDecl.getTypeArguments().length, equals(1));
    });

    test('should handle Map<K,V> types', () {
      final mapDecl = TypeDiscovery.findByType(Map);
      expect(mapDecl, isNotNull);
      expect(mapDecl!.isGeneric(), isTrue);
      expect(mapDecl.getTypeArguments().length, equals(2));
    });

    test('should handle List<T> types', () {
      final listDecl = TypeDiscovery.findByType(List<String>);
      expect(listDecl, isNotNull);
      expect(listDecl!.getTypeArguments().length, equals(1));
      expect(listDecl.isGeneric(), isTrue);
      expect(listDecl.getTypeArguments()[0].getType(), equals(String));
    });

    test('should handle Map<K,V> types', () {
      final mapDecl = TypeDiscovery.findByType(Map<String, int>);
      expect(mapDecl, isNotNull);
      expect(mapDecl!.isGeneric(), isTrue);
      expect(mapDecl.getTypeArguments().length, equals(2));
      expect(mapDecl.getTypeArguments()[0].getType(), equals(String));
      expect(mapDecl.getTypeArguments()[1].getType(), equals(int));
    });

    test('should resolve List<String> type arguments', () {
      final listStringDecl = TypeDiscovery.findByName('List<String>');
      expect(listStringDecl, isNotNull);
      expect(listStringDecl!.getTypeArguments(), hasLength(1));
      expect(listStringDecl.getTypeArguments()[0].getType(), equals(String));
    });

    test('should handle nested generics like Map<String, List<int>>', () {
      final complexDecl = TypeDiscovery.findByName('Map<String, List<int>>');
      expect(complexDecl, isNotNull);
      
      final typeArgs = complexDecl!.getTypeArguments();
      expect(typeArgs, hasLength(2));
      expect(typeArgs[0].getType(), equals(String));
      expect(typeArgs[1].getType(), equals(List));
      
      final nestedArgs = typeArgs[1].getTypeArguments();
      expect(nestedArgs, hasLength(1));
      expect(nestedArgs[0].getType(), equals(int));
    });

    // test('should handle generic type variables', () {
    //   // Assuming we have a class like: class Box<T extends num> {}
    //   final boxDecl = TypeDiscovery.findByName('Box');
    //   expect(boxDecl, isNotNull);
      
    //   final typeParams = boxDecl!.getTypeArguments();
    //   expect(typeParams, hasLength(1));
    //   expect(typeParams[0].getUpperBound()?.getType(), equals(num));
    // });
  });

  group('TypeDiscovery - Name Resolution', () {
    test('should find by simple name', () {
      final decl = TypeDiscovery.findByName('BaseStream');
      expect(decl, isNotNull);
    });

    test('should find by qualified name', () {
      final decl = TypeDiscovery.findByQualifiedName('package:jetleaf_lang/src/io/closeable.dart.Closeable');
      expect(decl, isNotNull);
      expect(decl?.getIsPublic(), true)
;    });

    test('should return null for non-existent type', () {
      final decl = TypeDiscovery.findByName('NonExistentType');
      expect(decl, isNull);
    });
  });

  group('TypeDiscovery - Inheritance', () {
    test('should find subclasses', () {
      // Assuming Animal is a base class with Cat and Dog subclasses
      final subclasses = TypeDiscovery.findSubclassesOf(Animal);
      expect(subclasses, hasLength(2));
      expect(subclasses.any((c) => c.getSimpleName() == 'Cat'), isTrue);
      expect(subclasses.any((c) => c.getSimpleName() == 'Dog'), isTrue);
    });

    test('should find implementers of interface', () {
      // Assuming Serializable is an interface
      final implementers = TypeDiscovery.findImplementersOf(Serializable);
      expect(implementers, isNotEmpty);
    });

    test('should handle multiple inheritance', () {
      // Assuming class MyClass extends Base with Mixin implements Interface
      final myClassDecl = TypeDiscovery.findByType(MyClass);
      expect(myClassDecl, isNotNull);
      
      expect(myClassDecl!.getSuperClass()?.getType(), equals(Base));
      expect(myClassDecl.getMixins().any((m) => m.getType() == Mixin), isTrue);
      expect(myClassDecl.getInterfaces().any((i) => i.getType() == Interface), isTrue);
    });
  });
}

// Test classes
class Animal {}
class Cat extends Animal {}
class Dog extends Animal {}
class Serializable {}
class MyClass extends Base with Mixin implements Interface {}
class Base {}
mixin Mixin {}
class Interface implements Serializable {}