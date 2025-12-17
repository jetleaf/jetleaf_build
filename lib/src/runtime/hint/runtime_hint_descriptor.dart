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

import 'runtime_hint.dart';

/// {@template runtime_hint_descriptor}
/// An abstract descriptor that represents a collection of [RuntimeHint] instances.
///
/// The [RuntimeHintDescriptor] serves as a centralized container for runtime hints,
/// which are objects encapsulating dynamic behavior for constructors, method
/// invocations, and field access. This descriptor allows JetLeaf runtime systems
/// to query, add, and iterate over hints in a unified manner.
///
/// ## Characteristics
/// - Implements [Iterable] to allow iteration over all contained [RuntimeHint] instances.
/// - Provides typed access to specific hints via [getHint].
/// - Supports dynamic addition of hints using [addHint].
///
/// ## Usage
/// Typically, implementations of this class are used by runtime resolvers and
/// hint processors to maintain a registry of runtime hints for a particular
/// type, library, or execution context.
///
/// Example:
/// ```dart
/// final descriptor = MyRuntimeHintDescriptor();
/// descriptor.addHint(MyCustomRuntimeHint());
/// final hint = descriptor.getHint<MyCustomRuntimeHint>();
/// ```
/// {@endtemplate}
abstract class RuntimeHintDescriptor extends Iterable<RuntimeHint> {
  /// {@macro runtime_hint_descriptor}
  const RuntimeHintDescriptor();

  /// Retrieves a [RuntimeHint] of type [T].
  ///
  /// Optionally, an [instance] or [type] can be provided to narrow the lookup.
  /// Returns `null` if no matching hint is found.
  ///
  /// Example:
  /// ```dart
  /// final hint = descriptor.getHint<MyRuntimeHint>(instance: myObject);
  /// ```
  RuntimeHint? getHint<T>({Object? instance, Type? type});

  /// Adds a new [RuntimeHint] to the descriptor.
  ///
  /// Implementations typically append the hint to an internal collection,
  /// making it available for iteration and future lookups.
  ///
  /// Example:
  /// ```dart
  /// descriptor.addHint(MyCustomRuntimeHint());
  /// ```
  void addHint(RuntimeHint hint);
}