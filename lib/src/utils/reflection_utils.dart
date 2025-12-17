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

import 'dart:mirrors' as mirrors;

/// {@template reflection_utils}
/// Lightweight runtime reflection utility built on top of `dart:mirrors`.
///
/// This class provides convenience methods for inspecting runtime types
/// and instances to determine their *qualified names*, i.e. the fully
/// resolved identity of a symbol within its library or package context.
///
/// Qualified names are formatted as:
///
/// ```
/// package:my_app/models/user.dart.User
/// dart:core.String
/// ```
///
/// This utility is used internally within Jetleaf for tasks like
/// class resolution, dependency registration, and annotation scanning.
///
/// > **Note:** Reflection via `dart:mirrors` may not be supported in all
/// runtime environments (e.g. Flutter AOT). This utility is primarily
/// intended for development or server-side usage.
/// {@endtemplate}
final class ReflectionUtils {
  /// Private constructor to prevent instantiation.
  const ReflectionUtils._();

  // ─────────────────────────────────────────────────────────────
  // Instance Reflection
  // ─────────────────────────────────────────────────────────────

  /// {@template reflection_utils.find_qualified_name}
  /// Returns the **qualified name** of an object instance.
  ///
  /// This method inspects the runtime type of the given [instance]
  /// and constructs a fully-qualified symbol reference including
  /// its originating library URI.
  ///
  /// ### Example
  /// ```dart
  /// final user = User();
  /// print(ReflectionUtils.findQualifiedName(user));
  /// // → "package:my_app/models/user.dart.User"
  /// ```
  ///
  /// ### Returns
  /// A string containing the qualified name, e.g.
  /// `dart:core.String` or `package:jetleaf_core/src/log/log_property.dart.LogProperty`.
  ///
  /// ### Notes
  /// - If the source URI cannot be resolved, `"unknown"` is used as a fallback.
  /// {@endtemplate}
  static String findQualifiedName(Object instance) {
    final mirror = mirrors.reflect(instance);
    final classMirror = mirror.type;

    final className = mirrors.MirrorSystem.getName(classMirror.simpleName);

    // Library URI is taken from owner or type location
    final libraryUri = classMirror.location?.sourceUri.toString() ?? classMirror.owner?.location?.sourceUri.toString() ?? 'unknown';

    return buildQualifiedName(className, libraryUri);
  }

  /// Checks if the given [instance] or [mirrors.TypeMirror] represents a **record type**.
  ///
  /// {@template reflection_utils.is_this_a_record}
  /// This method inspects the runtime type of the provided object or the
  /// `TypeMirror` to determine whether it is a Dart 3 record type.
  ///
  /// ### Behavior
  /// - If [instance] is a `TypeMirror`, it verifies:
  ///   - The simple name is `"Record"`.
  ///   - The reflected type matches the built-in Dart `Record` type.
  /// - If [instance] is an actual object, it reflects its type and
  ///   recursively applies the same checks.
  ///
  /// ### Example
  /// ```dart
  /// final r = (42, "hello");
  /// print(ReflectionUtils.isThisARecord(r)); // → true (Dart 3+)
  ///
  /// final str = "not a record";
  /// print(ReflectionUtils.isThisARecord(str)); // → false
  /// ```
  ///
  /// ### Returns
  /// - `true` if the object or type is a record.
  /// - `false` otherwise.
  /// {@endtemplate}
  static bool isThisARecord(Object instance) {
    if (instance case mirrors.TypeMirror instance) {
      return mirrors.MirrorSystem.getName(instance.simpleName) == "Record" && instance.hasReflectedType && instance.reflectedType == Record;
    }

    return isThisARecord(mirrors.reflect(instance).type);
  }

  /// Checks if the given [instance] or [mirrors.TypeMirror] represents a **function type**.
  ///
  /// {@template reflection_utils.is_this_a_function}
  /// This method inspects the runtime type of the provided object or the
  /// `TypeMirror` to determine whether it represents a Dart function.
  ///
  /// ### Behavior
  /// - If [instance] is a `TypeMirror`, it checks if it is a
  ///   [mirrors.FunctionTypeMirror].
  /// - If [instance] is an actual object, it reflects its type and
  ///   recursively applies the same check.
  ///
  /// ### Example
  /// ```dart
  /// void myFunction(int x) {}
  /// print(ReflectionUtils.isThisAFunction(myFunction)); // → true
  ///
  /// final str = "not a function";
  /// print(ReflectionUtils.isThisAFunction(str)); // → false
  /// ```
  ///
  /// ### Returns
  /// - `true` if the object or type is a function.
  /// - `false` otherwise.
  ///
  /// ### Notes
  /// - This relies on `dart:mirrors` and may not work in all runtime environments.
  /// - Covers top-level functions, static methods, closures, and function-typed variables.
  /// {@endtemplate}
  static bool isThisAFunction(Object instance) {
    if (instance is mirrors.TypeMirror) {
      return instance is mirrors.FunctionTypeMirror;
    }

    return isThisAFunction(mirrors.reflect(instance).type);
  }

  // ─────────────────────────────────────────────────────────────
  // Type Reflection
  // ─────────────────────────────────────────────────────────────

  /// {@template reflection_utils.find_qualified_name_from_type}
  /// Returns the **qualified name** of a static [Type].
  ///
  /// Unlike [findQualifiedName], this method operates directly on
  /// the type object itself, not an instance.
  ///
  /// ### Example
  /// ```dart
  /// print(ReflectionUtils.findQualifiedNameFromType(String));
  /// // → "dart:core.String"
  /// ```
  ///
  /// ### Returns
  /// A string representing the type’s fully qualified symbol.
  ///
  /// ### Notes
  /// - Falls back to `"unknown"` if the library URI is not available.
  /// {@endtemplate}
  static String findQualifiedNameFromType(Type type) {
    final typeMirror = mirrors.reflectType(type);
    final typeName = mirrors.MirrorSystem.getName(typeMirror.simpleName);
    final libraryUri = typeMirror.location?.sourceUri.toString() ?? 'unknown';

    return buildQualifiedName(typeName, libraryUri);
  }

  // ─────────────────────────────────────────────────────────────
  // Internal Utilities
  // ─────────────────────────────────────────────────────────────

  /// {@template reflection_utils.build_qualified_name}
  /// Builds a fully qualified name from a type [name] and its
  /// associated [libraryUri].
  ///
  /// This is a small helper used internally by both
  /// [findQualifiedName] and [findQualifiedNameFromType].
  ///
  /// Example:
  /// ```dart
  /// ReflectionUtils.buildQualifiedName('User', 'package:my_app/models/user.dart');
  /// // → "package:my_app/models/user.dart.User"
  /// ```
  /// {@endtemplate}
  static String buildQualifiedName(String typeName, String libraryUri) {
    // Ensures there’s only one dot between segments
    return '$libraryUri.$typeName'.replaceAll("..", '.');
  }
}