part of 'declaration.dart';

/// {@template library_declaration}
/// Represents a **Dart library declaration** within JetLeaf’s reflection
/// and generation system.
///
/// A [LibraryDeclaration] models the **source-level library** abstraction,
/// including its URI, containing package, and associated metadata. It
/// extends [SourceDeclaration] to provide a standardized interface for
/// querying libraries across packages and source files.
///
/// This class is **abstract**; concrete implementations are provided by
/// JetLeaf’s internal materialization system.
///
/// Typical usage includes:
/// - Resolving the library URI
/// - Accessing the containing package
/// - Bridging runtime objects to library-level declarations
/// {@endtemplate}
abstract final class LibraryDeclaration extends SourceDeclaration {
  /// {@macro library_declaration}
  const LibraryDeclaration();

  /// Returns the URI of the library.
  ///
  /// The URI is typically a string representing the library location
  /// in either a package or file context.
  ///
  /// ### Example
  /// ```dart
  /// final uri = myLibrary.getUri();
  /// print(uri); // e.g., "package:my_app/main.dart"
  /// ```
  String getUri();

  /// Returns the [Package] that contains this library.
  ///
  /// This allows resolving relative URIs and accessing package-specific
  /// configuration, dependencies, or metadata.
  ///
  /// ### Example
  /// ```dart
  /// final pkg = myLibrary.getPackage();
  /// print(pkg.getName()); // "my_app"
  /// ```
  Package getPackage();

  @override
  String getName() => getUri();
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
@internal
final class StandardLibraryDeclaration extends StandardSourceDeclaration with EqualsAndHashCode implements LibraryDeclaration {
  final String _uri;
  final Package _parentPackage;

  /// {@macro standard_library}
  StandardLibraryDeclaration({
    required String uri,
    required Package parentPackage,
    required super.name,
    required super.isPublic,
    required super.isSynthetic,
  })  : _uri = uri, _parentPackage = parentPackage, super(type: LibraryDeclaration);

  @override
  String getUri() => _uri;

  @override
  Package getPackage() => _parentPackage;

  @override
  Type getType() => runtimeType;

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
    
    return result;
  }

  @override
  List<Object?> equalizedProperties() => [getName(), getPackage(), getUri(), getSourceLocation(), getAnnotations()];
}