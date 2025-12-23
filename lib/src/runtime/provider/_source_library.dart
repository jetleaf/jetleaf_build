part of 'runtime_provider.dart';

/// Signature for a **type resolution callback** used during runtime class analysis.
///
/// `_TypeResolver` defines a function that maps a Dart runtime type and its
/// associated reflection metadata into a resolved `Type`. This allows
/// JetLeaf to unify runtime and mirror-based type information when building
/// internal class references.
///
/// ---
///
/// ## Parameters
/// - `runtimeType` : The raw Dart `Type` obtained from `ClassMirror.reflectedType`
///                  or `ClassMirror.runtimeType`.  
/// - `mirror`      : The Dart reflection `TypeMirror` representing the class, used
///                  for detailed inspection or generic type resolution.  
/// - `libraryUri`  : The string representation of the library URI where the class
///                  is declared.  
/// - `sourceUri`   : The actual `Uri` object pointing to the source of the class.  
/// - `typeName`    : The simple name of the class as a string (without library prefix).  
///
/// ## Returns
/// - The resolved Dart `Type` for the class, potentially modified or validated
///   according to JetLeaf internal rules.
///
/// ---
///
/// ## Example Usage
/// ```dart
/// Type myResolver(Type runtimeType, mirrors.TypeMirror mirror, String libUri, Uri srcUri, String name) {
///   // Custom logic to adjust type resolution
///   return runtimeType;
/// }
///
/// final Type resolved = myResolver(String, myMirror, 'package:myapp/main.dart', Uri.parse('package:myapp/main.dart'), 'String');
/// print(resolved); // String
/// ```
///
/// This typedef is typically passed to `_ClassReference` constructors to
/// consistently resolve the final Dart `Type` of each class.
typedef _TypeResolver = Type Function(
  Type runtimeType,
  mirrors.TypeMirror mirror,
  String libraryUri,
  Uri sourceUri,
  String typeName
);

/// {@template source_library}
/// Represents a Dart source library analyzed at runtime.
///
/// This class encapsulates a library's core metadata and source code,
/// providing access to its package, URI, source content, and whether
/// it belongs to the Dart SDK.
///
/// It is primarily used by runtime scanners and reflection systems
/// to track library declarations and resolve references within
/// packages or the SDK.
///
/// Example:
/// ```dart
/// final lib = _SourceLibrary(package, uri, sourceCode, false, libraryMirror);
/// print(lib.getUri()); // 'package:my_app/main.dart'
/// print(lib.getPackage().getName()); // 'my_app'
/// ```
/// {@endtemplate}
final class _SourceLibrary implements SourceLibrary {
  /// The package to which this library belongs.
  final Package _package;

  /// The URI of this library.
  final Uri _uri;

  /// The raw source code of the library.
  final String _sourceCode;

  /// Whether this library is part of the Dart SDK.
  final bool _isSdkLibrary;

  /// The mirror representation of this library.
  final mirrors.LibraryMirror _libraryMirror;

  /// The hierarchy level of the library, used internally for sorting or analysis.
  int _hierarchy = -1;

  /// Holds all **class references** discovered within a library.
  ///
  /// `_classReferences` stores lightweight [_ClassReference] objects for
  /// every class declared in a `_SourceLibrary`. Each reference includes
  /// the class's qualified name, raw Dart [Type], direct superclass, and
  /// implemented interfaces.
  ///
  /// ---
  ///
  /// ## Purpose
  /// - Provides a fast, in-memory representation of all classes in the library.
  /// - Enables **hierarchy traversal**, subclass resolution, and interface lookups
  ///   without materializing full [ClassDeclaration] objects.
  /// - Supports runtime reflection and analysis tools in JetLeaf.
  ///
  /// ---
  ///
  /// ## Usage
  /// ```dart
  /// for (final classRef in library._classReferences) {
  ///   print(classRef.getQualifiedName());
  ///   print(classRef.getType());
  ///   final superClass = classRef.getSuperClass();
  ///   final interfaces = classRef.getInterfaces();
  /// }
  /// ```
  ///
  /// ---
  ///
  /// ## Notes
  /// - This list is populated once during library scanning using mirrors.
  /// - Designed for **fast lookup and iteration**, not for modification after initialization.
  final List<_ClassReference> _classReferences = [];

  /// {@macro source_library}
  _SourceLibrary(this._package, this._sourceCode, this._isSdkLibrary, this._libraryMirror) : _uri = _libraryMirror.uri;

  /// Builds all classes in this [_SourceLibrary] into lightweight [_ClassReference] for fast lookups
  void _init(_TypeResolver resolver) {
    try {
      final classMirrors = _libraryMirror.declarations.values.whereType<mirrors.ClassMirror>();

      for (final classMirror in classMirrors) {
        _classReferences.add(_ClassReference(classMirror, _uri, resolver));
      }
    } catch (_) {}
  }

  void _setHierarchy(int value) => _hierarchy = value;

  @override
  Uri getSourceLocation() => _uri;

  @override
  String getDebugIdentifier() => _isSdkLibrary ? "[dart_sdk]:::_$_uri" : "[lib]:::_$_uri";

  @override
  Package getPackage() => _package;

  @override
  String getUri() => _uri.toString();

  @override
  String sourceCode() => _sourceCode;

  @override
  bool isSdkLibrary() => _isSdkLibrary;

  @override
  String getName() => mirrors.MirrorSystem.getName(_libraryMirror.simpleName);

  @override
  List<Object?> equalizedProperties() => [_uri, _package, _sourceCode];

  /// Searches for a class reference within this `_SourceLibrary` by its fully
  /// qualified name.
  ///
  /// `_classReferences` stores lightweight [_ClassReference] objects representing
  /// every class declared in the library. `findClass` provides **fast lookup**
  /// without needing to iterate externally or materialize full class metadata.
  ///
  /// ---
  ///
  /// ## Parameters
  /// - `qualifiedName`: The fully qualified name of the class to search for,
  ///   e.g., `"package:my_app/models.dart.User"`.
  ///
  /// ## Returns
  /// - The matching `_ClassReference` if found, or `null` if no class with the
  ///   given name exists in this library.
  ///
  /// ---
  /// 
  /// ## Example
  /// ```dart
  /// final userClassRef = library.findClass("package:my_app/models.dart.User");
  /// if (userClassRef != null) {
  ///   print(userClassRef.getQualifiedName()); // package:my_app/models.dart.User
  ///   print(userClassRef.getType());          // User runtime type
  /// }
  /// ```
  _ClassReference? findClass(String qualifiedName) => _classReferences.where((c) => c._qualifiedName == qualifiedName).firstOrNull;

  /// Searches for a class reference within this `_SourceLibrary` by its Dart runtime [Type].
  ///
  /// `_classReferences` stores lightweight [_ClassReference] objects representing
  /// every class declared in the library. `findClassByType` provides **fast lookup**
  /// for runtime type comparisons without needing to match qualified names or load
  /// full class metadata.
  ///
  /// ---
  ///
  /// ## Parameters
  /// - `type`: The Dart runtime [Type] of the class to search for, e.g., `User`.
  ///
  /// ## Returns
  /// - The matching `_ClassReference` if a class with the given type exists in
  ///   this library.
  /// - Returns `null` if no class with the specified type is found.
  ///
  /// ---
  ///
  /// ## Example
  /// ```dart
  /// final userClassRef = library.findClassByType(User);
  /// if (userClassRef != null) {
  ///   print(userClassRef.getQualifiedName()); // e.g., "package:my_app/models.dart.User"
  ///   print(userClassRef.getType());          // User runtime type
  /// }
  /// ```
  _ClassReference? findClassByType(Type type) => _classReferences.where((c) => c._type == type).firstOrNull;

  @override
  String toString() {
    final count = _classReferences.length;

    final buffer = StringBuffer(
      "This source library contains $count "
      "${count == 1 ? 'class' : 'classes'}"
    );

    buffer.write(_isSdkLibrary ? " from the Dart SDK" : " from package ${_package.getName()}");

    buffer.write(" at $_uri");

    if (_classReferences.isNotEmpty) {
      if (count == 1) {
        buffer.write(" (${_classReferences.first._qualifiedName})");
      } else {
        buffer.write(" (${_classReferences.map((c) => c._qualifiedName).join(', ')})");
      }
    }

    return buffer.toString();
  }
}

/// Concrete implementation of [ClassReference] using Dart mirrors.
///
/// `_ClassReference` provides a **runtime-backed, lightweight representation**
/// of a Dart class, including its qualified name, type, direct superclass,
/// and implemented interfaces.  
/// This class is intended for **internal use** within JetLeaf to enable
/// fast hierarchy traversal and reflection without materializing full
/// class metadata.
///
/// ---
///
/// ## Key Features
/// - Stores fully qualified name for stable identification
/// - Holds raw Dart [Type] for runtime comparisons
/// - Maintains references to direct superclass and interfaces
/// - Lightweight and optimized for internal caching and hierarchy resolution
///
/// ---
///
/// ## Example
/// ```dart
/// final ref = _ClassReference(classMirror, libraryUri, resolver);
/// print(ref.getQualifiedName()); // e.g., "package:example/MyClass"
/// print(ref.getType());          // e.g., MyClass runtime type
/// print(ref.getSuperClass()?.getQualifiedName());
/// print(ref.getInterfaces().map((i) => i.getQualifiedName()));
/// ```
final class _ClassReference extends ClassReference {
  /// Fully-qualified name of the class, e.g., "package:myapp/models.dart.MyClass".
  late String _qualifiedName;

  /// Raw Dart [Type] represented by this class reference.
  ///
  /// Used for fast type comparisons and pointer-level resolution.
  late Type _type;

  /// The mirror representing the class declaration.
  final mirrors.ClassMirror _classMirror;

  /// The library uri for this class.
  final Uri _libraryUri;

  /// Holds the list of annotated methods within the class.
  /// 
  /// This is used for fast lookups when looking for annotated methods.
  final List<_AnnotatedMethodReference> _annotatedMethods = [];

  /// Direct superclass reference, or `null` if this class has no superclass.
  _ClassReference? _superClass;

  /// List of interfaces implemented by this class.
  ///
  /// Stored as [_ClassReference] objects for lightweight hierarchy traversal.
  final List<_ClassReference> _interfaces = [];

  _ClassReference(this._classMirror, this._libraryUri, _TypeResolver resolver) {
    final uri = _classMirror.location?.sourceUri ?? _classMirror.owner?.location?.sourceUri ?? _libraryUri;
    final typeName = mirrors.MirrorSystem.getName(_classMirror.simpleName);
    Type type = _classMirror.hasReflectedType ? _classMirror.reflectedType : _classMirror.runtimeType;

    _type = resolver(type, _classMirror, uri.toString(), uri, typeName);
    _qualifiedName = ReflectionUtils.buildQualifiedName(typeName, uri.toString());

    try {
      for (final method in _classMirror.declarations.values.whereType<mirrors.MethodMirror>()) {
        if (!method.isConstructor && method.metadata.isNotEmpty) {
          for (final metadata in method.metadata) {
            if (metadata.hasReflectee) {
              _annotatedMethods.add(_AnnotatedMethodReference(method, metadata.reflectee, "$_qualifiedName#${mirrors.MirrorSystem.getName(method.simpleName)}"));
            }
          }
        }
      }
    } catch (_) {}

    if (_classMirror.superclass case final superClass?) {
      _superClass = _ClassReference(superClass, superClass.location?.sourceUri ?? superClass.owner?.location?.sourceUri ?? _libraryUri, resolver);
    }

    if (_classMirror.superinterfaces.isNotEmpty) {
      for (final interface in _classMirror.superinterfaces) {
        _interfaces.add(_ClassReference(interface, interface.location?.sourceUri ?? interface.owner?.location?.sourceUri ?? _libraryUri, resolver));
      }
    }
  }

  @override
  String getQualifiedName() => _qualifiedName;

  @override
  Type getType() => _type;

  @override
  ClassReference? getSuperClass() => _superClass;

  @override
  List<ClassReference> getInterfaces() => UnmodifiableListView(_interfaces);

  @override
  List<Object?> equalizedProperties() => [_qualifiedName, _type];

  @override
  String toString() {
    final buffer = StringBuffer("This class references $_qualifiedName of type $_type");

    if (_superClass case final superClass?) {
      buffer.write(" with super class ${superClass._qualifiedName}");
    }

    if (_interfaces.isNotEmpty) {
      if (_interfaces.length == 1) {
        buffer.write(" and 1 (${_interfaces.first._qualifiedName}) interface");
      } else {
        buffer.write(" and ${_interfaces.length} (${_interfaces.map((i) => i._qualifiedName).join(', ')}) interfaces");
      }
    }

    return buffer.toString();
  }
}

/// Internal runtime representation of a method annotated with metadata.
///
/// `_AnnotatedMethodReference` is used by JetLeaf to track methods that
/// have annotations applied, allowing for **fast lookup and reflection**
/// without scanning all methods repeatedly.
///
/// ---
///
/// ## Purpose
/// - Associate a Dart [mirrors.MethodMirror] with its runtime annotation instance.
/// - Enable caching of annotated methods within `_ClassReference`.
/// - Facilitate runtime reflection, dependency injection, or annotation-driven
///   logic in JetLeaf systems.
///
/// ---
///
/// ## Fields
/// - `_methodMirror`: The [mirrors.MethodMirror] representing the method declaration.
/// - `annotationInstance`: The actual runtime instance of the annotation
///   applied to the method.
///
/// ---
///
/// ## Example Usage
/// ```dart
/// final annotatedMethod = _AnnotatedMethodReference(methodMirror, MyAnnotation());
/// print(annotatedMethod._methodMirror.simpleName); // method name
/// print(annotatedMethod.annotationInstance);       // MyAnnotation instance
/// ```
///
/// Typically, these objects are stored inside `_ClassReference` for
/// efficient access to all annotated methods in a class.
final class _AnnotatedMethodReference {
  /// The mirror representing the method declaration.
  final mirrors.MethodMirror _methodMirror;

  /// The runtime instance of the annotation applied to this method.
  final dynamic annotationInstance;

  /// The unique id of this method to avoid duplicate
  final String _id;

  /// Creates a new reference linking the method to its annotation.
  _AnnotatedMethodReference(this._methodMirror, this.annotationInstance, this._id);
}