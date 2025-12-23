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

/// {@template system_environment}
/// The [SystemProperties] interface provides a clean, method-based API
/// for querying the runtime environment. Unlike direct property access,
/// all system state is exposed via methods to enforce immutability
/// and ensure consistent naming conventions.
///
/// ### Features
/// - Runtime **compilation mode** detection
/// - **Execution environment** analysis
/// - **IDE integration** detection
/// - **Lifecycle & configuration** metadata
///
/// ### Example
/// ```dart
/// if (SystemEnvironment.isRunningAot()) {
///   logger.info('Running in AOT mode');
/// }
///
/// if (SystemEnvironment.isIdeRunning()) {
///   enableHotReload();
/// }
/// ```
/// {@endtemplate}
abstract interface class SystemProperties {
  /// {@macro system_environment}
  const SystemProperties();

  /// {@template system_environment_compilation_mode}
  /// Returns the current Dart VM [CompilationMode].
  ///
  /// Example:
  /// ```dart
  /// final mode = env.getCompilationMode();
  /// if (mode.isProduction()) {
  ///   print('Production build');
  /// }
  /// ```
  /// {@endtemplate}
  CompilationMode getCompilationMode();

  /// {@template system_environment_running_aot}
  /// Returns `true` if the application is running with **AOT (Ahead-of-Time)** compilation.
  ///
  /// Example:
  /// ```dart
  /// if (env.isRunningAot()) {
  ///   print('Optimized AOT runtime');
  /// }
  /// ```
  /// {@endtemplate}
  bool isRunningAot();

  /// {@template system_environment_running_jit}
  /// Returns `true` if the application is running with **JIT (Just-in-Time)** compilation.
  ///
  /// Example:
  /// ```dart
  /// if (env.isRunningJit()) {
  ///   print('Dynamic JIT runtime');
  /// }
  /// ```
  /// {@endtemplate}
  bool isRunningJit();

  /// {@template system_environment_running_dill}
  /// Returns `true` if the application is running from a precompiled `.dill` file.
  ///
  /// Example:
  /// ```dart
  /// if (env.isRunningFromDill()) {
  ///   print('Bootstrapped from dill file');
  /// }
  /// ```
  /// {@endtemplate}
  bool isRunningFromDill();

  /// {@template system_environment_ide}
  /// Returns `true` if the application was launched from an **IDE environment**.
  ///
  /// Example:
  /// ```dart
  /// if (env.isIdeRunning()) {
  ///   print('IDE mode enabled');
  /// }
  /// ```
  /// {@endtemplate}
  bool isIdeRunning();

  /// {@template system_environment_watch}
  /// Returns `true` if the application is running in **watch / hot-reload mode**.
  ///
  /// Example:
  /// ```dart
  /// if (env.isWatchModeEnabled()) {
  ///   print('Hot reload active');
  /// }
  /// ```
  /// {@endtemplate}
  bool isWatchModeEnabled();

  /// {@template system_environment_dev}
  /// Returns `true` if the application is running in **development mode**.
  ///
  /// Example:
  /// ```dart
  /// if (env.isDevelopmentMode()) {
  ///   print('Development environment');
  /// }
  /// ```
  /// {@endtemplate}
  bool isDevelopmentMode();

  /// {@template system_environment_prod}
  /// Returns `true` if the application is running in **production mode**.
  ///
  /// Example:
  /// ```dart
  /// if (env.isProductionMode()) {
  ///   print('Production environment');
  /// }
  /// ```
  /// {@endtemplate}
  bool isProductionMode();

  /// {@template system_environment_entrypoint}
  /// Returns the **application entry point** file path.
  ///
  /// Example:
  /// ```dart
  /// print('App started from: ${env.getEntrypoint()}');
  /// ```
  /// {@endtemplate}
  String getEntrypoint();

  /// {@template system_environment_launch_command}
  /// Returns the full **command** used to launch the application.
  ///
  /// Example:
  /// ```dart
  /// print('Launch command: ${env.getLaunchCommand()}');
  /// ```
  /// {@endtemplate}
  String getLaunchCommand();

  /// {@template system_environment_dependency_count}
  /// Returns the number of resolved **dependencies** in the application context.
  ///
  /// Example:
  /// ```dart
  /// print('Dependencies loaded: ${env.getDependencyCount()}');
  /// ```
  /// {@endtemplate}
  int getDependencyCount();

  /// {@template system_environment_configuration_count}
  /// Returns the number of discovered **configuration classes**.
  ///
  /// Example:
  /// ```dart
  /// print('Configurations: ${env.getConfigurationCount()}');
  /// ```
  /// {@endtemplate}
  int getConfigurationCount();
}