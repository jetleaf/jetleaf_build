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

import '../../exceptions.dart';
import '../runtime_hint/runtime_hint_descriptor.dart';
import 'runtime_resolver.dart';

/// {@template aot_runtime_resolver}
/// A concrete implementation of [RuntimeResolver] that operates using
/// a [RuntimeHintDescriptor] registry.
///
/// This class is ideal for Ahead-Of-Time (AOT) compiled environments where
/// `dart:mirrors` is not supported. Instead of using reflection, it leverages
/// pre-registered [RuntimeHint]s for dynamic method invocation,
/// instance creation, and field access.
///
/// ## Usage Example
///
/// First, register descriptors in a [RuntimeHintDescriptor]:
///
/// ```dart
/// final generativeExecutable = GenerativeExecutable()
///   ..register(MyClass, RuntimeHintDescriptor(
///     newInstance: (name, args, namedArgs) => MyClass(),
///     invokeMethod: (instance, method, {args = const [], namedArgs = const {}}) {
///       if (method == 'greet') return (instance as MyClass).greet();
///       throw Exception('Unknown method');
///     },
///     getValue: (instance, field) {
///       if (field == 'message') return (instance as MyClass).message;
///       throw Exception('Unknown field');
///     },
///     setValue: (instance, field, value) {
///       if (field == 'message') (instance as MyClass).message = value as String;
///     },
///   ));
///
/// final resolver = AotExecutableResolver(generativeExecutable);
/// final instance = resolver.newInstance<MyClass>('Aot');
/// final greeting = resolver.invokeMethod(instance, 'greet');
/// print(greeting); // Hello!
/// ```
///
/// {@endtemplate}
class AotRuntimeResolver implements RuntimeResolver {
  /// The registry used to resolve and execute generative descriptors.
  final RuntimeHintDescriptor? resolver;

  /// {@macro aot_runtime_resolver}
  const AotRuntimeResolver(this.resolver);

  @override
  T newInstance<T>(String name, [Type? returnType, List<Object?> args = const [], Map<String, Object?> namedArgs = const {}]) {
    final descriptor = resolver?.getRuntimeHints()[returnType ?? T];
    
    if (descriptor == null || descriptor.newInstance == null) {
      throw ConstructorNotFoundException(T.toString(), name);
    }
    
    return descriptor.newInstance!(name, args, namedArgs) as T;
  }

  @override
  Object? invokeMethod<T>(T instance, String method, {List<Object?> args = const [], Map<String, Object?> namedArgs = const {}}) {
    final descriptor = instance.runtimeType != Type 
      ? resolver?.getRuntimeHints()[instance.runtimeType]
      : resolver?.getRuntimeHints()[instance];
    
    if (descriptor == null || descriptor.invokeMethod == null) {
      throw MethodNotFoundException(instance.runtimeType.toString(), method);
    }

    return descriptor.invokeMethod!(instance as Object, method, args, namedArgs);
  }

  @override
  Object? getValue<T>(T instance, String name) {
    final descriptor = instance.runtimeType != Type 
      ? resolver?.getRuntimeHints()[instance.runtimeType]
      : resolver?.getRuntimeHints()[instance];
    
    if (descriptor == null || descriptor.getValue == null) {
      throw FieldAccessException(instance.runtimeType.toString(), name);
    }

    return descriptor.getValue!(instance as Object, name);
  }

  @override
  void setValue<T>(T instance, String name, Object? value) {
    final descriptor = instance.runtimeType != Type 
      ? resolver?.getRuntimeHints()[instance.runtimeType]
      : resolver?.getRuntimeHints()[instance];
    
    if (descriptor == null || descriptor.setValue == null) {
      throw FieldMutationException(instance.runtimeType.toString(), name);
    }

    descriptor.setValue!(instance as Object, name, value);
  }
}