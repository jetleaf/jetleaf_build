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

/// Internal constant referencing the canonical JetLeaf classes library.
///
/// This URI serves as the authoritative location for core JetLeaf marker
/// types such as [Void] and [Dynamic].  
///
/// JetLeaf uses this package URI for:
/// - Constructing fully-qualified type identifiers
/// - Linking metadata entries to their defining library
/// - Runtime and build-time resolution where mirrors may be unavailable
///
/// The value is intentionally stable and must not change without updating all
/// generated JetLeaf metadata systems.
String _PACKAGE_URI = "package:jetleaf_build/src/classes.dart";

/// {@template jetleaf_void_base}
/// Abstract base class representing a **marker or placeholder type** in the
/// JetLeaf type system.
///
/// The [Void] base class is intended to serve as a generic type parameter
/// or sentinel type where no actual value is expected or needed. It is often
/// used in APIs or frameworks that require a `Class<T>` reference but do
/// not need to store a concrete instance.
///
/// ### Purpose
/// - Provide a first-class type representation for "no-value" or placeholder scenarios.
/// - Enable generic programming patterns where a type parameter is required but no data exists.
/// - Serve as a foundation for JetLeaf internal type-system constructs.
///
/// ### Features
/// - **Abstract base:** Cannot be instantiated directly.
///
/// ### Example Usage
/// ```dart
/// final voidClass = Void.getClass();
/// // voidClass can now be used as a type reference in generic APIs
/// ```
///
/// This allows APIs expecting a type to accept [Void] as a valid type argument
/// without requiring a concrete instance.
/// {@endtemplate}
abstract base class Void {
  /// Returns the fully-qualified JetLeaf type identifier for the [Void] marker class.
  ///
  /// This name is used internally for stable, cross-runtime type resolution,
  /// especially in contexts where mirrors are unavailable or unreliable.
  ///
  /// See the shared documentation block above for detailed explanation.
  static String getQualifiedName() => "$_PACKAGE_URI.Void";

  /// Returns the canonical `Uri` pointing to the JetLeaf library that declares [Void].
  ///
  /// JetLeaf uses this URI to associate metadata entries with their origin
  /// library, enabling consistent resolution during build-time generation and
  /// runtime JIT lookup.
  ///
  /// This is a lightweight helper around the `_PACKAGE_URI` constant and always
  /// returns the same parsed URI instance.
  static Uri getUri() => Uri.parse(_PACKAGE_URI);

  /// Internal keyword representing the JetLeaf **void marker type**.
  ///
  /// This is the canonical keyword used by JetLeaf to identify the [Void] type
  /// in reflection, generics, and metadata operations.
  ///
  /// Example:
  /// ```dart
  /// final voidKeyword = Void.KEYWORD; // "void"
  /// ```
  static const String KEYWORD = "void";
}

/// {@template jetleaf_dynamic_base}
/// Abstract base class representing a **dynamic or unconstrained type** within
/// the JetLeaf type system.
///
/// The [Dynamic] base class is used to model values whose type is not known
/// at compile time or is intentionally left unrestricted. It acts as a
/// counterpart to Dart’s built-in `dynamic` keyword, but within JetLeaf’s own
/// type-reflection and runtime-resolution framework.
///
/// ### Purpose
/// - Represent type-erased or dynamically-typed values in JetLeaf.
/// - Support APIs that require a type parameter but should accept **any** type.
/// - Enable reflection-driven operations where type information is discovered
///   or resolved at runtime rather than statically.
/// - Provide a consistent internal marker for “unknown” or “flexible” types.
///
/// ### Features
/// - **Abstract base:** Cannot be instantiated directly.
/// - **Type-agnostic:** Serves purely as a symbolic or sentinel type.
/// - **Runtime-friendly:** Useful in dynamic dispatch, reflection, and
///   JIT-resolution systems where types cannot be known ahead of time.
///
/// ### Example Usage
/// ```dart
/// final dynamicClass = Dynamic.getClass();
/// // Used when a JetLeaf API should accept any possible value type
/// ```
///
/// This allows JetLeaf components to express “no static type constraints”
/// explicitly in their type signatures or runtime metadata.
/// {@endtemplate}
abstract base class Dynamic {
  /// Returns the fully-qualified JetLeaf type identifier for the [Dynamic] marker class.
  ///
  /// This identifier provides a stable reference to JetLeaf’s dynamic
  /// placeholder type, enabling consistent metadata resolution across build-time
  /// and runtime environments.
  ///
  /// See the shared documentation block above for detailed explanation.
  static String getQualifiedName() => "$_PACKAGE_URI.Dynamic";

  /// Returns the canonical `Uri` pointing to the JetLeaf library that declares [Void].
  ///
  /// JetLeaf uses this URI to associate metadata entries with their origin
  /// library, enabling consistent resolution during build-time generation and
  /// runtime JIT lookup.
  ///
  /// This is a lightweight helper around the `_PACKAGE_URI` constant and always
  /// returns the same parsed URI instance.
  static Uri getUri() => Uri.parse(_PACKAGE_URI);

  /// Internal keyword representing the JetLeaf **dynamic marker type**.
  ///
  /// This is the canonical keyword used by JetLeaf to identify the [Dynamic] type
  /// in reflection, generics, and runtime type resolution.
  ///
  /// Example:
  /// ```dart
  /// final dynamicKeyword = Dynamic.KEYWORD; // "dynamic"
  /// ```
  static const String KEYWORD = "dynamic";

  /// Checks if the given [K] or [type] is dynamic
  /// 
  /// This is used to know what to do in case where the result of the response should be typed or not.
  static bool isDynamic<K>([Type? type]) {
    if (type case final type?) {
      return type.toString() == Dynamic.KEYWORD || type.runtimeType.toString() == Dynamic.KEYWORD;
    }

    return K.toString() == Dynamic.KEYWORD || K.runtimeType.toString() == Dynamic.KEYWORD;
  }
}