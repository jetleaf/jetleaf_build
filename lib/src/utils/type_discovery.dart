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

import 'constant.dart';
import '../declaration/declaration.dart';
import 'generic_type_parser.dart';
import '../runtime/provider/meta_runtime_provider.dart';

/// {@template type_discovery}
/// A powerful type discovery system that can find any declaration using various search criteria.
/// 
/// Supports searching by:
/// - Runtime Type
/// - Analyzer Element
/// - String name (simple or qualified)
/// - Generic type patterns
/// 
/// Returns specific declaration types (ClassDeclaration, EnumDeclaration, etc.) while
/// maintaining type safety through internal casting and the public TypeDeclaration interface.
/// 
/// ## Features
/// - Comprehensive caching for performance
/// - Multiple search strategies with fallbacks
/// - Subclass/inheritance discovery
/// - Generic type resolution
/// - Thread-safe operations
/// 
/// ## Example Usage
/// ```dart
/// // Find by runtime type
/// final classDecl = TypeDiscovery.findByType(MyClass);
/// 
/// // Find by name
/// final enumDecl = TypeDiscovery.findByName('Status');
/// 
/// // Find subclasses
/// final subclasses = TypeDiscovery.findSubclassesOf(BaseClass);
/// 
/// // Find by analyzer element
/// final mixinDecl = TypeDiscovery.findByElement(mixinElement);
/// ```
/// {@endtemplate}
class TypeDiscovery {
  /// Keywords we want to interchange for their types.
  static final List<String> _caveats = ['_Map', '_Set'];

  /// Cache for type-based lookups
  static final Map<Type, ClassDeclaration?> _typeCache = {};
  
  /// Cache for name-based lookups
  static final Map<String, ClassDeclaration?> _nameCache = {};

  /// Cache for simple name-based lookups
  static final Map<String, ClassDeclaration?> _simpleNameCache = {};

  /// Cache for qualified name-based lookups
  static final Map<String, ClassDeclaration?> _qualifiedNameCache = {};

  /// Private constructor - this is a static utility class
  /// 
  /// {@macro type_discovery}
  TypeDiscovery._();

  /// Clears all internal caches. Useful for testing or when the type system changes.
  static void clearCaches() {
    _typeCache.clear();
    _nameCache.clear();
    _simpleNameCache.clear();
    _qualifiedNameCache.clear();
  }

  // ================================== GENERIC HELPER METHODS =========================================
  /// Parse generic types from a GenericTypeParsingResult and convert to TypeDeclarations
  static List<ClassDeclaration> _parseGenericTypes(GenericTypeParsingResult result) {
    final types = <ClassDeclaration>[];
    
    for (final genericType in result.types) {
      final typeDecl = _convertGenericResultToTypeDeclaration(genericType);
      if (typeDecl != null) {
        types.add(typeDecl);
      }
    }
    
    return types;
  }

  /// Convert a GenericTypeParsingResult to a ClassDeclaration
  static ClassDeclaration? _convertGenericResultToTypeDeclaration(GenericTypeParsingResult result) {
    if (result.types.isEmpty) {
      // Non-generic type, find by name
      return findClassByName(result.base);
    } else {
      // Generic type, recursively resolve
      return findGeneric(result.typeString);
    }
  }

  /// Enhanced resolution for generic types at runtime
  static ClassDeclaration? findGeneric(String typeString, [String? package]) {
   final parseResult = GenericTypeParser.resolveGenericType(typeString);

    // Handle caveats for base name
    String baseName = parseResult.base;
    if(_caveats.any((c) => c == baseName)) {
      baseName = baseName.replaceAll("_", "");
    }

    final baseDeclaration = findClassByName(baseName, package);
    
    if (baseDeclaration != null) {
      // Convert GenericParsingResult types to TypeDeclarations
      final genericTypes = _parseGenericTypes(parseResult);
      
      if (genericTypes.isNotEmpty) {
        // Create enhanced declaration with generic information
        return _createGenericClassDeclaration(baseDeclaration, genericTypes, typeString);
      }
      
      return baseDeclaration;
    }
    
    return null;
  }

  /// Enhanced resolution for generic class at runtime
  static ClassDeclaration? findGenericClass(String typeString, [String? package]) {
   final parseResult = GenericTypeParser.resolveGenericType(typeString);

    // Handle caveats for base name
    String baseName = parseResult.base;
    if(_caveats.any((c) => c == baseName)) {
      baseName = baseName.replaceAll("_", "");
    }

    final baseDeclaration = findClassByName(baseName, package);
    
    if (baseDeclaration != null) {
      // Convert GenericParsingResult types to TypeDeclarations
      final genericTypes = _parseGenericTypes(parseResult);
      
      if (genericTypes.isNotEmpty) {
        // Create enhanced declaration with generic information
        return _createGenericClassDeclaration(baseDeclaration, genericTypes, typeString);
      }
      
      return baseDeclaration;
    }
    
    return null;
  }

  /// Create a generic class declaration with preserved type parameter information
  static ClassDeclaration _createGenericClassDeclaration(ClassDeclaration baseDeclaration, List<TypeDeclaration> types, String fullTypeName) {
    final genericLinks = types.map((type) => 
      StandardLinkDeclaration(
        name: type.getName(),
        type: type.getType(),
        pointerType: type.getType(),
        qualifiedName: type.getQualifiedName(),
        canonicalUri: Uri.parse(type.getPackageUri()),
        referenceUri: Uri.parse(type.getPackageUri()),
        typeArguments: type.getTypeArguments(),
        isPublic: type.getIsPublic(),
        isSynthetic: type.getIsSynthetic(),
      )
    ).toList();

    if(baseDeclaration is MixinDeclaration) {
      return StandardMixinDeclaration(
        name: fullTypeName,
        parentLibrary: baseDeclaration.getParentLibrary(),
        isNullable: baseDeclaration.getIsNullable(),
        type: baseDeclaration.getType(), // Keep base type for compatibility
        qualifiedName: baseDeclaration.getQualifiedName(),
        typeArguments: genericLinks,
        superClass: baseDeclaration.getSuperClass(),
        interfaces: baseDeclaration.getInterfaces(),
        methods: baseDeclaration.getMethods(),
        fields: baseDeclaration.getFields(),
        constraints: baseDeclaration.getConstraints(),
        annotations: baseDeclaration.getAnnotations(),
        sourceLocation: baseDeclaration.getSourceLocation(),
        isPublic: baseDeclaration.getIsPublic(),
        isSynthetic: baseDeclaration.getIsSynthetic(),
      );
    } else if(baseDeclaration is EnumDeclaration) {
      return StandardEnumDeclaration(
        values: baseDeclaration.getValues(),
        name: fullTypeName,
        parentLibrary: baseDeclaration.getParentLibrary(),
        isNullable: baseDeclaration.getIsNullable(),
        type: baseDeclaration.getType(), // Keep base type for compatibility
        qualifiedName: baseDeclaration.getQualifiedName(),
        typeArguments: genericLinks,
        isAbstract: baseDeclaration.getIsAbstract(),
        isBase: baseDeclaration.getIsBase(),
        isFinal: baseDeclaration.getIsFinal(),
        isInterface: baseDeclaration.getIsInterface(),
        isMixin: baseDeclaration.getIsMixin(),
        isRecord: baseDeclaration.getIsRecord(),
        superClass: baseDeclaration.getSuperClass(),
        interfaces: baseDeclaration.getInterfaces(),
        mixins: baseDeclaration.getMixins(),
        constructors: baseDeclaration.getConstructors(),
        methods: baseDeclaration.getMethods(),
        fields: baseDeclaration.getFields(),
        annotations: baseDeclaration.getAnnotations(),
        sourceLocation: baseDeclaration.getSourceLocation(),
        isPublic: baseDeclaration.getIsPublic(),
        isSynthetic: baseDeclaration.getIsSynthetic(),
      );
    }

    return StandardClassDeclaration(
      name: fullTypeName,
      parentLibrary: baseDeclaration.getParentLibrary(),
      isNullable: baseDeclaration.getIsNullable(),
      type: baseDeclaration.getType(), // Keep base type for compatibility
      qualifiedName: baseDeclaration.getQualifiedName(),
      typeArguments: genericLinks,
      isAbstract: baseDeclaration.getIsAbstract(),
      isBase: baseDeclaration.getIsBase(),
      isFinal: baseDeclaration.getIsFinal(),
      isInterface: baseDeclaration.getIsInterface(),
      isMixin: baseDeclaration.getIsMixin(),
      isRecord: baseDeclaration.getIsRecord(),
      superClass: baseDeclaration.getSuperClass(),
      interfaces: baseDeclaration.getInterfaces(),
      mixins: baseDeclaration.getMixins(),
      constructors: baseDeclaration.getConstructors(),
      methods: baseDeclaration.getMethods(),
      fields: baseDeclaration.getFields(),
      annotations: baseDeclaration.getAnnotations(),
      sourceLocation: baseDeclaration.getSourceLocation(),
      isPublic: baseDeclaration.getIsPublic(),
      isSynthetic: baseDeclaration.getIsSynthetic(),
    );
  }

  /// {@template is_same_package}
  /// Checks if the given package URI belongs to the specified package.
  /// 
  /// This method handles both absolute and relative package URIs.
  /// 
  /// ## Example
  /// ```dart
  /// final isSame = TypeDiscovery.isSamePackage('myapp', 'package:myapp/models.dart.MyClass');
  /// ```
  /// {@endtemplate}
  static bool isSamePackage(String package, String packageUri) {
    // 1. Dart core libraries
    if (package == PackageNames.DART) {
      return packageUri.startsWith("dart:");
    }

    // 2. Special case: caller passed something like "dart:collection"
    if (package.startsWith("dart")) {
      return packageUri == package || packageUri.startsWith("dart:") || packageUri.startsWith(package);
    }

    // 3. Exact package match
    if (packageUri == package) {
      return true;
    }

    // 4. Belongs to: "package:foo/...something..."
    if (packageUri.startsWith("package:$package/")) {
      return true;
    }

    // 5. Fallback: plain startsWith (handles non-standard identifiers)
    if (packageUri.startsWith(package)) {
      return true;
    }

    return false;
  }

  // =========================================== TYPE SEARCH METHOD =============================================

  /// This is the primary entry point for class-based discovery.
  /// Uses multiple search strategies with comprehensive caching.
  /// 
  /// Returns the most specific ClassDeclaration available, or null if not found.
  /// 
  /// ## Search Strategy
  /// 1. Check cache first
  /// 2. Search in special/primitive types
  /// 3. Search in classes
  /// 4. Search in enums  
  /// 5. Search in mixins
  /// 
  /// ## Example
  /// ```dart
  /// final classDecl = TypeDiscovery.findClassByType(MyClass);
  /// final enumDecl = TypeDiscovery.findClassByType(Status);
  /// final listDecl = TypeDiscovery.findClassByType(List<String>);
  /// ```
  static ClassDeclaration? findClassByType(Type type, [String? package]) {
    // Check cache first
    final cached = _typeCache[type];
    if (cached case ClassDeclaration cached) return cached;
    
    ClassDeclaration? result;

    // Method 0: Enhanced generic type resolution for runtime instances
    if(GenericTypeParser.isGeneric(type.toString())) {
      result ??= findGenericClass(type.toString(), package);
    }

    // Method 1: Search in enums
    result ??= _searchInEnums(type, package) ?? _searchInEnums(type);

    // Method 2: Search in mixins
    result ??= _searchInMixins(type, package) ?? _searchInMixins(type);

    // Method 3: Search in classes
    result ??= _searchInClasses(type, package) ?? _searchInClasses(type);

    // Cache the result (even if null)
    _typeCache[type] = result;
    
    return result;
  }

  /// Search for type in class declarations
  static ClassDeclaration? _searchInClasses(Type type, [String? package]) {
    return Runtime.getAllClasses().where((d) {
      if(package != null) {
        return (isSamePackage(package, d.getPackageUri()) || isSamePackage(package, d.getQualifiedName()))
          && GenericTypeParser.shouldCheckGeneric(d.getType()) 
            ? d.getName().toString() == type.toString() 
            : d.getType() == type;
      }

      return GenericTypeParser.shouldCheckGeneric(d.getType()) ? d.getName().toString() == type.toString() : d.getType() == type;
    }).firstOrNull;
  }

  /// Search for type in enum declarations
  static EnumDeclaration? _searchInEnums(Type type, [String? package]) {
    return Runtime.getAllEnums().where((d) {
      if(package != null) {
        return (isSamePackage(package, d.getPackageUri()) || isSamePackage(package, d.getQualifiedName()))
          && GenericTypeParser.shouldCheckGeneric(d.getType()) 
            ? d.getName().toString() == type.toString() 
            : d.getType() == type;
      }

      return GenericTypeParser.shouldCheckGeneric(d.getType()) ? d.getName().toString() == type.toString() : d.getType() == type;
    }).firstOrNull;
  }

  /// Search for type in mixin declarations
  static MixinDeclaration? _searchInMixins(Type type, [String? package]) {
    return Runtime.getAllMixins().where((d) {
      if(package != null) {
        return (isSamePackage(package, d.getPackageUri()) || isSamePackage(package, d.getQualifiedName()))
          && GenericTypeParser.shouldCheckGeneric(d.getType()) 
            ? d.getName().toString() == type.toString() 
            : d.getType() == type;
      }

      return GenericTypeParser.shouldCheckGeneric(d.getType()) ? d.getName().toString() == type.toString() : d.getType() == type;
    }).firstOrNull;
  }

  /// Search for type in typedef declarations
  // static TypedefDeclaration? _searchInTypedefs(Type type, [String? package]) {
  //   return Runtime.getAllTypedefs().where((d) {
  //     if(package != null) {
  //       return (isSamePackage(package, d.getPackageUri()) || isSamePackage(package, d.getQualifiedName()))
  //         && GenericTypeParser.shouldCheckGeneric(d.getType()) 
  //           ? d.getName().toString() == type.toString() 
  //           : d.getType() == type;
  //     }

  //     return GenericTypeParser.shouldCheckGeneric(d.getType()) ? d.getName().toString() == type.toString() : d.getType() == type;
  //   }).firstOrNull;
  // }

  // ========================================= TYPE TO STRING SEARCH METHODS =======================================

  /// Finds a class declaration by its name (simple or qualified).
  /// 
  /// Supports both simple names ("MyClass") and qualified names 
  /// ("package:myapp/models.dart.MyClass").
  /// 
  /// ## Example
  /// ```dart
  /// final decl1 = TypeDiscovery.findClassByName('MyClass');
  /// final decl2 = TypeDiscovery.findClassByName('package:myapp/models.dart.MyClass');
  /// ```
  static ClassDeclaration? findClassByName(String name, [String? package]) {
    // Check cache first
    final cached = _nameCache[name];
    if (cached case ClassDeclaration cached) return cached;
    
    ClassDeclaration? result;

    // Method 0: Enhanced generic type resolution for runtime instances
    if(GenericTypeParser.isGeneric(name)) {
      result ??= findGenericClass(name);
    }

    // Method 1: Search in enums
    result ??= _findEnumDeclarationByString(name, package) ?? _findEnumDeclarationByString(name);

    // Method 2: Search in mixins
    result ??= _findMixinDeclarationByString(name, package) ?? _findMixinDeclarationByString(name);

    // Method 3: Search in classes
    result ??= _findClassDeclarationByString(name, package) ?? _findClassDeclarationByString(name);

    // Cache the result
    _nameCache[name] = result;
    
    return result;
  }

  /// Find class declaration by string name (simple or qualified)
  static ClassDeclaration? _findClassDeclarationByString(String name, [String? package]) {
    return Runtime.getAllClasses().where((d) {
      if(package != null) {
        return (isSamePackage(package, d.getPackageUri()) || isSamePackage(package, d.getQualifiedName()))
          && d.getName().toString() == name;
      }

      return d.getName().toString() == name;
    }).firstOrNull;
  }

  /// Find enum declaration by string name (simple or qualified)
  static EnumDeclaration? _findEnumDeclarationByString(String name, [String? package]) {
    return Runtime.getAllEnums().where((d) {
      if(package != null) {
        return (isSamePackage(package, d.getPackageUri()) || isSamePackage(package, d.getQualifiedName()))
          && d.getName().toString() == name;
      }

      return d.getName().toString() == name;
    }).firstOrNull;
  }

  /// Find mixin declaration by string name (simple or qualified)
  static MixinDeclaration? _findMixinDeclarationByString(String name, [String? package]) {
    return Runtime.getAllMixins().where((d) {
      if(package != null) {
        return (isSamePackage(package, d.getPackageUri()) || isSamePackage(package, d.getQualifiedName()))
          && d.getName().toString() == name;
      }

      return d.getName().toString() == name;
    }).firstOrNull;
  }

  // /// Find typedef declaration by string name (simple or qualified)
  // static TypedefDeclaration? _findTypedefDeclarationByString(String name, [String? package]) {
  //   return Runtime.getAllTypedefs().where((d) {
  //     if(package != null) {
  //       return (isSamePackage(package, d.getPackageUri()) || isSamePackage(package, d.getQualifiedName()))
  //         && d.getName().toString() == name;
  //     }

  //     return d.getName().toString() == name;
  //   }).firstOrNull;
  // }

  // /// Search by type string representation
  // static TypeDeclaration? _searchByTypeString(String typeString, [String? package]) {
  //   return Runtime.getAllTypes().where((d) {
  //     if(package != null) {
  //       return (isSamePackage(package, d.getPackageUri()) || isSamePackage(package, d.getQualifiedName()))
  //         && d.getName().toString() == typeString;
  //     }

  //     return d.getName().toString() == typeString;
  //   }).firstOrNull;
  // }

  // =========================================== QUALIFIED NAME SEARCH ========================================

  /// Finds a class declaration by its qualified name.
  /// 
  /// Supports only qualified names 
  /// ("package:myapp/models.dart.MyClass").
  /// 
  /// ## Example
  /// ```dart
  /// final decl1 = TypeDiscovery.findClassByQualifiedName('MyClass');
  /// final decl2 = TypeDiscovery.findClassByQualifiedName('package:myapp/models.dart.MyClass');
  /// ```
  static ClassDeclaration? findClassByQualifiedName(String name) {
    // Check cache first
    final cached = _qualifiedNameCache[name];
    if (cached case ClassDeclaration cached) return cached;
    
    ClassDeclaration? result;

    // Method 0: Enhanced generic class resolution for runtime instances
    if(GenericTypeParser.isGeneric(name)) {
      result ??= findGenericClass(name);
    }

    // Method 1: Search in enums
    result ??= _findEnumDeclarationByQualifiedName(name);

    // Method 2: Search in mixins
    result ??= _findMixinDeclarationByQualifiedName(name);

    // Method 3: Search in classes
    result ??= _findClassDeclarationByQualifiedName(name);

    // Cache the result
    _qualifiedNameCache[name] = result;
    
    return result;
  }

  /// Find class declaration by string name (simple or qualified)
  static ClassDeclaration? _findClassDeclarationByQualifiedName(String name) {
    return Runtime.getAllClasses().where((c) => c.getQualifiedName() == name).firstOrNull;
  }

  /// Find enum declaration by string name (simple or qualified)
  static EnumDeclaration? _findEnumDeclarationByQualifiedName(String name) {
    return Runtime.getAllEnums().where((e) => e.getQualifiedName() == name).firstOrNull;
  }

  /// Find mixin declaration by string name (simple or qualified)
  static MixinDeclaration? _findMixinDeclarationByQualifiedName(String name) {
    return Runtime.getAllMixins().where((m) => m.getQualifiedName() == name).firstOrNull;
  }

  // /// Find typedef declaration by string name (simple or qualified)
  // static TypedefDeclaration? _findTypedefDeclarationByQualifiedName(String name) {
  //   return Runtime.getAllTypedefs().where((t) => t.getQualifiedName() == name).firstOrNull;
  // }

  // /// Search by simple name across all declaration types
  // static TypeDeclaration? _searchByQualifiedName(String name) {
  //   return Runtime.getAllTypes().where((d) => d.getQualifiedName() == name).firstOrNull;
  // }

  // =========================================== SIMPLE NAME SEARCH ========================================

  /// Finds a class declaration by its name (simple or qualified).
  /// 
  /// Supports only simple names ("MyClass").
  /// 
  /// ## Example
  /// ```dart
  /// final decl1 = TypeDiscovery.findByName('MyClass');
  /// ```
  static ClassDeclaration? findClassBySimpleName(String name) {
    // Check cache first
    final cached = _simpleNameCache[name];
    if (cached case ClassDeclaration cached) return cached;
    
    ClassDeclaration? result;

    // Method 0: Enhanced generic class resolution for runtime instances
    if(GenericTypeParser.isGeneric(name)) {
      result ??= findGenericClass(name);
    }

    // Method 1: Search in enums
    result ??= _findEnumDeclarationBySimpleString(name);

    // Method 2: Search in mixins
    result ??= _findMixinDeclarationBySimpleString(name);

    // Method 3: Search in classes
    result ??= _findClassDeclarationBySimpleString(name);

    // Cache the result
    _simpleNameCache[name] = result;
    
    return result;
  }

  /// Find class declaration by string name (simple or qualified)
  static ClassDeclaration? _findClassDeclarationBySimpleString(String name) {
    return Runtime.getAllClasses().where((c) => c.getSimpleName() == name).firstOrNull;
  }

  /// Find enum declaration by string name (simple or qualified)
  static EnumDeclaration? _findEnumDeclarationBySimpleString(String name) {
    return Runtime.getAllEnums().where((e) => e.getSimpleName() == name).firstOrNull;
  }

  /// Find mixin declaration by string name (simple or qualified)
  static MixinDeclaration? _findMixinDeclarationBySimpleString(String name) {
    return Runtime.getAllMixins().where((m) => m.getSimpleName() == name).firstOrNull;
  }

  // /// Find typedef declaration by string name (simple or qualified)
  // static TypedefDeclaration? _findTypedefDeclarationBySimpleString(String name) {
  //   return Runtime.getAllTypedefs().where((t) => t.getSimpleName() == name).firstOrNull;
  // }

  // /// Search by type string representation
  // static TypeDeclaration? _searchBySimpleName(String name) {
  //   return Runtime.getAllTypes().where((d) => d.getSimpleName() == name).firstOrNull;
  // }
}