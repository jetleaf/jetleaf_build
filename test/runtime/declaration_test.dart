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

// ============================================================================
// TEST DECLARATIONS - LIBRARY 1: Core Types
// ============================================================================

// Base interfaces and abstract classes
import 'package:jetleaf_build/src/annotations.dart';
import 'package:jetleaf_build/src/runner/test_scan.dart';
import 'package:jetleaf_build/src/runtime/runtime_provider/meta_runtime_provider.dart';

abstract class BaseInterface {
  void doSomething();
  String get name;
}

abstract class BaseInterface2 {
  void doSomethingElse();
  int get priority => 0;
}

abstract class BaseInterface3<T> {
  T process(T input);
}

// Mixins with various constraints
mixin TestMixin {
  void mixinMethod() {
    print('TestMixin method');
  }
  
  String get mixinProperty => 'mixin';
}

mixin AnotherMixin on BaseInterface {
  void enforcedMethod() {
    print('Enforced method from AnotherMixin');
  }
  
  @override
  String get name => 'AnotherMixin';
}

mixin GenericMixin<T> {
  List<T> items = [];
  
  void addItem(T item) {
    items.add(item);
  }
}

mixin ConstrainedMixin<T extends num> on BaseInterface {
  T calculate(T value) => value;
}

// Sealed classes and their implementations
sealed class SealedAnimal {
  const SealedAnimal();
  String get sound;
}

final class Dog extends SealedAnimal {
  @override
  String get sound => 'Woof';
}

final class Cat extends SealedAnimal {
  @override
  String get sound => 'Meow';
}

base class Bird extends SealedAnimal {
  @override
  String get sound => 'Tweet';
}

// Interface classes
abstract interface class Drawable {
  void draw();
}

abstract interface class Serializable<T> {
  Map<String, dynamic> toJson();
  T fromJson(Map<String, dynamic> json);
}

// Base classes
base class Vehicle {
  final String brand;
  Vehicle(this.brand);
}

base class Car extends Vehicle {
  final int doors;
  Car(super.brand, this.doors);
}

// Final classes
final class ImmutablePoint {
  final double x;
  final double y;
  
  const ImmutablePoint(this.x, this.y);
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImmutablePoint && x == other.x && y == other.y;
  
  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

// Generic classes with various bounds
class GenericContainer<T> {
  final List<T> items;
  GenericContainer(this.items);
  
  T? get first => items.isEmpty ? null : items.first;
}

class BoundedContainer<T extends Comparable<T>> {
  final List<T> items;
  BoundedContainer(this.items);
  
  T? get max => items.isEmpty ? null : items.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
}

class MultiBoundedContainer<T extends BaseInterface> implements Comparable<T> {
  final T item;
  MultiBoundedContainer(this.item);
  
  @override
  int compareTo(T other) {
    throw UnimplementedError();
  }
}

@Resolved()
@Generic(TestClass, "")
class TestClass<T extends Major> extends BaseInterface 
    with TestMixin, AnotherMixin 
    implements BaseInterface2, SealedAnimal {
  String id;
  final List<T> genericList;
  static int instanceCount = 0;
  late final String computedValue;
  
  TestClass(this.id, this.genericList) {
    instanceCount++;
    computedValue = 'computed_$id';
  }
  
  // Named constructor
  TestClass.named(this.id) : genericList = [];
  
  // Factory constructor
  factory TestClass.create(String id, List<T> list) {
    return TestClass(id, list);
  }
  
  // Const constructor
  TestClass.constant(this.id, this.genericList);
  
  @override
  void doSomething() {
    print('TestClass doing something');
  }
  
  @override
  void doSomethingElse() {
    print('TestClass doing something else');
  }
  
  @override
  String get sound => 'TestClass sound';
  
  // Static method
  static TestClass<T> createDefault<T extends Major>() {
    return TestClass<T>('default', []);
  }
  
  // Generic method
  U transform<U>(U Function(T) transformer) {
    return transformer(genericList.first);
  }
  
  @override
  int get priority => throw UnimplementedError();
}

class Major {}

class Minor extends Major {
  final List<int> numbers;

  Minor(this.numbers);
}

class Checking extends TestClass<Minor> {
  final bool isActive;
  
  Checking({this.isActive = true}) : super("checking", []);
  
  Checking.inactive() : isActive = false, super("inactive", []);
}

class TestedClass<T extends Object> implements BaseInterface {
  @override
  late String name;

  final Map<String, T> data = {};
  
  TestedClass();
  
  TestedClass.withName(this.name);
  
  @override
  void doSomething() {
    print(name);
  }
  
  void addData(String key, T value) {
    data[key] = value;
  }
}

// Enums with various features
enum SimpleEnum {
  first,
  second,
  third
}

enum EnhancedEnum {
  small(1, 'S'),
  medium(2, 'M'),
  large(3, 'L');
  
  const EnhancedEnum(this.size, this.code);
  
  final int size;
  final String code;
  
  bool get isLarge => this == EnhancedEnum.large;
  
  static EnhancedEnum fromSize(int size) {
    return values.firstWhere((e) => e.size == size);
  }
}

enum StatusEnum implements Comparable<StatusEnum> {
  pending(0, 'Pending'),
  active(1, 'Active'),
  inactive(2, 'Inactive'),
  archived(3, 'Archived');
  
  const StatusEnum(this.priority, this.displayName);
  
  final int priority;
  final String displayName;
  
  @override
  int compareTo(StatusEnum other) => priority.compareTo(other.priority);
  
  bool get isActive => this == StatusEnum.active;
}

// Records
typedef PersonRecord = ({String name, int age, String? email});
typedef GenericRecord<T> = ({T value, String label});
typedef NestedRecord = ({PersonRecord person, List<String> tags});

// Complex record with methods
extension PersonRecordExtension on PersonRecord {
  bool get isAdult => age >= 18;
  String get displayName => email != null ? '$name <$email>' : name;
}

// Typedefs
typedef StringProcessor = String Function(String input);
typedef GenericProcessor<T, R> = R Function(T input);
typedef ComplexCallback<T extends Comparable<T>> = Future<List<T>> Function(T seed, int count);

// Function types
typedef VoidCallback = void Function();
typedef EventHandler<T> = void Function(T event);
typedef AsyncProcessor<T, R> = Future<R> Function(T input);

// ============================================================================
// ANNOTATIONS
// ============================================================================

// ============================================================================
// SAMPLE PODS AND SERVICES
// ============================================================================

class DataSource {
  final String url;
  const DataSource(this.url);
}

class CacheManager {
  final int maxSize;
  const CacheManager(this.maxSize);
}

class NoSqlClient {
  final String connectionString;
  const NoSqlClient(this.connectionString);
}

class DatabaseService {
  final DataSource dataSource;
  
  DatabaseService(this.dataSource);
  
  void connect() {
    print('DatabaseService connected.');
  }
  
  Future<List<String>> query(String sql) async {
    return ['result1', 'result2'];
  }
}

class AuditLogger {
  static final List<String> _logs = [];
  
  void log(String event) {
    _logs.add(event);
    print('Audit: $event');
  }
  
  List<String> get logs => List.unmodifiable(_logs);
}

/// Provides AOT-compatible runtime reflection hints for the `TestClass` class.
///
/// This class is generated automatically by the JetLeaf reflection system
/// for classes annotated with `@Resolved`.
// class TestClassRuntimeHintProcessor implements RuntimeHintProcessor {
//   /// {@macro runtime_hint_processor}
//   const TestClassRuntimeHintProcessor();

//   @override
//   void proceed(RuntimeHintDescriptor descriptor) {
//     descriptor.addRuntimeHint(
//       RuntimeHint(
//         type: TestClass,
//         newInstance: (name, args, namedArgs) {
//           switch (name) {
//         case '':
//           return TestClass(args[0] as String, args[1] as List<Major>);
//         case 'named':
//           return TestClass.named(args[0] as String);
//         case 'constant':
//           return TestClass.constant(args[0] as String, args[1] as List<Major>);
//         case 'create':
//           return TestClass.create(args[0] as String, args[1] as List<Major>);
//         default:
//           throw UnImplementedResolverException(TestClass, 'Unknown constructor: $name');
//       }

//         },
//         invokeMethod: (instance, method, args, namedArgs) {
//           instance = instance as TestClass;
//           switch (method) {
//             case 'createDefault':
//               return TestClass.createDefault() as TestClass<dynamic>;
//             case 'transform':
//               instance.transform(args[0] as dynamic Function(Major));
//             case 'getUri':
//               return instance.getUri();
//             case 'getType':
//               return instance.getType();
//             case 'doSomething':
//               instance.doSomething();
//             case 'doSomethingElse':
//               instance.doSomethingElse();
//             default:
//               throw UnImplementedResolverException(TestClass, 'Unknown method: $method');
//           }

//         },
//         getValue: (instance, name) {
//           instance = instance as TestClass;
//           switch (name) {
//             case 'id':
//               return instance.id;
//             case 'genericList':
//               return instance.genericList;
//             case 'instanceCount':
//               return TestClass.instanceCount;
//             case 'computedValue':
//               return instance.computedValue;
//             case 'sound':
//               return instance.sound;
//             case 'priority':
//               return instance.priority;
//             default:
//               throw UnImplementedResolverException(TestClass, 'Unknown field or getter: $name');
//           }

//         },
//         setValue: (instance, name, value) {
//           switch (name) {
//             case 'instanceCount':
//               TestClass.instanceCount = value as int;
//               break;
//             default:
//               throw UnImplementedResolverException(TestClass, 'Unknown field or setter: $name');
//           }
//         },
//       ),
//     );
//   }
// }


// ============================================================================
// TEST RUNNER
// ============================================================================

void main() async {
  print('Setting up comprehensive reflection test environment...');
  await runTestScan(filesToLoad: [
    "/Users/mac/Documents/Hapnium/jetleaf/test/lang/reflect/declaration_test.dart",
    "/Users/mac/Documents/Hapnium/jetleaf/test/lang/reflect/class_test.dart",
  ]);

  print(Runtime.getAllClasses().map((clazz) => clazz.getName()).join(", "));
  
  print('Test environment ready!');
  print('Available libraries: ${Runtime.getAllLibraries().length}');
  print('Available classes: ${Runtime.getAllClasses().length}');
  print('Available enums: ${Runtime.getAllEnums().length}');
}