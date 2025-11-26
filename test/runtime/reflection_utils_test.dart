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
}