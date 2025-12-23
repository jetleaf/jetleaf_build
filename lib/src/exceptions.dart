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

/// {@template throwable}
/// Base class for all throwable exceptions in JetLeaf.
///
/// This abstract type combines both [Error] and [Exception] so that all
/// JetLeaf errors can be caught using `on Exception`, `on Error`, or
/// the shared `on Throwable` type. This provides consistency across the
/// framework for handling system-level and application-level errors.
///
/// Extend this class for any custom exceptions that should be treated as
/// fatal or critical by the JetLeaf runtime.
/// {@endtemplate}
abstract interface class Throwable extends Error implements Exception {
  /// The message associated with this exception.
  /// 
  /// It defaults to the string representation of the exception.
  String getMessage() => toString();

  /// The stack trace associated with this exception.
  /// 
  /// It defaults to [StackTrace.current] if not provided.
  StackTrace getStackTrace() => StackTrace.current;

  /// The cause of this exception, if any.
  /// 
  /// It defaults to the exception itself if not provided.
  Object? getCause() => this;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Throwable) return false;
    if(other.getMessage() != getMessage()) return false;
    if(other.getStackTrace() != getStackTrace()) return false;
    if(other.getCause() != getCause()) return false;
    return true;
  }

  @override
  int get hashCode {
    return getMessage().hashCode ^ getStackTrace().hashCode ^ getCause().hashCode;
  }
}

/// {@template runtime_exception}
/// Represents an unchecked runtime exception in JetLeaf.
///
/// A [RuntimeException] signals a system-level failure or application bug
/// that was not expected at runtime. This is commonly used for failures
/// such as invalid application state, misconfigurations, or internal
/// logic errors that are not recoverable.
///
/// It includes a [message], optional [cause], and a [stackTrace] (defaults
/// to [StackTrace.current] if not provided).
///
/// ### Example:
/// ```dart
/// throw RuntimeException('Invalid state', cause: SomeOtherError());
/// ```
/// {@endtemplate}
class RuntimeException extends Error implements Throwable {
  /// The message describing the error.
  final String message;

  /// The underlying cause of this exception, if any.
  final Object? cause;

  /// The associated stack trace.
  @override
  final StackTrace stackTrace;

  /// Creates a new [RuntimeException] with a message and [StackTrace].
  /// 
  /// {@macro runtime_exception}
  RuntimeException(this.message, {this.cause, StackTrace? stackTrace}) : stackTrace = stackTrace ?? StackTrace.current;

  @override
  String getMessage() => message;

  @override
  StackTrace getStackTrace() => stackTrace;

  @override
  Object getCause() => cause ?? this;

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message\n$stackTrace');
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }

    return buffer.toString();
  }
}

/// {@template jetleaf_build_exception}
/// An exception thrown when a **build-time or configuration-time failure**
/// occurs within the Jetleaf framework.
///
/// This exception is used to signal errors that arise during:
/// - Repository definition construction
/// - Context or pod initialization
/// - Dynamic code generation or runtime wiring
/// - Any internal build or setup process where additional cause information
///   may be relevant
///
/// The exception supports an optional [cause] and [stackTrace], making it
/// suitable for wrapping lower-level exceptions while preserving diagnostic
/// context.
///
/// ### Usage Example
/// ```dart
/// void buildRepository() {
///   try {
///     // Some operation that fails
///     throw StateError("Invalid repository metadata");
///   } catch (e, s) {
///     throw BuildException(
///       "Failed to build repository definition",
///       cause: e,
///       stackTrace: s,
///     );
///   }
/// }
/// ```
///
/// ### Design Notes
/// - Immutable and lightweight (`const` constructor).
/// - Provides a detailed `toString()` implementation for improved debugging.
/// - Intended for internal build processes, not user-facing errors.
///
/// ### Example Behavior
/// | Field | Description |
/// |-------|-------------|
/// | `message` | Primary reason for the failure |
/// | `cause` | Optional underlying error |
/// | `stackTrace` | Optional trace of where the error originated |
///
/// ### See Also
/// - [Exception]
/// - [Error]
/// - [StackTrace]
/// {@endtemplate}
final class BuildException extends RuntimeException {
  /// {@macro jetleaf_build_exception}
  BuildException(super.message, {super.cause, super.stackTrace});

  @override
  String toString() {
    if (cause != null) {
      return 'BuildException: $message (cause: $cause)\n$stackTrace';
    }
    return 'BuildException: $message';
  }
}

/// {@template jetleaf_runtime_resolver_exception}
/// Base class for all **resolver-related exceptions** within the Jetleaf
/// resolution and evaluation subsystem.
///
/// This abstract exception type provides a standardized foundation for
/// more specific resolver failures—such as expression resolution,
/// metadata lookup, dynamic method binding, or annotation-based processing.
///
/// It exists primarily as a convenience superclass, delegating all
/// exception-handling fields to [RuntimeException], including:
/// - `message` — a human-readable description of the error  
/// - `cause` — optional underlying exception  
/// - `stackTrace` — optional diagnostic stack trace  
///
/// Subclasses are expected to represent concrete resolution failures while
/// inheriting consistent behavior and formatting.
///
/// ### Usage Example
/// ```dart
/// class InvalidExpressionException extends RuntimeResolverException {
///   InvalidExpressionException(String expression, Object cause)
///     : super(
///         "Invalid expression: $expression",
///         cause: cause,
///       );
/// }
///
/// // Thrown elsewhere:
/// throw InvalidExpressionException("1 + * 2", FormatException("Bad token"));
/// ```
///
/// ### Design Notes
/// - Extends [RuntimeException] to align with Jetleaf’s runtime error model.
/// - Intended strictly as a base class; not thrown directly.
/// - Ensures consistent error formatting across all resolver-related exceptions.
/// - Simplifies subclass definitions by forwarding constructor parameters.
///
/// ### Example Behavior
/// | Field | Inherited From | Meaning |
/// |-------|----------------|---------|
/// | `message` | RuntimeException | Description of the resolution error |
/// | `cause` | RuntimeException | Underlying failure (optional) |
/// | `stackTrace` | RuntimeException | Captured call stack (optional) |
///
/// ### See Also
/// - [RuntimeException]
/// - [Exception]
/// - Resolver-specific subclasses that extend this type
/// {@endtemplate}
abstract class RuntimeResolverException extends RuntimeException {
  /// {@macro jetleaf_runtime_resolver_exception}
  RuntimeResolverException(super.message, {super.cause, super.stackTrace});
}

/// {@template jetleaf_constructor_not_found_exception}
/// Exception thrown when a **requested constructor cannot be found or invoked**
/// for a given type during resolution.
///
/// Typically occurs when:
/// - A constructor name does not exist on a class
/// - The constructor exists but is inaccessible
/// - The resolver attempts to dynamically instantiate a type using metadata,
///   reflection, or dependency injection mechanisms
///
/// This exception is part of the resolver error hierarchy and extends
/// [RuntimeResolverException], preserving its message, cause, and stack trace
/// handling.
///
/// ### Usage Example
/// ```dart
/// // Attempting to resolve a non-existent constructor
/// throw ConstructorNotFoundException(
///   "UserService",
///   "fromConfig",
///   cause: NoSuchMethodError,
/// );
/// ```
///
/// ### Design Notes
/// - Provides clear, human-readable diagnostics referencing both the type and
///   constructor name.
/// - Maintains exception chaining through the optional [cause] parameter.
/// - Used by dynamic resolution processes, such as reflection-based factories
///   or dependency injection pipelines.
/// - Does **not** attempt to recover; this is a terminal resolution error.
///
/// ### Example Behavior
/// | Type | Constructor | Result |
/// |------|-------------|--------|
/// | `UserRepository` | `create` | ❌ Throws `ConstructorNotFoundException` |
/// | `Config` | `Config.load` | ❌ Throws if method is not a constructor |
/// | `Widget` | unnamed constructor | ❌ Throws if unnamed constructor missing |
///
/// ### See Also
/// - [RuntimeResolverException]
/// - [RuntimeException]
/// - [NoSuchMethodError]
/// {@endtemplate}
final class ConstructorNotFoundException extends RuntimeResolverException {
  /// {@macro jetleaf_constructor_not_found_exception}
  ConstructorNotFoundException(Object type, String ctorName, {Object? cause, StackTrace? stack}) : super(
    'Constructor "$ctorName" not found for type $type.',
    cause: cause,
    stackTrace: stack,
  );
}

/// {@template jetleaf_method_not_found_exception}
/// Exception thrown when a **requested method cannot be found or invoked**
/// on a given type during dynamic resolution.
///
/// This error typically occurs when:
/// - A method name does not exist on the target type
/// - The method exists but is not accessible
/// - The resolver uses reflection, metadata, or DI logic to invoke a method
///   and the target method does not match the expected signature
///
/// This exception is part of the resolver error hierarchy and extends
/// [RuntimeResolverException], preserving exception chaining and trace
/// information.
///
/// ### Usage Example
/// ```dart
/// throw MethodNotFoundException(
///   "UserRepository",
///   "saveUser",
///   cause: NoSuchMethodError(),
/// );
/// ```
///
/// ### Design Notes
/// - Provides clean diagnostics referencing both type and missing method.
/// - Supports exception chaining with the optional [cause].
/// - Indicates a terminal error in the resolution pipeline—this exception is
///   not recoverable during method dispatch.
///
/// ### Example Behavior
/// | Type | Method | Result |
/// |------|--------|--------|
/// | `UserService` | `findUser` | ❌ Throws if method missing |
/// | `ConfigLoader` | `load` | ❌ Throws if method signature does not match |
/// | `Controller` | unnamed method | ❌ Always invalid |
///
/// ### See Also
/// - [RuntimeResolverException]
/// - [RuntimeException]
/// - [NoSuchMethodError]
/// {@endtemplate}
final class MethodNotFoundException extends RuntimeResolverException {
  /// {@macro jetleaf_method_not_found_exception}
  MethodNotFoundException(Object type, String methodName, {Object? cause, StackTrace? stack}) : super(
    'Method "$methodName" not found on type $type.',
    cause: cause,
    stackTrace: stack,
  );
}

/// {@template jetleaf_field_access_exception}
/// Exception thrown when **reading a field or getter fails** on a given type.
///
/// This error is typically raised when:
/// - The specified field does not exist
/// - Access to the field or getter is restricted (e.g., private or protected)
/// - The resolver attempts dynamic field access using reflection or metadata
///
/// Extends [RuntimeResolverException], inheriting support for:
/// - `message` — a description of the error  
/// - `cause` — optional underlying exception  
/// - `stackTrace` — optional diagnostic stack trace  
///
/// ### Usage Example
/// ```dart
/// throw FieldAccessException(
///   "User",
///   "password",
///   cause: NoSuchMethodError(),
/// );
/// ```
///
/// ### Design Notes
/// - Provides clear diagnostics including both type and field name.
/// - Supports exception chaining for better debugging.
/// - Indicates a terminal resolution error; cannot automatically recover.
///
/// ### Example Behavior
/// | Type | Field/Getter | Result |
/// |------|--------------|--------|
/// | `User` | `email` | ❌ Throws if field missing or inaccessible |
/// | `Config` | `version` | ❌ Throws if getter not available |
/// | `Widget` | private property | ❌ Throws on restricted access |
///
/// ### See Also
/// - [RuntimeResolverException]
/// - [RuntimeException]
/// - [NoSuchMethodError]
/// {@endtemplate}
final class FieldAccessException extends RuntimeResolverException {
  /// {@macro jetleaf_field_access_exception}
  FieldAccessException(Object type, String fieldName, {Object? cause, StackTrace? stack}) : super(
    'Unable to read field/getter "$fieldName" on type $type.',
    cause: cause,
    stackTrace: stack,
  );
}

/// {@template jetleaf_field_mutation_exception}
/// Exception thrown when **writing to a field or setter fails** on a given type.
///
/// This error is typically raised when:
/// - The specified field does not exist
/// - Access to the field or setter is restricted (e.g., private or final)
/// - The resolver attempts dynamic field mutation using reflection or metadata
///
/// Extends [RuntimeResolverException], inheriting support for:
/// - `message` — a description of the error  
/// - `cause` — optional underlying exception  
/// - `stackTrace` — optional diagnostic stack trace  
///
/// ### Usage Example
/// ```dart
/// throw FieldMutationException(
///   "User",
///   "email",
///   cause: NoSuchMethodError(),
/// );
/// ```
///
/// ### Design Notes
/// - Provides clear diagnostics including both type and field name.
/// - Supports exception chaining for better debugging.
/// - Indicates a terminal resolution error; cannot automatically recover.
///
/// ### Example Behavior
/// | Type | Field/Setter | Result |
/// |------|--------------|--------|
/// | `User` | `email` | ❌ Throws if field missing or inaccessible |
/// | `Config` | `version` | ❌ Throws if setter not available |
/// | `Widget` | final property | ❌ Throws on restricted write access |
///
/// ### See Also
/// - [RuntimeResolverException]
/// - [RuntimeException]
/// - [NoSuchMethodError]
/// {@endtemplate}
final class FieldMutationException extends RuntimeResolverException {
  /// {@macro jetleaf_field_mutation_exception}
  FieldMutationException(Object type, String fieldName, {Object? cause, StackTrace? stack}) : super(
    'Unable to set field/setter "$fieldName" on type $type.',
    cause: cause,
    stackTrace: stack,
  );
}

/// {@template jetleaf_generic_resolution_exception}
/// Exception thrown when **generic type resolution fails** during dynamic
/// analysis or reflection-based processing.
///
/// This typically occurs when:
/// - A generic type parameter cannot be inferred or resolved
/// - The type arguments are incompatible with the expected type
/// - Reflection or metadata inspection encounters an ambiguous or unsupported generic
///
/// Extends [RuntimeResolverException], preserving support for:
/// - `message` — a human-readable description of the failure  
/// - `cause` — optional underlying exception  
/// - `stackTrace` — optional diagnostic stack trace  
///
/// ### Usage Example
/// ```dart
/// throw GenericResolutionException(
///   "Failed to resolve type parameter T for Repository<User>",
///   cause: TypeError(),
/// );
/// ```
///
/// ### Design Notes
/// - Provides clear diagnostics for generic type resolution failures.
/// - Supports exception chaining for deeper analysis of root causes.
/// - Typically used during reflection, repository building, or dynamic wiring.
///
/// ### Example Behavior
/// | Context | Result |
/// |---------|--------|
/// | Generic parameter `T` missing | ❌ Throws `GenericResolutionException` |
/// | Type argument incompatible | ❌ Throws with detailed message |
/// | Ambiguous or unknown generic | ❌ Throws |
///
/// ### See Also
/// - [RuntimeResolverException]
/// - [RuntimeException]
/// - [TypeError]
/// {@endtemplate}
final class GenericResolutionException extends RuntimeResolverException {
  /// {@macro jetleaf_generic_resolution_exception}
  GenericResolutionException(super.message, {super.cause, super.stackTrace});
}

/// {@template jetleaf_unsupported_runtime_operation_exception}
/// Exception thrown when an **operation cannot be performed due to runtime
/// environment limitations**.
///
/// This replaces the old `UnImplementedResolverException` and is typically
/// raised when:
/// - The current runtime does not support a specific feature
/// - Reflection or generic operations are unavailable
/// - Certain repository or resolver functionality is disabled or incompatible
///
/// Extends [RuntimeResolverException], inheriting support for:
/// - `message` — human-readable description of the failure  
/// - `cause` — optional underlying exception  
/// - `stackTrace` — optional diagnostic stack trace  
///
/// ### Usage Example
/// ```dart
/// throw UnsupportedRuntimeOperationException(
///   MyRepository,
///   "Dynamic proxy generation not supported in this environment",
///   cause: UnsupportedError(),
/// );
/// ```
///
/// ### Design Notes
/// - Provides clear diagnostics including type and explanation.
/// - Signals terminal errors due to environmental constraints.
/// - Supports exception chaining for deeper diagnostics.
///
/// ### Example Behavior
/// | Operation | Result |
/// |-----------|--------|
/// | Attempt dynamic proxy in restricted runtime | ❌ Throws `UnsupportedRuntimeOperationException` |
/// | Use reflection on unsupported platform | ❌ Throws |
/// | Access unavailable generic | ❌ Throws |
///
/// ### See Also
/// - [RuntimeResolverException]
/// - [RuntimeException]
/// - [UnsupportedError]
/// {@endtemplate}
final class UnsupportedRuntimeOperationException extends RuntimeResolverException {
  /// {@macro jetleaf_unsupported_runtime_operation_exception}
  UnsupportedRuntimeOperationException(Type type, String message, {Object? cause, StackTrace? stack}) : super(
    'Unsupported operation for type "$type": $message',
    cause: cause,
    stackTrace: stack,
  );
}

/// {@template jetleaf_private_method_invocation_exception}
/// Exception thrown when a developer attempts to invoke a **private method**
/// dynamically, which is not allowed by JetLeaf.
///
/// This occurs when:
/// - The method name starts with `_`
/// - The framework or runtime prohibits direct invocation of private members
///
/// Extends [RuntimeResolverException], preserving message, cause, and stack trace.
///
/// ### Usage Example
/// ```dart
/// throw PrivateMethodInvocationException(MyService, "_secretMethod");
/// ```
///
/// ### Design Notes
/// - Clearly distinguishes private method invocation errors from missing methods
/// - Provides the type and method name for easy debugging
/// {@endtemplate}
final class PrivateMethodInvocationException extends RuntimeResolverException {
  /// The type on which the private method was attempted to be invoked
  final Object type;

  /// The private method name
  final String methodName;

  /// Creates a new [PrivateMethodInvocationException]
  /// 
  /// {@macro jetleaf_private_method_invocation_exception}
  PrivateMethodInvocationException(this.type, this.methodName, {Object? cause, StackTrace? stack})
      : super(
          'Cannot invoke private method "$methodName" on type $type. Private methods are not accessible.',
          cause: cause,
          stackTrace: stack,
        );

  @override
  String toString() {
    final buffer = StringBuffer('PrivateMethodInvocationException: Cannot invoke private method "$methodName" on type $type.');
    if (cause != null) buffer.write('\nCaused by: $cause');
    buffer.write('\n$stackTrace');
    return buffer.toString();
  }
}

/// {@template jetleaf_private_constructor_invocation_exception}
/// Exception thrown when a developer attempts to invoke a **private constructor**
/// dynamically, which is not allowed by JetLeaf.
///
/// This occurs when:
/// - The constructor name starts with `_`
/// - The framework or runtime prohibits direct instantiation of private constructors
///
/// Extends [RuntimeResolverException], preserving message, cause, and stack trace.
///
/// ### Usage Example
/// ```dart
/// throw PrivateConstructorInvocationException(MyService, "_internal");
/// ```
///
/// ### Design Notes
/// - Clearly distinguishes private constructor invocation errors from missing constructors
/// - Provides the type and constructor name for easy debugging
/// {@endtemplate}
final class PrivateConstructorInvocationException extends RuntimeResolverException {
  /// The type whose private constructor was attempted to be invoked
  final Object type;

  /// The private constructor name
  final String constructorName;

  /// Creates a new [PrivateConstructorInvocationException]
  /// 
  /// {@macro jetleaf_private_constructor_invocation_exception}
  PrivateConstructorInvocationException(this.type, this.constructorName, {Object? cause, StackTrace? stack})
      : super(
          'Cannot invoke private constructor "$constructorName" on type $type. Private constructors are not accessible.',
          cause: cause,
          stackTrace: stack,
        );

  @override
  String toString() {
    final buffer = StringBuffer(
      'PrivateConstructorInvocationException: Cannot invoke private constructor "$constructorName" on type $type.',
    );
    if (cause != null) buffer.write('\nCaused by: $cause');
    buffer.write('\n$stackTrace');
    return buffer.toString();
  }
}

/// {@template jetleaf_private_field_access_exception}
/// Exception thrown when attempting to **access a private field or getter/setter**
/// on a type during runtime resolution.
///
/// This includes:
/// - Attempting to read a private getter
/// - Attempting to write to a private field or setter
/// - Attempting to reflectively access any identifier beginning with `_`
///
/// Since private members are library-scoped in Dart, JetLeaf does not allow
/// invoking or accessing them through its reflection/runtime layer.
///
/// ### Example
/// ```dart
/// throw PrivateFieldAccessException(User, '_password');
/// ```
///
/// ### See Also
/// - [FieldAccessException]
/// - [FieldMutationException]
/// {@endtemplate}
final class PrivateFieldAccessException extends RuntimeResolverException {
  /// {@macro jetleaf_private_field_access_exception}
  PrivateFieldAccessException(Object type, String fieldName, {Object? cause, StackTrace? stack})
      : super(
          'Cannot access private field or getter "$fieldName" on type $type. '
          'Private members cannot be accessed through JetLeaf runtime.',
          cause: cause,
          stackTrace: stack,
        );
}

/// {@template jetleaf_unresolved_type_instantiation_exception}
/// Exception thrown when JetLeaf is unable to instantiate a class or resolve a
/// constructor because the **runtime type is unresolved**.
///
/// This typically occurs with:
/// - Generic type parameters (e.g., `T`, `U`, `E`) that have no concrete type
/// - Types that cannot be determined through mirrors
/// - Missing or incomplete [RuntimeHint] registrations
/// - AOT scenarios where type metadata is erased
///
/// ### Example:
/// ```dart
/// throw UnresolvedTypeInstantiationException(T);
/// ```
///
/// ### See Also
/// - [ConstructorNotFoundException]
/// - [GenericResolutionException]
/// - [RuntimeResolverException]
/// {@endtemplate}
final class UnresolvedTypeInstantiationException extends RuntimeResolverException {
  /// {@macro jetleaf_unresolved_type_instantiation_exception}
  UnresolvedTypeInstantiationException(Object type, {Object? cause, StackTrace? stack})
      : super(
          'Unable to instantiate type "$type": runtime type is unresolved or '
          'cannot be constructed. This often occurs with generic type '
          'parameters or when no RuntimeHint is registered.',
          cause: cause,
          stackTrace: stack,
        );
}

/// {@template argument_resolution_exception}
/// Base class for exceptions thrown during **argument resolution**.
///
/// These errors are raised when preparing arguments for method or constructor
/// invocation—typically during reflective calls, dependency injection,
/// runtime resolvers, or invocation pipelines.
///
/// This exception includes:
/// - A human-readable message
/// - The underlying cause (if any)
/// - The call-site or resolver location where the failure occurred
///
/// Subclasses represent specific resolution failures such as missing required
/// parameters, invalid argument types, or constraint violations.
/// {@endtemplate}
abstract class ArgumentResolutionException extends RuntimeResolverException {
  /// The logical or physical location where the argument resolution failed.
  ///
  /// This may refer to:
  /// - A method name
  /// - A constructor signature
  /// - A reflection site
  /// - A file or URI associated with the call
  ///
  /// Used for producing more contextual diagnostic messages.
  final String location;

  /// {@macro argument_resolution_exception}
  ///
  /// - [message] describes the failure.
  /// - [cause] is the underlying root cause, if any.
  /// - [stackTrace] optionally provides additional debugging information.
  /// - [location] identifies the call-site or point of failure.
  ArgumentResolutionException(
    super.message, {
    Object? cause,
    super.stackTrace,
    required this.location,
  }) : super(cause: cause ?? location);
}

/// {@template missing_required_named_parameter}
/// Thrown when a **required named parameter** is missing during runtime method
/// or constructor invocation.
///
/// This error typically occurs when:
/// - Invoking a method reflectively using incomplete argument maps
/// - Auto-binding or dependency injection fails to supply a required value
/// - Runtime resolvers attempt to call APIs without fulfilling required
///   named-parameter contracts
///
/// Example:
/// ```dart
/// void method({required int count}) {}
///
/// // Missing 'count' → throws MissingRequiredNamedParameter
/// resolver.invoke(method, {});
/// ```
/// {@endtemplate}
class MissingRequiredNamedParameterException extends ArgumentResolutionException {
  /// The name of the missing required named parameter.
  final String name;

  /// {@macro missing_required_named_parameter}
  ///
  /// - [name] is the missing parameter.
  /// - [location] identifies where the resolution was attempted.
  MissingRequiredNamedParameterException(
    this.name, {
    required String location,
  }) : super('Missing required named parameter: $name', location: location);
}

/// {@template missing_required_positional_parameter}
/// Thrown when a **required positional parameter** is missing during
/// runtime method or constructor invocation.
///
/// This typically occurs when:
/// - A reflective call omits a required positional argument
/// - An invocation pipeline provides fewer arguments than the method's
///   positional parameter count
/// - Dependency injection or auto-binding fails to supply required values
///
/// Example:
/// ```dart
/// void f(int a, int b) {}
///
/// // Missing 'b' → throws MissingRequiredPositionalParameter
/// resolver.invoke(f, [1]);
/// ```
/// {@endtemplate}
class MissingRequiredPositionalParameterException extends ArgumentResolutionException {
  /// The name of the missing positional parameter.
  final String name;

  /// {@macro missing_required_positional_parameter}
  ///
  /// - [name] is the missing parameter.
  /// - [location] identifies where the resolution attempt occurred.
  MissingRequiredPositionalParameterException(
    this.name, {
    required String location,
  }) : super('Missing required positional parameter: $name', location: location);
}

/// {@template too_few_positional_arguments}
/// Thrown when a runtime invocation receives **fewer positional arguments**
/// than the target function or constructor requires.
///
/// This error is raised before invocation occurs, during argument-shape
/// validation, and typically represents incorrect caller behavior or a failed
/// binding/resolution process.
///
/// Example:
/// ```dart
/// void g(int a, int b, int c) {}
///
/// // Expected 3 positional args but got 1
/// resolver.invoke(g, [7]);
/// ```
/// {@endtemplate}
class TooFewPositionalArgumentException extends ArgumentResolutionException {
  /// The number of required positional arguments expected by the target.
  final int expected;

  /// The number of positional arguments actually supplied by the caller.
  final int actual;

  /// {@macro too_few_positional_arguments}
  ///
  /// - [expected] is the required minimum positional count.
  /// - [actual] is the number of provided arguments.
  /// - [location] identifies where resolution/validation failed.
  TooFewPositionalArgumentException(
    this.expected,
    this.actual, {
    required String location,
  }) : super('Expected at least $expected positional arguments, got $actual', location: location);
}

/// {@template too_many_positional_arguments}
/// Thrown when a runtime invocation receives **more positional arguments**
/// than the target function or constructor accepts.
///
/// This error occurs during argument-shape validation before invocation
/// and indicates that the caller supplied excess positional values.
///
/// Example:
/// ```dart
/// void f(int a, int b) {}
///
/// // Provided 3 args, but function accepts only 2
/// resolver.invoke(f, [1, 2, 3]);
/// ```
/// {@endtemplate}
class TooManyPositionalArgumentException extends ArgumentResolutionException {
  /// The maximum number of positional arguments allowed by the target.
  final int expected;

  /// The number of positional arguments actually supplied.
  final int actual;

  /// {@macro too_many_positional_arguments}
  ///
  /// - [expected] is the allowed maximum positional count.
  /// - [actual] is the number provided by the caller.
  /// - [location] identifies where the resolution failed.
  TooManyPositionalArgumentException(
    this.expected,
    this.actual, {
    required String location,
  }) : super('Expected at most $expected positional arguments, got $actual', location: location);
}

/// {@template unexpected_argument}
/// Thrown when an invocation receives an argument that **does not correspond
/// to any declared parameter**, usually a named parameter that the target
/// method or constructor does not define.
///
/// This is commonly caused by:
/// - Typos in argument names
/// - Passing named arguments not supported by the target
/// - Mismatched signatures between caller and callee
///
/// Example:
/// ```dart
/// void f({int x = 0}) {}
///
/// // 'y' is not a declared named parameter → throws UnexpectedArgument
/// resolver.invoke(f, [], named: {'y': 1});
/// ```
/// {@endtemplate}
class UnexpectedArgumentException extends ArgumentResolutionException {
  /// The name of the unexpected or undeclared argument.
  final String argumentName;

  /// {@macro unexpected_argument}
  ///
  /// - [argumentName] is the illegal argument encountered.
  /// - [location] indicates where the resolution occurred.
  UnexpectedArgumentException(this.argumentName, {required String location})
      : super('Unexpected argument: $argumentName', location: location);
}

/// {@template classNotFoundException}
/// A runtime exception in **JetLeaf** thrown when a requested class
/// cannot be found by the runtime provider.
///
/// This exception indicates a **class resolution failure** during
/// runtime reflection or materialization.
///
/// ---
///
/// ## Common Causes
/// This typically occurs when:
/// - The class has not been registered or scanned by the runtime provider
/// - There is a typo in the requested class name or qualified name
/// - The class is missing from the active package or library context
///
/// ---
///
/// ## Usage Example
/// ```dart
/// try {
///   final clazz = Class.forName('NonExistentClass');
/// } on ClassNotFoundException catch (e) {
///   print(e);
/// }
/// ```
///
/// ---
///
/// This exception is the **base class** for more specific
/// class resolution failures such as [ImmaterialClassException].
/// {@endtemplate}
class ClassNotFoundException extends RuntimeException {
  /// The name of the class that could not be located.
  ///
  /// Useful for debugging, logging, and error reporting to
  /// identify which class resolution failed.
  final String className;

  /// {@macro classNotFoundException}
  ClassNotFoundException(this.className, {String? message}) : super(message ??
    'Class "$className" could not be found.\n'
        'This typically means:\n'
        ' • The class has not been registered with the runtime provider.\n'
        ' • A typo exists in the requested class name.\n'
        ' • The class is missing from the current ClassLoader context.\n',
  );
}

/// {@template immaterial_class_exception}
/// Thrown when a class **exists** but cannot be materialized into a
/// concrete [ClassDeclaration] by JetLeaf.
///
/// This exception represents a **semantic failure**, not a lookup failure.
/// The class was located, but JetLeaf could not construct a stable,
/// fully-resolved runtime representation.
///
/// ---
///
/// ## Common Causes
/// This typically occurs when:
/// - A `dart:mirrors` type such as `ClassMirror` or `TypeMirror` is used
/// - A generic class is referenced without resolved type arguments
/// - Generic type information has been erased at runtime
///
/// ---
///
/// ## Why This Matters
/// JetLeaf requires a **concrete, fully-resolved runtime type**
/// to safely perform reflection, hierarchy analysis, and code generation.
///
/// Mirror-only or erased generic types do not provide sufficient guarantees.
///
/// ---
///
/// ## How to Fix
/// - Use a concrete class instead of a mirror-based type
/// - Annotate generic classes with `@Generic(MyResolvedClass)`
/// - For Dart core generic types, use the fully qualified concrete type
///
/// ---
///
/// This exception extends [ClassNotFoundException] to allow
/// unified handling of class resolution failures.
/// {@endtemplate}
final class ImmaterialClassException extends ClassNotFoundException {
  /// {@macro immaterial_class_exception}
  ImmaterialClassException(super.className) : super(message:
    'Class "$className" cannot be materialized.\n'
    'This type originates from `dart:mirrors` or has lost generic information.\n\n'
    'JetLeaf requires a concrete, fully-resolved runtime type.\n\n'
    'This typically means:\n'
    ' • A mirror type such as ClassMirror or TypeMirror was encountered.\n'
    ' • A generic class was used without resolution.\n'
    ' • Generic type arguments were erased at runtime.\n\n'
    'How to fix:\n'
    ' • Use a concrete class instead of a mirror type.\n'
    ' • Annotate generic classes with @Generic(MyResolvedClass).\n'
    ' • For Dart core generic types, use the qualified name of the type.\n',
  );
}