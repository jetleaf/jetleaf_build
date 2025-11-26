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

/// {@template runtime_hint}
/// A hint that defines how to interact with a specific type `Object` through reflection-like operations.
///
/// `RuntimeHint` is a metadata container used by JetLeaf's reflection system, especially
/// in environments without `dart:mirrors`, such as ahead-of-time (AOT) compilation.
///
/// It provides function references to:
/// - Create new instances of `Object`
/// - Invoke methods on `Object`
/// - Read fields on `Object`
/// - Write fields on `Object`
///
/// These operations are usually supplied by generated code or runtime hooks.
///
/// ## Example
/// ```dart
/// final descriptor = RuntimeHint(
///   type: MyClass,
///   newInstance: (name, [args = const [], namedArgs = const {}]) => MyClass(),
///   invokeMethod: (instance, method, {args = const [], namedArgs = const {}}) {
///     if (method == 'sayHello') return instance.sayHello();
///     throw UnimplementedError();
///   },
///   getValue: (instance, name) {
///     if (name == 'value') return instance.value;
///     throw UnimplementedError();
///   },
///   setValue: (instance, name, value) {
///     if (name == 'value') instance.value = value;
///   },
/// );
/// ```
///
/// {@endtemplate}
class RuntimeHint {
  /// The runtime type this descriptor applies to.
  ///
  /// This is usually the `Object` type for which the descriptor was registered.
  final Type type;

  /// Function to create a new instance of type `Object`.
  ///
  /// This function is used internally by the [RuntimeResolver] to instantiate
  /// objects without `dart:mirrors`.
  ///
  /// See [NewInstanceCreator] for details.
  final NewInstanceCreator? newInstance;

  /// Function to invoke a method on an instance of type `Object`.
  ///
  /// This is used by reflection systems to dynamically dispatch method calls.
  /// If not supplied, calling [RuntimeResolver.invokeMethod] will throw.
  ///
  /// See [InvokeMethodCreator] for function signature.
  final InvokeMethodCreator? invokeMethod;

  /// Function to get the value of a field on an instance of type `Object`.
  ///
  /// This allows reflective access to fields on the object.
  ///
  /// See [GetValueCreator] for function signature.
  final GetValueCreator? getValue;

  /// Function to set the value of a field on an instance of type `Object`.
  ///
  /// This allows reflective mutation of object fields.
  ///
  /// See [SetValueCreator] for function signature.
  final SetValueCreator? setValue;

  /// {@macro runtime_hint}
  const RuntimeHint({required this.type, this.newInstance, this.invokeMethod, this.getValue, this.setValue});
}

/// {@template new_instance_creator}
/// Typedef for a function that creates a new instance of type `Object`.
///
/// - `name`: The constructor name (e.g., `''` for default, `'named'` for named constructors).
/// - `args`: Positional arguments passed to the constructor.
/// - `namedArgs`: Named arguments passed to the constructor.
///
/// Returns a new instance of `Object`.
///
/// {@endtemplate}
typedef NewInstanceCreator = Object Function(String name, List<Object?> args, Map<String, Object?> namedArgs);

/// {@template invoke_method_creator}
/// Typedef for a function that invokes a method on an instance of type `Object`.
///
/// - `instance`: The target instance of `Object`.
/// - `method`: The name of the method to invoke.
/// - `args`: Positional arguments.
/// - `namedArgs`: Named arguments.
///
/// Returns the result of the method, or `null` if the method returns `void`.
///
/// {@endtemplate}
typedef InvokeMethodCreator = Object? Function(Object instance, String method, List<Object?> args, Map<String, Object?> namedArgs);

/// {@template get_value_creator}
/// Typedef for a function that gets the value of a field on an instance of type `Object`.
///
/// - `instance`: The object instance.
/// - `name`: The name of the field to retrieve.
///
/// Returns the field value as [Object?].
///
/// {@endtemplate}
typedef GetValueCreator = Object? Function(Object instance, String name);

/// {@template set_value_creator}
/// Typedef for a function that sets the value of a field on an instance of type `Object`.
///
/// - `instance`: The target object.
/// - `name`: The name of the field to assign.
/// - `value`: The value to set.
///
/// {@endtemplate}
typedef SetValueCreator = void Function(Object instance, String name, Object? value);