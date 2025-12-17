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

import 'dart:io';

import 'abstract_file_loader_utility.dart';

/// {@template abstract_part_file_utility}
/// Provides common functionality for detecting whether a Dart source file
/// represents a **part file** (i.e., contains a valid `part of` directive).
///
/// This abstract utility encapsulates the logic for scanning source code using
/// a lightweight directive tokenizer and performing the minimal directive
/// parsing necessary to recognize `part of` declarations.
///
/// ### What qualifies as a **part file**
///
/// A file is considered a part file if it contains a syntactically valid:
///
/// ```dart
/// part of <identifier or stringLiteral>;
/// ```
///
/// The scanner is deliberately lightweight, ignoring comments, whitespace, and
/// string contents, and does not perform full Dart parsing. It only identifies
/// the directive pattern.
///
/// ### Notable behaviors
///
/// - Returns `false` for unreadable files or I/O failures.
/// - Ignores malformed directives such as `part of ;`.
/// - Accepts either:
///   - `part of someLibrary;`
///   - `part of 'some_library.dart';`
///
/// Subclasses may extend functionality by providing directory traversal or
/// caching, but detection logic is centralized here.
/// 
/// See also: [AbstractFileLoaderUtility]
/// 
/// {@endtemplate}
abstract class AbstractPartFileUtility extends AbstractFileLoaderUtility {
  /// {@macro abstract_part_file_utility}
  AbstractPartFileUtility(super.configuration, super.onError, super.onInfo, super.onWarning, super.tryOutsideIsolate);

  /// Creates and returns a new [_DirectiveScanner] for the given raw source.
  ///
  /// This indirection allows subclasses to override or customize the scanner
  /// if different tokenization behavior is desired.
  _DirectiveScanner getDirectiveScanner(String src) => _DirectiveScanner(src);

  /// Returns `true` if the given [file] contains a valid `part of` directive.
  ///
  /// The file is read synchronously. If the file cannot be read, or if an
  /// exception occurs, the method returns `false`.
  ///
  /// This is simply a convenience wrapper around [_containsPartOfDirective].
  @override
  bool isPartFile(File file) {
    try {
      final text = file.readAsStringSync();
      return _containsPartOfDirective(text);
    } catch (_) {
      // Errors (missing file, unreadable text) are treated as non-part files.
      return false;
    }
  }

  /// Returns `true` if [src] contains a valid `part of` directive.
  ///
  /// The logic uses a [_DirectiveScanner] to tokenize the source without
  /// parsing it fully. The expected token sequence is:
  ///
  /// ```
  /// part of <IDENTIFIER or STRING> ;
  /// ```
  ///
  /// ### Syntax rules enforced:
  /// - The keyword `part` must appear.
  /// - Must be immediately followed by the keyword `of`.
  /// - Next token must *not* be `;` (guarding against invalid `part of ;`).
  /// - Next token after the name/string must be a semicolon.
  ///
  /// Returns `true` for both:
  ///   - `part of my_library;`
  ///   - `part of 'my_library.dart';`
  ///
  /// Returns `false` for malformed forms such as:
  ///   - `part of ;`
  ///   - `part of`
  ///   - `part someOtherThing`
  ///
  /// The method performs no semantic validation of identifiers; it only checks
  /// directive structure.
  bool _containsPartOfDirective(String src) {
    final scanner = _DirectiveScanner(src);

    while (scanner.moveNextToken()) {
      if (scanner.token == 'part') {
        // Expect: part of X ;
        if (scanner.moveNextToken() && scanner.token == 'of') {
          // Next token is either IDENTIFIER or STRING literal
          if (scanner.moveNextToken()) {
            final tok = scanner.token;

            if (tok == ';') {
              // invalid "part of ;" → ignore
              continue;
            }

            // Must be followed by a semicolon
            if (scanner.moveNextToken() && scanner.token == ';') {
              return true;
            }
          }
        }
      }
    }
    return false;
  }
}

/// A lightweight, single-pass tokenizer used for scanning Dart directive
/// structures (e.g., `import`, `export`, `part`, `part of`).
///
/// This scanner is intentionally **minimal** and optimized for directive
/// extraction rather than full lexical correctness.
///
/// ### Features
///
/// - Skips:
///   - Whitespace
///   - `//` line comments
///   - `/* */` block comments
///   - Normal string literals: `"..."`, `'...'`
///   - Triple-quoted strings
///   - Raw strings: `r"..."`, `r'...'`
///
/// - Yields:
///   - Identifiers (letters, digits after first, `_`, `$`)
///   - Keywords (treated the same as identifiers)
///   - Single-character symbols
///   - A placeholder token `"STR"` for any type of string literal
///
/// ### Limitations
/// - Does not validate token correctness beyond basic lexical structure.
/// - Does not handle interpolation content inside strings.
/// - Symbols are returned as **single characters only**.
///
/// The class is intentionally simple because directive scanning does not
/// require full lexical precision.
class _DirectiveScanner {
  /// The raw source code being scanned.
  final String src;

  /// Current scan index into [src].
  ///
  /// Always points to the next character to be consumed by `_nextToken`.
  int i = 0;

  /// The most recently produced token, or `null` if scanning has finished.
  ///
  /// Populated by [moveNextToken].
  String? token;

  /// Creates a new scanner instance operating on the provided source [src].
  _DirectiveScanner(this.src);

  /// Returns `true` if scanning has reached the end of the source.
  bool get _eof => i >= src.length;

  /// Advances the scanner to the next token.
  ///
  /// Updates [token] with the next token value or `null` if no more tokens
  /// exist.
  ///
  /// Returns:
  /// - `true` if a token was produced
  /// - `false` if end-of-file was reached
  bool moveNextToken() {
    token = _nextToken();
    return token != null;
  }

  /// Reads and returns the next token from the source.
  ///
  /// Performs all whitespace/comment/string skipping before returning a
  /// meaningful token.
  ///
  /// Token Types:
  /// - Identifier/keyword: `'foo'`, `'import'`, `'part'`, …
  /// - Symbol: `'{'`, `';'`, `'.'`, …
  /// - String literal placeholder: `"STR"`
  ///
  /// Returns `null` only when EOF is reached.
  String? _nextToken() {
    while (!_eof) {
      final c = src[i];

      // ---------------------------------------
      // Skip whitespace
      // ---------------------------------------
      if (c.trim().isEmpty) {
        i++;
        continue;
      }

      // ---------------------------------------
      // Skip // comments
      // ---------------------------------------
      if (c == '/' && _peek() == '/') {
        i += 2;
        while (!_eof && src[i] != '\n') {
          i++;
        }
        continue;
      }

      // ---------------------------------------
      // Skip /* block comments */
      // ---------------------------------------
      if (c == '/' && _peek() == '*') {
        i += 2;
        while (!_eof && !(src[i] == '*' && _peek() == '/')) {
          i++;
        }
        i += 2;
        continue;
      }

      // ---------------------------------------
      // Skip string literals "..." or '...'
      // ---------------------------------------
      if (c == '"' || c == "'") {
        _skipString(c);
        return '"STR"'; // placeholder token
      }

      // ---------------------------------------
      // Skip raw strings r"..."
      // ---------------------------------------
      if (c == 'r' && (_peek() == '"' || _peek() == "'")) {
        final q = _peek()!;
        i += 2;
        while (!_eof && src[i] != q) {
          i++;
        }
        i++;
        return '"STR"';
      }

      // ---------------------------------------
      // Identifiers / keywords
      // ---------------------------------------
      if (_isIdentStart(c)) {
        final start = i;
        i++;
        while (!_eof && _isIdentContinue(src[i])) {
          i++;
        }
        return src.substring(start, i);
      }

      // ---------------------------------------
      // Symbols
      // ---------------------------------------
      i++;
      return c;
    }

    return null;
  }

  /// Skips a normal or triple-quoted string literal beginning with [quote].
  ///
  /// Handles:
  /// - `'...'`
  /// - `"..."`  
  /// - `'''...'''`
  /// - `"""..."""`
  ///
  /// Escapes (`\`) inside normal (non-raw) strings are supported so escaped
  /// quotes inside strings do not prematurely terminate scanning.
  void _skipString(String quote) {
    final isTriple = i + 2 < src.length && src[i + 1] == quote && src[i + 2] == quote;

    if (isTriple) {
      i += 3;
      while (!_eof &&
          !(src[i] == quote &&
            src[i + 1] == quote &&
            src[i + 2] == quote)) {
        i++;
      }
      i += 3;
      return;
    }

    // Normal string
    i++;
    while (!_eof) {
      if (src[i] == '\\') {
        i += 2;
        continue;
      }
      if (src[i] == quote) {
        i++;
        break;
      }
      i++;
    }
  }

  /// Looks ahead one character without consuming it.
  ///
  /// Returns the next character or `null` if at end-of-file.
  String? _peek() => (i + 1 < src.length) ? src[i + 1] : null;

  /// Returns `true` if [c] is a valid start character for a Dart identifier.
  ///
  /// Valid start characters:
  /// - A–Z
  /// - a–z
  /// - `_`
  /// - `$`
  bool _isIdentStart(String c) =>
      (c.codeUnitAt(0) >= 65 && c.codeUnitAt(0) <= 90) || // A-Z
      (c.codeUnitAt(0) >= 97 && c.codeUnitAt(0) <= 122) || // a-z
      c == '_' || c == '\$';

  /// Returns `true` if [c] is a valid subsequent character in a Dart identifier.
  ///
  /// Valid continuation characters:
  /// - Identifier-start characters
  /// - Digits 0–9
  bool _isIdentContinue(String c) =>
      _isIdentStart(c) ||
      (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57); // 0-9
}

  // bool isPartFile(File file) {
  //   try {
  //     final content = file.readAsStringSync();
  //     return content.contains(RegExp(r'^\s*part\s+of\s+', multiLine: true));
  //   } catch (e) {
  //     return false;
  //   }
  // }