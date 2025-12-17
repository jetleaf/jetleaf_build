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
import 'runtime_hint_descriptor.dart';

/// {@template default_runtime_hint_descriptor}
/// A concrete implementation of [RuntimeHintDescriptor] that stores hints in a simple list.
///
/// [DefaultRuntimeHintDescriptor] serves as the standard, out-of-the-box
/// container for runtime hints in JetLeaf. It maintains a collection of
/// [RuntimeHint] objects and provides basic operations for adding and retrieving
/// hints by type or associated instance.
///
/// ## Characteristics
/// - Internally stores hints in a list (`_hints`) to preserve insertion order.
/// - Supports type-based and instance-based lookup through [getHint].
/// - Implements [Iterable] to allow iteration over all stored hints.
/// - Designed for general-purpose runtime hint management, suitable for both
///   AOT and JIT execution contexts.
///
/// ## Typical Usage
/// This class is typically used by JetLeaf runtime systems to:
/// - Maintain a registry of runtime hints for a library, class, or execution context.
/// - Provide type-safe access to specific runtime hints.
/// - Iterate over all hints for processing by resolvers or generators.
///
/// Example:
/// ```dart
/// final descriptor = DefaultRuntimeHintDescriptor();
/// descriptor.addHint(MyCustomRuntimeHint());
///
/// final hint = descriptor.getHint<MyCustomRuntimeHint>();
/// for (final h in descriptor) {
///   // Process each hint
/// }
/// ```
///
/// This implementation guarantees deterministic iteration order and
/// basic type resolution for hints, making it the default choice in
/// most runtime scenarios.
/// {@endtemplate}
class DefaultRuntimeHintDescriptor extends RuntimeHintDescriptor {
  /// Internal storage for runtime hints.
  ///
  /// This list maintains all [RuntimeHint] instances added to the
  /// [DefaultRuntimeHintDescriptor]. It preserves insertion order,
  /// allowing deterministic iteration and lookup.  
  /// Access to this list is restricted to the class itself to ensure
  /// encapsulation and maintain control over how hints are added and retrieved.
  final List<RuntimeHint> _hints = [];

  /// {@macro default_runtime_hint_descriptor}
  DefaultRuntimeHintDescriptor();

  @override
  RuntimeHint? getHint<T>({Object? instance, Type? type}) {
    final hint = _hints.where((hint) => hint.obtainTypeOfRuntimeHint() == (type ?? T)).firstOrNull;

    if (hint != null) {
      return hint;
    }

    return instance.runtimeType != Type 
      ? _hints.where((hint) => hint.obtainTypeOfRuntimeHint() == instance.runtimeType).firstOrNull
      : _hints.where((hint) => hint.obtainTypeOfRuntimeHint() == instance).firstOrNull;
  }

  @override
  void addHint(RuntimeHint hint) => _hints.add(hint);
  
  @override
  Iterator<RuntimeHint> get iterator => _hints.iterator;
}