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

import '../../../exceptions.dart';
import 'abstract_jit_runtime_executor.dart';

/// {@template abstract_field_jit_runtime_executor}
/// Provides field-level reflective access for JetLeaf’s JIT runtime.
///
/// This resolver supports:
///  * instance field reads/writes
///  * static field reads/writes
///  * getter/setter invocation via mirrors
///  * inherited and interface-provided members (via `findDeclaration`)
///
/// The class overrides the high-level `getValue` and `setValue` operations
/// and delegates concrete mirror interaction to the internal helpers
/// `_getValue` and `_setValue`.  
///
/// All operations are defensive and convert reflection failures into
/// JetLeaf’s domain exceptions (`FieldAccessException`,
/// `FieldMutationException`, `GenericResolutionException`), while providing
/// mirror-aware diagnostics from `AbstractJitRuntimeResolver.getErrorMessage`.
/// {@endtemplate}
abstract class AbstractFieldJitRuntimeExecutor extends AbstractJitRuntimeExecutor {
  /// {@macro abstract_field_jit_runtime_executor}
  const AbstractFieldJitRuntimeExecutor();

  @override
  Object? getValue<T>(T instance, String name) {
    mirrors.InstanceMirror getter;

    try {
      if (instance is Type) { // For static fields
        final mirror = mirrors.reflectType(instance);

        if (mirror is mirrors.ClassMirror) {
          getter = _getValue(mirror, mirror, name);
        } else {
          throw FieldAccessException(getType(instance), name);
        }
      } else {
        final mirror = mirrors.reflect(instance);
        getter = _getValue(mirror, mirror.type, name);
      }
    } on FieldAccessException catch (_) {
      rethrow;
    } on NoSuchMethodError catch (e, stack) {
      throw FieldAccessException(getType(instance), name, cause: e, stack: stack);
    } on mirrors.AbstractClassInstantiationError catch (e, stack) {
      final guidance = getErrorMessage(instance);
      throw GenericResolutionException('Mirror error while getting "$name" on instance of $T. $guidance\n$e\n$stack');
    } catch (e, stack) {
      Error.throwWithStackTrace(e, stack);
    }

    return getter.reflectee;
  }

  /// Internal reflective getter implementation.
  ///
  /// This method is shared by both instance and static read operations.
  ///
  /// The procedure is:
  /// 1. Look for the declaration using `findDeclaration`.
  /// 2. If not found, try the setter symbol name (`"$name="`) as an alternative.
  /// 3. If the declaration is a getter, invoke it.
  /// 4. Otherwise attempt to read with `getField`.
  ///
  /// If mirror invocation fails because of runtime inconsistencies, the method
  /// falls back to a `getField` attempt, since some mirror environments are
  /// more permissive.
  mirrors.InstanceMirror _getValue(mirrors.ObjectMirror mirror, mirrors.ClassMirror type, String name) {
    Symbol symbol = Symbol(name);

    try {
      mirrors.DeclarationMirror? declaration = findDeclaration(symbol, type);

      if (declaration == null) {
        symbol = Symbol("$name=");
        declaration = findDeclaration(symbol, type);
      }

      if (declaration is mirrors.MethodMirror && declaration.isGetter) {
        return mirror.invoke(symbol, []);
      }

      return mirror.getField(symbol);
    } on FieldAccessException catch (_) {
      rethrow;
    } catch (inner) {
      // attempt a best-effort invoke (some runtimes may accept it)
      return mirror.getField(symbol);
    }
  }

  @override
  void setValue<T>(T instance, String name, Object? value) {
    mirrors.InstanceMirror setter;

    try {
      if (instance is Type) {
        final mirror = mirrors.reflectType(instance);

        if (mirror is mirrors.ClassMirror) {
          setter = _setValue(mirror, mirror, instance, name, value);
        } else {
          throw FieldMutationException(getType(instance), name);
        }
      } else {
        final mirror = mirrors.reflect(instance);
        setter = _setValue(mirror, mirror.type, instance, name, value);
      }
    } on FieldMutationException catch (_) {
      rethrow;
    } on NoSuchMethodError catch (e, stack) {
      throw FieldMutationException(getType(instance), name, cause: e, stack: stack);
    } on mirrors.AbstractClassInstantiationError catch (e, stack) {
      final guidance = getErrorMessage(instance);
      throw GenericResolutionException('Mirror error while setting "$name" on instance of $T. $guidance\n$e\n$stack');
    } catch (e, stack) {
      if (e is TypeError || e is ArgumentError) {
        throw FieldMutationException(getType(instance), name, cause: e, stack: stack);
      }

      if (e.toString().contains('LateError') || e.toString().contains('LateInitializationError')) {
        rethrow;
      }

      throw FieldMutationException(getType(instance), name, cause: e, stack: stack);
    }

    setter.reflectee;
  }

  /// Internal reflective setter implementation.
  ///
  /// Similar to `_getValue`, this method performs both instance and static
  /// mutation operations.
  ///
  /// The logic is:
  /// 1. Find the member declaration via `findDeclaration`.
  /// 2. If not found, try the setter-style symbol `"name="`.
  /// 3. If declaration is a setter, invoke it.
  /// 4. If declaration is a const variable, throw mutation exception.
  /// 5. Otherwise perform a direct `setField`.
  ///
  /// A fallback `setField` attempt is provided because some mirror variants
  /// accept assignment even without fully resolved declarations.
  mirrors.InstanceMirror _setValue(mirrors.ObjectMirror mirror, mirrors.ClassMirror type, dynamic instance, String name, Object? value) {
    Symbol symbol = Symbol(name);
    
    try {
      mirrors.DeclarationMirror? declaration = findDeclaration(symbol, type);

      if (declaration == null) {
        symbol = Symbol("$name=");
        declaration = findDeclaration(symbol, type);
      }

      if (declaration is mirrors.MethodMirror && declaration.isSetter) {
        return mirror.invoke(symbol, [value]);
      }

      if (declaration is mirrors.VariableMirror && declaration.isConst) {
        throw FieldMutationException(getType(instance), name);
      }

      return mirror.setField(symbol, value);
    } on FieldMutationException catch (_) {
      rethrow;
    } catch (inner) {
      // attempt a best-effort invoke (some runtimes may accept it)
      return mirror.setField(symbol, value);
    }
  }
}