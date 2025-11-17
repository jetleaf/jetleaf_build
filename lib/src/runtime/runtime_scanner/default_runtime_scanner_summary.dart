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

import '../runtime_provider/configurable_runtime_provider.dart';
import 'configurable_runtime_scanner_summary.dart';

/// {@template default_runtime_scan_summary}
/// A default implementation of [ConfigurableRuntimeScannerSummary] that
/// holds the results of a Runtime scan including the build context,
/// timestamp, and all reported messages (errors, warnings, and info).
///
/// This class is typically used as a container during or after a Runtime
/// scan to collect and access scanning results.
///
/// ## Example:
/// ```dart
/// final summary = DefaultRuntimeScannerSummary();
/// summary.setContext(context);
/// summary.setBuildTime(DateTime.now());
/// summary.addError("Missing annotation on class Foo");
/// summary.addWarning("Deprecated API used in Bar");
/// summary.addInfo("Scan completed in 120ms");
///
/// print(summary.getErrors()); // ["Missing annotation on class Foo"]
/// ```
/// {@endtemplate}
class DefaultRuntimeScannerSummary extends ConfigurableRuntimeScannerSummary {
  late ConfigurableRuntimeProvider _context;
  late DateTime _buildTime;
  late List<String> _errors;
  late List<String> _warnings;
  late List<String> _infos;
  late Map<String, String> _generatedFiles;

  /// {@macro default_runtime_scan_summary}
  DefaultRuntimeScannerSummary() {
    _errors = <String>[];
    _warnings = <String>[];
    _infos = <String>[];
    _generatedFiles = <String, String>{};
  }

  @override
  ConfigurableRuntimeProvider getContext() => _context;

  @override
  DateTime getBuildTime() => _buildTime;

  @override
  List<String> getErrors() => _errors;

  @override
  List<String> getWarnings() => _warnings;

  @override
  List<String> getInfos() => _infos;

  @override
  void setContext(ConfigurableRuntimeProvider context) {
    _context = context;
  }

  @override
  void setBuildTime(DateTime buildTime) {
    _buildTime = buildTime;
  }

  @override
  void addErrors(List<String> errors) {
    _errors.addAll(errors);
  }

  @override
  void addWarnings(List<String> warnings) {
    _warnings.addAll(warnings);
  }

  @override
  void addInfos(List<String> infos) {
    _infos.addAll(infos);
  }

  @override
  void addGeneratedFiles(Map<String, String> files) {
    _generatedFiles.addAll(files);
  }

  @override
  Map<String, String> getGeneratedFiles() => _generatedFiles;
}