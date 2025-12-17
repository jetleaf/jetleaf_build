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

import 'dart:mirrors' as mirrors;

import 'package:meta/meta.dart';

import '../../../utils/generic_type_parser.dart';
import '../runtime_executor.dart';

/// {@template abstract_jit_runtime_executor}
/// A base class providing shared utilities for runtime resolution in
/// JetLeaf’s JIT (Just-In-Time) environments.
///
/// This resolver focuses on detecting unresolved types—particularly generic
/// types or `dart:mirrors` symbols—and producing actionable guidance for the
/// user. Concrete implementations may use these helpers to surface meaningful
/// diagnostics when type resolution fails at runtime.
///
/// The class centralizes:
///  - Mirror detection and classification.
///  - Human-readable descriptions of mirrors.
///  - User-facing error messages for unresolved generics or symbols.
///  - Fallback diagnostics for unsupported or unavailable runtime metadata.
///
/// It is intended for internal framework use and should be extended by
/// resolvers that interact with reflection or generic-type resolution.
/// {@endtemplate}
abstract class AbstractJitRuntimeExecutor implements RuntimeExecutor {
  /// {@macro abstract_jit_runtime_executor}
  const AbstractJitRuntimeExecutor();

  /// Produces a descriptive, user-facing error message explaining why a given
  /// `typeOrMirror` could not be resolved at runtime.
  ///
  /// The returned message is tailored according to the input:
  ///
  /// 1. **Mirror instances**  
  ///    When a `dart:mirrors` object is provided, the message explains
  ///    potential causes such as:
  ///     - missing generic type information,
  ///     - use of mirrors in AOT builds,
  ///     - private or non-exported symbols.
  ///
  /// 2. **Generic type strings**  
  ///    If the input appears to be a generic type name (e.g. `"List<Foo>"`),
  ///    the message recommends providing a `RuntimeHint` or annotating with
  ///    `@Generic(...)` so JetLeaf can resolve the type arguments.
  ///
  /// 3. **Fallback**  
  ///    When no known pattern matches, a general resolution guide is returned.
  ///
  /// This method is intended to help developers diagnose generic resolution
  /// and reflection-based failures in JIT mode or mixed reflection environments.
  @protected
  String getErrorMessage(dynamic typeOrMirror) {
    // If a mirror instance was passed, describe it
    if (isMirror(typeOrMirror)) {
      final kind = getMirrorKind(typeOrMirror);
      final friendly = getMirrorFriendlyName(typeOrMirror);
      return '''
The runtime encountered an unresolved $kind ($friendly). JetLeaf couldn't resolve this mirror-backed type or member.
Possible reasons:
  - This is a generic type that wasn't provided runtime hints for.
  - The runtime environment is AOT and lacks dart:mirrors support for this symbol.
  - The symbol is private/obfuscated or not exported.

Remedies (v1.0.0):
  - Add a `RuntimeHint` for the generic or symbol.
  - Use the `@Generic(...)` annotation to provide explicit generic information.
  - Avoid relying on dart:mirrors in AOT builds; use generated factories / build-time registration instead.
''';
    }

    // If the string looks like a generic name (e.g. List<Foo>), provide guidance
    final text = typeOrMirror?.toString() ?? '<unknown>';
    if (GenericTypeParser.isGeneric(text)) {
      return '''
This is happening because the requesting type "$text" appears to be a generic type which JetLeaf runtime couldn't resolve.
For reliable resolution, create a `RuntimeHint` for the generic type or annotate the declaration with `@Generic(...)`
so JetLeaf can resolve the type arguments at runtime.
''';
    }

    // Fallback guidance
    return '''
This might be happening because the requesting type "$text" couldn't be resolved at runtime.
Consider:
  - Providing a `RuntimeHint` or `@Generic(...)`.
  - Ensuring the symbol is exported and available in this runtime environment.
  - Avoiding dart:mirrors in AOT builds and using build-time generated registration.
''';
  }

  /// Returns `true` if [obj] is any supported `dart:mirrors` type, including:
  ///  - `Mirror`
  ///  - `DeclarationMirror`
  ///  - `TypeMirror`
  ///
  /// This method is used to determine whether the resolver should treat an
  /// object as a reflection symbol and generate mirror-aware diagnostics.
  @protected
  bool isMirror(dynamic obj) {
    return obj is mirrors.Mirror || obj is mirrors.DeclarationMirror || obj is mirrors.TypeMirror;
  }

  /// Returns a human-readable classification for a mirror instance.
  ///
  /// Examples:
  ///  - `ClassMirror`  
  ///  - `MethodMirror`  
  ///  - `VariableMirror`  
  ///  - `InstanceMirror`  
  ///
  /// If the instance is not a known mirror subtype, its runtime type name
  /// is returned instead.
  @protected
  String getMirrorKind(dynamic mirror) {
    if (mirror is mirrors.ClassMirror) return 'ClassMirror';
    if (mirror is mirrors.MethodMirror) return 'MethodMirror';
    if (mirror is mirrors.VariableMirror) return 'VariableMirror';
    if (mirror is mirrors.InstanceMirror) return 'InstanceMirror';
    if (mirror is mirrors.DeclarationMirror) return 'DeclarationMirror';
    if (mirror is mirrors.TypeMirror) return 'TypeMirror';
    return mirror.runtimeType.toString();
  }

  /// Extracts a descriptive, “friendly” name from a mirror, suitable for
  /// error messages and diagnostics.
  ///
  /// For symbol-based mirrors (classes, methods, variables), the symbol’s
  /// `simpleName` is used. For instance mirrors, the underlying
  /// `reflectedType` is returned.
  ///
  /// If extraction fails (for example due to restricted metadata in AOT),
  /// the mirror’s `toString()` value is used as a last resort.
  @protected
  String getMirrorFriendlyName(dynamic mirror) {
    try {
      if (mirror is mirrors.ClassMirror) return mirror.simpleName.toString();
      if (mirror is mirrors.MethodMirror) return mirror.simpleName.toString();
      if (mirror is mirrors.VariableMirror) return mirror.simpleName.toString();
      if (mirror is mirrors.InstanceMirror) {
        final rt = mirror.type.reflectedType;
        return rt.toString();
      }
      if (mirror is mirrors.DeclarationMirror) return mirror.simpleName.toString();
    } catch (_) {
      // ignore; fallthrough to toString
    }
    return mirror?.toString() ?? '<unknown mirror>';
  }

  /// Returns a representation of the static or runtime type associated with
  /// the generic parameter [T] or, when [T] is `dynamic`, the runtime type
  /// of the provided [instance].
  ///
  /// This utility is used by JIT-based resolvers when extracting type
  /// information in situations where full `dart:mirrors` metadata may not be
  /// available. The behavior is:
  ///
  /// - **If `T` is a concrete generic type** (e.g. `String`, `List<int>`):  
  ///   The method returns the string form of `T`, allowing the caller to
  ///   identify the compile-time type argument.
  ///
  /// - **If `T` is `dynamic`**:  
  ///   The static type cannot be determined, so the method falls back to the
  ///   runtime value by returning `instance.toString()`. This provides a
  ///   minimal description that can still be used for diagnostics.
  ///
  /// This method is particularly helpful when working in mixed reflection or
  /// AOT environments where generic type information is erased or unavailable.
  ///
  /// - [instance]: the runtime value whose type may be inspected when [T]
  ///   is `dynamic`.
  /// - Returns: a string-like object that identifies the type.
  @protected
  Object getType<T>(T instance) {
    if (T.toString() == "dynamic") {
      return instance.toString();
    } else {
      return T.toString();
    }
  }

  /// Attempts to locate a member declaration (field, method, getter, setter,
  /// or any `DeclarationMirror`) with the given [symbol] inside the provided
  /// [type] and its full inheritance hierarchy.
  ///
  /// This method performs a *deep reflective lookup* and is used in JetLeaf’s
  /// JIT runtime when resolving members dynamically through `dart:mirrors`.
  /// Because the mirror system does not automatically traverse superclasses
  /// or interfaces for declarations, this resolver manually walks the type
  /// hierarchy.
  ///
  /// The search order is:
  ///
  /// 1. **Direct declarations**  
  ///    Checks `type.declarations` for a matching symbol.
  ///
  /// 2. **Superclass chain**  
  ///    Recursively traverses each superclass until either:
  ///    - a declaration is found, or  
  ///    - the root (`Object`) is reached.
  ///
  /// 3. **Interfaces**  
  ///    Recursively searches all implemented interfaces, mirroring Dart’s
  ///    interface inheritance rules.
  ///
  /// 4. **Instance members**  
  ///    If still not found, checks `instanceMembers` for inherited or mixed-in
  ///    members that do not appear in `declarations`.
  ///
  /// 5. **Static members**  
  ///    Finally checks `staticMembers` for static methods or fields that match
  ///    the symbol.
  ///
  /// If no matching declaration is found after searching the full hierarchy,
  /// the method returns `null`.
  ///
  /// ### Example
  /// ```dart
  /// final cm = reflectClass(MySubclass);
  /// final mirror = findDeclaration(#someMethod, cm);
  /// if (mirror != null) {
  ///   print('Found: ${mirror.simpleName}');
  /// }
  /// ```
  ///
  /// This method is particularly useful when:
  ///  - resolving overridden members,
  ///  - detecting inherited fields or methods,
  ///  - inspecting mixins or interface-provided members,
  ///  - performing late-binding member resolution in JIT mode.
  ///
  /// - [symbol]: the member name to look up (`#foo`, `#bar=`, etc.)
  /// - [type]: the class in which to begin the search
  /// - Returns: the matching `DeclarationMirror`, or `null` if no match exists.
  ///
  /// This method does **not** throw — a missing declaration is treated
  /// as a normal resolution failure.
  @protected
  mirrors.DeclarationMirror? findDeclaration(Symbol symbol, mirrors.ClassMirror type) {
    // 1. Check current class
    final declaration = type.declarations[symbol];
    if (declaration != null) return declaration;

    final methodMirror = type.instanceMembers[symbol];
    if (methodMirror != null) return methodMirror;

    final staticMethodMirror = type.staticMembers[symbol];
    if (staticMethodMirror != null) return staticMethodMirror;

    // 2. Recursively check superclass
    final superclass = type.superclass;
    if (superclass != null) {
      final foundInSuper = findDeclaration(symbol, superclass);
      if (foundInSuper != null) return foundInSuper;
    }

    // 3. Recursively check interfaces
    for (final interface in type.superinterfaces) {
      final foundInInterface = findDeclaration(symbol, interface);
      if (foundInInterface != null) return foundInInterface;
    }

    return null;
  }
}