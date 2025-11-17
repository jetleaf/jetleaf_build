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
    final buffer = StringBuffer('RuntimeException: $message\n$stackTrace');
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
  ConstructorNotFoundException(String type, String ctorName, {Object? cause, StackTrace? stack}) : super(
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
  MethodNotFoundException(String type, String methodName, {Object? cause, StackTrace? stack}) : super(
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
///   cause: NoSuchFieldError(),
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
/// - [NoSuchFieldError]
/// {@endtemplate}
final class FieldAccessException extends RuntimeResolverException {
  /// {@macro jetleaf_field_access_exception}
  FieldAccessException(String type, String fieldName, {Object? cause, StackTrace? stack}) : super(
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
///   cause: NoSuchFieldError(),
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
/// - [NoSuchFieldError]
/// {@endtemplate}
final class FieldMutationException extends RuntimeResolverException {
  /// {@macro jetleaf_field_mutation_exception}
  FieldMutationException(String type, String fieldName, {Object? cause, StackTrace? stack}) : super(
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

/// {@template jetleaf_mirror_resolution_exception}
/// Exception thrown for **mirror/reflection-related failures** within the
/// Jetleaf framework.
///
/// This can occur when:
/// - Reflection is not supported in the current runtime environment
/// - The mirror API encounters an unexpected or unsupported type
/// - Accessing metadata, methods, or fields via mirrors fails
///
/// Extends [RuntimeResolverException], inheriting support for:
/// - `message` — human-readable description of the error  
/// - `cause` — optional underlying exception  
/// - `stackTrace` — optional diagnostic stack trace  
///
/// ### Usage Example
/// ```dart
/// throw MirrorResolutionException(
///   "Cannot access private field via reflection",
///   cause: UnsupportedError(),
/// );
/// ```
///
/// ### Design Notes
/// - Signals terminal reflection-related errors during dynamic resolution.
/// - Provides detailed diagnostics via `message` and optional `cause`.
/// - Helps distinguish mirror failures from other resolver exceptions.
///
/// ### Example Behavior
/// | Context | Result |
/// |---------|--------|
/// | Unsupported runtime | ❌ Throws `MirrorResolutionException` |
/// | Attempting to reflect private field | ❌ Throws |
/// | Metadata access fails | ❌ Throws |
///
/// ### See Also
/// - [RuntimeResolverException]
/// - [RuntimeException]
/// - [UnsupportedError]
/// {@endtemplate}
final class MirrorResolutionException extends RuntimeResolverException {
  /// {@macro jetleaf_mirror_resolution_exception}
  MirrorResolutionException(super.message, {super.cause, super.stackTrace});
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