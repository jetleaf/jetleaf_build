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

import '../../../argument/executable_argument.dart';
import '../../declaration/declaration.dart';
import '../../../exceptions.dart';
import '../../hint/runtime_hint_descriptor.dart';
import '../runtime_executor.dart';

/// {@template aot_runtime_executor}
/// An [RuntimeExecutor] implementation that leverages Ahead-of-Time (AOT) 
/// generative hints to perform instance creation, method invocation, and 
/// field access at runtime without relying on mirrors or dynamic reflection.
///
/// ## Purpose
/// The [AotRuntimeExecutor] is designed for environments where:
/// - Generative hints for constructors, methods, and fields are precomputed.
/// - Deterministic execution is required (e.g., for production AOT builds).
/// - Performance and type safety are critical, and runtime reflection overhead must be minimized.
///
/// ## How It Works
/// This executor queries a [RuntimeHintDescriptor] for type-specific [RuntimeHint]s. 
/// Each hint knows how to construct instances, invoke methods, and access fields 
/// for its associated type. The executor delegates all operations to these hints 
/// and enforces strict execution semantics:
/// - If a hint successfully executes an operation, the result is returned.
/// - If no suitable hint is found, a type-specific exception is thrown 
///   ([ConstructorNotFoundException], [MethodNotFoundException], [FieldAccessException], 
///   or [FieldMutationException]).
///
/// ## Use Cases
/// - Performing runtime operations in a fully AOT compiled Dart environment.
/// - Replacing mirror-based reflection with precomputed generative resolutions.
/// - Integrating with JetLeaf's hint system for deterministic and type-safe execution.
///
/// ## Field
/// - [descriptor]: The [RuntimeHintDescriptor] registry used to resolve hints
///   for all types that this executor may operate on.
/// {@endtemplate}
class AotRuntimeExecutor implements RuntimeExecutor {
  /// The registry used to resolve and execute generative descriptors.
  ///
  /// This descriptor maintains a mapping of types to [RuntimeHint]
  /// instances and is queried whenever an instance, method, or field
  /// operation is invoked via this executor.
  final RuntimeHintDescriptor descriptor;

  /// {@macro aot_runtime_executor}
  const AotRuntimeExecutor(this.descriptor);

  @override
  T newInstance<T>(String name, ExecutableArgument argument, ConstructorDeclaration constructor, [Type? returnType]) {
    final hint = descriptor.getHint<T>(type: returnType ?? T);
    final type = hint?.obtainTypeOfRuntimeHint() ?? returnType ?? T;
    
    if (hint case final hint?) {
      final result = hint.createNewInstance<T>(name, argument);
      if (result.getIsExecuted()) {
        if (result.getResult() case final object?) {
          return object as T;
        } else {
          throw UnsupportedRuntimeOperationException(hint.obtainTypeOfRuntimeHint(), "Constructor creation cannot be null");
        }
      }
    }
    
    throw ConstructorNotFoundException(type, name);
  }

  @override
  Object? invokeMethod<T>(T instance, String method, ExecutableArgument argument) {
    final hint = descriptor.getHint<T>(type: T, instance: instance);
    final type = hint?.obtainTypeOfRuntimeHint() ?? T;
    
    if (hint case final hint?) {
      final result = hint.invokeMethod<T>(instance, method, argument);
      if (result.getIsExecuted()) {
        return result.getResult();
      }
    }
    
    throw MethodNotFoundException(type, method);
  }

  @override
  Object? getValue<T>(T instance, String name) {
    final hint = descriptor.getHint<T>(type: T, instance: instance);
    final type = hint?.obtainTypeOfRuntimeHint() ?? T;
    
    if (hint case final hint?) {
      final result = hint.getFieldValue<T>(instance, name);
      if (result.getIsExecuted()) {
        return result.getResult();
      }
    }
    
    throw FieldAccessException(type, name);
  }

  @override
  void setValue<T>(T instance, String name, Object? value) {
    final hint = descriptor.getHint<T>(type: T, instance: instance);
    final type = hint?.obtainTypeOfRuntimeHint() ?? T;
    
    if (hint case final hint?) {
      final result = hint.setFieldValue<T>(instance, name, value);
      if (result.getIsExecuted()) {
        return;
      }
    }
    
    throw FieldMutationException(type, name);
  }
}