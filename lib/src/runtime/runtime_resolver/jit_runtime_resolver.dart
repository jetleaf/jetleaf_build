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

import '../../exceptions.dart';
import '../utils/generic_type_parser.dart';
import 'runtime_resolver.dart';

/// {@template jit_executable_resolver}
/// A reflection-based implementation of [RuntimeResolver] using `dart:mirrors`.
///
/// This class provides dynamic instantiation, method invocation, and field access
/// for types at runtime, leveraging the Dart mirrors API. It is intended for use
/// in JIT (Just-In-Time) environments where `dart:mirrors` is available (e.g., VM,
/// not AOT-compiled code).
///
/// ### Example: Instantiating a class
/// ```dart
/// final resolver = JitExecutableResolver();
/// final person = resolver.newInstance<Person>('named', ['Eve']);
/// ```
///
/// ### Example: Invoking a method
/// ```dart
/// resolver.invokeMethod(person, 'greet'); // calls person.greet()
/// ```
///
/// ### Example: Getting and setting a field
/// ```dart
/// final name = resolver.getValue(person, 'name');
/// resolver.setValue(person, 'name', 'Alice');
/// ```
///
/// This is especially useful in frameworks that need to instantiate objects or
/// call methods based on metadata, annotations, or configuration at runtime.
/// {@endtemplate}
class JitRuntimeResolver implements RuntimeResolver {
  // {@macro jit_executable_resolver}
  const JitRuntimeResolver();

  // Return a user-facing guidance message when the problem seems to be about unresolved generics
  String _message(dynamic typeOrMirror) {
    // If a mirror instance was passed, describe it
    if (_isMirror(typeOrMirror)) {
      final kind = _mirrorKind(typeOrMirror);
      final friendly = _mirrorFriendlyName(typeOrMirror);
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

  bool _isMirror(dynamic obj) {
    return obj is mirrors.Mirror || obj is mirrors.DeclarationMirror || obj is mirrors.TypeMirror;
  }

  String _mirrorKind(dynamic mirror) {
    if (mirror is mirrors.ClassMirror) return 'ClassMirror';
    if (mirror is mirrors.MethodMirror) return 'MethodMirror';
    if (mirror is mirrors.VariableMirror) return 'VariableMirror';
    if (mirror is mirrors.InstanceMirror) return 'InstanceMirror';
    if (mirror is mirrors.DeclarationMirror) return 'DeclarationMirror';
    if (mirror is mirrors.TypeMirror) return 'TypeMirror';
    return mirror.runtimeType.toString();
  }

  String _mirrorFriendlyName(dynamic mirror) {
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

  @override
  T newInstance<T>(String name, [Type? returnType, List<Object?> args = const [], Map<String, Object?> namedArgs = const {}]) {
    final Type effectiveType = (T != dynamic && T != Object)
        ? T
        : (returnType ?? (throw GenericResolutionException('Missing returnType when T is dynamic/Object')));

    try {
      final mirror = mirrors.reflectClass(effectiveType);
      final symbol = name.isEmpty ? Symbol('') : Symbol(name);

      if (namedArgs.isNotEmpty) {
        final named = namedArgs.map((k, v) => MapEntry(Symbol(k), v));
        return mirror.newInstance(symbol, args, named).reflectee as T;
      }

      return mirror.newInstance(symbol, args).reflectee as T;
    } on UnsupportedRuntimeOperationException catch (_) {
      rethrow;
    } on NoSuchMethodError catch (e, stack) {
      throw ConstructorNotFoundException(effectiveType.toString(), name, cause: e, stack: stack);
    } on mirrors.AbstractClassInstantiationError catch (e, stack) {
      // Mirrors-specific error
      final guidance = _message(effectiveType);
      throw MirrorResolutionException('Mirror error while creating instance of $effectiveType. $guidance\n$e\n$stack');
    } catch (e, stack) {
      // TypeError, ArgumentError, etc. — provide context-aware hints
      if (e is TypeError || e is ArgumentError) {
        final guidance = _message(effectiveType);
        throw GenericResolutionException('Failed to construct $effectiveType using constructor "$name". $guidance\nError: $e\nStack:\n$stack');
      }

      if (e.toString().contains('LateError') || e.toString().contains('LateInitializationError')) {
        rethrow;
      }

      // Generic fallback
      final guidance = _isMirror(effectiveType) ? _message(effectiveType) : _message(effectiveType);
      throw GenericResolutionException('Failed to create new instance of $effectiveType using constructor "$name". $guidance\nError: $e\nStack:\n$stack');
    }
  }

  @override
  Object? invokeMethod<T>(T instance, String method, {List<Object?> args = const [], Map<String, Object?> namedArgs = const {}}) {
    try {
      final mirror = mirrors.reflect(instance);
      final symbol = Symbol(method);

      try {
        final declaration = mirror.type.declarations[symbol];
        if (declaration is! mirrors.MethodMirror) {
          throw MethodNotFoundException(T.toString(), method);
        }

        if (declaration.isConstructor || declaration.isGetter || declaration.isSetter) {
          throw MethodNotFoundException(T.toString(), method);
        }

        return mirror.invoke(symbol, args, namedArgs.map((k, v) => MapEntry(Symbol(k), v))).reflectee;
      } on MethodNotFoundException catch (_) {
        rethrow;
      } catch (inner) {
        // attempt a best-effort invoke (some runtimes may accept it)
        return mirror.invoke(symbol, args, namedArgs.map((k, v) => MapEntry(Symbol(k), v))).reflectee;
      }
    } on MethodNotFoundException catch (_) {
      rethrow;
    } on NoSuchMethodError catch (e, stack) {
      throw MethodNotFoundException(T.toString(), method, cause: e, stack: stack);
    } on mirrors.AbstractClassInstantiationError catch (e, stack) {
      final guidance = _message(instance);
      throw MirrorResolutionException('Mirror error while invoking method "$method" on instance of $T. $guidance\n$e\n$stack');
    } catch (e, stack) {
      if (e is TypeError || e is ArgumentError) {
        final guidance = _message(instance);
        throw GenericResolutionException('Failed invoking method "$method" on $T. $guidance\nError: $e\nStack:\n$stack');
      }

      if (e.toString().contains('LateError') || e.toString().contains('LateInitializationError')) {
        rethrow;
      }

      if (e is FormatException) {
        rethrow;
      }

      throw MethodNotFoundException(T.toString(), method, cause: e, stack: stack);
    }
  }

  @override
  Object? getValue<T>(T instance, String name) {
    try {
      final mirror = mirrors.reflect(instance);
      final symbol = Symbol(name);

      try {
        final declaration = mirror.type.declarations[symbol];

        if (declaration is! mirrors.VariableMirror) {
          // Might be a getter (method without args)
          final symbol = Symbol(name);
          try {
            final declaration = mirror.type.declarations[symbol];
            if (declaration is! mirrors.MethodMirror) {
              throw FieldAccessException(T.toString(), name);
            }

            if (declaration.isGetter) {
              return mirror.invoke(symbol, []).reflectee;
            }

            throw FieldAccessException(T.toString(), name);
          } on FieldAccessException catch (_) {
            rethrow;
          } catch (inner) {
            // attempt a best-effort invoke (some runtimes may accept it)
            return mirror.invoke(symbol, []).reflectee;
          }
        }

        return mirror.getField(symbol).reflectee;
      } on FieldAccessException catch (_) {
        rethrow;
      } catch (inner) {
        // attempt a best-effort invoke (some runtimes may accept it)
        return mirror.getField(symbol).reflectee;
      }
    } on FieldAccessException catch (_) {
      rethrow;
    } on NoSuchMethodError catch (e, stack) {
      throw FieldAccessException(T.toString(), name, cause: e, stack: stack);
    } on mirrors.AbstractClassInstantiationError catch (e, stack) {
      final guidance = _message(instance);
      throw MirrorResolutionException('Mirror error while getting "$name" on instance of $T. $guidance\n$e\n$stack');
    } catch (e, stack) {
      if (e.toString().contains('LateError') || e.toString().contains('LateInitializationError')) {
        rethrow;
      }

      throw FieldAccessException(T.toString(), name, cause: e, stack: stack);
    }
  }

  @override
  void setValue<T>(T instance, String name, Object? value) {
    try {
      final mirror = mirrors.reflect(instance);
      final symbol = Symbol(name);
      
      try {
        final fieldMirror = mirror.type.declarations[symbol];

        if (fieldMirror is! mirrors.VariableMirror) {
          // Could be a setter method
          final symbol = Symbol('$name=');
          try {
            final setterDecl = mirror.type.declarations[symbol];

            if (setterDecl is! mirrors.MethodMirror) {
              throw FieldMutationException(T.toString(), name);
            }

            if (setterDecl.isSetter) {
              mirror.invoke(symbol, [value]);
              return;
            }

            throw FieldMutationException(T.toString(), name);
          } on FieldMutationException catch (_) {
            rethrow;
          } catch (inner) {
            // attempt a best-effort invoke (some runtimes may accept it)
            mirror.setField(symbol, value);
          }
        }

        if (fieldMirror is mirrors.VariableMirror && fieldMirror.isConst) {
          throw FieldMutationException(T.toString(), name);
        }

        mirror.setField(symbol, value);
      } on FieldMutationException catch (_) {
        rethrow;
      } catch (inner) {
        // attempt a best-effort invoke (some runtimes may accept it)
        mirror.setField(symbol, value);
      }
    } on FieldMutationException catch (_) {
      rethrow;
    } on NoSuchMethodError catch (e, stack) {
      throw FieldMutationException(T.toString(), name, cause: e, stack: stack);
    } on mirrors.AbstractClassInstantiationError catch (e, stack) {
      final guidance = _message(instance);
      throw MirrorResolutionException('Mirror error while setting "$name" on instance of $T. $guidance\n$e\n$stack');
    } catch (e, stack) {
      if (e is TypeError || e is ArgumentError) {
        throw FieldMutationException(T.toString(), name, cause: e, stack: stack);
      }

      if (e.toString().contains('LateError') || e.toString().contains('LateInitializationError')) {
        rethrow;
      }

      throw FieldMutationException(T.toString(), name, cause: e, stack: stack);
    }
  }
}