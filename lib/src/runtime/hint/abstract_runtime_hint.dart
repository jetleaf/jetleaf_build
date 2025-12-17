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
import '../../annotations.dart';
import '../../helpers/equals_and_hash_code.dart';
import 'runtime_hint.dart';

/// {@template abstract_runtime_hint}
/// A generic, opt-in base class for implementing strongly typed
/// [RuntimeHint] providers.
///
/// `AbstractRuntimeHint<T>` standardizes the process of associating a hint
/// implementation with a specific runtime type `T`. By combining:
///
/// - **Generic type binding**  
/// - **Automatic type reporting**  
/// - **Default no-operation behavior**  
///
/// this class provides an ergonomic starting point for implementers who want
/// to override JetLeaf’s runtime behavior only for particular types.
///
/// ## Purpose
/// JetLeaf relies on *hint-driven execution* to selectively override runtime
/// operations such as:
///
/// - Instance creation  
/// - Method invocation  
/// - Field access  
/// - Field mutation  
///
/// Each hint decides whether it wants to handle a given request. If it does
/// not, the runtime continues evaluating other hints or falls back to the
/// default execution strategy.
///
/// `AbstractRuntimeHint<T>` makes it trivial to build hints that activate only
/// when the target instance or requested type matches `T`.
///
/// ## Generic Binding
/// The `@Generic(AbstractRuntimeHint)` annotation ensures that JetLeaf’s
/// build system captures the type argument `T` at compile time. This allows
/// code generators, resolvers, and dispatch layers to:
///
/// - Associate the hint with its target type  
/// - Produce optimized invocation paths  
/// - Avoid reflective type inference or mirror lookups  
///
/// ## Default Behavior
/// All RuntimeHint methods in this class return `Hint.notExecuted()`.
///
/// This has two advantages:
///
/// 1. **Minimal boilerplate.** Implementers override only the hooks they need.  
/// 2. **Predictable fallback behavior.** If a hint does not explicitly handle
///    something, it safely declines without interfering with other runtime
///    logic.
///
/// ## Example
/// ```dart
/// class UserHint extends AbstractRuntimeHint<User> {
///   @override
///   Hint getFieldValue(Object instance, String name) {
///     if (instance is User && name == 'isAdmin') {
///       return Hint.executed(true);
///     }
///     return super.getFieldValue(instance, name);
///   }
/// }
/// ```
///
/// ## Intended Use Cases
/// - AOT or build-time generated runtime adapters  
/// - Lightweight overrides for domain models  
/// - Instrumentation, diagnostics, and profiling layers  
/// - Intercepting reflective behavior for performance optimizations  
///
/// {@endtemplate}
@Generic(AbstractRuntimeHint)
abstract class AbstractRuntimeHint<T> with EqualsAndHashCode implements RuntimeHint {
  /// {@macro abstract_runtime_hint}
  const AbstractRuntimeHint();

  @override
  Type obtainTypeOfRuntimeHint() => T;

  @override
  Hint createNewInstance<U>(String constructorName, ExecutableArgument argument) => Hint.notExecuted();

  @override
  Hint invokeMethod<U>(U instance, String methodName, ExecutableArgument argument) => Hint.notExecuted();

  @override
  Hint getFieldValue<U>(U instance, String fieldName) => Hint.notExecuted();

  @override
  Hint setFieldValue<U>(U instance, String fieldName, Object? value) => Hint.notExecuted();

  @override
  List<Object?> equalizedProperties() => [T];
}