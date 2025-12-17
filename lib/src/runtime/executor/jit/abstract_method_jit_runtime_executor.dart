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

import '../../../argument/executable_argument.dart';
import '../../../exceptions.dart';
import 'abstract_field_jit_runtime_executor.dart';

/// {@template abstract_method_jit_runtime_executor}
/// Provides reflective method invocation for JetLeaf’s JIT runtime.
///
/// This resolver extends [AbstractFieldJitRuntimeExecutor] with the ability to:
///
///  * invoke instance methods;
///  * invoke static methods (when the `instance` argument is a `Type`);
///  * resolve overloaded or inherited members via `findDeclaration`;
///  * normalize reflection failures into JetLeaf-specific exceptions.
///
/// ### Error Handling
/// The override of [invokeMethod]:
///  - Converts reflection errors into:
///    * `MethodNotFoundException` when a method is missing or inaccessible.
///    * `GenericResolutionException` when invocation fails due to unresolved
///      generic types or argument mismatches.
///    * `GenericResolutionException` when mirrors are unavailable or restricted
///      (e.g., AOT).
///  - Preserves meaningful runtime failures such as:
///    * `LateInitializationError`
///    * `FormatException`
///
/// The actual mirror call is performed by the internal helper [_invoke],
/// which validates the declaration type (must be a non-constructor method)
/// before performing the invocation.
///
/// This class is intended for use by JetLeaf’s JIT-based DI model, runtime
/// factories, dynamic serializers, and any utilities requiring late-bound
/// method dispatch.
/// {@endtemplate}
abstract class AbstractMethodJitRuntimeExecutor extends AbstractFieldJitRuntimeExecutor {
  /// {@macro abstract_method_jit_runtime_executor}
  const AbstractMethodJitRuntimeExecutor();

  @override
  Object? invokeMethod<T>(T instance, String method, ExecutableArgument argument) {
    mirrors.InstanceMirror invoker;
    
    try {
      final symbol = Symbol(method);
      
      if (instance is Type) {
        final mirror = mirrors.reflectType(instance);
        
        if (mirror is mirrors.ClassMirror) {
          invoker = _invoke(mirror, mirror, symbol, getType(instance), method, argument);
        } else {
          throw MethodNotFoundException(getType(instance), method);
        }
      } else {
        final mirror = mirrors.reflect(instance);
        invoker = _invoke(mirror, mirror.type, symbol, getType(instance), method, argument);
      }
    } on MethodNotFoundException catch (_) {
      rethrow;
    } on NoSuchMethodError catch (e, stack) {
      throw MethodNotFoundException(getType(instance), method, cause: e, stack: stack);
    } on mirrors.AbstractClassInstantiationError catch (e, stack) {
      final guidance = getErrorMessage(instance);
      throw GenericResolutionException('Mirror error while invoking method "$method" on instance of $T. $guidance\n$e\n$stack');
    } catch (e, stack) {
      Error.throwWithStackTrace(e, stack);
    }

    return invoker.reflectee;
  }

  /// Internal reflective method invocation implementation.
  ///
  /// This method performs the actual mirror-level invocation and is shared by
  /// both static and instance contexts.
  ///
  /// ### Validation Rules
  /// A declaration is considered valid *only if it is*:
  ///  - a `MethodMirror`
  ///  - **not** a constructor
  ///  - **not** a getter
  ///  - **not** a setter
  ///
  /// If the declaration does not meet these requirements, a
  /// [MethodNotFoundException] is thrown.
  ///
  /// ### Invocation Behavior
  ///  - Converts named arguments into Symbol keys.
  ///  - Performs `mirror.invoke` directly.
  ///
  /// If an unexpected mirror failure occurs, a second best-effort invocation is
  /// attempted because some mirror environments accept invocation even when
  /// declaration metadata is incomplete.
  mirrors.InstanceMirror _invoke(mirrors.ObjectMirror mirror, mirrors.ClassMirror type, Symbol symbol, Object typeName, String method, ExecutableArgument argument) {
    try {
      final declaration = findDeclaration(symbol, type);
      if (declaration is! mirrors.MethodMirror || declaration.isConstructor || declaration.isGetter || declaration.isSetter) {
        throw MethodNotFoundException(typeName, method);
      }

      return mirror.invoke(symbol, argument.getPositionalArguments(), argument.getSymbolizedNamedArguments());
    } on MethodNotFoundException {
      rethrow;
    } catch (_) {
      // Best-effort fallback
      return mirror.invoke(symbol, argument.getPositionalArguments(), argument.getSymbolizedNamedArguments());
    }
  }
}