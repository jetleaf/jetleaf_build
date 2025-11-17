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

import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../runtime_scanner/runtime_scanner_configuration.dart';

/// {@template reflect_utils}
/// Utility class for reflection-related operations in JetLeaf.
///
/// Provides helper methods for:
/// - URI and package resolution
/// - File exclusion/inclusion checks
/// - Source code analysis
/// - JetLeaf-specific filtering
///
/// {@template reflect_utils_example}
/// Example usage:
/// ```dart
/// final utils = ReflectUtils();
///
/// // Check if a URI should be excluded
/// final shouldExclude = await ReflectUtils.shouldNotIncludeLibrary(
///   Uri.parse('package:some_pkg/file.dart'),
///   loader,
///   print,
/// );
///
/// // Get package name from URI
/// final pkgName = ReflectUtils.getPackageNameFromUri('package:html/html.dart');
/// ```
/// {@endtemplate}
/// {@endtemplate}
class RuntimeUtils {
  /// {@macro reflect_utils}
  RuntimeUtils._();

  /// Regular expression to identify JetLeaf packages that should be skipped.
  ///
  /// Matches internal JetLeaf packages like:
  /// - `package:jetleaf_lang/src/lang`
  /// - `package:jetleaf_lang/test`
  /// - `package:jetleaf_lang/src/utils`
  static final RegExp _jetLeafPackagesToSkip = RegExp(
    r'^package:jetleaf_build/(?:'
    r'src/lang/reflect/(?:runtime_provider|runtime_scanner|runtime_resolver|declaration|generators)|'
    r'src/(?:runtime|meta|utils|cli|mock|test|meta)|'
    r'test'
    r')(?:/|$)',
  );

  /// Regular expression to identify JetLeaf folders that should be skipped.
  ///
  /// Matches internal JetLeaf directories like:
  /// - `jetleaf_lang/bin`
  /// - `jetleaf_lang/tool`
  /// - `jetleaf_lang/src/runtime`
  static final RegExp _jetLeafFoldersToSkip = RegExp(
    r'jetleaf_build/(?:'
    r'bin|'
    r'tool|'
    r'src/lang/reflect/(?:runtime_provider|runtime_scanner|runtime_resolver|declaration|generators)|'
    r'src/(?:runtime|meta|utils|cli|mock|test|meta)|'
    r'test'
    r')(?:/|$)',
  );

  /// Determines if a JetLeaf file should not be loaded.
  ///
  /// {@template non_loadable_check}
  /// Checks if the file matches any of the excluded JetLeaf internal paths.
  ///
  /// Parameters:
  /// - [uri]: The URI to check
  ///
  /// Returns `true` if the file is:
  /// - In JetLeaf's internal implementation directories
  /// - In JetLeaf's test directories
  /// - In JetLeaf's tooling directories
  ///
  /// Example:
  /// ```dart
  /// final shouldSkip = ReflectUtils.isNonLoadableJetLeafFile(
  ///   Uri.parse('package:jetleaf_lang/src/lang/parser.dart'),
  /// ); // returns true
  /// ```
  /// {@endtemplate}
  static bool isNonLoadableJetLeafFile(Uri uri) {
    final path = uri.toString();
    return _jetLeafFoldersToSkip.hasMatch(path);
  }

  /// Determines if a JetLeaf package should be skipped during scanning.
  ///
  /// {@macro non_loadable_check}
  /// 
  /// Example:
  /// ```dart
  /// final shouldSkip = ReflectUtils.isSkippableJetLeafPackage(
  ///   Uri.parse('package:jetleaf_lang/test/utils_test.dart'),
  /// ); // returns true
  /// ```
  static bool isSkippableJetLeafPackage(Uri identifier) {
    final path = identifier.toString();
    return _jetLeafPackagesToSkip.hasMatch(path);
  }

  /// Extracts the package name from a URI, handling both Dart core and pub packages.
  ///
  /// {@template package_name_extraction}
  /// Parameters:
  /// - [uri]: Either a String or Uri representing the package location
  ///
  /// Returns:
  /// - The package name for `package:` URIs (e.g., 'html' for 'package:html')
  /// - `null` for Dart core libraries or invalid URIs
  ///
  /// Example:
  /// ```dart
  /// final pkg1 = ReflectUtils.getPackageNameFromUri('package:http/http.dart'); // 'http'
  /// final pkg2 = ReflectUtils.getPackageNameFromUri('dart:core'); // null
  /// ```
  /// {@endtemplate}
  static String? getPackageNameFromUri(dynamic uri) {
    if (uri is String) {
      try {
        uri = Uri.parse(uri);
      } catch (e) {
        return null;
      }
    }

    if (uri is! Uri) {
      return null;
    }

    if (uri.scheme == 'dart') {
      return null;
    }

    if (uri.scheme != 'package') {
      return null;
    }

    if (uri.pathSegments.isEmpty || uri.pathSegments.first.isEmpty) {
      return null;
    }

    return uri.pathSegments.first;
  }

  /// Resolves a package URI to its file system location.
  ///
  /// {@template uri_resolution}
  /// Parameters:
  /// - [uri]: The URI to resolve
  ///
  /// Returns:
  /// - The resolved file URI for `package:` URIs
  /// - The original URI for `file:` URIs
  /// - `null` for `dart:` URIs or unresolvable URIs
  ///
  /// Example:
  /// ```dart
  /// final resolved = await ReflectUtils.resolveUri(
  ///   Uri.parse('package:path/path.dart'),
  /// );
  /// ```
  /// {@endtemplate}
  static Future<Uri?> resolveUri(Uri uri) async {
    if (uri.scheme == "file") {
      return uri;
    }

    if (uri.scheme == "dart" || uri.scheme != "package") {
      return null;
    }

    return await Isolate.resolvePackageUri(uri);
  }

  /// Determines if a library should be excluded based on loader configuration.
  ///
  /// {@template library_exclusion}
  /// Parameters:
  /// - [uri]: The library URI to check
  /// - [loader]: The [RuntimeScannerConfiguration] configuration
  /// - [onError]: Error callback function
  ///
  /// Returns `true` if the library should be excluded because:
  /// - It's a Dart core library
  /// - It matches exclusion patterns
  /// - It doesn't match inclusion patterns (when specified)
  ///
  /// Example:
  /// ```dart
  /// final exclude = await ReflectUtils.shouldNotIncludeLibrary(
  ///   uri,
  ///   loader,
  ///   (error) => print('Error: $error'),
  /// );
  /// ```
  /// {@endtemplate}
  static Future<bool> shouldNotIncludeLibrary(Uri uri, RuntimeScannerConfiguration loader) async {
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first.equalsAny([
      'analyzer',
      '_fe_analyzer_shared',
    ])) {
      return true;
    }

    final packageName = getPackageNameFromUri(uri);
    final filePath = (await resolveUri(uri))?.toFilePath();

    // 🚫 Skip unwanted common folders
    const excludedDirs = [
      '/example/',
      '/benchmark/',
      '/tool/',
      '/build/',
      '/.dart_tool/',
    ];
    if (excludedDirs.any((dir) => packageName != null && uri.toString().contains("$packageName$dir"))) {
      return true;
    }

    if (matchesAnyPattern(uri.toString(), loader.packagesToExclude) || (packageName != null && matchesAnyPattern(packageName, loader.packagesToExclude))) {
      return true;
    }
    if (filePath != null && matchesAnyFile(filePath, loader.filesToExclude)) {
      return true;
    }

    if (loader.packagesToScan.isNotEmpty || loader.filesToScan.isNotEmpty) {
      final packageMatch = loader.packagesToScan.isEmpty || 
          matchesAnyPattern(uri.toString(), loader.packagesToScan) ||
          (packageName != null && matchesAnyPattern(packageName, loader.packagesToScan));

      final fileMatch = filePath != null && (loader.filesToScan.isEmpty || matchesAnyFile(filePath, loader.filesToScan));

      return !(packageMatch || fileMatch);
    }

    return false;
  }

  // Regular expressions for source code analysis
  static final RegExp _partOfDirectiveRegex = RegExp(
    r'''^\s*part\s+of\s+(['"])[\w.]+\1\s*;''',
    multiLine: true,
    caseSensitive: false,
  );

  static final RegExp _mirrorImportRegex = RegExp(
    r'''^\s*import\s+(['"])dart:mirrors\1\s*(?:as\s+\w+)?\s*(?:show\s+[^;]+)?\s*(?:hide\s+[^;]+)?\s*;''',
    multiLine: true,
    caseSensitive: false,
  );

  static final RegExp _testImportRegex = RegExp(
    r'''^\s*(?:import|export)\s+(['"])package:test/[\w/]*\.dart\1\s*;''',
    multiLine: true,
    caseSensitive: false,
  );

  /// Checks if content contains a `part of` directive.
  ///
  /// {@template is_part_of}
  /// Parameters:
  /// - [content]: The Dart source code to check
  ///
  /// Returns `true` if the content contains a valid `part of` directive.
  ///
  /// Example:
  /// ```dart
  /// final isPart = ReflectUtils.isPartOf('part of my_library;');
  /// ```
  /// {@endtemplate}
  static bool isPartOf(String content) => _partOfDirectiveRegex.hasMatch(content);

  /// {@template is_mirror_import}
  /// Checks if content imports `dart:mirrors`.
  /// 
  /// Returns `true` if the content imports the mirrors library.
  /// {@endtemplate}
  static bool hasMirrorImport(String content) => _mirrorImportRegex.hasMatch(content);

  /// {@template is_test}
  /// Checks if content is a test file.
  ///
  /// Returns `true` if the content imports the test package.
  /// {@endtemplate}
  static bool isTest(String content) => _testImportRegex.hasMatch(content);

  /// Matches input against a list of patterns.
  ///
  /// {@template pattern_matching}
  /// Parameters:
  /// - [input]: The string to match against
  /// - [patterns]: List of patterns (strings or regex patterns prefixed with 'r:')
  ///
  /// Returns `true` if any pattern matches the input.
  ///
  /// Example:
  /// ```dart
  /// final matches = ReflectUtils.matchesAnyPattern(
  ///   'package:http/http.dart',
  ///   ['http', 'r:package:http/.*'],
  /// );
  /// ```
  /// {@endtemplate}
  static bool matchesAnyPattern(String input, List<String> patterns) {
    return patterns.any((pattern) {
      if (pattern.startsWith('r:')) {
        try {
          return RegExp(pattern.substring(2)).hasMatch(input);
        } catch (e) {
          return false;
        }
      } else if (pattern.startsWith("r'")) {
        try {
          return RegExp(pattern).hasMatch(input);
        } catch (e) {
          return false;
        }
      }
      return input == pattern;
    });
  }

  /// {@template should_not_include_path}
  /// Determines if a path should be excluded based on loader configuration.
  ///
  /// {@endtemplate}
  static Future<bool> shouldNotIncludePath(Uri uri, File file, RuntimeScannerConfiguration loader) async {
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first.equalsAny(['analyzer', '_fe_analyzer_shared'])) {
      return true;
    }

    final packageName = getPackageNameFromUri(uri);
    final filePath = file.path;

    if (matchesAnyPattern(filePath, loader.packagesToExclude) || (packageName != null && matchesAnyPattern(packageName, loader.packagesToExclude))) {
      return true;
    }

    if (matchesAnyFile(filePath, loader.filesToExclude)) {
      return true;
    }

    if (loader.packagesToScan.isNotEmpty || loader.filesToScan.isNotEmpty) {
      final packageMatch = loader.packagesToScan.isEmpty || 
          matchesAnyPattern(uri.toString(), loader.packagesToScan) ||
          (packageName != null && matchesAnyPattern(packageName, loader.packagesToScan));

      final fileMatch = (loader.filesToScan.isEmpty || matchesAnyFile(filePath, loader.filesToScan));

      return !(packageMatch || fileMatch);
    }

    return false;
  }

  /// Matches a file path against a list of files.
  ///
  /// {@macro pattern_matching}
  /// Parameters:
  /// - [filePath]: The path to check
  /// - [files]: List of [File] objects to match against
  ///
  /// Returns `true` if the normalized path matches any file.
  static bool matchesAnyFile(String filePath, List<File> files) {
    final normalizedPath = p.normalize(filePath);
    return files.any((file) => p.normalize(file.absolute.path) == normalizedPath);
  }

  /// Determines if the type is a list type.
  /// 
  /// This method determines if the type is a list type.
  /// It handles complex type relationships and source code analysis to provide
  /// accurate reflection information.
  /// 
  /// **Parameters:**
  /// - [type]: The type to process
  /// 
  /// **Returns:** True if the type is a list type, false otherwise
  static bool isListType(Type type) {
    return isStringAListType(type.toString())
      || type == List 
      || type == Iterable 
      || type is Iterable
      || type == Queue
      || type == HashSet;
  }

  /// Determines if the type is a list type.
  /// 
  /// This method determines if the type is a list type.
  /// It handles complex type relationships and source code analysis to provide
  /// accurate reflection information.
  /// 
  /// **Parameters:**
  /// - [type]: The type to process
  /// 
  /// **Returns:** True if the type is a list type, false otherwise
  static bool isStringAListType(String type) {
    return type.startsWith('List<')
      || type.startsWith('ArrayList<')
      || type.startsWith('LinkedList<')
      || type.startsWith('Stack<')
      || type.startsWith('Queue<')
      || type.startsWith('LinkedQueue<')
      || type.startsWith('LinkedStack<')
      || type.startsWith('HashSet<');
  }

  /// Determines if the type is a map type or a generic key-value container type.
  /// 
  /// This method checks if the type is either:
  /// - A Map/HashMap type
  /// - A generic class with at least two type parameters (potential key-value container)
  /// 
  /// **Parameters:**
  /// - [type]: The type to process
  /// 
  /// **Returns:** True if the type is a map or key-value container type, false otherwise
  static bool isMapType(Type type) {
    return isStringAMapType(type.toString())
      || type == Map 
      || type == HashMap
      || type is Map
      || _isKeyValueContainerType(type);
  }

  /// Determines if the type string represents a map or key-value container type.
  /// 
  /// This checks for:
  /// - Standard Map types (Map<..., ...>, HashMap<..., ...>)
  /// - Generic types with two type parameters (e.g., `Repository<String, User>`)
  /// 
  /// **Parameters:**
  /// - [type]: The type string to process
  /// 
  /// **Returns:** True if the type string matches a map or key-value pattern
  static bool isStringAMapType(String type) {
    return type.startsWith('Map<') 
      || type.startsWith('HashMap<')
      || _isGenericKeyValueTypeString(type);
  }

  /// Checks if a Type represents a generic class with at least two type parameters
  static bool _isKeyValueContainerType(Type type) {
    final typeString = type.toString();
    return _isGenericKeyValueTypeString(typeString);
  }

  /// Checks if a type string represents a generic with at least two type parameters
  static bool _isGenericKeyValueTypeString(String typeString) {
    // Pattern for generic types with at least two type parameters
    final genericPattern = RegExp(r'^[^<]+<[^,]+,[^>]+>');
    return genericPattern.hasMatch(typeString);
  }

  /// Strip comments from source code
  static String stripComments(String code) {
    final commentPattern = RegExp(
      r'(//.*?$)|(/\*\*?[\s\S]*?\*/)|(^///.*?$)',
      multiLine: true,
      dotAll: true,
    );
    return code.replaceAll(commentPattern, '');
  }
}

@internal
extension StringX on String {
  bool equalsAny(List<String> values, {bool isLowerCase = false, bool isUpperCase = false, bool isIgnoreCase = false}) {
    if(isUpperCase) {
      return values.any((v) => v.toUpperCase() == toUpperCase());
    }

    return values.any((v) => toLowerCase() == v.toLowerCase());
  }
}