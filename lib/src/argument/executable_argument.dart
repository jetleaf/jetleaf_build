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

import 'dart:collection';

part '_executable_argument.dart';

/// {@template executable_argument}
/// Represents a fully normalized and transport-safe view of arguments passed
/// to an executable entity (constructor, method, function, or tear-off).
///
/// The [ExecutableArgument] interface abstracts away how arguments were
/// originally supplied and exposes a stable representation consisting of:
///
/// - **Ordered positional arguments**
/// - **Named arguments**, keyed using both string names and symbol names
///
/// This abstraction is used throughout the JetLeaf runtime reflection and
/// hint-processing pipeline to unify how arguments are captured, inspected,
/// transformed, or re-invoked.
///
/// ## Purpose
/// Reflection APIs, hint systems, and runtime resolvers often need to:
/// - Reconstruct invocation contexts
/// - Forward argument sets to new execution paths (AOT, JIT, hints, or mirrors)
/// - Normalize arguments so that they can be serialized or compared
///
/// [ExecutableArgument] provides a single contract that allows all components
/// in the system to work with argument collections safely and consistently.
///
/// ## Positional vs. Named Arguments
/// Positional arguments preserve the **exact order** in which the caller
/// supplied them. Named arguments preserve:
/// - Their **string name** (preferred for userland reflection)  
/// - Their **symbol key** (required for low-level `dart:mirrors` invocation)
///
/// Implementations ensure that these two representations remain aligned.
///
/// ## Immutability & Consistency
/// While implementations may store arguments in any internal representation,
/// callers should treat the returned collections as read-only snapshots.
/// Runtime resolvers and hint processors rely on argument immutability to
/// ensure deterministic behavior.
///
/// ## Creation
/// The static factory [ExecutableArgument.unmodified] constructs a normalized
/// argument container used by most parts of the runtime system.
///
/// Example:
/// ```dart
/// final args = ExecutableArgument.inEqualized(
///   {'count': 3},
///   [42, true],
/// );
///
/// print(args.getPositionalArguments()); // [42, true]
/// print(args.getNamedArguments());      // { 'count': 3 }
/// print(args.getSymbolizedNamedArguments());
/// // { #count: 3 }
/// ```
///
/// Implementations (such as [_UnmodifableExecutableArgument]) must guarantee
/// that both the string-keyed and symbol-keyed named argument maps represent
/// the same underlying values.
/// {@endtemplate}
abstract interface class ExecutableArgument {
  /// {@macro executable_argument}
  const ExecutableArgument();

  /// Returns the list of **positional arguments** in the order they were
  /// provided to the original call site.
  ///
  /// Implementations must preserve the exact ordering, as many downstream
  /// invocation paths—including AOT resolvers and mirror-based calls—depend on
  /// positional accuracy.
  ///
  /// Null values are allowed and should be represented faithfully.
  List<Object?> getPositionalArguments();

  /// Returns a map of **named arguments** keyed by their string names.
  ///
  /// This representation is useful for user-facing tooling, diagnostics,
  /// logging, and hint processors that operate at a semantic level.
  ///
  /// Keys must correspond exactly to the name used in invocation (without
  /// symbol wrapping or mangling). Values may be `null`.
  Map<String, Object?> getNamedArguments();

  /// Retrieves a single argument—either positional or named—based on the lookup
  /// value provided.
  ///
  /// This unified accessor exists to support dynamic, inspection-driven
  /// workflows in the JetLeaf runtime, where components may not know in advance
  /// whether an argument was originally passed positionally or by name.
  ///
  /// ## Lookup Rules
  ///
  /// The meaning of the [object] parameter depends on the [fromNamed] flag:
  ///
  /// ### 1. Named-argument lookup (`fromNamed == true`)
  /// - [object] must be a `String` representing the original name of the
  ///   argument as written at the call site.
  /// - Returns the value associated with that key, or `null` if the key exists
  ///   but the value is explicitly `null`.
  /// - Returns `null` if the argument name was not provided.
  ///
  /// Example:
  /// ```dart
  /// args.getArgument('count', true); // → 5
  /// ```
  ///
  /// ### 2. Positional lookup (`fromNamed == false`)
  /// - [object] must be an `int` representing the zero-based index of the
  ///   positional argument.
  /// - Returns the positional value at that index.
  /// - Throws `RangeError` if the index is outside the positional argument list.
  ///
  /// Example:
  /// ```dart
  /// args.getArgument(0, false); // → first positional argument
  /// ```
  ///
  /// ### 3. Automatic mode (`fromNamed == null`)
  /// When [fromNamed] is omitted, the lookup mode is inferred automatically:
  ///
  /// - If `object` is a `String` → named lookup  
  /// - If `object` is an `int` → positional lookup  
  /// - Otherwise → returns `null`  
  ///
  /// This mode is frequently used by generative systems, hint processors, and
  /// reflection layers that cannot assume ahead of time how the argument was
  /// supplied.
  ///
  /// ## Behavior Guarantees
  /// - Does *not* mutate the argument collection  
  /// - Respects all immutability guarantees of [ExecutableArgument]  
  /// - Operates strictly on the normalized, internal representation  
  ///
  /// ## Typical Usage
  ///
  /// ```dart
  /// final args = ExecutableArgument.unmodified(
  ///   {'flag': true},
  ///   ['hello', 42],
  /// );
  ///
  /// args.getArgument(1);          // → 42
  /// args.getArgument('flag');     // → true
  /// args.getArgument('missing');  // → null
  /// ```
  ///
  /// ## When to Use
  /// This method is ideal when:
  /// - A hint processor needs to inspect arbitrary argument bindings  
  /// - A runtime resolver is reconstructing invocation tokens  
  /// - Tooling needs a unified read API independent of argument style  
  ///
  /// It should *not* be used when callers already know whether arguments are
  /// named or positional—use the dedicated getters in those cases for clarity
  /// and performance.
  Object? getArgument(Object object, [bool? fromNamed]);

  /// Returns a map of **named arguments** keyed using [Symbol] objects.
  ///
  /// This representation is primarily required for `dart:mirrors` invocations,
  /// which only accept symbolic named arguments.
  ///
  /// Implementations must ensure that:
  /// - The set of keys here corresponds one-to-one with [getNamedArguments]  
  /// - The values mirror the same entries  
  ///
  /// Example:
  /// - `"count"` → `#count`
  Map<Symbol, Object?> getSymbolizedNamedArguments();

  /// Creates an [ExecutableArgument] from explicitly supplied named and
  /// positional arguments, ensuring both representations are internally
  /// aligned and normalized.
  ///
  /// This is the standard factory used by the runtime to wrap invocation
  /// contexts into a consistent format before they are passed to resolvers,
  /// generators, or hint processors.
  ///
  /// The returned implementation guarantees:
  /// - Positional argument order is preserved  
  /// - Named arguments are available in both string and symbol forms  
  /// - No further normalization is required downstream  
  static ExecutableArgument unmodified(Map<String, Object?> named, List<Object?> positional) => _UnmodifableExecutableArgument(named, positional);

  /// Returns a singleton or empty representation of [ExecutableArgument] 
  /// that contains **no positional or named arguments**.
  ///
  /// This is useful in scenarios where:
  /// - A method or constructor does not require any arguments
  /// - You want to provide a default, safe placeholder for argument lists
  /// - Generative, reflective, or hint-based systems expect an argument object 
  ///   even when no arguments are supplied
  ///
  /// ## Behavior
  /// - The returned instance guarantees that:
  ///   - `getPositionalArguments()` returns an empty list  
  ///   - `getNamedArguments()` returns an empty map  
  ///   - `getSymbolizedNamedArguments()` returns an empty map  
  /// - Immutability is preserved, so consumers cannot add arguments to this instance
  ///
  /// ## Example
  /// ```dart
  /// final emptyArgs = ExecutableArgument.none();
  ///
  /// assert(emptyArgs.getPositionalArguments().isEmpty);
  /// assert(emptyArgs.getNamedArguments().isEmpty);
  /// assert(emptyArgs.getSymbolizedNamedArguments().isEmpty);
  /// ```
  static ExecutableArgument none() => _NoExecutableArgument();

  /// Creates an [ExecutableArgument] containing **only positional arguments**.
  ///
  /// This is a convenience factory for cases where an invocation supplies
  /// positional arguments exclusively and no named arguments are present.
  ///
  /// Internally, this method delegates to [ExecutableArgument.unmodified]
  /// with an empty named-argument map.
  ///
  /// ## Behavior
  /// - Positional argument order is preserved exactly
  /// - Named arguments are treated as empty
  /// - The returned instance is immutable
  ///
  /// ## Example
  /// ```dart
  /// final args = ExecutableArgument.positional([1, 'hello', true]);
  ///
  /// print(args.getPositionalArguments()); // [1, 'hello', true]
  /// print(args.getNamedArguments());      // {}
  /// ```
  static ExecutableArgument positional(List<Object?> positional) => unmodified({}, positional);

  /// Creates an [ExecutableArgument] containing **only named arguments**.
  ///
  /// This factory is useful for invocations where arguments are supplied
  /// entirely by name (such as configuration objects or builder-style APIs).
  ///
  /// Internally, this method delegates to [ExecutableArgument.unmodified]
  /// with an empty positional-argument list.
  ///
  /// ## Behavior
  /// - Named arguments are available in both string-keyed and symbol-keyed forms
  /// - Positional arguments are treated as empty
  /// - The returned instance is immutable
  ///
  /// ## Example
  /// ```dart
  /// final args = ExecutableArgument.named({
  ///   'count': 5,
  ///   'enabled': true,
  /// });
  ///
  /// print(args.getNamedArguments()); // {count: 5, enabled: true}
  /// print(args.getPositionalArguments()); // []
  /// ```
  static ExecutableArgument named(Map<String, Object?> named) => unmodified(named, []);

  /// Creates an [ExecutableArgument] with **optional positional and named
  /// arguments**, defaulting to empty collections when omitted.
  ///
  /// This factory exists to simplify call sites where either argument group
  /// may be absent, while still guaranteeing a fully normalized
  /// [ExecutableArgument] instance.
  ///
  /// ## Behavior
  /// - If [named] is `null`, it is treated as an empty map
  /// - If [positional] is `null`, it is treated as an empty list
  /// - The returned instance is immutable and fully normalized
  ///
  /// ## Example
  /// ```dart
  /// final args1 = ExecutableArgument.optional(
  ///   positional: [42],
  /// );
  ///
  /// final args2 = ExecutableArgument.optional(
  ///   named: {'debug': true},
  /// );
  ///
  /// final args3 = ExecutableArgument.optional();
  /// ```
  ///
  /// This method is commonly used by:
  /// - Hint processors
  /// - Reflection utilities
  /// - Generative systems that conditionally supply arguments
  static ExecutableArgument optional({Map<String, Object?>? named, List<Object?>? positional}) {
    if (named == null && positional == null) {
      return none();
    }

    return unmodified(named ?? {}, positional ?? []);
  }
}