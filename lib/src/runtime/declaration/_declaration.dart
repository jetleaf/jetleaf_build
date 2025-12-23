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

@internal
final class StandardDeclaration extends Declaration with EqualsAndHashCode {
  /// Runtime type of the declared entity
  final Type _type;

  /// Name as declared in source
  final String _name;

  /// Checks if this declaration is public or not
  final bool _isPublic;

  /// Checks if the declaration is synthetic
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
  List<Object?> equalizedProperties() => [_type, _name, _isPublic, _isSynthetic];
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
@internal
final class StandardEntityDeclaration extends StandardDeclaration  implements EntityDeclaration {
  /// Debug identifier for developer tools
  final String _debugger;

  /// Creates a standard entity declaration
  ///
  /// {@template standard_entity_constructor}
  /// Parameters:
  /// - [type]: Required runtime [Type] of the entity
  /// - [debugger]: Optional custom debug identifier (defaults to "type_$type")
  ///
  /// All fields are immutable once created.
  /// {@endtemplate}
  const StandardEntityDeclaration({
    required super.type,
    required super.isPublic,
    required super.isSynthetic,
    required super.name,
    String? debugger
  }) : _debugger = debugger ?? "type_$type";

  @override
  String getDebugIdentifier() => _debugger;

  @override
  Map<String, Object> toJson() => {
    "type": _type.toString(),
    "debugger": _debugger
  };

  @override
  List<Object?> equalizedProperties() => [_type, _name, _isPublic, _isSynthetic, _debugger];
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
@internal
final class StandardSourceDeclaration extends StandardEntityDeclaration implements SourceDeclaration {
  /// Annotations applied to this declaration
  final List<AnnotationDeclaration> _annotations;

  /// Source file location (URI)
  final Uri? _sourceLocation;

  /// Creates a standard source declaration
  ///
  /// {@template standard_source_constructor}
  /// Parameters:
  /// - [type]: Required runtime [Type] of the declaration
  /// - [name]: Source code name of the declaration (required)
  /// - [debugger]: Optional custom debug identifier
  /// - [annotations]: List of annotations (default empty)
  /// - [sourceLocation]: Optional source file URI
  ///
  /// All fields are immutable once created.
  /// {@endtemplate}
  const StandardSourceDeclaration({
    required super.type,
    required super.name,
    required super.isPublic,
    required super.isSynthetic,
    super.debugger,
    List<AnnotationDeclaration> annotations = const [],
    Uri? sourceLocation
  }) : _annotations = annotations,
       _sourceLocation = sourceLocation,
       super();

  @override
  List<AnnotationDeclaration> getAnnotations() => _annotations;

  @override
  Uri? getSourceLocation() => _sourceLocation;

  @override
  List<Object?> equalizedProperties() => [_annotations, _sourceLocation, getName(), getIsPublic(), getIsSynthetic()];
}

/// Resolves arguments for a method invocation.
/// 
/// Takes a map of arguments and a list of parameters, and returns an [ExecutableArgument]
/// object containing the resolved positional and named arguments.
/// 
/// The function also checks for the following:
/// 
/// * If the number of positional arguments provided matches the number of required positional arguments.
/// * If the number of positional arguments provided does not exceed the total number of positional arguments.
/// * If all named arguments provided are valid parameters.
/// 
/// If any of these checks fail, an [BuildException] is thrown.
ExecutableArgument _resolveArgument(Map<String, dynamic> arguments, List<ParameterDeclaration> parameters, String location) {
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
      } else if (param.getHasDefaultValue()) {
        named[name] = arguments[param.getDefaultValue()];
      } else if (param.getIsNullable()) {
        named[name] = arguments[null];
      } else if (!param.getIsNullable() && !param.getIsOptional()) {
        throw MissingRequiredNamedParameterException(name, location: location);
      }
    } else {
      // Positional parameter
      if (arguments.containsKey(name)) {
        positional.add(arguments[name]);
      } else if (argKeys.isNotEmpty && i < argKeys.length) {
        final key = argKeys.elementAt(i);
        final keyInt = int.tryParse(key);

        if(keyInt != null && keyInt == param.getIndex()) {
          positional.add(arguments[key]);
        } else if (param.getHasDefaultValue()) {
          positional.add(param.getDefaultValue());
        } else if (param.getIsNullable()) {
          positional.add(null);
        } else if(!param.getIsNullable() && !param.getIsOptional()) {
          throw MissingRequiredPositionalParameterException(name, location: location);
        }
      } else if (param.getIsNullable()) {
        positional.add(null);
      } else if (param.getHasDefaultValue()) {
        positional.add(param.getDefaultValue());
      } 
    }
  }
  
  // Check if we have the right number of positional arguments
  final requiredPositionalCount = parameters.where((p) => !p.getIsNamed() && !p.getIsNullable() && !p.getIsOptional()).length;
  final totalPositionalCount = parameters.where((p) => !p.getIsNamed()).length;
      
  if (positional.length < requiredPositionalCount) {
    throw TooFewPositionalArgumentException(requiredPositionalCount, positional.length, location: location);
  }
  
  if (positional.length > totalPositionalCount) {
    throw TooManyPositionalArgumentException(totalPositionalCount, positional.length, location: location);
  }
  
  // Check for unexpected named arguments
  for (final argName in arguments.keys) {
    final hasMatchingParam = parameters.any((p) => p.getName() == argName);
    if (!hasMatchingParam) {
      throw UnexpectedArgumentException(argName, location: location);
    }
  }

  return ExecutableArgument.unmodified(named, positional);
}