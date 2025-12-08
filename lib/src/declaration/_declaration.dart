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

part of 'declaration.dart';

/// {@template asset_implementation}
/// A concrete, immutable implementation of the [Asset] interface.
///
/// This class represents a single asset in the system, containing the
/// file path, file name, package name, and binary content.
///
/// Typically used in scenarios where reflective or dynamic loading
/// of files and packages is required.
///
/// ### Example
/// ```dart
/// final asset = AssetImplementation(
///   filePath: 'lib/resources/logo.png',
///   fileName: 'logo.png',
///   packageName: 'my_package',
///   contentBytes: await File('lib/resources/logo.png').readAsBytes(),
/// );
/// print(asset.fileName); // logo.png
/// ```
/// {@endtemplate}
class AssetImplementation extends Asset with EqualsAndHashCode {
  /// {@macro asset_implementation}
  const AssetImplementation({
    required super.filePath,
    required super.fileName,
    required super.packageName,
    required super.contentBytes,
  });

  @override
  List<Object?> equalizedProperties() {
    return [
      _filePath,
      _fileName,
      _packageName,
      _contentBytes,
    ];
  }

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['filePath'] = _filePath;
    result['fileName'] = _fileName;
    result['packageName'] = _packageName;
    result['contentBytes'] = _contentBytes.toString();
    return result;
  }
}

/// {@template package_implementation}
/// A concrete, immutable implementation of the [Package] interface.
///
/// Represents a Dart package with metadata such as name, version,
/// file path, and language version.
///
/// Useful in reflective frameworks, build tools, or analyzers
/// that inspect or manipulate Dart packages programmatically.
///
/// ### Example
/// ```dart
/// final package = PackageImplementation(
///   name: 'jetleaf',
///   version: '1.2.3',
///   languageVersion: '3.3',
///   isRootPackage: true,
///   filePath: '/project/jetleaf/pubspec.yaml',
/// );
///
/// print(package.name); // jetleaf
/// print(package.isRootPackage); // true
/// ```
/// {@endtemplate}
class PackageImplementation extends Package with EqualsAndHashCode {
  /// {@macro package_implementation}
  const PackageImplementation({
    required super.name,
    required super.version,
    super.languageVersion,
    required super.isRootPackage,
    required super.filePath,
    required super.rootUri,
  });

  @override
  List<Object?> equalizedProperties() {
    return [
      _name,
      _version,
      _languageVersion,
      _isRootPackage,
      _filePath,
      _rootUri,
    ];
  }
}

final class StandardDeclaration extends Declaration with EqualsAndHashCode {
  /// Runtime type of the declared entity
  final Type _type;

  /// Name as declared in source
  final String _name;

  /// Checks if this declaration is public or not
  final bool _isPublic;
  final bool _isSynthetic;

  const StandardDeclaration({
    required Type type,
    required String name,
    required bool isPublic,
    required bool isSynthetic,
  }) : _type = type, _name = name, _isPublic = isPublic, _isSynthetic = isSynthetic;

  @override
  Type getType() => _type;

  @override
  String getName() => _name;

  @override
  bool getIsPublic() => _isPublic;

  @override
  bool getIsSynthetic() => _isSynthetic;

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['type'] = _type;
    result['name'] = _name;
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      _type,
      _name,
      _isPublic,
      _isSynthetic,
    ];
  }
}

/// {@template standard_entity_declaration}
/// Concrete implementation of [EntityDeclaration] providing standard reflection metadata.
///
/// Represents a declared entity (class, function, variable, etc.) with:
/// - Optional analyzer elements
/// - Optional Dart type information
/// - Runtime type information
/// - Debug identifiers
///
/// {@template standard_entity_declaration_features}
/// ## Key Features
/// - Bridges analyzer and runtime reflection
/// - Lightweight immutable value object
/// - Debug-friendly representations
/// - JSON serialization support
///
/// ## Typical Usage
/// Used by code generators and runtime systems to represent declared program
/// elements in reflection contexts.
/// {@endtemplate}
///
/// {@template standard_entity_declaration_example}
/// ## Example Creation
/// ```dart
/// final declaration = StandardEntityDeclaration(
///   element: someElement,      // Optional analyzer Element
///   dartType: someDartType,    // Optional analyzer DartType
///   type: MyClass,            // Required runtime Type
///   debugger: 'my_class_decl' // Optional debug identifier
/// );
/// ```
/// {@endtemplate}
/// {@endtemplate}
final class StandardEntityDeclaration extends StandardDeclaration  implements EntityDeclaration {
  /// Optional analyzer Element for static analysis integration
  final Element? _element;

  /// Optional analyzer DartType for static type information
  final DartType? _dartType;

  /// Debug identifier for developer tools
  final String _debugger;

  /// Creates a standard entity declaration
  ///
  /// {@template standard_entity_constructor}
  /// Parameters:
  /// - [element]: Optional analyzer [Element] for static analysis
  /// - [dartType]: Optional analyzer [DartType] for static typing
  /// - [type]: Required runtime [Type] of the entity
  /// - [debugger]: Optional custom debug identifier (defaults to "type_$type")
  ///
  /// All fields are immutable once created.
  /// {@endtemplate}
  const StandardEntityDeclaration({
    Element? element,
    DartType? dartType,
    required super.type,
    required super.isPublic,
    required super.isSynthetic,
    required super.name,
    String? debugger
  }) : _element = element, 
       _dartType = dartType,
       _debugger = debugger ?? "type_$type";

  @override
  DartType? getDartType() => _dartType;

  @override
  Element? getElement() => _element;

  @override
  bool hasAnalyzerSupport() => _dartType != null;

  @override
  String getDebugIdentifier() => _debugger;

  @override
  Map<String, Object> toJson() {
    return {
      "type": _type.toString(),
      "debugger": _debugger
    };
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      _type,
      _name,
      _isPublic,
      _isSynthetic,
      _element,
      _dartType,
      _debugger,
    ];
  }
}

/// {@template standard_source_declaration}
/// Concrete implementation of [SourceDeclaration] representing source-level declarations.
///
/// Provides standardized reflection metadata for source code elements including:
/// - Name and location in source
/// - Parent library context
/// - Annotations
/// - Type information
///
/// {@template standard_source_declaration_features}
/// ## Key Features
/// - Complete source element metadata
/// - Annotation introspection
/// - Source location tracking
/// - Library context awareness
/// - Immutable value object
///
/// ## Typical Usage
/// Used by code generators and runtime systems to represent:
/// - Classes
/// - Functions
/// - Variables
/// - Parameters
/// - Other source declarations
/// {@endtemplate}
///
/// {@template standard_source_declaration_example}
/// ## Example Creation
/// ```dart
/// final declaration = StandardSourceDeclaration(
///   element: classElement,       // Optional analyzer Element
///   type: MyClass,              // Required runtime Type
///   dartType: classDartType,    // Optional analyzer DartType
///   name: 'MyClass',            // Source name
///   debugger: 'my_class',       // Optional debug identifier
///   annotations: annotations,   // List of annotations
///   libraryDeclaration: libDecl,// Parent library
///   sourceLocation: classUri    // Optional source URI
/// );
/// ```
/// {@endtemplate}
/// {@endtemplate}
final class StandardSourceDeclaration extends StandardEntityDeclaration implements SourceDeclaration {
  /// Annotations applied to this declaration
  final List<AnnotationDeclaration> _annotations;

  /// Parent library containing this declaration
  final LibraryDeclaration _library;

  /// Source file location (URI)
  final Uri? _sourceLocation;

  /// Creates a standard source declaration
  ///
  /// {@template standard_source_constructor}
  /// Parameters:
  /// - [element]: Optional analyzer [Element] for static analysis
  /// - [type]: Required runtime [Type] of the declaration
  /// - [dartType]: Optional analyzer [DartType] for static typing
  /// - [name]: Source code name of the declaration (required)
  /// - [debugger]: Optional custom debug identifier
  /// - [annotations]: List of annotations (default empty)
  /// - [libraryDeclaration]: Parent library (required)
  /// - [sourceLocation]: Optional source file URI
  ///
  /// All fields are immutable once created.
  /// {@endtemplate}
  const StandardSourceDeclaration({
    super.element,
    required super.type,
    super.dartType,
    required super.name,
    required super.isPublic,
    required super.isSynthetic,
    super.debugger,
    List<AnnotationDeclaration> annotations = const [],
    required LibraryDeclaration libraryDeclaration,
    Uri? sourceLocation
  }) : _annotations = annotations,
       _library = libraryDeclaration,
       _sourceLocation = sourceLocation,
       super();

  @override
  List<AnnotationDeclaration> getAnnotations() => _annotations;

  @override
  LibraryDeclaration getParentLibrary() => _library;

  @override
  Uri? getSourceLocation() => _sourceLocation;

  @override
  List<Object?> equalizedProperties() {
    return [
      _annotations,
      _library,
      _sourceLocation,
    ];
  }
}

/// {@template standard_link_declaration}
/// A standard implementation of [LinkDeclaration] for representing links to
/// other types.
///
/// This class holds metadata such as the type's name, runtime representation,
/// nullability, kind (e.g., class, enum), generic type arguments, and optionally
/// a reference to a [SourceDeclaration].
///
/// ## Example
/// ```dart
/// final link = StandardReflectedLink(
///   name: 'List',
///   type: List,
///   pointerType: List,
///   pointerQualifiedName: 'List',
///   canonicalUri: Uri.parse('dart:core#List'),
///   referenceUri: Uri.parse('dart:core#List'),
///   variance: TypeVariance.invariant,
/// );
///
/// print(link.getName()); // "List"
/// print(link.getKind()); // TypeKind.classType
/// ```
/// {@endtemplate}
final class StandardLinkDeclaration extends StandardDeclaration implements LinkDeclaration {
  final Type _pointerType;
  final String _pointerQualifiedName;
  final Uri? _canonicalUri;
  final Uri? _referenceUri;
  final TypeVariance _variance;
  final LinkDeclaration? _upperBound;
  final List<LinkDeclaration> _typeArguments;

  /// {@macro standard_link_declaration}
  const StandardLinkDeclaration({
    required super.name,
    required super.type,
    required Type pointerType,
    List<LinkDeclaration> typeArguments = const [],
    required String qualifiedName,
    Uri? canonicalUri,
    required super.isPublic,
    required super.isSynthetic,
    Uri? referenceUri,
    TypeVariance variance = TypeVariance.invariant,
    LinkDeclaration? upperBound
  }) : _pointerType = pointerType, _pointerQualifiedName = qualifiedName, _typeArguments = typeArguments,
       _canonicalUri = canonicalUri, _referenceUri = referenceUri, _variance = variance, _upperBound = upperBound;

  @override
  Type getPointerType() => _pointerType;

  @override
  String getPointerQualifiedName() => _pointerQualifiedName;

  @override
  List<LinkDeclaration> getTypeArguments() => List.unmodifiable(_typeArguments);

  @override
  Uri? getCanonicalUri() => _canonicalUri;

  @override
  Uri? getReferenceUri() => _referenceUri;

  @override
  TypeVariance getVariance() => _variance;

  @override
  LinkDeclaration? getUpperBound() => _upperBound;

  @override
  bool getIsCanonical() => _canonicalUri != null && _referenceUri != null && _canonicalUri == _referenceUri;

  @override
  Map<String, Object> toJson() => {
    "type": _type,
    "pointer": _pointerType,
    "qualified_name": _pointerQualifiedName,
    if(_canonicalUri != null) "canonical_uri": _canonicalUri.toString(),
    if(_referenceUri != null) "reference_uri": _referenceUri.toString(),
    "variance": _variance,
    if(_upperBound != null) "upper_bound": _upperBound.toJson(),
    if(_typeArguments.isNotEmpty) "type_arguments": _typeArguments.map((t) => t.toJson()).toList(),
  };

  @override
  List<Object?> equalizedProperties() {
    return [
      _pointerType,
      _pointerQualifiedName,
      _canonicalUri,
      _referenceUri,
      _variance,
      _upperBound,
      _typeArguments,
    ];
  }
}

/// {@template standard_type}
/// A standard implementation of [TypeDeclaration] for representing common Dart types,
/// such as primitive types, classes, enums, typedefs, and records.
///
/// This class holds metadata such as the type's name, runtime representation,
/// nullability, kind (e.g., class, enum), generic type arguments, and optionally
/// a reference to a [SourceDeclaration].
///
/// ## Example
/// ```dart
/// final type = StandardReflectedType(
///   name: 'String',
///   type: String,
///   isNullable: false,
///   kind: TypeKind.classType,
///   declaration: MyReflectedClassDeclaration(),
/// );
///
/// print(type.getName()); // "String"
/// print(type.getKind()); // TypeKind.classType
/// ```
/// {@endtemplate}
final class StandardTypeDeclaration extends TypeDeclaration with EqualsAndHashCode {
  final String _name;
  final bool _isNullable;
  final TypeKind _kind;
  final Element? _element;
  final DartType? _dartType;
  final Type _type;
  final String _qualifiedName;
  final String _simpleName;
  final String _packageUri;
  final List<LinkDeclaration> _mixins;
  final List<LinkDeclaration> _interfaces;
  final LinkDeclaration? _superClass;
  final List<LinkDeclaration> _typeArguments;
  final bool _isPublic;
  final bool _isSynthetic;

  /// {@macro standard_type}
  const StandardTypeDeclaration({
    required String name,
    required bool isNullable,
    required TypeKind kind,
    required Element? element,
    required DartType? dartType,
    required Type type,
    required String qualifiedName,
    required String simpleName,
    required String packageUri,
    List<LinkDeclaration> mixins = const [],
    List<LinkDeclaration> interfaces = const [],
    LinkDeclaration? superClass,
    required bool isPublic,
    required bool isSynthetic,
    List<LinkDeclaration> typeArguments = const [],
  })  : _name = name,
        _isNullable = isNullable,
        _isPublic = isPublic, _isSynthetic = isSynthetic,
        _typeArguments = typeArguments,
        _element = element,
        _dartType = dartType,
        _type = type,
        _kind = kind,
        _qualifiedName = qualifiedName,
        _simpleName = simpleName,
        _packageUri = packageUri,
        _mixins = mixins,
        _interfaces = interfaces,
        _superClass = superClass;

  @override
  String getName() => _name;

  @override
  bool getIsNullable() => _isNullable;

  @override
  bool getIsPublic() => _isPublic;

  @override
  bool getIsSynthetic() => _isSynthetic;

  @override
  TypeKind getKind() => _kind;

  @override
  bool isAssignableFrom(TypeDeclaration other)  {
    return other.isAssignableTo(this);
  }

  @override
  bool isAssignableTo(TypeDeclaration target) {
    // // Use analyzer's type system if available
    // if (hasAnalyzerSupport() && target.hasAnalyzerSupport()) {
    //   return _isAssignableToWithAnalyzer(target);
    // }
    
    // // Fallback to basic checking
    // return _isAssignableToBasic(target);
    return false;
  }

  // Private helper methods
  // bool _isAssignableToWithAnalyzer(TypeDeclaration target) {
  //   final from = getDartType();
  //   final to = target.getDartType();
    
  //   if (from == null || to == null) {
  //     return _isAssignableToBasic(target);
  //   }
    
  //   final typeSystem = from.element?.library?.typeSystem;
  //   if (typeSystem == null) {
  //     return _isAssignableToBasic(target);
  //   }
    
  //   return typeSystem.isAssignableTo(from, to);
  // }

  // bool _isAssignableToBasic(TypeDeclaration target) {
  //   // Basic assignability logic as fallback
  //   if (getName() == target.getName()) return true;
  //   if (getKind() == TypeKind.dynamicType && target.getKind() == TypeKind.dynamicType) return true;
  //   return false;
  // }

  @override
  bool isGeneric() {
    final dartType = getDartType();
    if (dartType is ParameterizedType) {
      return dartType.typeArguments.isNotEmpty;
    }
    return getTypeArguments().isNotEmpty || (getType().toString().contains("<") && getType().toString().endsWith(">"));
  }

  @override
  List<LinkDeclaration> getTypeArguments() => List.unmodifiable(_typeArguments);
  
  @override
  DartType? getDartType() => _dartType;
  
  @override
  Element? getElement() => _element;
  
  @override
  String getPackageUri() => _packageUri;
  
  @override
  String getQualifiedName() => _qualifiedName;
  
  @override
  String getSimpleName() => _simpleName;
  
  @override
  LinkDeclaration? getSuperClass() => _superClass;

  @override
  List<LinkDeclaration> getMixins() => List.unmodifiable(_mixins);

  @override
  List<LinkDeclaration> getInterfaces() => List.unmodifiable(_interfaces);
  
  @override
  Type getType() => _type;

  @override
  String getDebugIdentifier() => "type_${getSimpleName().toLowerCase()}";

  @override
  List<Object?> equalizedProperties() {
    return [
      _name,
      _isNullable,
      _kind,
      _element,
      _dartType,
      _type,
      _qualifiedName,
      _simpleName,
      _packageUri,
      _mixins,
      _interfaces,
      _superClass,
      _typeArguments,
      _isPublic,
      _isSynthetic,
    ];
  }
}

/// {@template standard_typedef}
/// Standard implementation of [TypedefDeclaration] used by JetLeaf's reflection system.
///
/// Represents a Dart `typedef`, capturing its name, underlying aliased type,
/// type parameters, parent library, annotations, and source location.
///
/// This class provides access to both the structural and metadata aspects of a typedef,
/// including support for resolving its aliased type and understanding whether the type is nullable.
///
/// ## Example
/// ```dart
/// typedef IntList = List<int>;
///
/// final typedef = StandardReflectedTypedef(
///   name: 'IntList',
///   type: IntList,
///   parentLibrary: myLibrary,
///   aliasedType: myListType,
/// );
///
/// print(typedef.getName()); // IntList
/// print(typedef.getAliasedType()); // List<int>
/// ```
/// {@endtemplate}
final class StandardTypedefDeclaration extends StandardTypeDeclaration implements TypedefDeclaration {
  final LibraryDeclaration _parentLibrary;
  final TypeDeclaration _aliasedType;
  final List<AnnotationDeclaration> _annotations;
  final Uri? _sourceLocation;

  /// {@macro standard_typedef}
  StandardTypedefDeclaration({
    required super.name,
    required super.type,
    required super.element,
    required super.dartType,
    required super.isPublic,
    required super.isSynthetic,
    String? qualifiedName,
    required LibraryDeclaration parentLibrary,
    required TypeDeclaration aliasedType,
    super.isNullable = false,
    super.typeArguments,
    List<AnnotationDeclaration> annotations = const [],
    Uri? sourceLocation,
  })  : _parentLibrary = parentLibrary,
        _aliasedType = aliasedType,
        _annotations = annotations,
        _sourceLocation = sourceLocation,
        super(
          qualifiedName: qualifiedName ?? '${parentLibrary.getUri()}.$name',
          simpleName: name,
          packageUri: parentLibrary.getUri(),
          kind: TypeKind.typedefType,
        );

  @override
  LibraryDeclaration getParentLibrary() => _parentLibrary;

  @override
  List<AnnotationDeclaration> getAnnotations() => List.unmodifiable(_annotations);

  @override
  Uri? getSourceLocation() => _sourceLocation;

  @override
  TypeDeclaration getAliasedType() => _aliasedType;

  @override
  String getDebugIdentifier() => 'typedef_${getName().toLowerCase()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = "typedef";
    result['name'] = getName();
    result['type'] = "${getType()}";
    result['isNullable'] = getIsNullable();
    result['kind'] = getKind().toString();

    final arguments = getTypeArguments().map((a) => a.toJson()).toList();
    if(arguments.isNotEmpty) {
      result['typeArguments'] = arguments;
    }
    
    final parentLibrary = getParentLibrary().toJson();
    if(parentLibrary.isNotEmpty) {
      result['parentLibrary'] = parentLibrary;
    }
    
    final annotations = getAnnotations().map((a) => a.toJson()).toList();
    if(annotations.isNotEmpty) {
      result['annotations'] = annotations;
    }
    
    final sourceLocation = getSourceLocation();
    if(sourceLocation != null) {
      result['sourceLocation'] = sourceLocation.toString();
    }
    
    final aliasedType = getAliasedType().toJson();
    if(aliasedType.isNotEmpty) {
      result['aliasedType'] = aliasedType;
    }

    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getParentLibrary(),
      getAnnotations(),
      getSourceLocation(),
      getType(),
      getIsNullable(),
      getKind(),
      getTypeArguments(),
      getAliasedType(),
    ];
  }

  StandardTypedefDeclaration copyWith({
    String? name,
    Type? type,
    LibraryDeclaration? parentLibrary,
    TypeDeclaration? aliasedType,
    bool? isNullable,
    List<LinkDeclaration>? typeArguments,
    List<AnnotationDeclaration>? annotations,
    Uri? sourceLocation,
    Element? element,
    bool? isPublic,
    bool? isSynthetic,
    DartType? dartType,
    String? qualifiedName,
  }) {
    return StandardTypedefDeclaration(
      name: name ?? getName(),
      type: type ?? getType(),
      isPublic: isPublic ?? getIsPublic(),
      isSynthetic: isSynthetic ?? getIsSynthetic(),
      parentLibrary: parentLibrary ?? getParentLibrary(),
      aliasedType: aliasedType ?? getAliasedType(),
      isNullable: isNullable ?? getIsNullable(),
      typeArguments: typeArguments ?? getTypeArguments(),
      annotations: annotations ?? getAnnotations(),
      sourceLocation: sourceLocation ?? getSourceLocation(),
      element: element ?? getElement(),
      dartType: dartType ?? getDartType(),
      qualifiedName: qualifiedName ?? getQualifiedName(),
    );
  }
}

/// {@template standard_type_variable}
/// A standard implementation of [TypeVariableDeclaration] for representing
/// type variables in Dart, such as `T` in `List<T>` or `E` in `Map<K, V>`.
///
/// This class holds metadata such as the type variable's name, runtime
/// representation, nullability, upper bound, and optionally a reference
/// to a [SourceDeclaration].
///
/// ## Example
/// ```dart
/// final typeVariable = StandardReflectedTypeVariable(
///   name: 'T',
///   type: Type,
///   isNullable: false,
///   upperBound: StandardReflectedType(
///     name: 'Object',
///     type: Object,
///     isNullable: false,
///     kind: TypeKind.classType,
///   ),
/// );
///
/// print(typeVariable.getName()); // "T"
/// print(typeVariable.getKind()); // TypeKind.typeVariable
/// ```
/// {@endtemplate}
final class StandardTypeVariableDeclaration extends StandardTypeDeclaration implements TypeVariableDeclaration {
  final TypeDeclaration? _upperBound;
  final LibraryDeclaration _parentLibrary;
  final List<AnnotationDeclaration> _annotations;
  final Uri? _sourceLocation;
  final TypeVariance _variance;

  /// {@macro standard_type_variable}
  StandardTypeVariableDeclaration({
    required super.name,
    required super.type,
    required super.element,
    required super.dartType,
    required super.isPublic,
    required super.isSynthetic,
    String? qualifiedName,
    super.isNullable = false,
    TypeDeclaration? upperBound,
    required LibraryDeclaration parentLibrary,
    List<AnnotationDeclaration> annotations = const [],
    Uri? sourceLocation,
    TypeVariance variance = TypeVariance.invariant,
  })  : _upperBound = upperBound,
        _parentLibrary = parentLibrary,
        _annotations = annotations,
        _sourceLocation = sourceLocation,
        _variance = variance,
        super(
          kind: TypeKind.typeVariable,
          qualifiedName: qualifiedName ?? name,
          simpleName: name,
          packageUri: 'dart:core',
        );

  @override
  TypeDeclaration? getUpperBound() => _upperBound;

  @override
  TypeVariance getVariance() => _variance;
  
  @override
  String getDebugIdentifier() => 'type_variable_${getName().toLowerCase()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'type_variable';
    result['name'] = getName();
    result['type'] = getType().toString();
    result['isNullable'] = getIsNullable();
    result['kind'] = getKind().toString();

    final arguments = getTypeArguments().map((a) => a.toJson()).toList();
    if(arguments.isNotEmpty) {
      result['typeArguments'] = arguments;
    }
    
    final parentLibrary = getParentLibrary().toJson();
    if(parentLibrary.isNotEmpty) {
      result['parentLibrary'] = parentLibrary;
    }
    
    final annotations = getAnnotations().map((a) => a.toJson()).toList();
    if(annotations.isNotEmpty) {
      result['annotations'] = annotations;
    }
    
    final sourceLocation = getSourceLocation();
    if(sourceLocation != null) {
      result['sourceLocation'] = sourceLocation.toString();
    }
    
    final upperBound = getUpperBound()?.toJson();
    if(upperBound != null) {
      result['upperBound'] = upperBound;
    }
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getUpperBound(),
      getType(),
      getIsNullable(),
      getKind(),
      getTypeArguments(),
    ];
  }

  StandardTypeVariableDeclaration copyWith({
    String? name,
    Type? type,
    TypeDeclaration? upperBound,
    Element? element,
    DartType? dartType,
    String? qualifiedName,
    TypeVariance? variance,
    bool? isNullable,
    LibraryDeclaration? parentLibrary,
    List<AnnotationDeclaration>? annotations,
    Uri? sourceLocation,
    bool? isPublic,
    bool? isSynthetic,
  }) {
    return StandardTypeVariableDeclaration(
      name: name ?? getName(),
      type: type ?? getType(),
      isPublic: isPublic ?? getIsPublic(),
      isSynthetic: isSynthetic ?? getIsSynthetic(),
      upperBound: upperBound ?? getUpperBound(),
      element: element ?? getElement(),
      dartType: dartType ?? getDartType(),
      qualifiedName: qualifiedName ?? getQualifiedName(),
      variance: variance ?? getVariance(),
      isNullable: isNullable ?? getIsNullable(),
      parentLibrary: parentLibrary ?? getParentLibrary(),
      annotations: annotations ?? getAnnotations(),
      sourceLocation: sourceLocation ?? getSourceLocation(),
    );
  }
  
  @override
  List<AnnotationDeclaration> getAnnotations() => _annotations;
  
  @override
  LibraryDeclaration getParentLibrary() => _parentLibrary;
  
  @override
  Uri? getSourceLocation() => _sourceLocation;
}

/// {@template standard_record}
/// A standard implementation of [RecordDeclaration] used to represent Dart [Record] types,
/// including their positional and named fields, type arguments, annotations,
/// and parent library metadata.
///
/// This is useful for reflecting on Dart record types, such as:
/// ```dart
/// (int, String name)
/// ```
/// where the positional and named fields can be inspected at runtime.
///
/// ## Example
/// ```dart
/// final recordType = StandardReflectedRecord(
///   name: '(int, {String name})',
///   type: (int, {String name}).type,
///   parentLibrary: myLibrary,
///   positionalFields: [StandardReflectedRecordField(position: 0, type: intType)],
///   namedFields: {
///     'name': StandardReflectedRecordField(name: 'name', type: stringType),
///   },
/// );
///
/// print(recordType.getPositionalFields().length); // 1
/// print(recordType.getNamedFields().keys); // (name)
/// ```
/// {@endtemplate}
final class StandardRecordDeclaration extends StandardTypeDeclaration implements RecordDeclaration {
  final LibraryDeclaration _parentLibrary;
  final List<RecordFieldDeclaration> _positionalFields;
  final Map<String, RecordFieldDeclaration> _namedFields;
  final List<AnnotationDeclaration> _annotations;
  final Uri? _sourceLocation;

  /// {@macro standard_record}
  StandardRecordDeclaration({
    required super.name,
    required super.type,
    required LibraryDeclaration parentLibrary,
    super.isNullable = false,
    super.typeArguments,
    required super.element,
    required super.isPublic,
    required super.isSynthetic,
    required super.dartType,
    String? qualifiedName,
    List<RecordFieldDeclaration> positionalFields = const [],
    Map<String, RecordFieldDeclaration> namedFields = const {},
    List<AnnotationDeclaration> annotations = const [],
    Uri? sourceLocation,
  })  : _parentLibrary = parentLibrary,
        _positionalFields = positionalFields,
        _namedFields = namedFields,
        _annotations = annotations,
        _sourceLocation = sourceLocation,
        super(
          kind: TypeKind.recordType,
          qualifiedName: qualifiedName ?? '${parentLibrary.getUri()}.$name',
          simpleName: name,
          packageUri: parentLibrary.getUri(),
        );

  @override
  LibraryDeclaration getParentLibrary() => _parentLibrary;

  @override
  List<AnnotationDeclaration> getAnnotations() => List.unmodifiable(_annotations);

  @override
  Uri? getSourceLocation() => _sourceLocation;

  @override
  List<RecordFieldDeclaration> getPositionalFields() => List.unmodifiable(_positionalFields);

  @override
  Map<String, RecordFieldDeclaration> getNamedFields() => Map.unmodifiable(_namedFields);

  @override
  RecordFieldDeclaration? getField(String name) => _namedFields[name];

  @override
  RecordFieldDeclaration? getPositionalField(int index) {
    return index >= 0 && index < _positionalFields.length ? _positionalFields[index] : null;
  }

  @override
  String getDebugIdentifier() => 'record_${getName().toLowerCase()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'record';
    result['name'] = getName();
    result['type'] = getType().toString();
    result['isNullable'] = getIsNullable();
    result['kind'] = getKind().toString();

    final arguments = getTypeArguments().map((t) => t.toJson()).toList();
    if(arguments.isNotEmpty) {
      result['typeArguments'] = arguments;
    }

    final parentLibrary = getParentLibrary().toJson();
    if(parentLibrary.isNotEmpty) {
      result['parentLibrary'] = parentLibrary;
    }

    final annotations = getAnnotations().map((a) => a.toJson()).toList();
    if(annotations.isNotEmpty) {
      result['annotations'] = annotations;
    }

    final sourceLocation = getSourceLocation();
    if(sourceLocation != null) {
      result['sourceLocation'] = sourceLocation.toString();
    }

    final positionalFields = getPositionalFields().map((f) => f.toJson()).toList();
    if(positionalFields.isNotEmpty) {
      result['positionalFields'] = positionalFields;
    }
    
    final namedFields = getNamedFields().map((key, value) => MapEntry(key, value.toJson()));
    if(namedFields.isNotEmpty) {
      result['namedFields'] = namedFields;
    }
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getType(),
      getIsNullable(),
      getKind(),
      getTypeArguments(),
      getParentLibrary(),
      getAnnotations(),
      getSourceLocation(),
      getPositionalFields(),
      getNamedFields(),
    ];
  }

  StandardRecordDeclaration copyWith({
    String? name,
    Type? type,
    LibraryDeclaration? parentLibrary,
    bool? isNullable,
    List<LinkDeclaration>? typeArguments,
    List<RecordFieldDeclaration>? positionalFields,
    Map<String, RecordFieldDeclaration>? namedFields,
    List<AnnotationDeclaration>? annotations,
    Uri? sourceLocation,
    Element? element,
    DartType? dartType,
    String? qualifiedName,
    bool? isPublic,
    bool? isSynthetic,
  }) {
    return StandardRecordDeclaration(
      name: name ?? getName(),
      type: type ?? getType(),
      isPublic: isPublic ?? getIsPublic(),
      isSynthetic: isSynthetic ?? getIsSynthetic(),
      element: element ?? getElement(),
      dartType: dartType ?? getDartType(),
      qualifiedName: qualifiedName ?? getQualifiedName(),
      parentLibrary: parentLibrary ?? getParentLibrary(),
      isNullable: isNullable ?? getIsNullable(),
      typeArguments: typeArguments ?? getTypeArguments(),
      positionalFields: positionalFields ?? getPositionalFields(),
      namedFields: namedFields ?? getNamedFields(),
      annotations: annotations ?? getAnnotations(),
      sourceLocation: sourceLocation ?? getSourceLocation(),
    );
  }
}

/// {@template standard_record_field}
/// Represents an individual field within a Dart record type, either positional or named.
///
/// The field contains metadata such as its position (for positional fields),
/// name (for named fields), and the reflected type.
///
/// ## Example
/// ```dart
/// final positional = StandardReflectedRecordField(
///   position: 0,
///   type: intType,
/// );
///
/// final named = StandardReflectedRecordField(
///   name: 'label',
///   type: stringType,
/// );
///
/// print(positional.getIsPositional()); // true
/// print(named.getIsNamed()); // true
/// ```
/// {@endtemplate}
final class StandardRecordFieldDeclaration extends StandardSourceDeclaration implements RecordFieldDeclaration {
  final int? _position; // null for named fields
  final bool _isNullable;
  final LinkDeclaration _typeDeclaration;

  /// {@macro standard_record_field}
  const StandardRecordFieldDeclaration({
    required super.name,
    required super.isPublic,
    required super.isSynthetic,
    int? position,
    required LinkDeclaration typeDeclaration,
    super.sourceLocation,
    super.element,
    super.dartType,
    required super.type,
    required super.libraryDeclaration,
    required bool isNullable,
    super.annotations
  })  : _position = position, _typeDeclaration = typeDeclaration, _isNullable = isNullable;

  @override
  String getName() => _name;

  @override
  int? getPosition() => _position;

  @override
  LinkDeclaration getLinkDeclaration() => _typeDeclaration;

  @override
  Element? getElement() => _element;

  @override
  DartType? getDartType() => _dartType;

  @override
  Type getType() => _type;

  @override
  bool isNullable() => _isNullable;

  @override
  bool getIsNamed() => _position == null;

  @override
  bool getIsPositional() => _position != null;
  
  @override
  Uri? getSourceLocation() => _sourceLocation;

  @override
  String getDebugIdentifier() => 'record_field_${getName().toLowerCase()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'record_field';
    result['name'] = getName();

    final position = getPosition();
    if(position != null) {
      result['position'] = position;
    }

    result['isNamed'] = getIsNamed();
    
    final parentLibrary = getParentLibrary().toJson();
    if(parentLibrary.isNotEmpty) {
      result['parentLibrary'] = parentLibrary;
    }

    final sourceLocation = getSourceLocation();
    if(sourceLocation != null) {
      result['sourceLocation'] = sourceLocation.toString();
    }

    result['isPositional'] = getIsPositional();
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getPosition(),
      getType(),
      getIsNamed(),
      getIsPositional(),
      getParentLibrary(),
      getAnnotations(),
      getSourceLocation(),
    ];
  }
}

/// {@template standard_enum}
/// A standard implementation of [EnumDeclaration] that provides reflection
/// metadata about an enum declaration in a Dart program.
///
/// This class exposes the name, runtime type, nullability, type arguments,
/// parent library, annotations, enum values, source location, and declared members.
///
/// ## Example
///
/// ```dart
/// final enumType = StandardReflectedEnum(
///   name: 'Color',
///   type: Color,
///   parentLibrary: myLibrary,
///   values: ['red', 'green', 'blue'],
/// );
///
/// print(enumType.getName()); // Color
/// print(enumType.getValues()); // [red, green, blue]
/// print(enumType.getKind()); // TypeKind.enumType
/// ```
///
/// Useful for tools and frameworks that need to inspect or work with enums
/// at runtime or during analysis, especially in reflection-based systems.
///
/// {@endtemplate}
final class StandardEnumDeclaration extends StandardTypeDeclaration implements EnumDeclaration {
  final LibraryDeclaration _parentLibrary;
  final List<EnumFieldDeclaration> _values;
  final List<MemberDeclaration> _members;
  final List<AnnotationDeclaration> _annotations;
  final Uri? _sourceLocation;

  /// {@macro standard_enum}
  StandardEnumDeclaration({
    required super.name,
    required super.type,
    required super.element,
    required super.dartType,
    required super.isPublic,
    required super.isSynthetic,
    String? qualifiedName,
    required LibraryDeclaration parentLibrary,
    super.isNullable = false,
    super.typeArguments,
    required List<EnumFieldDeclaration> values,
    List<MemberDeclaration> members = const [],
    List<AnnotationDeclaration> annotations = const [],
    Uri? sourceLocation,
  })  : _parentLibrary = parentLibrary,
        _values = values,
        _members = members,
        _annotations = annotations,
        _sourceLocation = sourceLocation,
        super(
          kind: TypeKind.enumType,
          qualifiedName: '${parentLibrary.getUri()}.$name',
          simpleName: name,
          packageUri: parentLibrary.getUri(),
        );

  @override
  LibraryDeclaration getParentLibrary() => _parentLibrary;

  @override
  List<AnnotationDeclaration> getAnnotations() => List.unmodifiable(_annotations);

  @override
  Uri? getSourceLocation() => _sourceLocation;

  @override
  List<EnumFieldDeclaration> getValues() => List.unmodifiable(_values);

  @override
  List<MemberDeclaration> getMembers() => List.unmodifiable(_members);

  @override
  String getDebugIdentifier() => 'enum_${getName().toLowerCase()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'enum';
    result['name'] = getName();
    
    final parentLibrary = getParentLibrary().toJson();
    if(parentLibrary.isNotEmpty) {
      result['parentLibrary'] = parentLibrary;
    }

    final annotations = getAnnotations().map((a) => a.toJson()).toList();
    if (annotations.isNotEmpty) {
      result['annotations'] = annotations;
    }

    final sourceLocation = getSourceLocation();
    if (sourceLocation != null) {
      result['sourceLocation'] = sourceLocation.toString();
    }

    final values = getValues();
    if (values.isNotEmpty) {
      result['values'] = values;
    }

    final members = getMembers();
    if (members.isNotEmpty) {
      result['members'] = members.map((m) => m.toJson()).toList();
    }

    final typeArguments = getTypeArguments();
    if (typeArguments.isNotEmpty) {
      result['typeArguments'] = typeArguments.map((t) => t.toJson()).toList();
    }

    final declaration = getDeclaration();
    if (declaration != null) {
      result['declaration'] = declaration.toJson();
    }

    result['type'] = getType().toString();
    result['isNullable'] = getIsNullable();
    result['kind'] = getKind().toString();
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getParentLibrary(),
      getAnnotations(),
      getSourceLocation(),
      getType(),
      getIsNullable(),
      getKind(),
      getTypeArguments(),
      getValues(),
      getMembers(),
    ];
  }

  StandardEnumDeclaration copyWith({
    String? name,
    Type? type,
    LibraryDeclaration? parentLibrary,
    bool? isNullable,
    List<LinkDeclaration>? typeArguments,
    List<EnumFieldDeclaration>? values,
    List<MemberDeclaration>? members,
    List<AnnotationDeclaration>? annotations,
    Uri? sourceLocation,
    Element? element,
    DartType? dartType,
    String? qualifiedName,
    bool? isPublic,
    bool? isSynthetic,
  }) {
    return StandardEnumDeclaration(
      name: name ?? getName(),
      type: type ?? getType(),
      isPublic: isPublic ?? getIsPublic(),
      isSynthetic: isSynthetic ?? getIsSynthetic(),
      parentLibrary: parentLibrary ?? getParentLibrary(),
      isNullable: isNullable ?? getIsNullable(),
      typeArguments: typeArguments ?? getTypeArguments(),
      values: values ?? getValues(),
      members: members ?? getMembers(),
      annotations: annotations ?? getAnnotations(),
      sourceLocation: sourceLocation ?? getSourceLocation(),
      element: element ?? getElement(),
      dartType: dartType ?? getDartType(),
      qualifiedName: qualifiedName ?? getQualifiedName(),
    );
  }
}

/// {@template standard_enum_field_declaration}
/// Concrete implementation of [EnumFieldDeclaration] representing an enum value.
///
/// Provides standard reflective access to enum values with efficient storage
/// of the name, value, and parent enum reference.
///
/// {@template standard_enum_field_declaration_features}
/// ## Key Features
/// - Lightweight immutable implementation
/// - Efficient value storage
/// - JSON serialization support
/// - Value equality comparison
/// - Debug identifiers
///
/// ## Typical Usage
/// Used by code generators and runtime systems to represent enum values
/// in reflection contexts.
/// {@endtemplate}
///
/// {@template standard_enum_field_declaration_example}
/// ## Example Creation
/// ```dart
/// enum Status { active, paused }
///
/// final enumDecl = StandardEnumDeclaration(
///   'Status', 
///   Status.values,
///   Status.type
/// );
///
/// final field = StandardEnumFieldDeclaration(
///   'active',
///   Status.active,
///   enumDecl
/// );
/// ```
/// {@endtemplate}
/// {@endtemplate}
final class StandardEnumFieldDeclaration extends StandardSourceDeclaration implements EnumFieldDeclaration {
  /// The runtime value of the enum field
  final dynamic _value;

  /// The enum field position
  final int _position;

  /// Whether this enum field is nullable
  final bool _isNullable;

  /// Creates a standard enum field declaration
  ///
  /// {@template standard_enum_field_constructor}
  /// Parameters:
  /// - [_name]: The declared name of the enum value
  /// - [_value]: The actual enum value instance  
  /// - [_enum]: The parent enum declaration
  ///
  /// All parameters are required and immutable.
  /// {@endtemplate}
  const StandardEnumFieldDeclaration({
    required super.name,
    super.element,
    super.dartType,
    required super.type,
    required super.isPublic,
    required super.isSynthetic,
    required dynamic value,
    required int position,
    required super.libraryDeclaration,
    super.annotations,
    required bool isNullable,
  }) : _value = value, _position = position, _isNullable = isNullable;

  @override
  dynamic getValue() => _value;

  @override
  int getPosition() => _position;

  @override
  bool isNullable() => _isNullable;

  @override
  String getDebugIdentifier() => 'enum_field_${getName().toLowerCase()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'enum_field';
    result['name'] = getName();
    result['value'] = getValue();
    result['type'] = getType().toString();
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getValue(),
      getType(),
    ];
  }
}

/// {@template standard_mixin}
/// A standard implementation of [MixinDeclaration] that provides reflection
/// metadata about a Dart mixin declaration.
///
/// This class exposes the mixin's name, runtime type, type parameters,
/// constraints, fields, methods, and other metadata necessary for
/// runtime introspection of mixin declarations.
///
/// ## Example
///
/// ```dart
/// mixin TimestampMixin on BaseModel {
///   DateTime? createdAt;
///   DateTime? updatedAt;
///   
///   void updateTimestamp() {
///     updatedAt = DateTime.now();
///   }
/// }
///
/// final mixinReflection = StandardReflectedMixin(
///   name: 'TimestampMixin',
///   type: TimestampMixin,
///   parentLibrary: myLibrary,
///   constraints: [baseModelType],
///   fields: [createdAtField, updatedAtField],
///   methods: [updateTimestampMethod],
/// );
///
/// print(mixinReflection.getName()); // TimestampMixin
/// print(mixinReflection.getOnConstraints().length); // 1
/// ```
///
/// This implementation supports all the standard reflection operations
/// including type checking, member access, constraint inspection, and annotation access.
///
/// {@endtemplate}
final class StandardMixinDeclaration extends StandardTypeDeclaration implements MixinDeclaration {
  final LibraryDeclaration _parentLibrary;
  final List<FieldDeclaration> _fields;
  final List<MethodDeclaration> _methods;
  final List<AnnotationDeclaration> _annotations;
  final List<LinkDeclaration> _constraints;
  final Uri? _sourceLocation;

  /// {@macro standard_mixin}
  StandardMixinDeclaration({
    required super.name,
    required super.type,
    required super.element,
    required super.dartType,
    required super.isPublic,
    required super.isSynthetic,
    String? qualifiedName,
    required LibraryDeclaration parentLibrary,
    super.isNullable = false,
    super.typeArguments,
    super.interfaces,
    super.superClass,
    List<FieldDeclaration> fields = const [],
    List<MethodDeclaration> methods = const [],
    List<AnnotationDeclaration> annotations = const [],
    List<LinkDeclaration> constraints = const [],
    Uri? sourceLocation,
  })  : _parentLibrary = parentLibrary,
        _fields = fields,
        _methods = methods,
        _constraints = constraints,
        _annotations = annotations,
        _sourceLocation = sourceLocation,
        super(
          kind: TypeKind.mixinType,
          qualifiedName: '${parentLibrary.getUri()}.$name',
          simpleName: name,
          packageUri: parentLibrary.getUri(),
        );

  @override
  LibraryDeclaration getParentLibrary() => _parentLibrary;

  @override
  List<AnnotationDeclaration> getAnnotations() => List.unmodifiable(_annotations);

  @override
  Uri? getSourceLocation() => _sourceLocation;

  @override
  List<MemberDeclaration> getMembers() {
    return [
      ..._fields,
      ..._methods,
    ];
  }

  @override
  List<FieldDeclaration> getFields() => List.unmodifiable(_fields);

  @override
  List<MethodDeclaration> getMethods() => List.unmodifiable(_methods);

  @override
  List<LinkDeclaration> getConstraints() => List.unmodifiable(_constraints);

  @override
  bool getHasConstraints() => _constraints.isNotEmpty;

  @override
  bool getHasInterfaces() => _interfaces.isNotEmpty;

  @override
  List<FieldDeclaration> getInstanceFields() => _fields.where((field) => !field.getIsStatic()).toList();

  @override
  List<FieldDeclaration> getStaticFields() => _fields.where((field) => field.getIsStatic()).toList();

  @override
  List<MethodDeclaration> getInstanceMethods() => _methods.where((method) => !method.getIsStatic()).toList();

  @override
  List<MethodDeclaration> getStaticMethods() => _methods.where((method) => method.getIsStatic()).toList();

  @override
  FieldDeclaration? getField(String fieldName) {
    try {
      return _fields.firstWhere((field) => field.getName() == fieldName);
    } catch (_) {
      return null;
    }
  }

  @override
  MethodDeclaration? getMethod(String methodName) {
    try {
      return _methods.firstWhere((method) => method.getName() == methodName);
    } catch (_) {
      return null;
    }
  }

  @override
  bool hasField(String fieldName) => getField(fieldName) != null;

  @override
  bool hasMethod(String methodName) => getMethod(methodName) != null;

  /// Creates a copy of this mixin with the specified properties changed.
  StandardMixinDeclaration copyWith({
    String? name,
    Type? type,
    bool? isNullable,
    List<LinkDeclaration>? typeArguments,
    List<AnnotationDeclaration>? annotations,
    Uri? sourceLocation,
    LibraryDeclaration? parentLibrary,
    List<FieldDeclaration>? fields,
    List<MethodDeclaration>? methods,
    List<LinkDeclaration>? constraints,
    List<LinkDeclaration>? interfaces,
    LinkDeclaration? superClass,
    Element? element,
    DartType? dartType,
    String? qualifiedName,
    bool? isPublic,
    bool? isSynthetic,
  }) {
    return StandardMixinDeclaration(
      name: name ?? _name,
      type: type ?? getType(),
      isPublic: isPublic ?? getIsPublic(),
      isSynthetic: isSynthetic ?? getIsSynthetic(),
      isNullable: isNullable ?? _isNullable,
      typeArguments: typeArguments ?? _typeArguments,
      annotations: annotations ?? _annotations,
      sourceLocation: sourceLocation ?? _sourceLocation,
      parentLibrary: parentLibrary ?? _parentLibrary,
      fields: fields ?? _fields,
      methods: methods ?? _methods,
      constraints: constraints ?? _constraints,
      interfaces: interfaces ?? _interfaces,
      superClass: superClass ?? _superClass,
      element: element ?? getElement(),
      dartType: dartType ?? getDartType(),
      qualifiedName: qualifiedName ?? getQualifiedName(),
    );
  }

  @override
  String getDebugIdentifier() => 'mixin_${getName().toLowerCase()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'mixin';
    result['name'] = getName();
    
    final parentLibrary = getParentLibrary().toJson();
    if(parentLibrary.isNotEmpty) {
      result['parentLibrary'] = parentLibrary;
    }

    final annotations = getAnnotations().map((a) => a.toJson()).toList();
    if (annotations.isNotEmpty) {
      result['annotations'] = annotations;
    }

    final sourceLocation = getSourceLocation();
    if (sourceLocation != null) {
      result['sourceLocation'] = sourceLocation.toString();
    }
    
    final constraints = getConstraints().map((c) => c.toJson()).toList();
    if (constraints.isNotEmpty) {
      result['constraints'] = constraints;
    }
    
    final interfaces = getInterfaces().map((i) => i.toJson()).toList();
    if (interfaces.isNotEmpty) {
      result['interfaces'] = interfaces;
    }
    
    final fields = getFields().map((f) => f.toJson()).toList();
    if (fields.isNotEmpty) {
      result['fields'] = fields;
    }
    
    final methods = getMethods().map((m) => m.toJson()).toList();
    if (methods.isNotEmpty) {
      result['methods'] = methods;
    }

    final typeArguments = getTypeArguments().map((t) => t.toJson()).toList();
    if (typeArguments.isNotEmpty) {
      result['typeArguments'] = typeArguments;
    }
    
    final declaration = getDeclaration();
    if (declaration != null) {
      result['declaration'] = declaration.toJson();
    }
    

    final members = getMembers().map((m) => m.toJson()).toList();
    if (members.isNotEmpty) {
      result['members'] = members;
    }
    
    result['type'] = getType().toString();
    result['isNullable'] = getIsNullable();
    result['kind'] = getKind().toString();
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getParentLibrary(),
      getAnnotations(),
      getSourceLocation(),
      getType(),
      getIsNullable(),
      getKind(),
      getTypeArguments(),
      getFields(),
      getMethods(),
      getHasConstraints(),
      getHasInterfaces(),
      getMembers(),
    ];
  }
}

/// {@template standard_class}
/// A standard implementation of [ClassDeclaration] that provides runtime
/// metadata and reflection capabilities for Dart classes.
///
/// This class supports inspection of class properties such as fields,
/// methods, constructors, supertypes, and metadata annotations. It can
/// also instantiate class objects reflectively using a provided factory
/// or by matching a suitable constructor.
///
/// ## Example
///
/// ```dart
/// final reflectedClass = StandardReflectedClass(
///   name: 'MyClass',
///   type: MyClass,
///   parentLibrary: myLibrary,
///   constructors: [myConstructor],
///   fields: [myField],
///   methods: [myMethod],
/// );
///
/// final instance = reflectedClass.newInstance({'value': 42});
/// ```
///
/// In this example, `StandardReflectedClass` provides access to the metadata
/// and creation mechanism of `MyClass`, which can be instantiated via
/// `newInstance()` with a map of named arguments.
///
/// {@endtemplate}
final class StandardClassDeclaration extends StandardTypeDeclaration implements ClassDeclaration {
  final LibraryDeclaration _parentLibrary;
  final List<ConstructorDeclaration> _constructors;
  final List<FieldDeclaration> _fields;
  final List<MethodDeclaration> _methods;
  final List<RecordDeclaration> _records;
  final List<AnnotationDeclaration> _annotations;
  final Uri? _sourceLocation;
  final bool _isAbstract;
  final bool _isMixin;
  final bool _isSealed;
  final bool _isBase;
  final bool _isInterface;
  final bool _isFinal;
  final bool _isRecord;

  /// {@macro standard_class}
  StandardClassDeclaration({
    required super.name,
    required super.type,
    required LibraryDeclaration parentLibrary,
    super.isNullable = false,
    super.typeArguments,
    required super.element,
    required super.dartType,
    String? qualifiedName,
    List<ConstructorDeclaration> constructors = const [],
    List<FieldDeclaration> fields = const [],
    List<MethodDeclaration> methods = const [],
    super.superClass,
    super.interfaces,
    super.mixins,
    List<RecordDeclaration> records = const [],
    List<AnnotationDeclaration> annotations = const [],
    Uri? sourceLocation,
    bool isAbstract = false,
    required super.isPublic,
    required super.isSynthetic,
    bool isMixin = false,
    bool isSealed = false,
    bool isBase = false,
    bool isInterface = false,
    bool isFinal = false,
    bool isRecord = false,
  })  : _parentLibrary = parentLibrary,
        _constructors = constructors,
        _fields = fields,
        _methods = methods,
        _records = records,
        _annotations = annotations,
        _sourceLocation = sourceLocation,
        _isAbstract = isAbstract,
        _isMixin = isMixin,
        _isSealed = isSealed,
        _isBase = isBase,
        _isInterface = isInterface,
        _isFinal = isFinal,
        _isRecord = isRecord,
        super(
          kind: TypeKind.classType,
          qualifiedName: qualifiedName ?? '${parentLibrary.getUri()}.$name',
          simpleName: name,
          packageUri: parentLibrary.getUri(),
        );

  @override
  LibraryDeclaration getParentLibrary() => _parentLibrary;

  @override
  List<AnnotationDeclaration> getAnnotations() => List.unmodifiable(_annotations);

  @override
  Uri? getSourceLocation() => _sourceLocation;

  @override
  List<ConstructorDeclaration> getConstructors() => List.unmodifiable(_constructors);

  @override
  List<FieldDeclaration> getFields() => List.unmodifiable(_fields);

  @override
  List<MethodDeclaration> getMethods() => List.unmodifiable(_methods);

  @override
  List<RecordDeclaration> getRecords() => List.unmodifiable(_records);

  @override
  bool getIsAbstract() => _isAbstract;

  @override
  bool getIsMixin() => _isMixin;

  @override
  bool getIsSealed() => _isSealed;

  @override
  bool getIsBase() => _isBase;

  @override
  bool getIsInterface() => _isInterface;

  @override
  bool getIsFinal() => _isFinal;

  @override
  bool getIsRecord() => _isRecord;

  /// Creates a copy of this class with the specified properties changed.
  StandardClassDeclaration copyWith({
    String? name,
    Type? type,
    LibraryDeclaration? parentLibrary,
    bool? isNullable,
    List<LinkDeclaration>? typeArguments,
    List<ConstructorDeclaration>? constructors,
    List<FieldDeclaration>? fields,
    List<MethodDeclaration>? methods,
    LinkDeclaration? superClass,
    List<LinkDeclaration>? interfaces,
    List<LinkDeclaration>? mixins,
    List<RecordDeclaration>? records,
    List<AnnotationDeclaration>? annotations,
    Uri? sourceLocation,
    bool? isAbstract,
    bool? isMixin,
    bool? isSealed,
    bool? isBase,
    bool? isInterface,
    bool? isFinal,
    bool? isRecord,
    Element? element,
    DartType? dartType,
    String? qualifiedName,
    bool? isPublic,
    bool? isSynthetic
  }) {
    return StandardClassDeclaration(
      name: name ?? getName(),
      type: type ?? getType(),
      isPublic: isPublic ?? getIsPublic(),
      isSynthetic: isSynthetic ?? getIsSynthetic(),
      parentLibrary: parentLibrary ?? _parentLibrary,
      isNullable: isNullable ?? getIsNullable(),
      typeArguments: typeArguments ?? getTypeArguments(),
      constructors: constructors ?? _constructors,
      fields: fields ?? _fields,
      methods: methods ?? _methods,
      superClass: superClass ?? _superClass,
      interfaces: interfaces ?? _interfaces,
      mixins: mixins ?? _mixins,
      records: records ?? _records,
      annotations: annotations ?? _annotations,
      sourceLocation: sourceLocation ?? _sourceLocation,
      isAbstract: isAbstract ?? _isAbstract,
      isMixin: isMixin ?? _isMixin,
      isSealed: isSealed ?? _isSealed,
      isBase: isBase ?? _isBase,
      isInterface: isInterface ?? _isInterface,
      element: element ?? getElement(),
      dartType: dartType ?? getDartType(),
      qualifiedName: qualifiedName ?? getQualifiedName(),
      isFinal: isFinal ?? _isFinal,
      isRecord: isRecord ?? _isRecord,
    );
  }

  @override
  List<MemberDeclaration> getMembers() {
    return [
      ..._constructors,
      ..._fields,
      ..._methods,
    ];
  }

  @override
  dynamic newInstance(Map<String, dynamic> arguments) {
    // Try to find a suitable constructor
    ConstructorDeclaration? constructor;
    if (arguments.isEmpty) {
      // Look for default constructor
      constructor = _constructors.firstWhere(
        (c) => c.getName().isEmpty && c.getParameters().isEmpty,
        orElse: () => _constructors.firstWhere(
          (c) => c.getParameters().every((p) => p.getIsNullable()),
          orElse: () => throw BuildException('No suitable constructor found for $_name with no arguments'),
        ),
      );
    } else {
      // Look for constructor that matches the provided arguments
      constructor = _constructors.firstWhere(
        (c) => _constructorMatches(c, arguments),
        orElse: () => throw BuildException('No suitable constructor found for $_name with arguments: ${arguments.keys}'),
      );
    }
    return constructor.newInstance(arguments);
  }

  @override
  String getDebugIdentifier() => 'class_${getName().toLowerCase()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'class';
    result['name'] = getName();
    
    final parentLibrary = getParentLibrary().toJson();
    if(parentLibrary.isNotEmpty) {
      result['parentLibrary'] = parentLibrary;
    }

    final annotations = getAnnotations().map((a) => a.toJson()).toList();
    if (annotations.isNotEmpty) {
      result['annotations'] = annotations;
    }

    final sourceLocation = getSourceLocation();
    if (sourceLocation != null) {
      result['sourceLocation'] = sourceLocation.toString();
    }

    result['type'] = getType().toString();
    result['isNullable'] = getIsNullable();
    result['kind'] = getKind().toString();

    final superClass = getSuperClass()?.toJson();
    if (superClass != null) {
      result['superClass'] = superClass;
    }

    final interfaces = getInterfaces();
    if (interfaces.isNotEmpty) {
      result['interfaces'] = interfaces.map((i) => i.toJson()).toList();
    }

    final mixins = getMixins();
    if (mixins.isNotEmpty) {
      result['mixins'] = mixins.map((m) => m.toJson()).toList();
    }

    final records = getRecords();
    if (records.isNotEmpty) {
      result['records'] = records.map((r) => r.toJson()).toList();
    }

    final typeArguments = getTypeArguments();
    if (typeArguments.isNotEmpty) {
      result['typeArguments'] = typeArguments.map((t) => t.toJson()).toList();
    }

    final constructors = getConstructors();
    if (constructors.isNotEmpty) {
      result['constructors'] = constructors.map((t) => t.toJson()).toList();
    }

    result['isAbstract'] = getIsAbstract();
    result['isMixin'] = getIsMixin();
    result['isSealed'] = getIsSealed();
    result['isBase'] = getIsBase();
    result['isInterface'] = getIsInterface();
    result['isFinal'] = getIsFinal();
    result['isRecord'] = getIsRecord();

    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getParentLibrary(),
      getAnnotations(),
      getSourceLocation(),
      getType(),
      getIsNullable(),
      getKind(),
      getTypeArguments(),
      getSuperClass(),
      getInterfaces(),
      getMixins(),
      getRecords(),
      getConstructors(),
      getIsAbstract(),
      getIsMixin(),
      getIsSealed(),
      getIsBase(),
      getIsInterface(),
      getIsFinal(),
      getIsRecord(),
    ];
  }
}

bool _constructorMatches(ConstructorDeclaration constructor, Map<String, dynamic> arguments) {
  final params = constructor.getParameters();
  // Check if all required parameters are provided
  for (final param in params) {
    if (!param.getIsNullable() && !arguments.containsKey(param.getName())) {
      return false;
    }
  }
  // Check if all provided arguments have corresponding parameters
  for (final argName in arguments.keys) {
    if (!params.any((p) => p.getName() == argName)) {
      return false;
    }
  }
  return true;
}

/// {@template standard_parameter}
/// A standard implementation of [ParameterDeclaration] used to represent metadata
/// about a parameter in a Dart function, method, or constructor.
///
/// This class provides information such as the parameter name, type,
/// whether it is optional or named, and whether it has a default value.
///
/// ## Example
/// ```dart
/// final param = StandardReflectedParameter(
///   name: 'count',
///   type: intType,
///   isOptional: true,
///   hasDefaultValue: true,
///   defaultValue: 5,
/// );
///
/// print(param.getName()); // "count"
/// print(param.getIsOptional()); // true
/// print(param.getDefaultValue()); // 5
/// ```
/// {@endtemplate}
final class StandardParameterDeclaration extends StandardSourceDeclaration implements ParameterDeclaration {
  final LinkDeclaration _typeDeclaration;
  final bool _isNullable;
  final bool _isNamed;
  final bool _hasDefaultValue;
  final dynamic _defaultValue;
  final int _index;
  final MemberDeclaration _memberDeclaration;

  /// {@macro standard_parameter}
  const StandardParameterDeclaration({
    required super.name,
    super.element,
    super.dartType,
    required super.type,
    required super.libraryDeclaration,
    required LinkDeclaration typeDeclaration,
    bool isNullable = false,
    bool isNamed = false,
    required super.isPublic,
    required super.isSynthetic,
    bool hasDefaultValue = false,
    dynamic defaultValue,
    required int index,
    required MemberDeclaration memberDeclaration,
    super.sourceLocation,
    super.annotations,
  })  : _typeDeclaration = typeDeclaration,
        _isNullable = isNullable,
        _isNamed = isNamed,
        _memberDeclaration = memberDeclaration,
        _hasDefaultValue = hasDefaultValue,
        _defaultValue = defaultValue,
        _index = index;

  @override
  LinkDeclaration getLinkDeclaration() => _typeDeclaration;

  @override
  bool getIsNullable() => _isNullable;

  @override
  bool getIsNamed() => _isNamed;

  @override
  bool getHasDefaultValue() => _hasDefaultValue;

  @override
  dynamic getDefaultValue() => _defaultValue;

  @override
  int getIndex() => _index;

  @override
  MemberDeclaration getMemberDeclaration() => _memberDeclaration;

  @override
  String getDebugIdentifier() => 'parameter_${getName().toLowerCase()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'parameter';
    result['name'] = getName();

    result['index'] = getIndex();
    result['isOptional'] = getIsNullable();
    result['isNamed'] = getIsNamed();
    result['hasDefaultValue'] = getHasDefaultValue();

    final defaultValue = getDefaultValue();
    if(defaultValue != null) {
      result['defaultValue'] = defaultValue.toString();
    }

    final parentLibrary = getParentLibrary().toJson();
    if(parentLibrary.isNotEmpty) {
      result['parentLibrary'] = parentLibrary;
    }

    final sourceLocation = getSourceLocation();
    if(sourceLocation != null) {
      result['sourceLocation'] = sourceLocation.toString();
    }

    final annotations = getAnnotations().map((a) => a.toJson()).toList();
    if(annotations.isNotEmpty) {
      result['annotations'] = annotations;
    }
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getParentLibrary(),
      getAnnotations(),
      getSourceLocation(),
      getType(),
      getIsNullable(),
      getIsNamed(),
      getHasDefaultValue(),
      getDefaultValue(),
      getIndex(),
      getMemberDeclaration(),
    ];
  }
}

/// {@template standard_method}
/// A standard implementation of [MethodDeclaration] representing a method,
/// constructor, getter, or setter in a Dart class or library.
///
/// It exposes metadata such as the method name, return type, parameters,
/// modifiers (e.g., `static`, `abstract`, `getter`, `setter`, `const`, `factory`),
/// and annotations. It can optionally support dynamic invocation using the
/// [invoke] function.
///
/// ## Example
/// ```dart
/// final method = StandardReflectedMethod(
///   name: 'greet',
///   parentLibrary: myLibrary,
///   returnType: stringType,
///   parameters: [
///     StandardReflectedParameter(name: 'name', type: stringType),
///   ],
/// );
///
/// final result = method.invoke(null, {'name': 'Eve'});
/// print(result); // "Hello, Eve"
/// ```
///
/// This class is commonly used in reflective systems to invoke methods
/// dynamically and to analyze method structures.
///
/// > Note: [invoke] throws if no `_invoker` function is supplied or if the
///   method's static/non-static requirements are not met.
/// {@endtemplate}
final class StandardMethodDeclaration extends StandardSourceDeclaration implements MethodDeclaration {
  LinkDeclaration returnType;
  List<ParameterDeclaration> parameters;
  bool isStatic;
  bool isAbstract;
  bool isGetter;
  bool isSetter;
  LinkDeclaration? parentClass;
  bool isConst;
  bool isFactory;

  /// {@macro standard_method}
  StandardMethodDeclaration({
    required super.name,
    required super.element,
    required super.dartType,
    required super.isPublic,
    required super.isSynthetic,
    required super.type,
    required super.libraryDeclaration,
    required this.returnType,
    this.parameters = const [],
    super.sourceLocation,
    super.annotations,
    this.isStatic = false,
    this.isAbstract = false,
    this.isGetter = false,
    this.isSetter = false,
    this.parentClass,
    this.isConst = false,
    this.isFactory = false,
  });

  @override
  LinkDeclaration getReturnType() => returnType;

  @override
  List<ParameterDeclaration> getParameters() => List.unmodifiable(parameters);

  @override
  bool getIsStatic() => isStatic;

  @override
  bool getIsAbstract() => isAbstract;

  @override
  bool getIsGetter() => isGetter;

  @override
  bool getIsSetter() => isSetter;

  @override
  dynamic invoke(dynamic instance, Map<String, dynamic> arguments) {
    InstanceArgument arg = _resolveArgument(arguments, parameters, "${parentClass?.getName() ?? "#"}$_name");

    if (isStatic) {
      return Runtime.getRuntimeResolver().invokeMethod(instance, _name, args: arg.getPositional(), namedArgs: arg.getNamed());
    } else {
      return Runtime.getRuntimeResolver().invokeMethod(instance, _name, args: arg.getPositional(), namedArgs: arg.getNamed());
    }
  }
  
  @override
  bool getIsConst() => isConst;
  
  @override
  bool getIsFactory() => isFactory;
  
  @override
  LinkDeclaration? getParentClass() => parentClass;

  @override
  String getDebugIdentifier() => 'method_${getName().toLowerCase()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'method';
    result['name'] = getName();
    
    final parentLibrary = getParentLibrary().toJson();
    if(parentLibrary.isNotEmpty) {
      result['parentLibrary'] = parentLibrary;
    }

    final annotations = getAnnotations().map((a) => a.toJson()).toList();
    if (annotations.isNotEmpty) {
      result['annotations'] = annotations;
    }

    final sourceLocation = getSourceLocation();
    if (sourceLocation != null) {
      result['sourceLocation'] = sourceLocation.toString();
    }

    final returnType = getReturnType().toJson();
    if (returnType.isNotEmpty) {
      result['returnType'] = returnType;
    }

    final parameters = getParameters().map((p) => p.toJson()).toList();
    if (parameters.isNotEmpty) {
      result['parameters'] = parameters;
    }

    result['isGetter'] = getIsGetter();
    result['isSetter'] = getIsSetter();
    result['isFactory'] = getIsFactory();
    result['isConst'] = getIsConst();
    result['isStatic'] = getIsStatic();
    result['isAbstract'] = getIsAbstract();

    final parentClass = getParentClass()?.toJson();
    if (parentClass != null) {
      result['parentClass'] = parentClass;
    }
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getParentLibrary(),
      getAnnotations(),
      getSourceLocation(),
      getParentClass(),
      getIsStatic(),
      getIsAbstract(),
      getReturnType(),
      getParameters(),
      getIsGetter(),
      getIsSetter(),
      getIsFactory(),
      getIsConst(),
    ];
  }
}

/// Resolves arguments for a method invocation.
/// 
/// Takes a map of arguments and a list of parameters, and returns an [InstanceArgument]
/// object containing the resolved positional and named arguments.
/// 
/// The function also checks for the following:
/// 
/// * If the number of positional arguments provided matches the number of required positional arguments.
/// * If the number of positional arguments provided does not exceed the total number of positional arguments.
/// * If all named arguments provided are valid parameters.
/// 
/// If any of these checks fail, an [BuildException] is thrown.
InstanceArgument _resolveArgument(Map<String, dynamic> arguments, List<ParameterDeclaration> parameters, String location) {
  InstanceArgument result = InstanceArgument();

  final positional = <dynamic>[];
  final named = <String, dynamic>{};
  final argKeys = arguments.keys.toList();

  // Separate positional and named arguments based on parameter definitions
  for (int i = 0; i < parameters.length; i++) {
    final param = parameters[i];
    final name = param.getName();
    
    if (param.getIsNamed()) {
      // Named parameter
      if (arguments.containsKey(name)) {
        named[name] = arguments[name];
      } else if (!param.getIsNullable()) {
        // Required named parameter is missing
        throw BuildException('Missing required named parameter: $name in $location');
      }
    } else {
      // Positional parameter
      if (argKeys.contains(name)) {
        positional.add(arguments[name]);
      } else if (argKeys.isNotEmpty && i < argKeys.length) {
        final key = argKeys.elementAt(i);
        final keyInt = int.tryParse(key);

        if(keyInt != null && keyInt == param.getIndex()) {
          positional.add(arguments[key]);
        } else if(!param.getIsNullable()) {
          // Required positional parameter is missing
          throw BuildException('Missing required positional parameter: $name in $location');
        }
      }
    }
  }
  
  // Check if we have the right number of positional arguments
  final requiredPositionalCount = parameters.where((p) => !p.getIsNamed() && !p.getIsNullable()).length;
  final totalPositionalCount = parameters.where((p) => !p.getIsNamed()).length;
      
  if (positional.length < requiredPositionalCount) {
    throw BuildException(
      'Not enough positional arguments provided. Expected at least $requiredPositionalCount, got ${positional.length} in $location'
    );
  }
  
  if (positional.length > totalPositionalCount) {
    throw BuildException(
      'Too many positional arguments provided. Expected at most $totalPositionalCount, got ${positional.length} in $location'
    );
  }
  
  // Check for unexpected named arguments
  for (final argName in arguments.keys) {
    final hasMatchingParam = parameters.any((p) => p.getName() == argName);
    if (!hasMatchingParam) {
      throw BuildException('Unexpected argument: $argName in $location');
    }
  }

  result.setNamed(named);
  result.setPositional(positional);

  return result;
}

class InstanceArgument {
  InstanceArgument();

  Map<String, dynamic> _named = {};
  List<dynamic> _positional = [];

  void setNamed(Map<String, dynamic> result) {
    _named = result;
  }

  Map<String, dynamic> getNamed() => _named;

  void setPositional(List<dynamic> result) {
    _positional = result;
  }

  List<dynamic> getPositional() => _positional;
}

/// {@template standard_library}
/// A standard implementation of [LibraryDeclaration] that provides access to
/// all top-level declarations in a Dart library.
///
/// This class encapsulates information about a Dart library such as:
/// - The URI of the library
/// - The parent package
/// - Its source location (if available)
/// - Its annotations
/// - All top-level declarations (e.g., classes, enums, typedefs, functions, fields, records)
///
/// You can use this class to inspect a library's structure reflectively, enabling
/// dynamic introspection for frameworks, compilers, and development tools.
///
/// ## Example
/// ```dart
/// final lib = StandardReflectedLibrary(
///   uri: 'package:my_app/src/my_library.dart',
///   parentPackage: myPackage,
///   declarations: [
///     myReflectedClass,
///     myReflectedEnum,
///     myTopLevelFunction,
///   ],
/// );
///
/// print(lib.getUri()); // "package:my_app/src/my_library.dart"
/// print(lib.getClasses().length); // 1
/// print(lib.getTopLevelMethods().first.getName()); // e.g., "myTopLevelFunction"
/// ```
/// {@endtemplate}
final class StandardLibraryDeclaration extends LibraryDeclaration with EqualsAndHashCode {
  final String _uri;
  final DartType? _dartType;
  final Element? _element;
  final Package _parentPackage;
  final List<AnnotationDeclaration> _annotations;
  final Uri? _sourceLocation;
  final bool _isPublic;
  final bool _isSynthetic;
  final List<SourceDeclaration> _declarations;

  /// {@macro standard_library}
  StandardLibraryDeclaration({
    required String uri,
    DartType? dartType,
    Element? element,
    required Package parentPackage,
    required List<SourceDeclaration> declarations,
    List<AnnotationDeclaration> annotations = const [],
    Uri? sourceLocation,
    required bool isPublic,
    required bool isSynthetic,
  })  : _uri = uri,
        _isPublic = isPublic,
        _isSynthetic = isSynthetic,
        _dartType = dartType,
        _element = element,
        _parentPackage = parentPackage,
        _declarations = declarations,
        _annotations = annotations,
        _sourceLocation = sourceLocation;

  @override
  String getUri() => _uri;

  @override
  bool getIsPublic() => _isPublic;

  @override
  bool getIsSynthetic() => _isSynthetic;

  @override
  DartType? getDartType() => _dartType;

  @override
  Element? getElement() => _element;

  @override
  List<AnnotationDeclaration> getAnnotations() => List.unmodifiable(_annotations);

  @override
  Uri? getSourceLocation() => _sourceLocation;

  @override
  LibraryDeclaration getParentLibrary() => this;

  @override
  List<SourceDeclaration> getDeclarations() => List.unmodifiable(_declarations);

  @override
  List<ClassDeclaration> getClasses() => _declarations.whereType<ClassDeclaration>().toList();

  @override
  List<EnumDeclaration> getEnums() => _declarations.whereType<EnumDeclaration>().toList();

  @override
  List<TypedefDeclaration> getTypedefs() => _declarations.whereType<TypedefDeclaration>().toList();

  @override
  List<ExtensionDeclaration> getExtensions() => _declarations.whereType<ExtensionDeclaration>().toList();

  @override
  List<MethodDeclaration> getTopLevelMethods() => _declarations.whereType<MethodDeclaration>().where((m) => m.getParentClass() == null).toList();

  @override
  List<FieldDeclaration> getTopLevelFields() => _declarations.whereType<FieldDeclaration>().where((f) => f.getParentClass() == null).toList();
  
  @override
  Package getPackage() => _parentPackage;

  @override
  Type getType() => runtimeType;
  
  @override
  List<RecordFieldDeclaration> getTopLevelRecordFields() => _declarations.whereType<RecordFieldDeclaration>().toList();
  
  @override
  List<RecordDeclaration> getTopLevelRecords() => _declarations.whereType<RecordDeclaration>().toList();

  /// Creates a copy of this library with the specified properties changed.
  StandardLibraryDeclaration copyWith({
    String? uri,
    Package? parentPackage,
    List<SourceDeclaration>? declarations,
    List<AnnotationDeclaration>? annotations,
    Uri? sourceLocation,
    DartType? dartType,
    Element? element,
    bool? isPublic,
    bool? isSynthetic,
  }) {
    return StandardLibraryDeclaration(
      uri: uri ?? _uri,
      dartType: dartType ?? _dartType,
      isPublic: isPublic ?? getIsPublic(),
      isSynthetic: isSynthetic ?? getIsSynthetic(),
      element: element ?? _element,
      parentPackage: parentPackage ?? _parentPackage,
      declarations: declarations ?? _declarations,
      annotations: annotations ?? _annotations,
      sourceLocation: sourceLocation ?? _sourceLocation,
    );
  }

  @override
  String getDebugIdentifier() => 'library_${getName().toLowerCase()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'library';
    result['name'] = getName();
    
    final package = getPackage().toJson();
    if(package.isNotEmpty) {
      result['package'] = package;
    }

    result['uri'] = getUri();

    final sourceLocation = getSourceLocation();
    if (sourceLocation != null) {
      result['sourceLocation'] = sourceLocation.toString();
    }

    final annotations = getAnnotations().map((a) => a.toJson()).toList();
    if (annotations.isNotEmpty) {
      result['annotations'] = annotations;
    }
    
    final declarations = getDeclarations().map((d) => d.toJson()).toList();
    if (declarations.isNotEmpty) {
      result['declarations'] = declarations;
    }
    
    final classes = getClasses().map((c) => c.toJson()).toList();
    if (classes.isNotEmpty) {
      result['classes'] = classes;
    }
    
    final enums = getEnums().map((e) => e.toJson()).toList();
    if (enums.isNotEmpty) {
      result['enums'] = enums;
    }
    
    final typedefs = getTypedefs().map((t) => t.toJson()).toList();
    if (typedefs.isNotEmpty) {
      result['typedefs'] = typedefs;
    }
    
    final extensions = getExtensions().map((e) => e.toJson()).toList();
    if (extensions.isNotEmpty) {
      result['extensions'] = extensions;
    }
    
    final topLevelMethods = getTopLevelMethods().map((m) => m.toJson()).toList();
    if (topLevelMethods.isNotEmpty) {
      result['topLevelMethods'] = topLevelMethods;
    }
    
    final topLevelFields = getTopLevelFields().map((f) => f.toJson()).toList();
    if (topLevelFields.isNotEmpty) {
      result['topLevelFields'] = topLevelFields;
    }
    
    final topLevelRecords = getTopLevelRecords().map((r) => r.toJson()).toList();
    if (topLevelRecords.isNotEmpty) {
      result['topLevelRecords'] = topLevelRecords;
    }
    
    final topLevelRecordFields = getTopLevelRecordFields().map((rf) => rf.toJson()).toList();
    if (topLevelRecordFields.isNotEmpty) {
      result['topLevelRecordFields'] = topLevelRecordFields;
    }
    
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getPackage(),
      getUri(),
      getSourceLocation(),
      getAnnotations(),
      getTopLevelMethods(),
      getTopLevelFields(),
      getTopLevelRecords(),
      getTopLevelRecordFields(),
      getClasses(),
      getEnums(),
      getTypedefs(),
      getExtensions(),
      getDeclarations(),
    ];
  }
}

/// {@template standard_field}
/// A standard implementation of [FieldDeclaration] that provides metadata and 
/// runtime access to class fields in a reflective system.
///
/// This class encapsulates all the necessary metadata about a Dart class field, 
/// such as its name, type, annotations, modifiers (`final`, `const`, `static`, etc.), 
/// and optionally supports runtime value access through provided getter/setter functions.
///
/// ## Example
/// ```dart
/// final field = StandardReflectedField(
///   name: 'age',
///   type: IntReflectedType(),
///   parentLibrary: myLibrary,
///   parentClass: myClass,
/// );
///
/// print(field.getName()); // age
/// print(field.getType()); // ReflectedType for int
/// print(field.getValue(someInstance)); // gets age
/// field.setValue(someInstance, 25); // sets age
/// ```
/// {@endtemplate}
final class StandardFieldDeclaration extends StandardSourceDeclaration implements FieldDeclaration {
  final LinkDeclaration? _parentClass;
  final LinkDeclaration _typeDeclaration;
  final bool _isFinal;
  final bool _isConst;
  final bool _isLate;
  final bool _isStatic;
  final bool _isAbstract;
  final bool _isNullable;

  /// {@macro standard_field}
  const StandardFieldDeclaration({
    required super.name,
    required super.type,
    super.dartType,
    super.element,
    required super.libraryDeclaration,
    LinkDeclaration? parentClass,
    required LinkDeclaration linkDeclaration,
    super.annotations,
    required super.isPublic,
    required super.isSynthetic,
    super.sourceLocation,
    bool isFinal = false,
    bool isConst = false,
    bool isLate = false,
    bool isStatic = false,
    bool isAbstract = false,
    bool isNullable = false,
  })  : _parentClass = parentClass,
        _typeDeclaration = linkDeclaration,
        _isFinal = isFinal,
        _isConst = isConst,
        _isNullable = isNullable,
        _isLate = isLate,
        _isStatic = isStatic,
        _isAbstract = isAbstract;

  @override
  LinkDeclaration? getParentClass() => _parentClass;

  @override
  LinkDeclaration getLinkDeclaration() => _typeDeclaration;

  @override
  bool getIsFinal() => _isFinal;

  @override
  bool getIsConst() => _isConst;

  @override
  bool getIsLate() => _isLate;

  @override
  bool getIsStatic() => _isStatic;

  @override
  bool getIsAbstract() => _isAbstract;

  @override
  bool isNullable() => _isNullable;

  @override
  dynamic getValue(dynamic instance) {
    if (_isStatic) {
      return Runtime.getRuntimeResolver().getValue(instance, _name);
    } else {
      return Runtime.getRuntimeResolver().getValue(instance, _name);
    }
  }

  @override
  void setValue(dynamic instance, dynamic value) {
    if ((_isFinal || _isConst) && !_isLate) {
      throw BuildException('Cannot set value on final/const field $_name');
    }
    
    if (_isStatic) {
      Runtime.getRuntimeResolver().setValue(instance, _name, value);
    } else {
      Runtime.getRuntimeResolver().setValue(instance, _name, value);
    }
  }

  @override
  String getDebugIdentifier() => 'field_${getParentClass()?.getName()}.${getName()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'field';
    result['name'] = getName();

    final parentLibrary = getParentLibrary().toJson();
    if(parentLibrary.isNotEmpty) {
      result['parentLibrary'] = parentLibrary;
    }
    
    final parentClass = getParentClass()?.toJson();
    if(parentClass != null) {
      result['parentClass'] = parentClass;
    }
    
    final annotations = getAnnotations().map((a) => a.toJson()).toList();
    if(annotations.isNotEmpty) {
      result['annotations'] = annotations;
    }
    
    final sourceLocation = getSourceLocation();
    if(sourceLocation != null) {
      result['sourceLocation'] = sourceLocation.toString();
    }
    
    result['isFinal'] = getIsFinal();
    result['isConst'] = getIsConst();
    result['isLate'] = getIsLate();
    result['isStatic'] = getIsStatic();
    result['isAbstract'] = getIsAbstract();
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getParentLibrary(),
      getAnnotations(),
      getSourceLocation(),
      getParentClass(),
      getIsStatic(),
      getIsAbstract(),
      getType(),
      getIsFinal(),
      getIsConst(),
      getIsLate(),
    ];
  }
}

/// {@template standard_extension}
/// A standard implementation of [ExtensionDeclaration] that represents metadata
/// about a Dart extension in a reflected form.
///
/// This class is part of a reflection system and is typically used to inspect
/// Dart extensions at runtime. It encapsulates key metadata such as the extension's
/// name, the type it extends, its members, annotations, and the source location
/// if available.
///
/// ## Example
/// ```dart
/// final extension = StandardReflectedExtension(
///   name: 'StringUtils',
///   parentLibrary: myLibrary,
///   extendedType: ReflectedType.of(String),
///   annotations: [Deprecated('Use new API')],
///   members: [
///     StandardReflectedMethod(...),
///     StandardReflectedField(...),
///   ],
/// );
///
/// print(extension.getName()); // StringUtils
/// print(extension.getExtendedType().getName()); // String
/// ```
///
/// Use this class when building tooling, analyzers, or serializers that need
/// to reason about or transform Dart code at runtime.
/// {@endtemplate}
final class StandardExtensionDeclaration extends StandardSourceDeclaration implements ExtensionDeclaration {
  final TypeDeclaration _extendedType;
  final List<MemberDeclaration> _members;

  /// {@macro standard_extension}
  const StandardExtensionDeclaration({
    required super.name,
    required super.type,
    required super.isPublic,
    required super.isSynthetic,
    required super.libraryDeclaration,
    required TypeDeclaration extendedType,
    super.annotations,
    super.sourceLocation,
    List<MemberDeclaration> members = const [],
  })  : _extendedType = extendedType, _members = members;

  @override
  TypeDeclaration getExtendedType() => _extendedType;

  @override
  List<MemberDeclaration> getMembers() => List.unmodifiable(_members);

  @override
  String getDebugIdentifier() => 'extension_${getName().toLowerCase()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'extension';
    result['name'] = getName();

    final parentLibrary = getParentLibrary().toJson();
    if(parentLibrary.isNotEmpty) {
      result['parentLibrary'] = parentLibrary;
    }
    
    final annotations = getAnnotations().map((a) => a.toJson()).toList();
    if(annotations.isNotEmpty) {
      result['annotations'] = annotations;
    }
    
    final sourceLocation = getSourceLocation();
    if(sourceLocation != null) {
      result['sourceLocation'] = sourceLocation.toString();
    }
    
    final extendedType = getExtendedType().toJson();
    if(extendedType.isNotEmpty) {
      result['extendedType'] = extendedType;
    }
    
    final members = getMembers().map((m) => m.toJson()).toList();
    if(members.isNotEmpty) {
      result['members'] = members;
    }
    
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getParentLibrary(),
      getAnnotations(),
      getSourceLocation(),
      getExtendedType(),
      getMembers(),
    ];
  }
}

/// {@template standard_constructor}
/// A standard implementation of [ConstructorDeclaration] that provides
/// metadata and instantiation logic for class constructors.
///
/// This class encapsulates the constructor name, owning class and library,
/// parameter list, annotations, and information such as whether the constructor
/// is a `const` or a `factory`. It also optionally provides a factory function
/// to support reflective instantiation.
///
/// ## Example
///
/// ```dart
/// final constructor = StandardReflectedConstructor(
///   name: 'MyClass',
///   parentLibrary: myLibrary,
///   parentClass: myClass,
///   isConst: true,
///   parameters: [
///     StandardReflectedParameter(name: 'value', type: intType),
///   ],
/// );
///
/// final instance = constructor.newInstance({'value': 42});
/// ```
///
/// This creates a reflective representation of a `MyClass` constructor and
/// uses it to create a new instance.
///
/// {@endtemplate}
final class StandardConstructorDeclaration extends StandardSourceDeclaration implements ConstructorDeclaration {
  LinkDeclaration parentClass;
  List<ParameterDeclaration> parameters;
  bool isFactory;
  bool isConst;

  /// {@macro standard_constructor}
  StandardConstructorDeclaration({
    required super.name,
    required super.type,
    super.element,
    super.dartType,
    required super.isPublic,
    required super.isSynthetic,
    required super.libraryDeclaration,
    required this.parentClass,
    super.annotations,
    this.parameters = const [],
    super.sourceLocation,
    this.isFactory = false,
    this.isConst = false,
  });

  @override
  LinkDeclaration getParentClass() => parentClass;

  @override
  List<ParameterDeclaration> getParameters() => List.unmodifiable(parameters);

  @override
  bool getIsFactory() => isFactory;

  @override
  bool getIsConst() => isConst;

  @override
  bool getIsStatic() => false; // Constructors are never static

  @override
  bool getIsAbstract() => false; // Constructors are never abstract

  @override
  T newInstance<T>(Map<String, dynamic> arguments) {
    InstanceArgument arg = _resolveArgument(arguments, parameters, "${parentClass.getName()}$_name");

    return Runtime.getRuntimeResolver().newInstance<T>(_name, parentClass.getType(), arg.getPositional(), arg.getNamed());
  }

  @override
  String getDebugIdentifier() => 'constructor_${getParentClass().getName()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'constructor';
    result['name'] = getName();

    final parentLibrary = getParentLibrary().toJson();
    if(parentLibrary.isNotEmpty) {
      result['parentLibrary'] = parentLibrary;
    }
    
    final annotations = getAnnotations().map((a) => a.toJson()).toList();
    if(annotations.isNotEmpty) {
      result['annotations'] = annotations;
    }
    
    final sourceLocation = getSourceLocation();
    if(sourceLocation != null) {
      result['sourceLocation'] = sourceLocation.toString();
    }

    result['parentClass'] = getParentClass().toJson();
    
    final parameters = getParameters().map((p) => p.toJson()).toList();
    if(parameters.isNotEmpty) {
      result['parameters'] = parameters;
    }
    
    result['isFactory'] = getIsFactory();
    result['isConst'] = getIsConst();
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getParentLibrary(),
      getAnnotations(),
      getSourceLocation(),
      getParentClass(),
      getIsStatic(),
      getIsAbstract(),
      getIsFactory(),
      getIsConst(),
    ];
  }
}

/// {@template standard_annotation}
/// A standard implementation of [AnnotationDeclaration] that provides
/// reflection metadata about an annotation applied to a declaration.
///
/// This class holds the type of the annotation, the actual arguments
/// passed to the annotation constructor, and the corresponding types
/// of those arguments.
///
/// ## Example
///
/// ```dart
/// final annotation = StandardReflectedAnnotation(
///   type: reflectedTypeOf(MyAnnotation),
///   arguments: {'value': 123},
///   argumentTypes: {'value': reflectedTypeOf(int)},
/// );
///
/// final type = annotation.getType(); // ReflectedType of MyAnnotation
/// final args = annotation.getArguments(); // {'value': 123}
/// final argTypes = annotation.getArgumentTypes(); // {'value': ReflectedType of int}
/// ```
///
/// This allows tools and frameworks to inspect annotations applied to
/// classes, methods, or fields at runtime with full access to metadata.
///
/// {@endtemplate}
final class StandardAnnotationDeclaration extends StandardEntityDeclaration implements AnnotationDeclaration {
  final LinkDeclaration _typeDeclaration;
  final dynamic _instance;
  final Map<String, AnnotationFieldDeclaration> _fields;
  final Map<String, dynamic> _userProvidedValues;

  /// {@macro standard_annotation}
  const StandardAnnotationDeclaration({
    required LinkDeclaration typeDeclaration,
    required dynamic instance,
    required super.dartType,
    required super.isPublic,
    required super.isSynthetic,
    super.element,
    required super.name,
    required super.type,
    required Map<String, AnnotationFieldDeclaration> fields,
    required Map<String, dynamic> userProvidedValues,
  })  : _typeDeclaration = typeDeclaration,
        _instance = instance,
        _fields = fields,
        _userProvidedValues = userProvidedValues;

  @override
  LinkDeclaration getLinkDeclaration() => _typeDeclaration;

  @override
  dynamic getInstance() => _instance;

  @override
  Map<String, dynamic> getUserProvidedValues() => Map.unmodifiable(_userProvidedValues);

  @override
  List<AnnotationFieldDeclaration> getFields() => List.unmodifiable(_fields.values.toList());

  @override
  Map<String, AnnotationFieldDeclaration> getMappedFields() => Map.unmodifiable(_fields);

  @override
  AnnotationFieldDeclaration? getField(String name) => _fields[name];

  @override
  List<String> getFieldNames() => _fields.keys.toList();

  @override
  Map<String, AnnotationFieldDeclaration> getFieldsWithDefaults() {
    final fieldsWithDefaults = <String, AnnotationFieldDeclaration>{};
    for (final entry in _fields.entries) {
      if (entry.value.hasDefaultValue()) {
        fieldsWithDefaults[entry.key] = entry.value;
      }
    }
    return Map.unmodifiable(fieldsWithDefaults);
  }

  @override
  Map<String, AnnotationFieldDeclaration> getFieldsWithUserValues() {
    final fieldsWithUserValues = <String, AnnotationFieldDeclaration>{};
    for (final entry in _fields.entries) {
      if (entry.value.hasUserProvidedValue()) {
        fieldsWithUserValues[entry.key] = entry.value;
      }
    }
    return Map.unmodifiable(fieldsWithUserValues);
  }

  @override
  String getDebugIdentifier() => 'annotation_${getLinkDeclaration().getName()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'annotation';

    final fields = getFields().map((f) => f.toJson()).toList();
    if(fields.isNotEmpty) {
      result['fields'] = fields;
    }

    final userProvidedValues = getUserProvidedValues();
    if(userProvidedValues.isNotEmpty) {
      result['userProvidedValues'] = userProvidedValues.map((key, value) => MapEntry(key, value.toString()));
    }

    final mappedFields = getMappedFields().map((key, value) => MapEntry(key, value.toJson()));
    if(mappedFields.isNotEmpty) {
      result['mappedFields'] = mappedFields;
    }

    final fieldNames = getFieldNames();
    if(fieldNames.isNotEmpty) {
      result['fieldNames'] = fieldNames;
    }

    final fieldsWithDefaults = getFieldsWithDefaults().map((key, value) => MapEntry(key, value.toJson()));
    if(fieldsWithDefaults.isNotEmpty) {
      result['fieldsWithDefaults'] = fieldsWithDefaults;
    }

    final fieldsWithUserValues = getFieldsWithUserValues().map((key, value) => MapEntry(key, value.toJson()));
    if(fieldsWithUserValues.isNotEmpty) {
      result['fieldsWithUserValues'] = fieldsWithUserValues;
    }
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getType(),
      getFields(),
      getUserProvidedValues(),
      getMappedFields(),
      getFieldsWithDefaults(),
      getFieldsWithUserValues(),
    ];
  }
}

/// Enhanced annotation field metadata
final class StandardAnnotationFieldDeclaration extends StandardEntityDeclaration implements AnnotationFieldDeclaration {
  final LinkDeclaration _typeDeclaration;
  final dynamic _defaultValue;
  final bool _hasDefaultValue;
  final dynamic _userValue;
  final bool _hasUserValue;
  final bool _isFinal;
  final bool _isConst;
  final int _position;
  final bool _isNullable;

  const StandardAnnotationFieldDeclaration({
    required super.name,
    required super.isPublic,
    required super.isSynthetic,
    required LinkDeclaration typeDeclaration,
    required dynamic defaultValue,
    required bool hasDefaultValue,
    required dynamic userValue,
    required bool hasUserValue,
    required bool isFinal,
    required bool isConst,
    required int position,
    required super.dartType,
    super.element,
    required bool isNullable,
    required super.type,
  }) : _typeDeclaration = typeDeclaration,
       _defaultValue = defaultValue,
       _hasDefaultValue = hasDefaultValue,
       _userValue = userValue,
       _hasUserValue = hasUserValue,
       _isFinal = isFinal,
       _position = position,
       _isConst = isConst,
       _isNullable = isNullable;

  @override
  LinkDeclaration getLinkDeclaration() => _typeDeclaration;

  @override
  dynamic getValue() => hasUserProvidedValue() ? getUserProvidedValue() : getDefaultValue();

  @override
  dynamic getDefaultValue() => _defaultValue;

  @override
  dynamic getUserProvidedValue() => _userValue;

  @override
  bool hasDefaultValue() => _hasDefaultValue;

  @override
  bool isNullable() => _isNullable;

  @override
  int getPosition() => _position;

  @override
  bool hasUserProvidedValue() => _hasUserValue;

  @override
  bool isFinal() => _isFinal;

  @override
  bool isConst() => _isConst;

  @override
  String getDebugIdentifier() => 'annotation_field_${getName().toLowerCase()}';

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['declaration'] = 'annotation_field';
    result['name'] = getName();

    final type = getLinkDeclaration().toJson();
    if(type.isNotEmpty) {
      result['type'] = type;
    }

    final defaultValue = getDefaultValue();
    if(defaultValue != null) {
      result['defaultValue'] = defaultValue.toString();
    }
    
    final userValue = getUserProvidedValue();
    if(userValue != null) {
      result['userValue'] = userValue.toString();
    }
  
    result['hasUserValue'] = hasUserProvidedValue();
    result['isFinal'] = isFinal();
    result['isConst'] = isConst();
    return result;
  }

  @override
  List<Object?> equalizedProperties() {
    return [
      getName(),
      getType(),
      getValue(),
      getDefaultValue(),
      getUserProvidedValue(),
      hasDefaultValue(),
      hasUserProvidedValue(),
      isFinal(),
      isConst(),
    ];
  }
}