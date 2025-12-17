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

import 'package:analyzer/dart/element/element.dart';

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
  static final Map<Type, TypeDeclaration?> _typeCache = {};
  
  /// Cache for name-based lookups
  static final Map<String, TypeDeclaration?> _nameCache = {};

  /// Cache for simple name-based lookups
  static final Map<String, TypeDeclaration?> _simpleNameCache = {};

  /// Cache for qualified name-based lookups
  static final Map<String, TypeDeclaration?> _qualifiedNameCache = {};
  
  /// Cache for element-based lookups
  static final Map<Element, TypeDeclaration?> _elementCache = {};
  
  /// Cache for subclass relationships
  static final Map<Type, List<ClassDeclaration>> _subclassCache = {};
  
  /// Cache for implementer relationships
  static final Map<Type, List<TypeDeclaration>> _implementerCache = {};

  /// Private constructor - this is a static utility class
  /// 
  /// {@macro type_discovery}
  TypeDiscovery._();

  /// Clears all internal caches. Useful for testing or when the type system changes.
  static void clearCaches() {
    _typeCache.clear();
    _nameCache.clear();
    _elementCache.clear();
    _subclassCache.clear();
    _implementerCache.clear();
  }

  // ================================== GENERIC HELPER METHODS =========================================
  /// Parse generic types from a GenericTypeParsingResult and convert to TypeDeclarations
  static List<TypeDeclaration> _parseGenericTypes(GenericTypeParsingResult result) {
    final types = <TypeDeclaration>[];
    
    for (final genericType in result.types) {
      final typeDecl = _convertGenericResultToTypeDeclaration(genericType);
      if (typeDecl != null) {
        types.add(typeDecl);
      }
    }
    
    return types;
  }

  /// Convert a GenericTypeParsingResult to a TypeDeclaration
  static TypeDeclaration? _convertGenericResultToTypeDeclaration(GenericTypeParsingResult result) {
    if (result.types.isEmpty) {
      // Non-generic type, find by name
      return findByName(result.base);
    } else {
      // Generic type, recursively resolve
      return findGeneric(result.typeString);
    }
  }

  /// Enhanced resolution for generic types at runtime
  static TypeDeclaration? findGeneric(String typeString, [String? package]) {
   final parseResult = GenericTypeParser.resolveGenericType(typeString);

    // Handle caveats for base name
    String baseName = parseResult.base;
    if(_caveats.any((c) => c == baseName)) {
      baseName = baseName.replaceAll("_", "");
    }

    final baseDeclaration = findByName(baseName, package);
    
    if (baseDeclaration != null) {
      // Convert GenericParsingResult types to TypeDeclarations
      final genericTypes = _parseGenericTypes(parseResult);
      
      if (genericTypes.isNotEmpty) {
        // Create enhanced declaration with generic information
        return _createGenericTypeDeclaration(baseDeclaration, genericTypes, typeString);
      }
      
      return baseDeclaration;
    }
    
    return null;
  }

  /// Create a generic type declaration with preserved type parameter information
  static TypeDeclaration _createGenericTypeDeclaration(TypeDeclaration baseDeclaration, List<TypeDeclaration> types, String fullTypeName) {
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
        dartType: type.getDartType(),
        isSynthetic: type.getIsSynthetic(),
      )
    ).toList();

    if(baseDeclaration is MixinDeclaration) {
      return _createGenericClassDeclaration(baseDeclaration, types, fullTypeName);
    } else if(baseDeclaration is EnumDeclaration) {
      return _createGenericClassDeclaration(baseDeclaration, types, fullTypeName);
    } else if(baseDeclaration is ClassDeclaration) {
      return _createGenericClassDeclaration(baseDeclaration, types, fullTypeName);
    } else if(baseDeclaration is TypedefDeclaration) {
      return StandardTypedefDeclaration(
        name: fullTypeName,
        parentLibrary: baseDeclaration.getParentLibrary(),
        isNullable: baseDeclaration.getIsNullable(),
        element: baseDeclaration.getElement(),
        dartType: baseDeclaration.getDartType(),
        type: baseDeclaration.getType(), // Keep base type for compatibility
        qualifiedName: baseDeclaration.getQualifiedName(),
        typeArguments: genericLinks,
        aliasedType: baseDeclaration.getAliasedType(),
        annotations: baseDeclaration.getAnnotations(),
        sourceLocation: baseDeclaration.getSourceLocation(),
        isPublic: baseDeclaration.getIsPublic(),
        isSynthetic: baseDeclaration.getIsSynthetic(),
        referent: baseDeclaration.getReferent()
      );
    }

    return StandardTypeDeclaration(
      name: fullTypeName,
      isNullable: baseDeclaration.getIsNullable(),
      kind: baseDeclaration.getKind(),
      element: baseDeclaration.getElement(),
      dartType: baseDeclaration.getDartType(),
      type: baseDeclaration.getType(), // Keep base type for compatibility
      qualifiedName: fullTypeName,
      simpleName: baseDeclaration.getSimpleName(),
      packageUri: baseDeclaration.getPackageUri(),
      typeArguments: genericLinks,
      superClass: baseDeclaration.getSuperClass(),
      interfaces: baseDeclaration.getInterfaces(),
      mixins: baseDeclaration.getMixins(),
      isPublic: baseDeclaration.getIsPublic(),
      isSynthetic: baseDeclaration.getIsSynthetic(),
    );
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
        dartType: type.getDartType()
      )
    ).toList();

    if(baseDeclaration is MixinDeclaration) {
      return StandardMixinDeclaration(
        name: fullTypeName,
        parentLibrary: baseDeclaration.getParentLibrary(),
        isNullable: baseDeclaration.getIsNullable(),
        element: baseDeclaration.getElement(),
        dartType: baseDeclaration.getDartType(),
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
        element: baseDeclaration.getElement(),
        dartType: baseDeclaration.getDartType(),
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
      element: baseDeclaration.getElement(),
      dartType: baseDeclaration.getDartType(),
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

  /// {@template find_by_type}
  /// Finds a type declaration by its runtime Type.
  /// 
  /// This is the primary entry point for type-based discovery.
  /// Uses multiple search strategies with comprehensive caching.
  /// 
  /// Returns the most specific TypeDeclaration available, or null if not found.
  /// 
  /// ## Search Strategy
  /// 1. Check cache first
  /// 2. Search in special/primitive types
  /// 3. Search in classes
  /// 4. Search in enums  
  /// 5. Search in mixins
  /// 6. Search in typedefs
  /// 7. Search in records
  /// 8. Resolve from string representation
  /// 
  /// ## Example
  /// ```dart
  /// final classDecl = TypeDiscovery.findByType(MyClass);
  /// final enumDecl = TypeDiscovery.findByType(Status);
  /// final listDecl = TypeDiscovery.findByType(List<String>);
  /// ```
  /// {@endtemplate}
  static TypeDeclaration? findByType(Type type, [String? package]) {
    // Check cache first
    final cached = _typeCache[type];
    if (cached != null) return cached;
    
    TypeDeclaration? result;

    // Method 0: Enhanced generic type resolution for runtime instances
    if(GenericTypeParser.isGeneric(type.toString())) {
      result ??= findGeneric(type.toString(), package);
    }

    // Method 1: Search in classes
    result ??= _searchInClasses(type, package);

    // Method 2: Search in enums
    result ??= _searchInEnums(type, package);

    // Method 3: Search in mixins
    result ??= _searchInMixins(type, package);

    // Method 4: Search in typedefs
    result ??= _searchInTypedefs(type, package);

    // Cache the result (even if null)
    _typeCache[type] = result;
    
    return result;
  }

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
  static TypedefDeclaration? _searchInTypedefs(Type type, [String? package]) {
    return Runtime.getAllTypedefs().where((d) {
      if(package != null) {
        return (isSamePackage(package, d.getPackageUri()) || isSamePackage(package, d.getQualifiedName()))
          && GenericTypeParser.shouldCheckGeneric(d.getType()) 
            ? d.getName().toString() == type.toString() 
            : d.getType() == type;
      }

      return GenericTypeParser.shouldCheckGeneric(d.getType()) ? d.getName().toString() == type.toString() : d.getType() == type;
    }).firstOrNull;
  }

  // ========================================= TYPE TO STRING SEARCH METHODS =======================================

  /// {@template find_by_name}
  /// Finds a type declaration by its name (simple or qualified).
  /// 
  /// Supports both simple names ("MyClass") and qualified names 
  /// ("package:myapp/models.dart.MyClass").
  /// 
  /// ## Example
  /// ```dart
  /// final decl1 = TypeDiscovery.findByName('MyClass');
  /// final decl2 = TypeDiscovery.findByName('package:myapp/models.dart.MyClass');
  /// ```
  /// {@endtemplate}
  static TypeDeclaration? findByName(String name, [String? package]) {
    // Check cache first
    final cached = _nameCache[name];
    if (cached != null) return cached;
    
    TypeDeclaration? result;

    // Method 0: Enhanced generic type resolution for runtime instances
    if(GenericTypeParser.isGeneric(name)) {
      result ??= findGeneric(name);
    }

    // Method 1: Search in classes
    result ??= _findClassDeclarationByString(name, package);

    // Method 2: Search in enums
    result ??= _findEnumDeclarationByString(name, package);

    // Method 3: Search in mixins
    result ??= _findMixinDeclarationByString(name, package);

    // Method 4: Search in typedefs
    result ??= _findTypedefDeclarationByString(name, package);

    // Search by type string representation
    result ??= _searchByTypeString(name, package);

    // Cache the result
    _nameCache[name] = result;
    
    return result;
  }

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

  /// Find typedef declaration by string name (simple or qualified)
  static TypedefDeclaration? _findTypedefDeclarationByString(String name, [String? package]) {
    return Runtime.getAllTypedefs().where((d) {
      if(package != null) {
        return (isSamePackage(package, d.getPackageUri()) || isSamePackage(package, d.getQualifiedName()))
          && d.getName().toString() == name;
      }

      return d.getName().toString() == name;
    }).firstOrNull;
  }

  /// Search by type string representation
  static TypeDeclaration? _searchByTypeString(String typeString, [String? package]) {
    return Runtime.getAllTypes().where((d) {
      if(package != null) {
        return (isSamePackage(package, d.getPackageUri()) || isSamePackage(package, d.getQualifiedName()))
          && d.getName().toString() == typeString;
      }

      return d.getName().toString() == typeString;
    }).firstOrNull;
  }

  // =========================================== QUALIFIED NAME SEARCH ========================================

  /// {@template find_by_name}
  /// Finds a type declaration by its qualified name.
  /// 
  /// Supports only qualified names 
  /// ("package:myapp/models.dart.MyClass").
  /// 
  /// ## Example
  /// ```dart
  /// final decl1 = TypeDiscovery.findByQualifiedName('MyClass');
  /// final decl2 = TypeDiscovery.findByQualifiedName('package:myapp/models.dart.MyClass');
  /// ```
  /// {@endtemplate}
  static TypeDeclaration? findByQualifiedName(String name) {
    // Check cache first
    final cached = _qualifiedNameCache[name];
    if (cached != null) return cached;
    
    TypeDeclaration? result;

    // Method 0: Enhanced generic type resolution for runtime instances
    if(GenericTypeParser.isGeneric(name)) {
      result ??= findGeneric(name);
    }

    // Method 1: Search in classes
    result ??= _findClassDeclarationByQualifiedName(name);

    // Method 2: Search in enums
    result ??= _findEnumDeclarationByQualifiedName(name);

    // Method 3: Search in mixins
    result ??= _findMixinDeclarationByQualifiedName(name);

    // Method 4: Search in typedefs
    result ??= _findTypedefDeclarationByQualifiedName(name);
    
    // Search by qualified name
    result ??= _searchByQualifiedName(name);

    // Cache the result
    _qualifiedNameCache[name] = result;
    
    return result;
  }

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

  /// Find typedef declaration by string name (simple or qualified)
  static TypedefDeclaration? _findTypedefDeclarationByQualifiedName(String name) {
    return Runtime.getAllTypedefs().where((t) => t.getQualifiedName() == name).firstOrNull;
  }

  /// Search by simple name across all declaration types
  static TypeDeclaration? _searchByQualifiedName(String name) {
    return Runtime.getAllTypes().where((d) => d.getQualifiedName() == name).firstOrNull;
  }

  // =========================================== SIMPLE NAME SEARCH ========================================

  /// {@template find_by_name}
  /// Finds a type declaration by its name (simple or qualified).
  /// 
  /// Supports only simple names ("MyClass").
  /// 
  /// ## Example
  /// ```dart
  /// final decl1 = TypeDiscovery.findBySimpleName('MyClass');
  /// ```
  /// {@endtemplate}
  static TypeDeclaration? findBySimpleName(String name) {
    // Check cache first
    final cached = _simpleNameCache[name];
    if (cached != null) return cached;
    
    TypeDeclaration? result;

    // Method 0: Enhanced generic type resolution for runtime instances
    if(GenericTypeParser.isGeneric(name)) {
      result ??= findGeneric(name);
    }

    // Method 1: Search in classes
    result ??= _findClassDeclarationBySimpleString(name);

    // Method 2: Search in enums
    result ??= _findEnumDeclarationBySimpleString(name);

    // Method 3: Search in mixins
    result ??= _findMixinDeclarationBySimpleString(name);

    // Method 4: Search in typedefs
    result ??= _findTypedefDeclarationBySimpleString(name);

    // Search by simple name first
    result ??= _searchBySimpleName(name);

    // Cache the result
    _simpleNameCache[name] = result;
    
    return result;
  }

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

  /// Find typedef declaration by string name (simple or qualified)
  static TypedefDeclaration? _findTypedefDeclarationBySimpleString(String name) {
    return Runtime.getAllTypedefs().where((t) => t.getSimpleName() == name).firstOrNull;
  }

  /// Search by type string representation
  static TypeDeclaration? _searchBySimpleName(String name) {
    return Runtime.getAllTypes().where((d) => d.getSimpleName() == name).firstOrNull;
  }

  /// {@template find_by_element}
  /// Finds a type declaration by its analyzer Element.
  /// 
  /// Useful when working with analyzer-based tools and needing to bridge
  /// to the runtime reflection system.
  /// 
  /// ## Example
  /// ```dart
  /// final classElement = getClassElementFromAnalyzer();
  /// final classDecl = TypeDiscovery.findByElement(classElement);
  /// ```
  /// {@endtemplate}
  static TypeDeclaration? findByElement(Element element) {
    // Check cache first
    final cached = _elementCache[element];
    if (cached != null) return cached;
    
    TypeDeclaration? result;

    // Method 1: Search in classes
    result ??= _findClassDeclarationByElement(element);

    // Method 2: Search in enums
    result ??= _findEnumDeclarationByElement(element);

    // Method 3: Search in mixins
    result ??= _findMixinDeclarationByElement(element);

    // Method 4: Search in typedefs
    result ??= _findTypedefDeclarationByElement(element);

    // Search by element in all declaration types
    result ??= _searchByElement(element);

    // Cache the result
    _elementCache[element] = result;
    
    return result;
  }

  /// Finds a class declaration by its analyzer Element.
  /// 
  /// Useful when working with analyzer-based tools and needing to bridge
  /// to the runtime reflection system.
  /// 
  /// ## Example
  /// ```dart
  /// final classElement = getClassElementFromAnalyzer();
  /// final classDecl = TypeDiscovery.findClassByElement(classElement);
  /// ```
  static ClassDeclaration? findClassByElement(Element element) {
    // Check cache first
    final cached = _elementCache[element];
    if (cached case ClassDeclaration cached) return cached;
    
    ClassDeclaration? result;

    // Method 1: Search in enums
    result ??= _findEnumDeclarationByElement(element);

    // Method 2: Search in mixins
    result ??= _findMixinDeclarationByElement(element);

    // Method 3: Search in classes
    result ??= _findClassDeclarationByElement(element);

    // Cache the result
    _elementCache[element] = result;
    
    return result;
  }

  // ============================================= ELEMENT SEARCH METHODS ===========================================

  /// Find class declaration by analyzer Element
  static ClassDeclaration? _findClassDeclarationByElement(Element element) {
    return Runtime.getAllClasses().where((c) => c.getElement() == element).firstOrNull;
  }

  /// Find enum declaration by analyzer Element
  static EnumDeclaration? _findEnumDeclarationByElement(Element element) {
    return Runtime.getAllEnums().where((e) => e.getElement() == element).firstOrNull;
  }

  /// Find mixin declaration by analyzer Element
  static MixinDeclaration? _findMixinDeclarationByElement(Element element) {
    return Runtime.getAllMixins().where((m) => m.getElement() == element).firstOrNull;
  }

  /// Find typedef declaration by analyzer Element
  static TypedefDeclaration? _findTypedefDeclarationByElement(Element element) {
    return Runtime.getAllTypedefs().where((t) => t.getElement() == element).firstOrNull;
  }

  /// Search by analyzer element
  static TypeDeclaration? _searchByElement(Element element) {
    return Runtime.getAllTypes().where((d) => d.getElement() == element).firstOrNull;
  }

  /// {@template find_subclasses_of}
  /// Finds all classes that extend or implement the given type.
  /// 
  /// Returns a list of ClassDeclarations that are subclasses of the given type.
  /// Uses caching for performance on repeated queries.
  /// 
  /// ## Example
  /// ```dart
  /// final subclasses = TypeDiscovery.findSubclassesOf(BaseService);
  /// for (final subclass in subclasses) {
  ///   print('Found subclass: ${subclass.getName()}');
  /// }
  /// ```
  /// {@endtemplate}
  static List<ClassDeclaration> findSubclassesOf(Type baseType) {
    // Check cache first
    final cached = _subclassCache[baseType];
    if (cached != null) return cached;

    final subclasses = <ClassDeclaration>[];
    final allClasses = Runtime.getAllClasses();

    for (final classDecl in allClasses) {
      if (_isSubclassOf(classDecl, baseType)) {
        subclasses.add(classDecl);
      }
    }

    // Cache the result
    _subclassCache[baseType] = subclasses;
    
    return subclasses;
  }

  // =========================================== SUB CLASS METHODS ==============================================

  /// Check if a class is a subclass of the given base type
  static bool _isSubclassOf(ClassDeclaration classDecl, Type baseType) {
    // Check direct superclass
    final superClass = classDecl.getSuperClass();
    if (superClass?.getPointerType() == baseType) {
      return true;
    }

    // Check interfaces
    for (final interface in classDecl.getInterfaces()) {
      if (interface.getPointerType() == baseType) {
        return true;
      }
    }

    // Check mixins
    for (final mixin in classDecl.getMixins()) {
      if (mixin.getPointerType() == baseType) {
        return true;
      }
    }

    // Recursive check up the inheritance chain
    if (superClass != null) {
      final superClassDecl = findByType(superClass.getPointerType());
      if (superClassDecl is ClassDeclaration && _isSubclassOf(superClassDecl, baseType)) {
        return true;
      }
    }

    return false;
  }

  /// {@template find_implementers_of}
  /// Finds all types that implement the given interface type.
  /// 
  /// Returns classes, mixins, and other types that implement the interface.
  /// 
  /// ## Example
  /// ```dart
  /// final implementers = TypeDiscovery.findImplementersOf(Serializable);
  /// ```
  /// {@endtemplate}
  static List<TypeDeclaration> findImplementersOf(Type interfaceType) {
    // Check cache first
    final cached = _implementerCache[interfaceType];
    if (cached != null) return cached;

    final implementers = <TypeDeclaration>[];
    final allDeclarations = Runtime.getAllTypes();

    for (final decl in allDeclarations) {
      if (_implementsInterface(decl, interfaceType)) {
        implementers.add(decl);
      }
    }

    // Cache the result
    _implementerCache[interfaceType] = implementers;
    
    return implementers;
  }

  // ================================= IMPLEMENTATION METHOD HELPERS ===========================================

  /// Check if a type implements the given interface
  static bool _implementsInterface(TypeDeclaration typeDecl, Type interfaceType) {
    // For classes, check interfaces and mixins
    if (typeDecl is ClassDeclaration) {
      for (final interface in typeDecl.getInterfaces()) {
        if (interface.getPointerType() == interfaceType) {
          return true;
        }
      }
      for (final mixin in typeDecl.getMixins()) {
        if (mixin.getPointerType() == interfaceType) {
          return true;
        }
      }
    }

    // For mixins, check interfaces
    if (typeDecl is MixinDeclaration) {
      for (final interface in typeDecl.getInterfaces()) {
        if (interface.getPointerType() == interfaceType) {
          return true;
        }
      }
    }

    return false;
  }

  /// {@template find_generic_instantiations}
  /// Finds all instantiations of a generic type.
  /// 
  /// For example, finding all `List<T>` instantiations would return
  /// `List<String>`, `List<int>`, etc.
  /// 
  /// ## Example
  /// ```dart
  /// final listTypes = TypeDiscovery.findGenericInstantiationsOf(List);
  /// ```
  /// {@endtemplate}
  static List<TypeDeclaration> findGenericInstantiationsOf(Type genericType) {
    final instantiations = <TypeDeclaration>[];
    final allTypes = Runtime.getAllTypes();

    final genericTypeName = genericType.toString().split('<').first;

    for (final typeDecl in allTypes) {
      final typeName = typeDecl.getName();
      if (typeName.startsWith(genericTypeName) && typeDecl.isGeneric()) {
        instantiations.add(typeDecl);
      }
    }

    return instantiations;
  }

  // ============================================= UTILITY METHODS ===========================================

  /// Gets statistics about the current cache state
  static Map<String, int> getCacheStatistics() {
    return {
      'typeCache': _typeCache.length,
      'nameCache': _nameCache.length,
      'elementCache': _elementCache.length,
      'subclassCache': _subclassCache.length,
      'implementerCache': _implementerCache.length,
    };
  }

  /// Preloads caches by scanning all available types
  static void preloadCaches() {
    final allDeclarations = Runtime.getAllTypes();

    for (final decl in allDeclarations) {
      // Preload type cache
      _typeCache[decl.getType()] = decl;
      
      // Preload name caches
      _nameCache[decl.getSimpleName()] = decl;
      _nameCache[decl.getQualifiedName()] = decl;
      
      // Preload element cache if available
      final element = decl.getElement();
      if (element != null) {
        _elementCache[element] = decl;
      }
    }
  }

  /// Validates cache consistency (useful for debugging)
  static List<String> validateCaches() {
    final issues = <String>[];
    
    // Check type cache consistency
    for (final entry in _typeCache.entries) {
      if (entry.value != null && entry.value!.getType() != entry.key) {
        issues.add('Type cache inconsistency: ${entry.key} -> ${entry.value!.getType()}');
      }
    }
    
    // Check name cache consistency
    for (final entry in _nameCache.entries) {
      if (entry.value != null) {
        final decl = entry.value!;
        if (decl.getSimpleName() != entry.key && decl.getQualifiedName() != entry.key) {
          issues.add('Name cache inconsistency: ${entry.key} -> ${decl.getSimpleName()}/${decl.getQualifiedName()}');
        }
      }
    }
    
    return issues;
  }
}