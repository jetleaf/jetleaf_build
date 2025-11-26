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

// ============================================= RUNTIME RESOLVER ===============================================

/// {@template runtime_resolver}
/// An interface that portrays how any code is handled in JetLeaf's reflection system.
///
/// This abstraction allows for different underlying mechanisms to resolve and
/// execute code, such as:
/// - Using `dart:mirrors` in JIT environments (e.g., during development)
/// - Using code generation or precompiled metadata for AOT environments (e.g., production builds)
///
/// The interface provides a unified way to:
/// - Create class instances
/// - Invoke methods
/// - Access and mutate fields
///
/// This allows JetLeaf to support reflection even when `dart:mirrors` is not available.
///
/// ## Example
/// ```dart
/// class MirrorRuntimeResolver extends RuntimeResolver {
///   @override
///   T newInstance<T>(String name, [List<Object?> args = const [], Map<String, Object?> namedArgs = const {}]) {
///     // Implementation using dart:mirrors
///   }
///
///   @override
///   T? invokeMethod<T>(T instance, String method, {List<Object?> args = const [], Map<String, Object?> namedArgs = const {}}) {
///     // Implementation using dart:mirrors
///   }
///
///   @override
///   Object? getValue<T>(T instance, String name) {
///     // Implementation using dart:mirrors
///   }
///
///   @override
///   void setValue<T>(T instance, String name, Object? value) {
///     // Implementation using dart:mirrors
///   }
/// }
/// ```
/// {@endtemplate}
abstract interface class RuntimeResolver {
  /// {@macro runtime_resolver}
  const RuntimeResolver();

  /// Creates a new instance of type `T` using the specified constructor `name`.
  ///
  /// For the default unnamed constructor, use an empty string `''` for `name`.
  ///
  /// - `name`: The name of the constructor (e.g., 'named', or '' for default).
  /// - `returnType`: The expected return type of the constructor.
  /// - `args`: Positional arguments for the constructor.
  /// - `namedArgs`: Named arguments for the constructor.
  ///
  /// Throws an [UnImplementedResolverException] if the constructor cannot be resolved.
  T newInstance<T>(String name, [Type? returnType, List<Object?> args = const [], Map<String, Object?> namedArgs = const {}]);

  /// Invokes a method `method` on the given `instance` of type `T`.
  ///
  /// - `instance`: The object on which to invoke the method.
  /// - `method`: The name of the method to invoke.
  /// - `args`: Positional arguments for the method.
  /// - `namedArgs`: Named arguments for the method.
  ///
  /// Returns the result of the method invocation, or `null` if the method returns `void`.
  /// Throws an [UnImplementedResolverException] if the method cannot be resolved.
  Object? invokeMethod<T>(T instance, String method, {List<Object?> args = const [], Map<String, Object?> namedArgs = const {}});
  
  /// Gets the value of an instance field `name` on the given `instance` of type `T`.
  ///
  /// - `instance`: The object from which to get the field value.
  /// - `name`: The name of the field.
  ///
  /// Returns the value of the field.
  /// Throws an [UnImplementedResolverException] if the field cannot be resolved.
  Object? getValue<T>(T instance, String name);
  
  /// Sets the value of an instance field `name` on the given `instance` of type `T`.
  ///
  /// - `instance`: The object on which to set the field value.
  /// - `name`: The name of the field.
  /// - `value`: The new value to set.
  ///
  /// Throws an [UnImplementedResolverException] if the field cannot be resolved or is not settable.
  void setValue<T>(T instance, String name, Object? value);
}