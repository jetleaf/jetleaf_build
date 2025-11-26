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

import '../exceptions.dart';
import 'runtime_resolver.dart';

/// {@template fallback_runtime_resolver}
/// A composite [RuntimeResolver] that delegates resolution to a primary
/// resolver, and falls back to a secondary resolver (typically mirror-based)
/// if the primary does not support the operation.
///
/// This is useful in hybrid environments where Ahead-of-Time (AOT) and
/// Just-in-Time (JIT) compilation coexist, or during gradual migration
/// from mirrors to generative resolution.
///
/// The fallback is only triggered when the primary resolver throws a
/// [UnImplementedResolverException].
///
/// ## Example
/// ```dart
/// final generative = GenerativeExecutableResolver(generativeExecutable);
/// final mirrors = MirrorExecutableResolver();
///
/// final resolver = FallbackExecutableResolver(generative, mirrors);
///
/// final instance = resolver.newInstance<MyClass>('default');
/// final result = resolver.invokeMethod(instance, 'run');
/// print(result);
/// ```
///
/// {@endtemplate}
class FallbackRuntimeResolver implements RuntimeResolver {
  /// The primary resolver to use first.
  final RuntimeResolver _primary;

  /// The fallback resolver to use when the primary fails.
  final RuntimeResolver _fallback;

  /// {@macro fallback_runtime_resolver}
  FallbackRuntimeResolver(this._primary, this._fallback);

  @override
  T newInstance<T>(String name, [Type? returnType, List<Object?> args = const [], Map<String, Object?> namedArgs = const {}]) {
    try {
      return _primary.newInstance<T>(name, returnType, args, namedArgs);
    } on ConstructorNotFoundException catch (_) {
      // Fallback only if the primary resolver explicitly states it's unimplemented
      return _fallback.newInstance<T>(name, returnType, args, namedArgs);
    } catch (_) {
      // For other errors, rethrow
      rethrow;
    }
  }

  @override
  Object? invokeMethod<T>(T instance, String method, {List<Object?> args = const [], Map<String, Object?> namedArgs = const {}}) {
    try {
      return _primary.invokeMethod<T>(instance, method, args: args, namedArgs: namedArgs);
    } on MethodNotFoundException catch (_) {
      return _fallback.invokeMethod<T>(instance, method, args: args, namedArgs: namedArgs);
    } catch (_) {
      rethrow;
    }
  }

  @override
  Object? getValue<T>(T instance, String name) {
    try {
      return _primary.getValue<T>(instance, name);
    } on FieldAccessException catch (_) {
      return _fallback.getValue<T>(instance, name);
    } catch (_) {
      rethrow;
    }
  }

  @override
  void setValue<T>(T instance, String name, Object? value) {
    try {
      _primary.setValue<T>(instance, name, value);
    } on FieldMutationException catch (_) {
      _fallback.setValue<T>(instance, name, value);
    } catch (_) {
      rethrow;
    }
  }
}