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

// ignore_for_file: unused_element, unused_field

import 'package:test/test.dart';
import 'package:jetleaf_build/jetleaf_build.dart';

// Simple enum
enum SimpleEnum {
  @Author("Eve")
  first,
  second,
  third,
}

// Simple enum with private values
enum PrivateEnum {
  _private,
  public,
  _anotherPrivate,
}

// Enhanced enum with fields and methods
enum Color {
  red(0xFF0000, 'Red'),
  green(0x00FF00, 'Green'),
  blue(0x0000FF, 'Blue'),
  yellow(0xFFFF00, 'Yellow'),
  purple(0x800080, 'Purple');
  
  const Color(this.hexCode, this.displayName);
  
  final int hexCode;
  final String displayName;
  
  String get rgb => 'rgb(${(hexCode >> 16) & 0xFF}, ${(hexCode >> 8) & 0xFF}, ${hexCode & 0xFF})';
  
  Color mix(Color other) {
    final mixedHex = (hexCode & 0xFEFEFE + other.hexCode & 0xFEFEFE) ~/ 2;
    return Color.values.firstWhere(
      (c) => c.hexCode == mixedHex,
      orElse: () => this,
    );
  }
  
  bool get isPrimary => this == red || this == green || this == blue;
  
  static Color parse(String name) {
    return Color.values.firstWhere(
      (c) => c.name == name.toLowerCase(),
      orElse: () => throw ArgumentError('Invalid color: $name'),
    );
  }
}

// Enum implementing interfaces
enum Priority implements Comparable<Priority> {
  low(0, 'Low'),
  medium(1, 'Medium'),
  high(2, 'High'),
  critical(3, 'Critical');
  
  const Priority(this.level, this.label);
  
  final int level;
  final String label;
  
  @override
  int compareTo(Priority other) => level.compareTo(other.level);
  
  bool get isHighPriority => level >= 2;
  
  static Priority fromLevel(int level) {
    return values.firstWhere(
      (p) => p.level == level,
      orElse: () => Priority.medium,
    );
  }
}

// Enum with static members
enum Direction {
  north,
  south,
  east,
  west;
  
  static final Map<String, Direction> fromAbbreviation = {
    'N': north,
    'S': south,
    'E': east,
    'W': west,
  };
  
  static Direction? parse(String value) {
    return fromAbbreviation[value.toUpperCase()] ??
           values.firstWhere(
             (d) => d.name.toLowerCase() == value.toLowerCase(),
             orElse: () => throw ArgumentError('Invalid direction: $value'),
           );
  }
  
  Direction get opposite {
    return switch (this) {
      north => south,
      south => north,
      east => west,
      west => east,
    };
  }
}

// Complex enum with factory constructor and private constructor
enum FileType {
  text('.txt', 'Text File', isBinary: false),
  image('.png', 'Image File', isBinary: true),
  audio('.mp3', 'Audio File', isBinary: true),
  video('.mp4', 'Video File', isBinary: true),
  document('.pdf', 'Document File', isBinary: true);
  
  const FileType(this.extension, this.description, {required this.isBinary});
  
  final String extension;
  final String description;
  final bool isBinary;
  
  bool matches(String filename) => filename.endsWith(extension);
  
  factory FileType.fromFilename(String filename) {
    for (final type in values) {
      if (type.matches(filename)) {
        return type;
      }
    }
    throw ArgumentError('Unknown file type for: $filename');
  }
}

// Enum with nullable field in enhanced enum
enum Config {
  enabled(true, 'Enabled configuration'),
  disabled(false, 'Disabled configuration'),
  unknown(null, 'Unknown status');
  
  const Config(this.value, this.description);
  
  final bool? value;
  final String description;
  
  bool get isDefined => value != null;
  
  String get statusText => switch (this) {
    Config.enabled => 'Enabled',
    Config.disabled => 'Disabled',
    Config.unknown => 'Unknown',
  };
}

// Enum with private fields and methods
enum SecretCode {
  alpha(1, 'Alpha code'),
  beta(2, 'Beta code'),
  gamma(3, 'Gamma code');
  
  const SecretCode(this._code, this.description);
  
  final int _code;
  final String description;
  
  int get code => _code * 100;
  
  String _encrypt() => 'ENCRYPTED_$_code';
  
  String get encryptedValue => _encrypt();
}

// Classes using enums
class EnumUser {
  final Priority priority;
  final Color color;
  
  EnumUser(this.priority, this.color);
  
  bool get isHighPriority => priority.isHighPriority;
  bool get isPrimaryColor => color.isPrimary;
}

class ColorPalette {
  final List<Color> colors;
  
  ColorPalette(this.colors);
  
  Color? get primaryColor => colors.where((c) => c.isPrimary).firstOrNull;
  
  List<Color> get warmColors => colors.where((c) => 
      c == Color.red || c == Color.yellow || c == Color.purple).toList();
}

// Functions using enums
String describePriority(Priority priority) {
  return switch (priority) {
    Priority.low => 'Low priority',
    Priority.medium => 'Medium priority',
    Priority.high => 'High priority',
    Priority.critical => 'Critical priority',
  };
}

List<Priority> filterHighPriorities(List<Priority> priorities) {
  return priorities.where((p) => p.isHighPriority).toList();
}

void main() async {
  setUpAll(() async {
    await runTestScan(filesToLoad: []);
  });

  group('EnumDeclaration Basic Properties', () {
    test('should identify enum type kind', () {
      final simpleEnum = Runtime.findClass<SimpleEnum>();
      
      expect(simpleEnum.getKind(), equals(TypeKind.enumType));
      expect(simpleEnum.getSimpleName(), equals('SimpleEnum'));
    });

    test('should inherit from ClassDeclaration', () {
      final colorEnum = Runtime.findClass<Color>();
      
      expect(colorEnum, isA<ClassDeclaration>());
      expect(colorEnum, isA<EnumDeclaration>());
    });

    // test('should identify enum-specific properties', () {
    //   final colorEnum = Runtime.getAllClasses()
    //       .firstWhere((c) => c.getName() == 'Color');
      
    //   // Enums are implicitly abstract (can't be instantiated directly)
    //   expect(colorEnum.getIsAbstract(), isTrue);
      
    //   // Enums are implicitly final
    //   expect(colorEnum.getIsFinal(), isTrue);
    // });
  });

  group('EnumDeclaration Real Enum Fields (EnumFieldDeclaration)', () {
    test('should retrieve real enum values', () {
      final simpleEnum = Runtime.findClass<SimpleEnum>();
      final enumDecl = simpleEnum as EnumDeclaration;
      
      expect(enumDecl, isNotNull);
      
      final values = enumDecl.getValues();
      expect(values.length, equals(3));
      expect(values.map((v) => v.getName()), containsAll(['first', 'second', 'third']));
    });

    test('should retrieve enum value instances', () {
      final colorEnum = Runtime.findClass<Color>();
      final enumDecl = colorEnum as EnumDeclaration;
      
      expect(enumDecl, isNotNull);
      
      final values = enumDecl.getValues();
      final redValue = values.firstWhere((v) => v.getName() == 'red');
      
      expect(redValue.getEnumValue(), equals(Color.red));
      expect(redValue.getPosition(), equals(0));
      expect(redValue.isNullable(), isFalse);
    });

    test('should handle enhanced enum values with fields', () {
      final colorEnum = Runtime.findClass<Color>();
      final enumDecl = colorEnum as EnumDeclaration;
      
      expect(enumDecl, isNotNull);
      
      final values = enumDecl.getValues();
      expect(values.length, equals(5));
      
      final blueValue = values.firstWhere((v) => v.getName() == 'blue');
      expect(blueValue.getEnumValue(), equals(Color.blue));
      expect(blueValue.getPosition(), equals(2));
    });

    test('should handle private enum values', () {
      final privateEnum = Runtime.findClass<PrivateEnum>();
      final enumDecl = privateEnum as EnumDeclaration;
      
      expect(enumDecl, isNotNull);
      
      final values = enumDecl.getValues();
      expect(values.length, equals(3));
      
      final privateValue = values.firstWhere((v) => v.getName() == '_private');
      expect(privateValue.getIsPublic(), isFalse);
      
      final publicValue = values.firstWhere((v) => v.getName() == 'public');
      expect(publicValue.getIsPublic(), isTrue);
    });
  });

  group('EnumDeclaration Regular Class Members (inherited from ClassDeclaration)', () {
    test('should retrieve enum constructors', () {
      final colorEnum = Runtime.findClass<Color>();
      
      final constructors = colorEnum.getConstructors();
      expect(constructors.length, equals(1)); // All enum values use the same constructor
      
      final constructor = constructors.first;
      expect(constructor.getIsConst(), isTrue); // Enum constructors are const
    });

    test('should retrieve enum fields (regular class fields, not enum values)', () {
      final colorEnum = Runtime.findClass<Color>();
      
      final fields = colorEnum.getFields();
      print(fields.map((f) => f.getName()));
      expect(fields.length, equals(3)); // hexCode and displayName fields with values field from enum design
      expect(fields.any((f) => f.getName() == 'hexCode'), isTrue);
      expect(fields.any((f) => f.getName() == 'displayName'), isTrue);
    });

    test('should retrieve enum methods (regular class methods)', () {
      final colorEnum = Runtime.findClass<Color>();
      
      final methods = colorEnum.getMethods();
      expect(methods.length, greaterThanOrEqualTo(4)); // rgb getter, mix, isPrimary, parse
      expect(methods.any((m) => m.getName() == 'rgb'), isTrue);
      expect(methods.any((m) => m.getName() == 'mix'), isTrue);
      expect(methods.any((m) => m.getName() == 'isPrimary'), isTrue);
      expect(methods.any((m) => m.getName() == 'parse'), isTrue);
    });

    test('should retrieve static members', () {
      final directionEnum = Runtime.findClass<Direction>();
      
      final staticFields = directionEnum.getStaticFields();
      expect(staticFields.any((f) => f.getName() == 'fromAbbreviation'), isTrue);
      
      final staticMethods = directionEnum.getStaticMethods();
      expect(staticMethods.any((m) => m.getName() == 'parse'), isTrue);
    });

    test('should handle private members in enums', () {
      final secretEnum = Runtime.findClassByType(SecretCode);
      
      final fields = secretEnum.getFields();
      final privateField = fields.firstWhere((f) => f.getName() == '_code');
      expect(privateField.getIsPublic(), isFalse);
      
      final publicField = fields.firstWhere((f) => f.getName() == 'description');
      expect(publicField.getIsPublic(), isTrue);
      
      final methods = secretEnum.getMethods();
      final privateMethod = methods.firstWhere((m) => m.getName() == '_encrypt');
      expect(privateMethod.getIsPublic(), isFalse);
      
      final publicMethod = methods.firstWhere((m) => m.getName() == 'encryptedValue');
      expect(publicMethod.getIsPublic(), isTrue);
    });
  });

  group('EnumDeclaration Inheritance and Interfaces', () {
    test('should retrieve implemented interfaces', () {
      final priorityEnum = Runtime.findClass<Priority>();
      
      final interfaces = priorityEnum.getInterfaces();
      expect(interfaces, isNotEmpty);
      expect(interfaces.any((i) => i.getName().contains('Comparable')), isTrue);
    });

    test('should handle enums without interfaces', () {
      final simpleEnum = Runtime.findClass<SimpleEnum>();
      
      final interfaces = simpleEnum.getInterfaces();
      expect(interfaces, isEmpty);
    });
  });

  group('EnumDeclaration Special Methods', () {
    test('should have values getter', () {
      final colorEnum = Runtime.findClass<Color>();
      
      final methods = colorEnum.getMethods();
      final valuesGetter = methods.firstWhere((m) => m.getName() == 'isPrimary' && m.getIsGetter());
      expect(valuesGetter, isNotNull);
    });

    test('should have name getter on enum values', () {
      final colorEnum = Runtime.findClass<Color>();
      final enumDecl = colorEnum as EnumDeclaration;
      
      expect(enumDecl, isNotNull);
      
      final values = enumDecl.getValues();
      final redValue = values.firstWhere((v) => v.getName() == 'red');
      
      // Each enum value should have access to its name
      expect(redValue.getName(), equals('red'));
    });
  });

  group('EnumDeclaration Factory Constructors', () {
    test('should handle enums with factory constructors', () {
      final fileTypeEnum = Runtime.findClass<FileType>();
      
      final constructors = fileTypeEnum.getConstructors();
      expect(constructors.length, equals(2)); // const constructor + factory constructor
      
      final factoryConstructor = constructors.firstWhere((c) => c.getIsFactory());
      expect(factoryConstructor, isNotNull);
      expect(factoryConstructor.getName(), equals('fromFilename'));
    });
  });

  group('EnumDeclaration Usage Examples', () {
    test('should demonstrate enum value access', () {
      final colorEnum = Runtime.findClass<Color>();
      final enumDecl = colorEnum as EnumDeclaration;
      
      expect(enumDecl, isNotNull);
      
      final values = enumDecl.getValues();
      final redValue = values.firstWhere((v) => v.getName() == 'red');
      
      expect(redValue.getEnumValue(), equals(Color.red));
      expect((redValue.getEnumValue() as Color).hexCode, equals(0xFF0000));
      expect((redValue.getEnumValue() as Color).displayName, equals('Red'));
    });

    test('should demonstrate enum method invocation', () {
      final colorEnum = Runtime.findClassByType(Color);
      
      final red = Color.red;
      final blue = Color.blue;
      final mixed = colorEnum.getMethods().firstWhere((m) => m.getName() == "mix").invoke(red, {"other": blue});
      
      expect(red.isPrimary, isTrue);
      expect(red.rgb, equals('rgb(255, 0, 0)'));
      expect(mixed, anyOf(equals(Color.purple), equals(Color.red)));
    });

    test('should demonstrate enum in pattern matching', () {
      final priority = Priority.high;
      final description = describePriority(priority);
      expect(description, equals('High priority'));
      
      expect(priority.isHighPriority, isTrue);
      expect(Priority.low.isHighPriority, isFalse);
    });

    test('should demonstrate static enum methods', () {
      expect(Direction.parse('north'), equals(Direction.north));
      expect(Direction.north.opposite, equals(Direction.south));
      expect(FileType.fromFilename('document.txt'), equals(FileType.text));
    });
  });

  group('EnumDeclaration Edge Cases', () {
    test('should handle enums with nullable fields', () {
      expect(Config.enabled.value, isTrue);
      expect(Config.disabled.value, isFalse);
      expect(Config.unknown.value, isNull);
      expect(Config.enabled.isDefined, isTrue);
      expect(Config.unknown.isDefined, isFalse);
      expect(Config.enabled.statusText, equals('Enabled'));
    });

    test('should handle enums with only private values', () {
      final privateEnum = Runtime.findClass<PrivateEnum>();
      final enumDecl = privateEnum as EnumDeclaration;
      
      expect(enumDecl, isNotNull);
      
      final values = enumDecl.getValues();
      expect(values.length, equals(3));
      
      // Even private enum values should be accessible through reflection
      final privateValue = values.firstWhere((v) => v.getName() == '_private');
      expect(privateValue.getEnumValue(), equals(PrivateEnum._private));
    });

    test('should distinguish between enum values and class fields', () {
      final colorEnum = Runtime.obtainClassDeclaration(Color);
      final enumDecl = colorEnum as EnumDeclaration;
      
      expect(enumDecl, isNotNull);
      
      // EnumFieldDeclaration for enum values
      final enumValues = enumDecl.getValues();
      expect(enumValues.length, equals(5));
      expect(enumValues.any((v) => v.getName() == 'red'), isTrue);
      
      // FieldDeclaration for class fields
      final classFields = colorEnum.getFields();
      expect(classFields.length, equals(3));
      expect(classFields.any((f) => f.getName() == 'hexCode'), isTrue);
      expect(classFields.any((f) => f.getName() == 'displayName'), isTrue);
      
      // These should be different types
      final redValue = enumValues.firstWhere((v) => v.getName() == 'red');
      final hexCodeField = classFields.firstWhere((f) => f.getName() == 'hexCode');
      
      expect(redValue, isA<EnumFieldDeclaration>());
      expect(hexCodeField, isA<FieldDeclaration>());
      expect(redValue.runtimeType, isNot(equals(hexCodeField.runtimeType)));
    });
  });
}