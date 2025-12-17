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

import 'package:jetleaf_build/src/runtime/scanner/runtime_scanner_configuration.dart';
import 'package:jetleaf_build/src/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  group('getPackageNameFromUri', () {
    test('should extract package name from pub packages', () {
      expect(RuntimeUtils.getPackageNameFromUri('package:html'), 'html');
      expect(RuntimeUtils.getPackageNameFromUri('package:async'), 'async');
      expect(RuntimeUtils.getPackageNameFromUri('package:test'), 'test');
      expect(RuntimeUtils.getPackageNameFromUri('package:collection'), 'collection');
    });

    test('should return null for Dart core libraries', () {
      expect(RuntimeUtils.getPackageNameFromUri('dart:html'), isNull);
      expect(RuntimeUtils.getPackageNameFromUri('dart:async'), isNull);
      expect(RuntimeUtils.getPackageNameFromUri('dart:core'), isNull);
      expect(RuntimeUtils.getPackageNameFromUri('dart:ui'), isNull);
    });

    test('should handle valid package names regardless of keywords', () {
      expect(RuntimeUtils.getPackageNameFromUri('package:class'), 'class');
      expect(RuntimeUtils.getPackageNameFromUri('package:void'), 'void');
      expect(RuntimeUtils.getPackageNameFromUri('package:for'), 'for');
    });

    test('should handle other edge cases', () {
      expect(RuntimeUtils.getPackageNameFromUri('package:_private'), '_private');
      expect(RuntimeUtils.getPackageNameFromUri('package:my_pkg/sub/path.dart'), 'my_pkg');
      expect(RuntimeUtils.getPackageNameFromUri('package:my_pkg/'), 'my_pkg');
      expect(RuntimeUtils.getPackageNameFromUri('package:my_pkg'), 'my_pkg');
    });

    test('should return null for invalid cases', () {
      expect(RuntimeUtils.getPackageNameFromUri('package:/'), isNull);
      expect(RuntimeUtils.getPackageNameFromUri('https://example.com'), isNull);
      expect(RuntimeUtils.getPackageNameFromUri('file:///path.dart'), isNull);
      expect(RuntimeUtils.getPackageNameFromUri(''), isNull);
      expect(RuntimeUtils.getPackageNameFromUri(null), isNull);
    });
  });

  group('isNonLoadableJetLeafFile', () {
    test('should match jetleaf tool/bin folders', () {
      expect(RuntimeUtils.isNonLoadableJetLeafFile(Uri.parse('file:///project/jetleaf_lang/bin')), true);
      expect(RuntimeUtils.isNonLoadableJetLeafFile(Uri.parse('file:///jetleaf_lang/tool/')), true);
      expect(RuntimeUtils.isNonLoadableJetLeafFile(Uri.parse('file:///some/path/jetleaf_lang/bin/main.dart')), true);
    });

    test('should not match other paths', () {
      expect(RuntimeUtils.isNonLoadableJetLeafFile(Uri.parse('file:///jetleaf_lang/src/main.dart')), false);
      expect(RuntimeUtils.isNonLoadableJetLeafFile(Uri.parse('file:///bin/jetleaf_lang')), false);
    });
  });

  group('isSkippableJetLeafPackage', () {
    test('should match specific jetleaf packages', () {
      expect(RuntimeUtils.isSkippableJetLeafPackage(Uri.parse('package:jetleaf_lang/src/lang/reflect/access')), true);
      expect(RuntimeUtils.isSkippableJetLeafPackage(Uri.parse('package:jetleaf_lang/src/logging/logger.dart')), true);
      expect(RuntimeUtils.isSkippableJetLeafPackage(Uri.parse('package:jetleaf_lang/test')), true);
    });

    test('should not match other packages', () {
      expect(RuntimeUtils.isSkippableJetLeafPackage(Uri.parse('package:jetleaf_lang/src/core')), false);
      expect(RuntimeUtils.isSkippableJetLeafPackage(Uri.parse('package:other_package/test')), false);
    });
  });

  group('ReflectUtils.shouldNotIncludeLibrary', () {
    test('should exclude packages in packagesToExclude', () async {
      final loader = RuntimeScannerConfiguration(
        packagesToExclude: ['package:html', 'r:package:.*_test'],
      );
      
      expect(await RuntimeUtils.shouldNotIncludeLibrary(Uri.parse('package:html/parser.dart'), loader), true);
      expect(await RuntimeUtils.shouldNotIncludeLibrary(Uri.parse('package:app_test/core.dart'), loader), true);
    });

    test('should include packages in packagesToScan', () async {
      final loader = RuntimeScannerConfiguration(
        packagesToScan: ['package:core', 'r:package:feature_.*'],
      );
      
      expect(await RuntimeUtils.shouldNotIncludeLibrary(Uri.parse('package:core/utils.dart'), loader), false);
      expect(await RuntimeUtils.shouldNotIncludeLibrary(Uri.parse('package:feature_auth/login.dart'), loader), false);
    });

    test('should handle non-package URIs', () async {
      final loader = RuntimeScannerConfiguration();
      
      expect(await RuntimeUtils.shouldNotIncludeLibrary(Uri.parse('dart:core'), loader), false);
      expect(await RuntimeUtils.shouldNotIncludeLibrary(Uri.parse('file:///test/main_test.dart'), loader), false);
    });
  });

  group('Content Analysis', () {
    test('isPartOf should detect part-of directives', () {
      expect(RuntimeUtils.isPartOf("part of 'main.dart';"), true);
      expect(RuntimeUtils.isPartOf("// part of main.dart"), false); // Commented out
    });

    test('hasMirrorImport should detect mirror imports', () {
      expect(RuntimeUtils.hasMirrorImport("import 'dart:mirrors';"), true);
      expect(RuntimeUtils.hasMirrorImport("import 'package:test/test.dart';"), false);
    });

    test('isTest should detect test imports', () {
      expect(RuntimeUtils.isTest("import 'package:test/test.dart';"), true);
      expect(RuntimeUtils.isTest("import 'package:test/scaffolding.dart';"), true);
    });
  });

  // Helper function tests
  group('Helper Functions', () {
    test('matchesAnyPattern should handle regex and string patterns', () {
      expect(RuntimeUtils.matchesAnyPattern('package:html', ['package:html']), true);
      expect(RuntimeUtils.matchesAnyPattern('package:test', ['r:package:t.*']), true);
      expect(RuntimeUtils.matchesAnyPattern('package:core', ['package:html']), false);
    });

    test('matchesAnyFile should match file paths', () {
      final currentDir = Directory.current.path;
      expect(RuntimeUtils.matchesAnyFile('$currentDir/lib/main.dart', [File('$currentDir/lib/main.dart')]), true);
      expect(RuntimeUtils.matchesAnyFile('$currentDir/lib/utils.dart', [File('$currentDir/lib/main.dart')]), false);
    });
  });
}