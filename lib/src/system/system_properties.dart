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

import 'compilation_mode.dart';
import 'properties.dart';

/// {@template system_properties}
/// Immutable snapshot of system runtime properties.
///
/// This class provides a serializable representation of the application's
/// runtime environment state, useful for:
/// - Diagnostic logging and monitoring
/// - Configuration management
/// - Performance analysis
/// - Environment-specific behavior
///
/// All properties are **immutable** and captured at creation time.
///
/// ### Example
/// ```dart
/// final properties = _SystemProperties.builder()
///   .compilationMode(CompilationMode.release)
///   .runningFromDill(true)
///   .entrypoint('build/main.dill')
///   .launchCommand('dart run build/main.dill')
///   .ideRunning(false)
///   .dependencyCount(34)
///   .configurationCount(12)
///   .watchModeEnabled(false)
///   .build();
///
/// print(properties.toJson());
/// ```
/// {@endtemplate}
class _SystemProperties implements SystemProperties {
  CompilationMode _compilationMode;
  bool _runningFromDill;
  bool _runningAot;
  bool _runningJit;
  String _entrypoint;
  String _launchCommand;
  bool _ideRunning;
  int _dependencyCount;
  int _configurationCount;
  bool _watchModeEnabled;

  /// {@macro system_properties}
  _SystemProperties({
    required CompilationMode compilationMode,
    required bool runningFromDill,
    required bool runningAot,
    required bool runningJit,
    required String entrypoint,
    required String launchCommand,
    required bool ideRunning,
    required int dependencyCount,
    required int configurationCount,
    required bool watchModeEnabled,
  })  : _compilationMode = compilationMode,
        _runningFromDill = runningFromDill,
        _runningAot = runningAot,
        _runningJit = runningJit,
        _entrypoint = entrypoint,
        _launchCommand = launchCommand,
        _ideRunning = ideRunning,
        _dependencyCount = dependencyCount,
        _configurationCount = configurationCount,
        _watchModeEnabled = watchModeEnabled;

  /// Creates a [_SystemProperties] instance with default values.
  ///
  /// By default:
  /// - [CompilationMode.debug]
  /// - JIT enabled
  /// - No dependencies or configuration
  /// - Watch mode disabled
  _SystemProperties.none()
      : _compilationMode = CompilationMode.debug,
        _runningFromDill = false,
        _runningAot = false,
        _runningJit = true,
        _entrypoint = '',
        _launchCommand = '',
        _ideRunning = false,
        _dependencyCount = 0,
        _configurationCount = 0,
        _watchModeEnabled = false;

  @override
  CompilationMode getCompilationMode() => _compilationMode;

  @override
  bool isRunningFromDill() => _runningFromDill;

  @override
  bool isRunningAot() => _runningAot;

  @override
  bool isRunningJit() => _runningJit;

  @override
  String getEntrypoint() => _entrypoint;

  @override
  String getLaunchCommand() => _launchCommand;

  @override
  bool isIdeRunning() => _ideRunning;

  @override
  int getDependencyCount() => _dependencyCount;

  @override
  int getConfigurationCount() => _configurationCount;

  @override
  bool isWatchModeEnabled() => _watchModeEnabled;

  @override
  bool isDevelopmentMode() => _compilationMode.isDevelopment();

  @override
  bool isProductionMode() => _compilationMode.isProduction();

  /// Serializes this object into a JSON-compatible [Map].
  ///
  /// Example:
  /// ```dart
  /// final properties = _SystemProperties.builder()
  ///   .compilationMode(CompilationMode.debug)
  ///   .build();
  ///
  /// print(properties.toJson());
  /// ```
  Map<String, Object> toJson() => {
    'compilationMode': _compilationMode.name,
    'runningFromDill': _runningFromDill,
    'runningAot': _runningAot,
    'runningJit': _runningJit,
    'entrypoint': _entrypoint,
    'launchCommand': _launchCommand,
    'ideRunning': _ideRunning,
    'dependencyCount': _dependencyCount,
    'configurationCount': _configurationCount,
    'watchModeEnabled': _watchModeEnabled,
  };

  @override
  String toString() {
    return '_SystemProperties(\n'
      '  compilationMode: $_compilationMode,\n'
      '  runningFromDill: $_runningFromDill,\n'
      '  runningAot: $_runningAot,\n'
      '  runningJit: $_runningJit,\n'
      '  entrypoint: $_entrypoint,\n'
      '  launchCommand: $_launchCommand,\n'
      '  ideRunning: $_ideRunning,\n'
      '  dependencyCount: $_dependencyCount,\n'
      '  configurationCount: $_configurationCount,\n'
      '  watchModeEnabled: $_watchModeEnabled\n'
      ')';
  }
}

/// {@template system_properties_builder}
/// Builder for creating [_SystemProperties] instances using a fluent API.
///
/// This allows you to configure runtime properties step by step before
/// finalizing the snapshot with [build].
///
/// Example:
/// ```dart
/// final properties = _SystemProperties.builder()
///   .compilationMode(CompilationMode.release)
///   .runningFromDill(true)
///   .entrypoint('build/main.dill')
///   .build();
///
/// print(properties.getCompilationMode()); // CompilationMode.release
/// ```
/// {@endtemplate}
class SystemPropertiesBuilder extends _SystemProperties {
  /// {@macro system_properties_builder}
  SystemPropertiesBuilder() : super.none();

  /// Sets the compilation mode.
  SystemPropertiesBuilder compilationMode(CompilationMode mode) {
    _compilationMode = mode;
    return this;
  }

  /// Sets whether the app is running from a `.dill` file.
  SystemPropertiesBuilder runningFromDill(bool value) {
    _runningFromDill = value;
    return this;
  }

  /// Sets whether the app is running in **AOT** mode.
  SystemPropertiesBuilder runningAot(bool value) {
    _runningAot = value;
    return this;
  }

  /// Sets whether the app is running in **JIT** mode.
  SystemPropertiesBuilder runningJit(bool value) {
    _runningJit = value;
    return this;
  }

  /// Sets the application entrypoint path.
  SystemPropertiesBuilder entrypoint(String path) {
    _entrypoint = path;
    return this;
  }

  /// Sets the launch command used to start the application.
  SystemPropertiesBuilder launchCommand(String command) {
    _launchCommand = command;
    return this;
  }

  /// Sets whether the app is running inside an IDE.
  SystemPropertiesBuilder ideRunning(bool value) {
    _ideRunning = value;
    return this;
  }

  /// Sets the dependency count.
  SystemPropertiesBuilder dependencyCount(int count) {
    _dependencyCount = count;
    return this;
  }

  /// Sets the configuration count.
  SystemPropertiesBuilder configurationCount(int count) {
    _configurationCount = count;
    return this;
  }

  /// Sets whether watch mode is enabled.
  SystemPropertiesBuilder watchModeEnabled(bool value) {
    _watchModeEnabled = value;
    return this;
  }

  /// Finalizes and creates a new immutable [_SystemProperties] snapshot.
  ///
  /// Example:
  /// ```dart
  /// final props = _SystemProperties.builder()
  ///   .compilationMode(CompilationMode.release)
  ///   .build();
  ///
  /// print(props.isProductionMode()); // true
  /// ```
  _SystemProperties build() {
    return _SystemProperties(
      compilationMode: _compilationMode,
      runningFromDill: _runningFromDill,
      runningAot: _runningAot,
      runningJit: _runningJit,
      entrypoint: _entrypoint,
      launchCommand: _launchCommand,
      ideRunning: _ideRunning,
      dependencyCount: _dependencyCount,
      configurationCount: _configurationCount,
      watchModeEnabled: _watchModeEnabled,
    );
  }
}