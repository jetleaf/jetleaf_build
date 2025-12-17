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

// ignore_for_file: deprecated_member_use_from_same_package

import 'package:jetleaf_build/jetleaf_build.dart';

// ========================================================================
// DESIGN 1: Classes that extend AbstractRuntimeHint or implement RuntimeHint
// ========================================================================

/// Simple RuntimeHint for String type
class StringRuntimeHint extends AbstractRuntimeHint<String> {
  const StringRuntimeHint();

  @override
  Hint createNewInstance<T>(String constructorName, ExecutableArgument argument) {
    if (constructorName == 'String.fromEnvironment') {
      final name = argument.getPositionalArguments().first as String;
      final defaultValue = argument.getNamedArguments()['defaultValue'] as String?;
      final result = String.fromEnvironment(name, defaultValue: defaultValue ?? '');
      return Hint.executed(result);
    }
    return super.createNewInstance(constructorName, argument);
  }

  @override
  Hint invokeMethod<T>(T instance, String methodName, ExecutableArgument argument) {
    if (instance is String && methodName == 'toUpperCase') {
      return Hint.executed(instance.toUpperCase());
    }
    return super.invokeMethod(instance, methodName, argument);
  }

  @override
  Hint getFieldValue<T>(T instance, String fieldName) {
    if (instance is String) {
      if (fieldName == 'length') {
        return Hint.executed(instance.length);
      }
      if (fieldName == 'isEmpty') {
        return Hint.executed(instance.isEmpty);
      }
    }
    return super.getFieldValue(instance, fieldName);
  }

  @override
  List<Object?> equalizedProperties() => [String];
}

/// RuntimeHint for int type with special behavior
class IntRuntimeHint implements RuntimeHint {
  const IntRuntimeHint();

  @override
  Type obtainTypeOfRuntimeHint() => int;

  @override
  Hint createNewInstance<T>(String constructorName, ExecutableArgument argument) {
    if (constructorName == 'int.parse') {
      final value = argument.getPositionalArguments().first as String;
      final result = int.parse(value);
      return Hint.executed(result);
    }
    return Hint.notExecuted();
  }

  @override
  Hint invokeMethod<T>(T instance, String methodName, ExecutableArgument argument) {
    if (instance is int) {
      if (methodName == 'abs') {
        return Hint.executed(instance.abs());
      }
      if (methodName == 'toString') {
        return Hint.executed(instance.toString());
      }
    }
    return Hint.notExecuted();
  }

  @override
  Hint getFieldValue<T>(T instance, String fieldName) {
    if (instance is int) {
      if (fieldName == 'isEven') {
        return Hint.executed(instance.isEven);
      }
      if (fieldName == 'isOdd') {
        return Hint.executed(instance.isOdd);
      }
    }
    return Hint.notExecuted();
  }

  @override
  Hint setFieldValue<T>(T instance, String fieldName, Object? value) {
    // ints are immutable, but we can still handle this
    if (instance is int && fieldName == 'runtimeType') {
      return Hint.executedWithoutResult();
    }
    return Hint.notExecuted();
  }

  @override
  List<Object?> equalizedProperties() => [int];
}

/// RuntimeHint for custom User class
class User {
  final String name;
  final int age;
  
  User(this.name, this.age);
  
  String get greeting => 'Hello, $name!';
  
  void celebrateBirthday() {
    print('Happy birthday, $name!');
  }
}

class UserRuntimeHint extends AbstractRuntimeHint<User> {
  const UserRuntimeHint();

  @override
  Hint createNewInstance<T>(String constructorName, ExecutableArgument argument) {
    if (constructorName == 'User') {
      final positional = argument.getPositionalArguments();
      final name = positional[0] as String;
      final age = positional[1] as int;
      return Hint.executed(User(name, age));
    }
    return super.createNewInstance(constructorName, argument);
  }

  @override
  Hint invokeMethod<T>(T instance, String methodName, ExecutableArgument argument) {
    if (instance is User) {
      if (methodName == 'greeting') {
        return Hint.executed(instance.greeting);
      }
      if (methodName == 'celebrateBirthday') {
        instance.celebrateBirthday();
        return Hint.executedWithoutResult();
      }
    }
    return super.invokeMethod(instance, methodName, argument);
  }

  @override
  Hint getFieldValue<T>(T instance, String fieldName) {
    if (instance is User) {
      if (fieldName == 'name') {
        return Hint.executed(instance.name);
      }
      if (fieldName == 'age') {
        return Hint.executed(instance.age);
      }
    }
    return super.getFieldValue(instance, fieldName);
  }

  @override
  Hint setFieldValue<T>(T instance, String fieldName, Object? value) {
    // User fields are final, so we can't actually set them
    // But we can demonstrate the hint being called
    if (instance is User) {
      print('Attempted to set $fieldName on User to $value');
      return Hint.executedWithoutResult();
    }
    return super.setFieldValue(instance, fieldName, value);
  }

  @override
  List<Object?> equalizedProperties() => [User];
}

/// RuntimeHintProvider for creating RuntimeHints
class ComplexRuntimeHintProvider implements RuntimeHintProvider {
  const ComplexRuntimeHintProvider();

  @override
  RuntimeHint createHint() {
    return ComplexRuntimeHint();
  }
}

class ComplexRuntimeHint implements RuntimeHint {
  @override
  Type obtainTypeOfRuntimeHint() => Map;

  @override
  Hint createNewInstance<T>(String constructorName, ExecutableArgument argument) {
    if (constructorName == 'Map') {
      return Hint.executed(<String, dynamic>{});
    }
    return Hint.notExecuted();
  }

  @override
  Hint invokeMethod<T>(T instance, String methodName, ExecutableArgument argument) {
    if (instance is Map) {
      if (methodName == 'putIfAbsent') {
        final key = argument.getPositionalArguments()[0] as String;
        final value = argument.getPositionalArguments()[1] as dynamic Function();
        return Hint.executed(instance.putIfAbsent(key, value));
      }
    }
    return Hint.notExecuted();
  }

  @override
  Hint getFieldValue<T>(T instance, String fieldName) {
    if (instance is Map) {
      if (fieldName == 'length') {
        return Hint.executed(instance.length);
      }
      if (fieldName == 'isEmpty') {
        return Hint.executed(instance.isEmpty);
      }
    }
    return Hint.notExecuted();
  }

  @override
  Hint setFieldValue<T>(T instance, String fieldName, Object? value) {
    if (instance is Map && fieldName.startsWith('[') && fieldName.endsWith(']')) {
      final key = fieldName.substring(1, fieldName.length - 1);
      instance[key] = value;
      return Hint.executedWithoutResult();
    }
    return Hint.notExecuted();
  }

    @override
  List<Object?> equalizedProperties() => [Map];
}

// ========================================================================
// DESIGN 2: Annotations that are RuntimeHints or RuntimeHintProviders
// ========================================================================

/// Annotation that IS a RuntimeHint
@Deprecated('Use NewStringRuntimeHint instead')
class StringRuntimeHintAnnotation implements RuntimeHint {
  final String prefix;
  
  const StringRuntimeHintAnnotation({this.prefix = 'Hinted: '});

  @override
  Type obtainTypeOfRuntimeHint() => String;

  @override
  Hint createNewInstance<T>(String constructorName, ExecutableArgument argument) {
    return Hint.notExecuted();
  }

  @override
  Hint invokeMethod<T>(T instance, String methodName, ExecutableArgument argument) {
    if (instance is String && methodName == 'toString') {
      return Hint.executed('$prefix$instance');
    }
    return Hint.notExecuted();
  }

  @override
  Hint getFieldValue<T>(T instance, String fieldName) {
    return Hint.notExecuted();
  }

  @override
  Hint setFieldValue<T>(T instance, String fieldName, Object? value) {
    return Hint.notExecuted();
  }

  @override
  List<Object?> equalizedProperties() => [String];
}

/// Annotation that IS a RuntimeHintProvider
class IntRuntimeHintProviderAnnotation implements RuntimeHintProvider {
  final bool verbose;
  
  const IntRuntimeHintProviderAnnotation({this.verbose = false});

  @override
  RuntimeHint createHint() {
    return VerboseIntRuntimeHint(verbose);
  }
}

class VerboseIntRuntimeHint implements RuntimeHint {
  final bool verbose;
  
  VerboseIntRuntimeHint(this.verbose);

  @override
  Type obtainTypeOfRuntimeHint() => int;

  @override
  Hint createNewInstance<T>(String constructorName, ExecutableArgument argument) {
    if (verbose) print('VerboseIntRuntimeHint.createNewInstance: $constructorName');
    return Hint.notExecuted();
  }

  @override
  Hint invokeMethod<T>(T instance, String methodName, ExecutableArgument argument) {
    if (verbose) print('VerboseIntRuntimeHint.invokeMethod: $methodName on $instance');
    if (instance is int) {
      if (methodName == 'toRadixString') {
        final radix = argument.getPositionalArguments().first as int;
        return Hint.executed(instance.toRadixString(radix));
      }
    }
    return Hint.notExecuted();
  }

  @override
  Hint getFieldValue<T>(T instance, String fieldName) {
    if (verbose) print('VerboseIntRuntimeHint.getFieldValue: $fieldName on $instance');
    return Hint.notExecuted();
  }

  @override
  Hint setFieldValue<T>(T instance, String fieldName, Object? value) {
    if (verbose) print('VerboseIntRuntimeHint.setFieldValue: $fieldName = $value on $instance');
    return Hint.notExecuted();
  }

  @override
  List<Object?> equalizedProperties() => [verbose];
}

/// Custom RuntimeHintDescriptor implementation
class CustomRuntimeHintDescriptor extends DefaultRuntimeHintDescriptor {
  final String name;
  
  CustomRuntimeHintDescriptor(this.name);
  
  @override
  String toString() => 'CustomRuntimeHintDescriptor($name)';
}

// ========================================================================
// Test classes with annotations
// ========================================================================

// Class with RuntimeHint annotation
@StringRuntimeHintAnnotation(prefix: 'ANNOTATED: ')
class AnnotatedStringUser {
  final String value;
  
  AnnotatedStringUser(this.value);
}

// Class with RuntimeHintProvider annotation
@IntRuntimeHintProviderAnnotation(verbose: true)
class AnnotatedIntUser {
  final int value;
  
  AnnotatedIntUser(this.value);
}

// Class that extends RuntimeHint (for discovery)
class DiscoverableRuntimeHint extends AbstractRuntimeHint<List> {
  const DiscoverableRuntimeHint();
  
  @override
  Hint createNewInstance<T>(String constructorName, ExecutableArgument argument) {
    if (constructorName == 'List.empty') {
      return Hint.executed(<dynamic>[]);
    }
    return super.createNewInstance(constructorName, argument);
  }
}

// Class that implements RuntimeHintProvider
class DiscoverableRuntimeHintProvider implements RuntimeHintProvider {
  const DiscoverableRuntimeHintProvider();
  
  @override
  RuntimeHint createHint() {
    return DiscoverableRuntimeHint();
  }
}

// Abstract class (should not be instantiated)
abstract class AbstractRuntimeHintClass implements RuntimeHint {
  const AbstractRuntimeHintClass();
  
  @override
  Type obtainTypeOfRuntimeHint() => Object;
  
  @override
  Hint createNewInstance<T>(String constructorName, ExecutableArgument argument) => Hint.notExecuted();
  
  @override
  Hint invokeMethod<T>(T instance, String methodName, ExecutableArgument argument) => Hint.notExecuted();
  
  @override
  Hint getFieldValue<T>(T instance, String fieldName) => Hint.notExecuted();
  
  @override
  Hint setFieldValue<T>(T instance, String fieldName, Object? value) => Hint.notExecuted();
}