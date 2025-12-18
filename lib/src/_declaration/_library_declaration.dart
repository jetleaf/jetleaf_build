part of '../declaration/declaration.dart';

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
  final Package _parentPackage;
  final List<AnnotationDeclaration> _annotations;
  final Uri? _sourceLocation;
  final bool _isPublic;
  final bool _isSynthetic;
  final List<SourceDeclaration> _declarations;
  final List<RecordLinkDeclaration> _recordLinkDeclarations;

  /// {@macro standard_library}
  StandardLibraryDeclaration({
    required String uri,
    required Package parentPackage,
    required List<SourceDeclaration> declarations,
    required List<RecordLinkDeclaration> recordLinkDeclarations,
    List<AnnotationDeclaration> annotations = const [],
    Uri? sourceLocation,
    required bool isPublic,
    required bool isSynthetic,
  })  : _uri = uri,
        _isPublic = isPublic,
        _isSynthetic = isSynthetic,
        _parentPackage = parentPackage,
        _declarations = declarations,
        _annotations = annotations,
        _recordLinkDeclarations = recordLinkDeclarations,
        _sourceLocation = sourceLocation;

  @override
  String getUri() => _uri;

  @override
  bool getIsPublic() => _isPublic;

  @override
  bool getIsSynthetic() => _isSynthetic;

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
  List<MethodDeclaration> getTopLevelMethods() => _declarations.whereType<MethodDeclaration>().where((m) => m.getParentClass() == null).toList();

  @override
  List<FieldDeclaration> getTopLevelFields() => _declarations.whereType<FieldDeclaration>().where((f) => f.getParentClass() == null).toList();
  
  @override
  Package getPackage() => _parentPackage;

  @override
  Type getType() => runtimeType;
  
  @override
  List<RecordLinkDeclaration> getTopLevelRecords() => _recordLinkDeclarations;

  /// Creates a copy of this library with the specified properties changed.
  StandardLibraryDeclaration copyWith({
    String? uri,
    Package? parentPackage,
    List<SourceDeclaration>? declarations,
    List<AnnotationDeclaration>? annotations,
    List<RecordLinkDeclaration>? records,
    Uri? sourceLocation,
    bool? isPublic,
    bool? isSynthetic,
  }) {
    return StandardLibraryDeclaration(
      uri: uri ?? _uri,
      isPublic: isPublic ?? getIsPublic(),
      isSynthetic: isSynthetic ?? getIsSynthetic(),
      parentPackage: parentPackage ?? _parentPackage,
      recordLinkDeclarations: records ?? _recordLinkDeclarations,
      declarations: declarations ?? _declarations,
      annotations: annotations ?? _annotations,
      sourceLocation: sourceLocation ?? _sourceLocation,
    );
  }

  @override
  String getDebugIdentifier() => 'library_${getName()}';

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
      getClasses(),
      getEnums(),
      getTypedefs(),
      getDeclarations(),
    ];
  }
}