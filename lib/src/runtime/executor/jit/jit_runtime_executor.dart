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
import '../../../declaration/declaration.dart';
import '../../../exceptions.dart';
import 'abstract_method_jit_runtime_executor.dart';
import '../runtime_executor.dart';

/// {@template jit_runtime_executor}
/// A reflection-based implementation of [RuntimeExecutor] using `dart:mirrors`.
///
/// This class provides dynamic instantiation, method invocation, and field access
/// for types at runtime, leveraging the Dart mirrors API. It is intended for use
/// in JIT (Just-In-Time) environments where `dart:mirrors` is available (e.g., VM,
/// not AOT-compiled code).
///
/// ### Example: Instantiating a class
/// ```dart
/// final resolver = JitExecutableResolver();
/// final person = resolver.newInstance<Person>('named', ['Eve']);
/// ```
///
/// ### Example: Invoking a method
/// ```dart
/// resolver.invokeMethod(person, 'greet'); // calls person.greet()
/// ```
///
/// ### Example: Getting and setting a field
/// ```dart
/// final name = resolver.getValue(person, 'name');
/// resolver.setValue(person, 'name', 'Alice');
/// ```
///
/// This is especially useful in frameworks that need to instantiate objects or
/// call methods based on metadata, annotations, or configuration at runtime.
/// {@endtemplate}
class JitRuntimeExecutor extends AbstractMethodJitRuntimeExecutor implements RuntimeExecutor {
  // {@macro jit_runtime_executor}
  const JitRuntimeExecutor();

  @override
  T newInstance<T>(String name, ExecutableArgument argument, ConstructorDeclaration constructor, [Type? returnType]) {
    mirrors.InstanceMirror invoker;
    mirrors.ClassMirror? classMirror;
    final Type effectiveType = (T != dynamic && T != Object)
        ? T
        : (returnType ?? (throw GenericResolutionException('Missing returnType when T is dynamic/Object')));

    try {
      classMirror = mirrors.reflectClass(effectiveType);
      final symbol = name.isEmpty ? Symbol('') : Symbol(name);
      final namedArgs = argument.getSymbolizedNamedArguments();

      if (namedArgs.isNotEmpty) {
        invoker = classMirror.newInstance(symbol, argument.getPositionalArguments(), namedArgs);
      } else {
        invoker = classMirror.newInstance(symbol, argument.getPositionalArguments());
      }
    } on UnsupportedRuntimeOperationException catch (_) {
      rethrow;
    } on GenericResolutionException catch (_) {
      rethrow;
    } on NoSuchMethodError catch (e, stack) {
      if (e.toString().contains("No constructor '_ClassMirror' declared in class '_ClassMirror'")) {
        throw UnresolvedTypeInstantiationException(constructor.getParentClass()?.getName() ?? constructor.getType(), cause: getErrorMessage(classMirror), stack: stack);
      }

      throw ConstructorNotFoundException(effectiveType.toString(), name, cause: e, stack: stack);
    } on mirrors.AbstractClassInstantiationError catch (e, stack) {
      // Mirrors-specific error
      final guidance = getErrorMessage(effectiveType);
      throw GenericResolutionException('Mirror error while creating instance of $effectiveType. $guidance\n$e\n$stack');
    } catch (e, stack) {
      Error.throwWithStackTrace(e, stack);
    }

    return invoker.reflectee as T;
  }
}