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
import '../../helpers/equals_and_hash_code.dart';

/// {@template hint}
/// Represents the outcome of a runtime hint operation within the JetLeaf
/// execution pipeline.
///
/// A [Hint] acts as a lightweight, immutable container that encodes:
///
/// - Whether a hint **execution path actually ran**
/// - The **result** of that execution, if any
///
/// This is used extensively throughout the AOT/JIT hybrid runtime to determine
/// whether a hint-provided override, transformation, or precomputation should
/// replace or bypass the default execution flow.
///
/// ## Purpose
/// Many components in JetLeaf—such as [RuntimeHint], `RuntimeHintProcessor`,
/// and the generative AOT executor—need a uniform way to express:
///
/// - “I executed and produced a replacement value”  
/// - “I executed but intentionally produced no result”  
/// - “I did not execute; please fall back to normal logic”  
///
/// [Hint] encodes these states concisely without requiring exception-based or
/// sentinel-value signaling.
///
/// ## Execution States
///
/// A [Hint] can be in one of three canonical states:
///
/// | State                      | Meaning | Created by |
/// |---------------------------|---------|------------|
/// | **Executed with result**  | The hint ran and produced a value | [Hint.executed] |
/// | **Executed without result** | The hint ran but intentionally returned no meaningful value | [Hint.executedWithoutResult] |
/// | **Not executed**          | The hint declined to participate; downstream systems must fall back | [Hint.notExecuted] |
///
/// These states are used by the runtime to coordinate layered hint
/// chains—where multiple hint processors may try to contribute logic.
///
/// ## Immutability
/// All fields are final, making every [Hint] instance effectively a sealed,
/// single-purpose message that cannot be modified after creation.
///
/// ## Typical Usage
///
/// ```dart
/// final hint = processor.invokeMethod()(instance, 'run', [], {});
///
/// if (hint.getIsExecuted()) {
///   final value = hint.getResult();
///   // Use the hint result instead of invoking reflectively.
/// } else {
///   // Fallback to default execution.
/// }
/// ```
///
/// {@endtemplate}
base class Hint {
  /// The result object produced by the hint execution, if any.
  ///
  /// - Contains the produced value when the hint executed and returned a result  
  /// - Contains `null` if the hint executed without returning a value  
  /// - Contains `null` if the hint did not execute at all  
  final Object? _object;

  /// Whether the hint-related logic actually executed.
  ///
  /// This distinguishes between:
  /// - A hint that declined to execute (value is `false`)
  /// - A hint that executed but produced `null` intentionally
  ///
  /// Runtime consumers rely on this flag to determine whether a fallback is
  /// needed.
  final bool _executed;

  /// Creates a new [Hint] with the given execution state and optional result.
  ///
  /// This is an internal constructor; end-users and runtime components should
  /// typically use the factory constructors ([executed], [executedWithoutResult],
  /// [notExecuted]) for clarity and correctness.
  ///
  /// {@macro hint}
  const Hint._(this._executed, this._object);

  /// Creates a [Hint] representing an executed operation that produced
  /// a result.
  ///
  /// - [object] is returned by [getResult]  
  /// - [getIsExecuted] will return `true`
  ///
  /// Example:
  /// ```dart
  /// return Hint.executed(42);
  /// ```
  static Hint executed(Object object) => Hint._(true, object);

  /// Creates a [Hint] representing an executed operation that intentionally
  /// produced **no result**.
  ///
  /// This is semantically different from not executing at all: the hint ran,
  /// chose not to override the value, but may have performed side effects.
  ///
  /// Typical use case:
  /// - Logging
  /// - Pre-validation
  /// - State preparation
  ///
  /// Example:
  /// ```dart
  /// return Hint.executedWithoutResult();
  /// ```
  static Hint executedWithoutResult() => Hint._(true, null);

  /// Creates a [Hint] representing a hint that **did not execute**.
  ///
  /// This signals to the runtime that fallback computation should occur.
  ///
  /// Example:
  /// ```dart
  /// return Hint.notExecuted();
  /// ```
  static Hint notExecuted() => Hint._(false, null);

  /// Returns the result value produced by the hint, if any.
  ///
  /// - May return a real value  
  /// - May return `null` because the hint executed without a result  
  /// - May return `null` because the hint did *not* execute  
  ///
  /// This method should always be evaluated in combination with [getIsExecuted].
  Object? getResult() => _object;

  /// Indicates whether the hint logic actually executed.
  ///
  /// Use this flag to distinguish:
  /// - No execution → fallback needed  
  /// - Executed but returned `null` → valid but empty override  
  ///
  /// Example:
  /// ```dart
  /// if (!hint.getIsExecuted()) {
  ///   // fall back
  /// }
  /// ```
  bool getIsExecuted() => _executed;
}

/// {@template runtime_hint}
/// A contract for providing runtime-level behavioral overrides to the JetLeaf
/// execution system.
///
/// `RuntimeHint` is the central extension point that allows AOT-generated
/// code, plugins, adapters, and custom reflection layers to intercept,
/// replace, or augment:
///
/// - **Instance creation**
/// - **Method invocation**
/// - **Field access**
/// - **Field mutation**
///
/// Instead of relying on the reflective capabilities of the Dart runtime,
/// JetLeaf uses a *hint-driven execution model* where each potential
/// runtime action consults available hints before falling back to
/// default/native execution.
///
/// Implementations of [RuntimeHint] can provide:
///
/// - Full overrides (replace the entire behavior)
/// - Conditional overrides (execute only for specific classes, patterns, or states)
/// - Diagnostic instrumentation (e.g., logging, tracing)
/// - Precomputation or AOT-substitution
///
/// All hint operations return a [Hint], which communicates:
///
/// - Whether the hint actually executed  
/// - Whether it produced a meaningful result  
/// - The result of the operation (if any)  
///
/// ## Execution Flow
/// A typical pipeline that evaluates hints may work as follows:
///
/// 1. The runtime attempts to create/invoke/read/write via hints.
/// 2. Each hint implementation receives the call.
/// 3. If the hint wants to handle it:
///    - It returns `Hint.executed(...)` or `Hint.executedWithoutResult()`.
/// 4. If the hint chooses not to handle it:
///    - It returns `Hint.notExecuted()`.
/// 5. If all hints decline, the system performs default behavior.
///
/// ## Implementing RuntimeHint
/// Concrete implementations typically:
///
/// - Are stateless or lightly cached  
/// - Provide fast pattern detection (e.g. type-based or metadata-based)  
/// - Maintain consistent interpretation of `ExecutableArgument`  
///
/// ```dart
/// class MyRuntimeHint implements RuntimeHint {
///   const MyRuntimeHint();
///
///   @override
///   Hint createNewInstance(String constructor, ExecutableArgument args) {
///     if (constructor == 'Special') {
///       return Hint.executed(Special(args.getPositionalArguments().first));
///     }
///     return Hint.notExecuted();
///   }
///
///   @override
///   FutureOr<Hint> invokeMethod(Object instance, String method, ExecutableArgument args) {
///     // custom interception...
///     return Hint.notExecuted();
///   }
///
///   // and so on...
/// }
/// ```
///
/// {@endtemplate}
abstract interface class RuntimeHint with EqualsAndHashCode {
  /// Base constructor for all runtime hint implementations.
  ///
  /// This constructor is const to allow hint implementations to be used as
  /// compile-time constants, cached singletons, or embedded into generated
  /// code without runtime overhead.
  ///
  /// {@macro runtime_hint}
  const RuntimeHint();

  // ---------------------------------------------------------------------------
  // Instance Creation
  // ---------------------------------------------------------------------------

  /// Attempts to create a new instance using the given constructor and arguments.
  ///
  /// ### Parameters
  /// - **constructorName** – The string identifier of the constructor,
  ///   typically the class name or named constructor (e.g., `'MyClass'`,
  ///   `'MyClass.named'`).
  /// - **argument** – A structured bundle of positional and named arguments,
  ///   represented by [ExecutableArgument].
  ///
  /// ### Return
  /// A [Hint] indicating:
  /// - `executed(...)` → The instance was created by the hint implementation.  
  /// - `executedWithoutResult()` → The hint performed work but declines to
  ///   return an instance.  
  /// - `notExecuted()` → The hint does not handle this constructor.
  ///
  /// ### Intended Usage
  /// Allows substitution of constructors, dependency injection,
  /// AOT-generated factories, or proxy instantiation.
  Hint createNewInstance<T>(String constructorName, ExecutableArgument argument);

  // ---------------------------------------------------------------------------
  // Method Invocation
  // ---------------------------------------------------------------------------

  /// Attempts to invoke a method on the given instance.
  ///
  /// ### Parameters
  /// - **instance** – The target object on which the method would be invoked.
  /// - **methodName** – The method identifier as a string.
  /// - **argument** – Positional and named arguments bundled in
  ///   [ExecutableArgument].
  ///
  /// ### Return
  /// A [FutureOr] of [Hint], enabling both synchronous and asynchronous
  /// resolution.  
  ///
  /// Returning:
  /// - `Hint.executed(result)` → The method call is fully handled.  
  /// - `Hint.executedWithoutResult()` → The hint handled it but produced no
  ///   return value.  
  /// - `Hint.notExecuted()` → Defer to the next hint or runtime fallback.
  ///
  /// ### Usage Scenarios
  /// - Method virtualization or remapping  
  /// - Lazy value computation  
  /// - AOT-generated function bodies  
  /// - Interception, logging, tracing  
  Hint invokeMethod<T>(T instance, String methodName, ExecutableArgument argument);

  // ---------------------------------------------------------------------------
  // Field Access
  // ---------------------------------------------------------------------------

  /// Attempts to read the value of a field from the given instance.
  ///
  /// ### Parameters
  /// - **instance** – The object containing the field.
  /// - **name** – Field name as a string.
  ///
  /// ### Return
  /// A [Hint] describing whether the hint provided a value or declined to act.
  ///
  /// Example return behavior:
  /// - `executed(value)` → The hint provides an override.  
  /// - `notExecuted()` → The runtime must fall back to normal property access.  
  ///
  /// ### Usage
  /// - Virtual fields  
  /// - Redirected or computed properties  
  /// - Diagnostics (field access tracing)
  Hint getFieldValue<T>(T instance, String fieldName);

  // ---------------------------------------------------------------------------
  // Field Mutation
  // ---------------------------------------------------------------------------

  /// Attempts to write a value to a field on the given instance.
  ///
  /// ### Parameters
  /// - **instance** – The object containing the field.
  /// - **name** – Name of the field to set.
  /// - **value** – The value to assign, which may be `null`.
  ///
  /// ### Return
  /// A [Hint] indicating whether the hint handled the assignment.
  ///
  /// Typical return patterns:
  /// - `executedWithoutResult()` → The assignment occurred via custom logic.  
  /// - `executed(value)` → The hint performed the assignment and returned the
  ///   effective value.  
  /// - `notExecuted()` → Defer to default field mutation.
  ///
  /// ### Usage
  /// - Write interception  
  /// - Validation or constraint enforcement  
  /// - Reactive triggers
  Hint setFieldValue<T>(T instance, String fieldName, Object? value);

  // ---------------------------------------------------------------------------
  // Type Information
  // ---------------------------------------------------------------------------

  /// Returns the runtime [Type] associated with this hint implementation.
  ///
  /// Used by hint registries, type-based dispatchers, and AOT code generators
  /// to associate hint logic with the types or patterns they target.
  ///
  /// Implementations typically return the type they are responsible for
  /// handling, not the type of the hint class itself.
  ///
  /// Example:
  /// ```dart
  /// class UserHint extends RuntimeHint {
  ///   @override
  ///   Type obtainTypeOfRuntimeHint() => User;
  /// }
  /// ```
  Type obtainTypeOfRuntimeHint();
}