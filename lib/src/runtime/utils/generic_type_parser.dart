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

/// {@template generic_parser}
/// Provides utilities for parsing and analyzing generic type strings in Dart.
///
/// Handles complex generic type signatures including nested generics, and
/// provides structured access to the parsed type information.
///
/// {@template generic_parser_features}
/// ## Key Features
/// - Extracts generic type parameters from type strings
/// - Handles nested generic types recursively
/// - Splits comma-separated generic parameters
/// - Resolves base types and their generic arguments
/// - Special handling for core collection types
/// {@endtemplate}
///
/// {@template generic_parser_example}
/// ## Example Usage
/// ```dart
/// // Parse a simple generic type
/// final result = GenericTypeParser.parseGenericTypes('List<String>');
///
/// // Parse nested generics
/// final complex = GenericTypeParser.parseGenericTypes('Map<String, List<int>>');
/// ```
/// {@endtemplate}
/// {@endtemplate}
class GenericTypeParser {
  /// Special case type names that need normalization
  static final List<String> _caveats = ['_Map', '_Set'];

  /// Private constructor to prevent instantiation
  /// 
  /// {@macro generic_parser}
  GenericTypeParser._();

  /// {@template mirror_type_to_format_with_generic}
  /// The type name of the mirror type to format with generic parameters.
  ///
  /// This is used to check if a type should be checked for generic parameters.
  ///
  /// Example:
  /// ```dart
  /// final result = GenericTypeParser.shouldCheckGeneric(List);
  /// print(result); // true
  /// ```
  /// {@endtemplate}
  static const String _MIRROR_TYPE_TO_FORMAT_WITH_GENERIC = "_ClassMirror";

  /// {@template should_check_generic}
  /// Checks if the given type should be checked for generic parameters.
  ///
  /// Parameters:
  /// - [type]: The type to check
  ///
  /// Returns:
  /// - `true` if the type should be checked for generic parameters
  /// - `false` otherwise
  ///
  /// Example:
  /// ```dart
  /// final result = GenericTypeParser.shouldCheckGeneric(List);
  /// print(result); // true
  /// ```
  /// {@endtemplate}
  static bool shouldCheckGeneric(Type type) => isGenericMirror(type.toString());

  /// {@template is_generic_mirror}
  /// Checks if the given type string is a mirror type to format with generic parameters.
  ///
  /// Parameters:
  /// - [typeString]: The type string to check
  ///
  /// Returns:
  /// - `true` if the type string is a mirror type to format with generic parameters
  /// - `false` otherwise
  ///
  /// Example:
  /// ```dart
  /// final result = GenericTypeParser.isGenericMirror("_ClassMirror");
  /// print(result); // true
  /// ```
  /// {@endtemplate}
  static bool isGenericMirror(String typeString) => typeString == _MIRROR_TYPE_TO_FORMAT_WITH_GENERIC;

  /// {@template extract_generic_part}
  /// Extracts the inner generic type parameters from a type string.
  ///
  /// Parameters:
  /// - [typeString]: The type string to parse (e.g., `List<String>`)
  ///
  /// Returns:
  /// - The inner generic part (e.g., `String` from `List<String>`)
  /// - Empty string if no generic parameters exist
  ///
  /// Example:
  /// ```dart
  /// final inner = GenericTypeParser.extractGenericPart('List<String>');
  /// print(inner); // 'String'
  ///
  /// final nested = GenericTypeParser.extractGenericPart('Map<String, List<int>>');
  /// print(nested); // 'String, List<int>'
  /// ```
  /// {@endtemplate}
  static String extractGenericPart(String typeString) {
    final startIndex = typeString.indexOf('<');
    final endIndex = typeString.lastIndexOf('>');
    
    if (startIndex == -1 || endIndex == -1 || startIndex >= endIndex) {
      return '';
    }
    
    return typeString.substring(startIndex + 1, endIndex);
  }

  /// {@template parse_generic_types}
  /// Fully parses a generic type string into structured results.
  ///
  /// Parameters:
  /// - [genericPart]: The type string to parse
  ///
  /// Returns:
  /// - List of [GenericTypeParsingResult] objects representing the type structure
  /// - Empty list for non-generic types
  ///
  /// Example:
  /// ```dart
  /// final results = GenericTypeParser.parseGenericTypes('Map<String, List<int>>');
  /// print(results[0].base); // 'Map'
  /// print(results[0].types[0].base); // 'String'
  /// print(results[0].types[1].base); // 'List'
  /// ```
  /// {@endtemplate}
  static List<GenericTypeParsingResult> parseGenericTypes(String genericPart) {
    if (genericPart.isEmpty) return [];
    
    final results = <GenericTypeParsingResult>[];
    final parts = splitGenericParts(genericPart);
    
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) {
        // Recursively parse each generic type
        final result = resolveGenericType(trimmed);
        results.add(result);
      }
    }
    
    return results;
  }

  /// {@template split_generic_parts}
  /// Splits comma-separated generic parameters while handling nested generics.
  ///
  /// Parameters:
  /// - [content]: The generic parameters string to split
  ///
  /// Returns:
  /// - List of individual generic parameter strings
  /// - Preserves nested generic structures
  ///
  /// Example:
  /// ```dart
  /// final parts = GenericTypeParser.splitGenericParts('String, List<int>, Map<String, int>');
  /// print(parts); // ['String', 'List<int>', 'Map<String, int>']
  /// ```
  /// {@endtemplate}
  static List<String> splitGenericParts(String content) {
    if (content.isEmpty) return [];
    
    final parts = <String>[];
    var current = '';
    var depth = 0;
    
    for (var i = 0; i < content.length; i++) {
      final char = content[i];
      
      if (char == '<') {
        depth++;
      } else if (char == '>') {
        depth--;
      } else if (char == ',' && depth == 0) {
        parts.add(current.trim());
        current = '';
        continue;
      }
      
      current += char;
    }
    
    if (current.trim().isNotEmpty) {
      parts.add(current.trim());
    }
    
    return parts;
  }

  /// {@template is_generic}
  /// Determines if a type string contains generic parameters.
  ///
  /// Parameters:
  /// - [typeString]: The type string to check
  ///
  /// Returns:
  /// - `true` if the type has generic parameters
  /// - `false` for non-generic types
  ///
  /// Example:
  /// ```dart
  /// GenericTypeParser.isGeneric('List<String>'); // true
  /// GenericTypeParser.isGeneric('String'); // false
  /// ```
  /// {@endtemplate}
  static bool isGeneric(String typeString) {
    if (!typeString.contains('<') || !typeString.contains('>')) {
      return false;
    }
    
    final openIndex = typeString.indexOf('<');
    final closeIndex = typeString.lastIndexOf('>');
    
    return openIndex < closeIndex && openIndex != -1 && closeIndex != -1;
  }

  /// {@template resolve_generic_type}
  /// Recursively resolves a type string into its components.
  ///
  /// Parameters:
  /// - [typeString]: The type string to resolve
  ///
  /// Returns:
  /// - [GenericTypeParsingResult] containing the base type and all generic arguments
  ///
  /// Example:
  /// ```dart
  /// final result = GenericTypeParser.resolveGenericType('Map<String, List<int>>');
  /// print(result.base); // 'Map'
  /// print(result.types.length); // 2
  /// ```
  /// {@endtemplate}
  static GenericTypeParsingResult resolveGenericType(String typeString) {
    // Handle generic types like "List<String>"
    if (isGeneric(typeString)) {
      String baseName = typeString.split('<').first;
      if(_caveats.any((c) => c == baseName)) {
        baseName = baseName.replaceAll("_", "");
      }
      
      // Extract generic parameters and recursively parse them
      final genericPart = extractGenericPart(typeString);
      final genericTypes = parseGenericTypes(genericPart);
      
      return GenericTypeParsingResult(baseName, typeString, genericTypes);
    }
    
    // Handle non-generic types (base case for recursion)
    return GenericTypeParsingResult(typeString, typeString, []);
  }
}

/// {@template generic_parsing_result}
/// Represents the parsed structure of a generic type.
///
/// Contains the base type name, original type string, and any generic type arguments.
/// This forms a recursive structure that can represent complex nested generic types.
///
/// {@template generic_parsing_result_example}
/// ## Example Structure
/// For type `Map<String, List<int>>`:
/// ```dart
/// GenericTypeParsingResult(
///   'Map',
///   'Map<String, List<int>>',
///   [
///     GenericTypeParsingResult('String', 'String', []),
///     GenericTypeParsingResult(
///       'List', 
///       'List<int>',
///       [GenericParsingResult('int', 'int', [])]
///     )
///   ]
/// )
/// ```
/// {@endtemplate}
/// {@endtemplate}
class GenericTypeParsingResult {
  /// The base type name without generic parameters
  final String base;

  /// The complete original type string
  final String typeString;

  /// List of generic type arguments (if any)
  final List<GenericTypeParsingResult> types;

  /// Creates a new parsing result
  GenericTypeParsingResult(this.base, this.typeString, this.types);
  
  @override
  String toString() {
    return 'GenericParsingResult(base: $base, typeString: $typeString, types: $types)';
  }
}