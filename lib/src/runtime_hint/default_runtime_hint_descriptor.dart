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

/// {@template default_generative_Runtime}
/// A concrete, mutable implementation of [RuntimeHintDescriptor] that stores
/// [RuntimeHint]s in an in-memory map.
///
/// This class acts as the central registry for JetLeaf's reflection system
/// in AOT (ahead-of-time) environments. It is typically used internally
/// by the reflection scanner and configured through [RuntimeHintProcessor]
/// implementations.
///
/// ## Example
///
/// ```dart
/// final Runtime = DefaultGenerativeRuntime();
/// Runtime.addRuntimeDescriptor(
///   RuntimeDescriptor<MyClass>(
///     type: MyClass,
///     newInstance: (name, [args = const [], namedArgs = const {}]) => MyClass(),
///     invokeMethod: (instance, method, {args = const [], namedArgs = const {}}) {
///       if (method == 'sayHello') {
///         return instance.sayHello();
///       }
///       return null;
///     },
///   ),
/// );
///
/// final descriptors = Runtime.getRuntimeDescriptors();
/// print(descriptors.containsKey(MyClass)); // true
/// ```
///
/// {@endtemplate}
class DefaultRuntimeHintDescriptors implements RuntimeHintDescriptor {
  /// Internal map storing type-to-[RuntimeHint] associations.
  final Map<Type, RuntimeHint> _descriptors = {};

  /// {@macro default_generative_executable}
  DefaultRuntimeHintDescriptors();

  @override
  Map<Type, RuntimeHint> getRuntimeHints() => Map.unmodifiable(_descriptors);

  @override
  void addRuntimeHints(List<RuntimeHint> hints) {
    for (final descriptor in hints) {
      _descriptors[descriptor.type] = descriptor;
    }
  }

  @override
  void addRuntimeHint(RuntimeHint hint) {
    _descriptors[hint.type] = hint;
  }
}