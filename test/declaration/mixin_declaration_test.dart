// // ---------------------------------------------------------------------------
// // 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
// //
// // Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
// //
// // This source file is part of the JetLeaf Framework and is protected
// // under copyright law. You may not copy, modify, or distribute this file
// // except in compliance with the JetLeaf license.
// //
// // For licensing terms, see the LICENSE file in the root of this project.
// // ---------------------------------------------------------------------------
// // 
// // 🔧 Powered by Hapnium — the Dart backend engine 🍃

// import 'package:test/test.dart';
// import 'package:jetleaf_build/jetleaf_build.dart';

// // Base classes for mixin constraints
// abstract class BaseModel {
//   String get id;
//   DateTime get createdAt;
// }

// abstract class Disposable {
//   void dispose();
// }

// abstract class Serializable {
//   Map<String, dynamic> toJson();
// }

// // Simple mixin
// mixin TimestampMixin {
//   DateTime? _createdAt;
//   DateTime? _updatedAt;
  
//   DateTime? get createdAt => _createdAt;
//   DateTime? get updatedAt => _updatedAt;
  
//   void updateTimestamp() {
//     _updatedAt = DateTime.now();
//     _createdAt ??= _updatedAt;
//   }
// }

// // Mixin with constraints
// mixin LoggingMixin on BaseModel {
//   void log(String message) {
//     print('[$id] $message at ${DateTime.now()}');
//   }
  
//   String get debugInfo => '$id created at $createdAt';
// }

// // Generic mixin
// @Generic(GenericMixin)
// mixin GenericMixin<T> {
//   final List<T> _items = [];
  
//   void addItem(T item) {
//     _items.add(item);
//   }
  
//   List<T> get items => List.unmodifiable(_items);
  
//   bool contains(T item) => _items.contains(item);
// }

// // Mixin with multiple constraints
// mixin AdvancedMixin on BaseModel implements Disposable, Serializable {
//   bool _isDisposed = false;
  
//   @override
//   void dispose() {
//     _isDisposed = true;
//     print('$id disposed');
//   }
  
//   @override
//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'createdAt': createdAt.toIso8601String(),
//       'isDisposed': _isDisposed,
//     };
//   }
  
//   bool get isDisposed => _isDisposed;
// }

// mixin St on StaticMixin, AdvancedMixin, BaseModel {}

// // Mixin with static members
// mixin StaticMixin {
//   static int instanceCount = 0;
//   static const String MIXIN_NAME = 'StaticMixin';
  
//   static void incrementCount() {
//     instanceCount++;
//   }
  
//   String get mixinInfo => '$MIXIN_NAME (instances: $instanceCount)';
// }

// // Mixin with private members
// mixin PrivateMixin {
//   final String _privateData = 'secret';
  
//   String get publicData => _privateData.toUpperCase();
  
//   void _privateMethod() {
//     print('Private method called');
//   }
  
//   void publicMethod() {
//     _privateMethod();
//     print('Public method: $publicData');
//   }
// }

// // Classes using mixins
// class User with TimestampMixin, GenericMixin<String> {
//   final String id;
//   final String name;
  
//   User(this.id, this.name) {
//     updateTimestamp();
//   }
// }

// class Product extends BaseModel with LoggingMixin, AdvancedMixin {
//   @override
//   final String id;
//   @override
//   final DateTime createdAt;
//   final String name;
//   final double price;
  
//   Product(this.id, this.name, this.price) : createdAt = DateTime.now();
// }

// class Service with StaticMixin, PrivateMixin {
//   final String serviceName;
  
//   Service(this.serviceName);
  
//   void run() {
//     print('Running $serviceName');
//     publicMethod();
//   }
// }

// mixin class Base {}

// // Mixin application class
// class MixedClassMixin = Base with TimestampMixin, GenericMixin<int>;

// // Constrained generic mixin
// mixin ComparableMixin<T extends Comparable<T>> {
//   int compareTo(T other);
  
//   bool operator >(T other) => compareTo(other) > 0;
//   bool operator <(T other) => compareTo(other) < 0;
//   bool operator >=(T other) => compareTo(other) >= 0;
//   bool operator <=(T other) => compareTo(other) <= 0;
// }

// void main() async {
//   setUpAll(() async {
//     await runTestScan(filesToLoad: []);
//   });

//   group('MixinDeclaration Basic Properties', () {
//     test('should identify mixin type kind', () {
//       final mixins = Runtime.getAllMixins();
      
//       expect(mixins, isNotEmpty);
      
//       final timestampMixin = mixins.firstWhere((m) => m.getName() == 'TimestampMixin');
//       expect(timestampMixin.getKind(), equals(TypeKind.mixinType));
//       expect(timestampMixin.getIsMixin(), isTrue);
//     });

//     test('should retrieve mixin members', () {
//       final mixins = Runtime.getAllMixins();
      
//       final timestampMixin = mixins.firstWhere((m) => m.getName() == 'TimestampMixin');
      
//       final members = timestampMixin.getMembers();
//       expect(members.length, greaterThanOrEqualTo(3)); // createdAt, updatedAt getters, updateTimestamp method
      
//       final fields = timestampMixin.getFields();
//       expect(fields.length, greaterThanOrEqualTo(2)); // _createdAt, _updatedAt
      
//       final methods = timestampMixin.getMethods();
//       expect(methods.any((m) => m.getName() == 'updateTimestamp'), isTrue);
//     });

//     test('should retrieve mixin constraints', () {
//       final mixins = Runtime.getAllMixins();
      
//       final loggingMixin = mixins.firstWhere((m) => m.getName() == 'LoggingMixin');
      
//       expect(loggingMixin.getHasConstraints(), isTrue);
//       final constraints = loggingMixin.getConstraints();
//       expect(constraints, isNotEmpty);
//       expect(constraints.any((c) => c.getName() == 'BaseModel'), isTrue);
//     });

//     test('should identify mixins without constraints - must always have Object', () {
//       final mixins = Runtime.getAllMixins();
      
//       final timestampMixin = mixins.firstWhere((m) => m.getName() == 'TimestampMixin');
      
//       expect(timestampMixin.getHasConstraints(), isTrue);
//       final constraints = timestampMixin.getConstraints();
//       expect(constraints, isNotEmpty);
//     });
//   });

//   group('MixinDeclaration Fields', () {
//     test('should retrieve instance fields', () {
//       final mixins = Runtime.getAllMixins();
      
//       final timestampMixin = mixins.firstWhere((m) => m.getName() == 'TimestampMixin');
      
//       final instanceFields = timestampMixin.getInstanceFields();
//       expect(instanceFields.length, greaterThanOrEqualTo(2));
//       expect(instanceFields.any((f) => f.getName() == '_createdAt'), isTrue);
//       expect(instanceFields.any((f) => f.getName() == '_updatedAt'), isTrue);
//     });

//     test('should retrieve static fields', () {
//       final mixins = Runtime.getAllMixins();
      
//       final staticMixin = mixins.firstWhere((m) => m.getName() == 'StaticMixin');
      
//       final staticFields = staticMixin.getStaticFields();
//       expect(staticFields.length, equals(2));
//       expect(staticFields.any((f) => f.getName() == 'instanceCount'), isTrue);
//       expect(staticFields.any((f) => f.getName() == 'MIXIN_NAME'), isTrue);
//     });

//     test('should handle private fields', () {
//       final mixins = Runtime.getAllMixins();
      
//       final privateMixin = mixins.firstWhere((m) => m.getName() == 'PrivateMixin');
      
//       final fields = privateMixin.getFields();
//       final privateField = fields.firstWhere((f) => f.getName() == '_privateData');
//       expect(privateField.getIsPublic(), isFalse);
      
//       final publicGetter = privateMixin.getMethods().firstWhere((m) => m.getName() == 'publicData' && m.getIsGetter());
//       expect(publicGetter, isNotNull);
//     });
//   });

//   group('MixinDeclaration Methods', () {
//     test('should retrieve instance methods', () {
//       final mixins = Runtime.getAllMixins();
      
//       final timestampMixin = mixins.firstWhere((m) => m.getName() == 'TimestampMixin');
      
//       final instanceMethods = timestampMixin.getInstanceMethods();
//       expect(instanceMethods.any((m) => m.getName() == 'updateTimestamp'), isTrue);
//     });

//     test('should retrieve static methods', () {
//       final mixins = Runtime.getAllMixins();
      
//       final staticMixin = mixins.firstWhere((m) => m.getName() == 'StaticMixin');
      
//       final staticMethods = staticMixin.getStaticMethods();
//       expect(staticMethods.any((m) => m.getName() == 'incrementCount'), isTrue);
//     });

//     test('should handle private methods', () {
//       final mixins = Runtime.getAllMixins();
      
//       final privateMixin = mixins.firstWhere((m) => m.getName() == 'PrivateMixin');
      
//       final methods = privateMixin.getMethods();
//       final privateMethod = methods.firstWhere((m) => m.getName() == '_privateMethod');
//       expect(privateMethod.getIsPublic(), isFalse);
      
//       final publicMethod = methods.firstWhere((m) => m.getName() == 'publicMethod');
//       expect(publicMethod.getIsPublic(), isTrue);
//     });

//     test('should retrieve specific method by name', () {
//       final mixins = Runtime.getAllMixins();
      
//       final timestampMixin = mixins.firstWhere((m) => m.getName() == 'TimestampMixin');
      
//       final updateMethod = timestampMixin.getMethod('updateTimestamp');
//       expect(updateMethod, isNotNull);
//       expect(updateMethod!.getName(), equals('updateTimestamp'));
      
//       final nonExistent = timestampMixin.getMethod('nonExistent');
//       expect(nonExistent, isNull);
//     });
//   });

//   group('MixinDeclaration Generic Mixins', () {
//     test('should handle generic mixins', () {
//       final mixins = Runtime.getAllMixins();
      
//       final genericMixin = mixins.firstWhere((m) => m.getName() == 'GenericMixin');
      
//       expect(genericMixin.isGeneric(), isTrue);
//       expect(genericMixin.getTypeArguments(), isNotEmpty);
//     });

//     test('should handle constrained generic mixins', () {
//       final mixins = Runtime.getAllMixins();
      
//       final comparableMixin = mixins.firstWhere((m) => m.getName() == 'ComparableMixin');
      
//       expect(comparableMixin.isGeneric(), isTrue);
//       // Type parameter should have upper bound of Comparable
//     });
//   });

//   group('MixinDeclaration Interfaces', () {
//     test('should identify mixins that implement interfaces', () {
//       final mixins = Runtime.getAllMixins();
      
//       final advancedMixin = mixins.firstWhere((m) => m.getName() == 'AdvancedMixin');
      
//       expect(advancedMixin.getHasInterfaces(), isTrue);
//       final interfaces = advancedMixin.getInterfaces();
//       expect(interfaces.length, equals(2));
//       expect(interfaces.any((i) => i.getName() == 'Disposable'), isTrue);
//       expect(interfaces.any((i) => i.getName() == 'Serializable'), isTrue);
//     });

//     test('should identify mixins without interfaces', () {
//       final mixins = Runtime.getAllMixins();
      
//       final timestampMixin = mixins.firstWhere((m) => m.getName() == 'TimestampMixin');
      
//       expect(timestampMixin.getHasInterfaces(), isFalse);
//       final interfaces = timestampMixin.getInterfaces();
//       expect(interfaces, isEmpty);
//     });
//   });

//   group('MixinDeclaration Usage in Classes', () {
//     test('should find mixins used by classes', () {
//       final userClass = Runtime.findClass<User>();
      
//       final mixins = userClass.getMixins();
//       expect(mixins.length, equals(2));
//       expect(mixins.any((m) => m.getName() == 'TimestampMixin'), isTrue);
//       expect(mixins.any((m) => m.getName().contains('GenericMixin')), isTrue);
//     });

//     test('should handle mixin application classes', () {
//       final mixedClass = Runtime.findClassByType(MixedClassMixin);
      
//       final mixins = mixedClass.getMixins();
//       expect(mixins.length, equals(3));
//       expect(mixins.any((m) => m.getName() == 'TimestampMixin'), isTrue);
//       expect(mixins.any((m) => m.getName().contains('GenericMixin')), isTrue);
//     });
//   });

//   group('MixinDeclaration Field and Method Lookup', () {
//     test('should find field by name', () {
//       final mixins = Runtime.getAllMixins();
      
//       final timestampMixin = mixins.firstWhere((m) => m.getName() == 'TimestampMixin');
      
//       final createdAtField = timestampMixin.getField('_createdAt');
//       expect(createdAtField, isNotNull);
//       expect(createdAtField!.getName(), equals('_createdAt'));
      
//       final nonExistentField = timestampMixin.getField('nonExistent');
//       expect(nonExistentField, isNull);
//     });

//     test('should check if mixin has field', () {
//       final mixins = Runtime.getAllMixins();
      
//       final timestampMixin = mixins.firstWhere((m) => m.getName() == 'TimestampMixin');
      
//       expect(timestampMixin.hasField('_createdAt'), isTrue);
//       expect(timestampMixin.hasField('_updatedAt'), isTrue);
//       expect(timestampMixin.hasField('nonExistent'), isFalse);
//     });

//     test('should check if mixin has method', () {
//       final mixins = Runtime.getAllMixins();
      
//       final timestampMixin = mixins.firstWhere((m) => m.getName() == 'TimestampMixin');
      
//       expect(timestampMixin.hasMethod('updateTimestamp'), isTrue);
//       expect(timestampMixin.hasMethod('nonExistent'), isFalse);
//     });
//   });
// }