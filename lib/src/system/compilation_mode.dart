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

/// {@template compilation_mode}
/// Dart supports multiple runtime modes, each optimized for different use cases:
///
/// - [debug]: Development mode with hot reload and assertions enabled
/// - [profile]: Performance analysis mode with minimal optimizations
/// - [release]: Production mode with full optimizations
///
/// JetLeaf uses this enum to determine runtime behavior and feature availability.
///
/// Example:
/// ```dart
/// if (SystemEnvironment.getCompilationMode() == CompilationMode.release) {
///   logger.info('Production mode enabled');
/// }
/// ```
/// {@endtemplate}
enum CompilationMode {
  /// {@macro compilation_mode}
  debug,

  /// {@macro compilation_mode}
  profile,

  /// {@macro compilation_mode}
  special,

  /// {@macro compilation_mode}
  release;

  /// Returns true if this is a development mode
  bool isDevelopment() => this == CompilationMode.debug;

  /// Returns true if this is a production mode
  bool isProduction() => this == CompilationMode.release || this == CompilationMode.special;

  @override
  String toString() => name;
}