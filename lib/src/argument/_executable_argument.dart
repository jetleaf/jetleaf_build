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

part of 'executable_argument.dart';

/// {@template _unmodifiable_exectuable_argument}
/// A concrete, fully normalized implementation of [ExecutableArgument] used by
/// the JetLeaf runtime to capture and transport invocation parameters in a
/// stable, immutable form.
///
/// `UnmodifableExecutableArgument` represents an **equalized argument packet**,
/// meaning that:
/// - Positional arguments are stored exactly in the order they were supplied  
/// - Named arguments are preserved exactly as written at the call site  
/// - Named arguments are internally available in both string-keyed and symbol-keyed forms  
///
/// This class is the canonical container used throughout the runtime pipeline
/// when arguments must cross boundaries between:
/// - AOT resolvers  
/// - JIT/mirror executors  
/// - Generative hint processors  
/// - Internal dispatchers and fallback strategies  
///
/// It ensures that no matter where the argument packet originates, downstream
/// components receive a consistent, snapshot-style representation—free of side
/// effects and safe to cache, inspect, and forward.
///
/// ## Immutability
/// The returned collections from all getters are wrapped in unmodifiable views.
/// This prevents accidental mutations that could cause desynchronization across
/// the system. It is especially critical in scenarios where:
/// - The same argument packet is forwarded to multiple resolvers  
/// - Hint processors capture arguments for delayed execution  
/// - The JIT/mirror executor reconstructs invocations dynamically  
///
/// Because the runtime relies heavily on argument stability to produce
/// deterministic results, immutability is a core guarantee of this type.
///
/// ## Responsibilities
/// This class does *not* attempt to restructure or validate arguments. Instead,
/// it assumes the supplying code (usually `ExecutableArgument.inEqualized`)
/// has already normalized the inputs. Its sole responsibilities are:
///
/// - Storing arguments in a minimal, structured form  
/// - Projecting named arguments into symbolic keys for mirror compatibility  
/// - Providing read-only accessors that uphold the `ExecutableArgument` contract  
///
/// ## Typical Usage
/// `UnmodifableExecutableArgument` is rarely instantiated directly in user code.
/// Instead, it is created via `ExecutableArgument.inEqualized`, ensuring all
/// runtime systems use a unified construction path.
///
/// Example:
/// ```dart
/// final args = ExecutableArgument.inEqualized(
///   {'flag': true, 'count': 5},
///   ['hello', 123],
/// );
///
/// // The runtime may use these values for reflective invocation:
/// resolver.invokeMethod(instance, 'run',
///   args: args.getPositionalArguments(),
///   namedArgs: args.getSymbolizedNamedArguments(),
/// );
/// ```
///
/// ## Integration Notes
/// This class is intentionally lightweight. It is frequently instantiated during
/// reflective dispatch, often in hot paths, and therefore avoids expensive
/// transformations while still ensuring the integrity and immutability required
/// at higher levels of the JetLeaf execution stack.
///
/// It forms the backbone of how JetLeaf models execution contexts across AOT,
/// JIT, generative, and mirror-based resolution environments.
/// {@endtemplate}
final class _UnmodifableExecutableArgument implements ExecutableArgument {
  /// The raw list of **positional arguments** exactly as they were provided
  /// at the call site.
  ///
  /// This list preserves:
  /// - The original ordering of arguments  
  /// - The original count (including any `null` values)  
  /// - The original runtime types of each element  
  ///
  /// It is intentionally stored as a mutable `List<Object?>` internally, but
  /// exposed only through an unmodifiable view. This design allows the runtime
  /// to construct argument packets efficiently—often within performance-critical
  /// invocation paths—while still guaranteeing *external immutability*.
  ///
  /// The JetLeaf runtime uses this field as the authoritative source of
  /// positional argument data when dispatching calls through:
  /// - AOT resolvers  
  /// - JIT/mirror method invocation  
  /// - Generated or hinted executables  
  ///
  /// Consumers should always access positional arguments through
  /// [getPositionalArguments], which provides an immutable snapshot.
  final List<Object?> _positionalArguments;

  /// The raw map of **named arguments**, keyed by their original identifier
  /// strings as written at the call site.
  ///
  /// This map preserves:
  /// - Exact argument names (pre-symbolization)  
  /// - Argument ordering as preserved by map insertion order  
  /// - All runtime values, including `null`  
  ///
  /// JetLeaf stores named arguments in their string-keyed form to maintain
  /// compatibility across:
  /// - AOT-generated executables  
  /// - Runtime hint processors  
  /// - Fallback mirror-based invocation  
  ///
  /// When a symbolic form is required (such as during reflective invocation),
  /// the map is lazily projected into a `Map<Symbol, Object?>` via
  /// [getSymbolizedNamedArguments], ensuring zero overhead for cases that do
  /// not require symbolization.
  ///
  /// Like positional arguments, this map is internally mutable only during
  /// construction; all public accessors expose immutable snapshots to preserve
  /// argument stability throughout the execution pipeline.
  final Map<String, Object?> _namedArguments;

  /// {@macro _unmodifiable_exectuable_argument}
  const _UnmodifableExecutableArgument(this._namedArguments, this._positionalArguments);

  @override
  Map<String, Object?> getNamedArguments() => UnmodifiableMapView(_namedArguments);

  @override
  List<Object?> getPositionalArguments() => UnmodifiableListView(_positionalArguments);

  @override
  Map<Symbol, Object?> getSymbolizedNamedArguments() {
    final symbolized = _namedArguments.map((key, value) => MapEntry(Symbol(key), value));
    return UnmodifiableMapView(symbolized);
  }

  @override
  Object? getArgument(Object object, [bool? fromNamed]) {
    if (fromNamed case true?) {
      return _namedArguments[object];
    }

    if (object case Symbol symbol) {
      return getSymbolizedNamedArguments()[symbol];
    }

    Object? result = _namedArguments[object];
    if (result == null) {
      if (object case int index) {
        return _positionalArguments.elementAt(index);
      }

      return _positionalArguments.where((element) => element == object).firstOrNull;
    }

    return result;
  }
}

/// {@template _no_executable_argument}
/// A specialized, immutable implementation of [ExecutableArgument] representing
/// the absence of any arguments.
///
/// This class is used internally by [ExecutableArgument.none()] to provide a
/// safe, consistent, and zero-overhead placeholder when no positional or named
/// arguments are present.
///
/// ## Characteristics
/// - **Empty**: contains no positional or named arguments.
/// - **Immutable**: all getters return empty collections or `null`.
/// - **Singleton-friendly**: can be reused wherever an empty argument container
///   is required, minimizing allocations.
///
/// ## Usage
/// Typically, you will not instantiate this class directly. Instead, use:
/// ```dart
/// final emptyArgs = ExecutableArgument.none();
/// ```
/// All methods (`getPositionalArguments`, `getNamedArguments`,
/// `getSymbolizedNamedArguments`, `getArgument`) will return empty or `null`
/// values, making it safe to pass to reflective or generative executors.
/// {@endtemplate}
final class _NoExecutableArgument implements ExecutableArgument {
  /// {@macro _no_executable_argument}
  const _NoExecutableArgument();

  @override
  Object? getArgument(Object object, [bool? fromNamed]) => null;

  @override
  Map<String, Object?> getNamedArguments() => {};

  @override
  List<Object?> getPositionalArguments() => [];

  @override
  Map<Symbol, Object?> getSymbolizedNamedArguments() => {};
}