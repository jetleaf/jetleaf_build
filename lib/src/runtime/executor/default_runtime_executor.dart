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

import '../../argument/executable_argument.dart';
import '../declaration/declaration.dart';
import '../../exceptions.dart';
import 'runtime_executor.dart';

/// {@template default_runtime_executor}
/// A robust runtime executor that coordinates between two resolver strategies
/// to handle dynamic operations on objects, methods, and fields at runtime.
///
/// `DefaultRuntimeExecutor` is designed to provide **maximum flexibility and
/// resilience** in hybrid environments where different runtime strategies
/// coexist. It combines a **primary resolver**, which is expected to handle
/// the majority of runtime operations efficiently (often using code generation
/// or precompiled logic), with a **fallback resolver**, which is used as a
/// safety net when the primary resolver cannot process a request (commonly
/// using Dart mirrors or reflective access).
///
/// This design is particularly useful in the following scenarios:
/// 
/// 1. **Hybrid Compilation Environments**: In projects where Ahead-of-Time
/// (AOT) compiled modules coexist with Just-in-Time (JIT) or reflective
/// modules, `DefaultRuntimeExecutor` ensures seamless operation by falling
/// back when a module cannot be resolved by the primary strategy.
///
/// 2. **Gradual Migration**: When migrating from mirror-based reflection
/// to generative code resolution, the primary resolver can handle the new
/// code-generated logic, while the fallback maintains support for legacy
/// mirror-based structures until the migration is complete.
///
/// 3. **Error Resilience**: If the primary resolver throws an exception
/// indicating an unimplemented operation (`UnImplementedResolverException`,
/// `ConstructorNotFoundException`, `MethodNotFoundException`,
/// `FieldAccessException`, or `FieldMutationException`), the fallback
/// resolver is automatically invoked, preventing runtime failures.
///
/// 4. **Dynamic Operations**: The executor supports creating new instances,
/// invoking methods, and getting/setting field values on arbitrary objects
/// at runtime, bridging gaps between static typing and dynamic reflection.
///
/// ### Design
/// The executor follows a **delegation pattern**:
/// - `_primary`: First point of contact for all runtime operations.
/// - `_fallback`: Secondary resolver invoked only if the primary fails
///   explicitly due to unimplemented functionality.
///
/// This ensures that performance-critical operations can be handled by
/// optimized resolvers, while still maintaining full dynamic capabilities.
///
/// ### Example
/// ```dart
/// final generative = GenerativeExecutableResolver(generativeExecutable);
/// final mirrors = MirrorExecutableResolver();
///
/// final executor = DefaultRuntimeExecutor(generative, mirrors);
///
/// // Create a new instance using the default constructor
/// final instance = executor.newInstance<MyClass>('');
///
/// // Invoke a method dynamically
/// final result = executor.invokeMethod(instance, 'run');
/// print(result);
/// ```
///
/// {@endtemplate}
final class DefaultRuntimeExecutor implements RuntimeExecutor {
  /// The primary resolver responsible for executing runtime operations.
  ///
  /// Typically, this resolver is precompiled or code-generated, providing
  /// efficient handling of object instantiation, method calls, and field
  /// access whenever possible.
  final RuntimeExecutor _primary;

  /// The fallback resolver used when the primary cannot handle a request.
  ///
  /// This resolver is usually reflective (mirror-based) and ensures that
  /// operations that the primary cannot resolve still succeed, at the
  /// cost of runtime performance.
  final RuntimeExecutor _fallback;

  /// {@macro default_runtime_executor}
  ///
  /// Constructs a new `DefaultRuntimeExecutor` by specifying a primary
  /// and fallback resolver.
  ///
  /// - [_primary]: The main resolver used for most operations.
  /// - [_fallback]: The secondary resolver used only if the primary fails.
  DefaultRuntimeExecutor(this._primary, this._fallback);

  @override
  T newInstance<T>(String name, ExecutableArgument argument, ConstructorDeclaration constructor, [Type? returnType]) {
    try {
      return _primary.newInstance<T>(name, argument, constructor, returnType);
    } on ConstructorNotFoundException catch (_) {
      return _fallback.newInstance<T>(name, argument, constructor, returnType);
    } catch (_) {
      rethrow;
    }
  }

  @override
  Object? invokeMethod<T>(T instance, String method, ExecutableArgument argument) {
    try {
      return _primary.invokeMethod<T>(instance, method, argument);
    } on MethodNotFoundException catch (_) {
      return _fallback.invokeMethod<T>(instance, method, argument);
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