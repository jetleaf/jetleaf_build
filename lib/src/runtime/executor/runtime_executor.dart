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
import '../../exceptions.dart';
import '../declaration/declaration.dart';

/// {@template runtime_executor}
/// Defines an interface for executing runtime operations in a Dart environment,
/// providing a high-level abstraction for dynamic object creation, method invocation,
/// and field manipulation.  
///
/// `RuntimeExecutor` is designed for scenarios where compile-time type knowledge
/// is insufficient or unavailable, such as:
/// - Dependency injection frameworks that dynamically instantiate classes.
/// - Serialization/deserialization engines that read and write object state generically.
/// - Plugin systems, code generators, or runtime reflection frameworks like JetLeaf,
///   where type information and behavior must be resolved dynamically.
///
/// This interface allows implementers to provide a uniform mechanism for:
/// 1. **Dynamic instantiation**: Create new objects, including those with named
///    constructors, without static type references.
/// 2. **Dynamic method invocation**: Call methods on instances at runtime,
///    supplying positional and named arguments, with proper exception handling
///    if a method cannot be resolved.
/// 3. **Dynamic field access**: Read and write instance fields dynamically,
///    supporting both public and internal fields if the implementation allows.
///
/// The interface ensures that all operations can throw descriptive, domain-specific
/// exceptions (e.g., `ConstructorNotFoundException`, `MethodNotFoundException`,
/// `FieldAccessException`, `FieldMutationException`) to clearly signal runtime failures.
///
/// **Key Design Principles:**
/// - **Type safety when possible**: Returns typed results (`T` in `newInstance`)
///   while allowing dynamic invocation where needed.
/// - **Consistency across Dart platforms**: Works on Dart VM, Flutter, or server
///   environments depending on implementation strategy (reflection, mirrors, or
///   generated code).
/// - **Extensibility**: Can be extended to support advanced runtime scenarios,
///   such as caching constructors/methods or enforcing runtime constraints.
///
/// Example usage:
/// ```dart
/// final executor = MyRuntimeExecutor();
///
/// // Create a new instance dynamically
/// var instance = executor.newInstance<MyClass>('namedConstructor', args: [42], namedArgs: {'flag': true});
///
/// // Invoke a method dynamically
/// var result = executor.invokeMethod(instance, 'compute', args: [10]);
///
/// // Get a field value
/// var age = executor.getValue(instance, 'age');
///
/// // Set a field value
/// executor.setValue(instance, 'age', 30);
/// ```
/// {@endtemplate}
abstract interface class RuntimeExecutor {
  /// {@macro runtime_executor}
  const RuntimeExecutor();

  /// Dynamically creates a new instance of type `T` using the specified constructor.
  ///
  /// This method allows instantiating objects without compile-time knowledge of
  /// the class or its constructor. Both unnamed and named constructors are supported.
  ///
  /// **Parameters:**
  /// - `name`: The constructor name. Use `''` for the default unnamed constructor.
  /// - `returnType`: Optionally specify the expected type of the object being created.
  ///   This can be used for runtime type validation or casting.
  /// - `args`: Positional arguments to pass to the constructor.
  /// - `namedArgs`: Named arguments to pass to the constructor.
  ///
  /// **Returns:** An instance of type `T`.
  ///
  /// **Exceptions:** Throws [ConstructorNotFoundException] if no constructor
  /// matches the name and signature, or if instantiation fails.
  ///
  /// **Example:**
  /// ```dart
  /// final executor = MyRuntimeExecutor();
  /// var instance = executor.newInstance<MyClass>('named', args: [42], namedArgs: {'flag': true});
  /// ```
  T newInstance<T>(String name, ExecutableArgument argument, ConstructorDeclaration constructor, [Type? returnType]);

  /// Invokes a method on a given object instance at runtime.
  ///
  /// This supports both positional and named arguments. The method name must
  /// match exactly, otherwise a `MethodNotFoundException` is thrown.
  ///
  /// **Parameters:**
  /// - `instance`: The object on which to invoke the method.
  /// - `method`: Name of the method to invoke.
  /// - `args`: Positional arguments for the method.
  /// - `namedArgs`: Named arguments for the method.
  ///
  /// **Returns:** The result of the invoked method, or `null` if the method returns `void`.
  ///
  /// **Exceptions:** Throws [MethodNotFoundException] if the method is not found
  /// or cannot be invoked with the provided arguments.
  ///
  /// **Example:**
  /// ```dart
  /// var result = executor.invokeMethod(user, 'setName', args: ['Alice']);
  /// ```
  Object? invokeMethod<T>(T instance, String method, ExecutableArgument argument);
  
  /// Retrieves the value of a field from the specified instance.
  ///
  /// Useful for dynamic property access, serialization, or runtime inspection.
  ///
  /// **Parameters:**
  /// - `instance`: Object instance to read the field from.
  /// - `name`: Name of the field.
  ///
  /// **Returns:** The current value of the field.
  ///
  /// **Exceptions:** Throws [FieldAccessException] if the field is not found
  /// or is inaccessible.
  ///
  /// **Example:**
  /// ```dart
  /// var value = executor.getValue(user, 'age');
  /// ```
  Object? getValue<T>(T instance, String name);
  
  /// Sets the value of a field on the specified instance at runtime.
  ///
  /// Allows modification of object state dynamically, including private fields
  /// if the implementation permits reflective access.
  ///
  /// **Parameters:**
  /// - `instance`: Object instance whose field will be updated.
  /// - `name`: Name of the field.
  /// - `value`: The new value to assign to the field.
  ///
  /// **Exceptions:** Throws [FieldMutationException] if the field does not exist,
  /// is read-only, or cannot be modified.
  ///
  /// **Example:**
  /// ```dart
  /// executor.setValue(user, 'age', 30);
  /// ```
  void setValue<T>(T instance, String name, Object? value);
}