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

import 'package:meta/meta.dart';

/// {@template constant}
/// Constant class containing predefined constants used across the application.
/// 
/// This class provides a centralized location for defining constants that are
/// used throughout the application. It includes:
/// - Default profile
/// - 
/// 
/// {@endtemplate}
class Constant {
  /// {@macro constant}
  Constant._();

  /// {@template html_constant_favicon}
  /// A base64-encoded [SVG] favicon string that renders an emoji icon directly in HTML.
  ///
  /// This is especially useful for lightweight server-rendered apps or development environments
  /// where no external favicon file is hosted.
  ///
  /// The icon defaults to the leaf emoji 🍃, but you can replace `${ICON}` with any valid character or emoji.
  ///
  /// Example:
  /// ```dart
  /// final faviconMarkup = HtmlConstant.FAVICON.replaceAll('${HtmlConstant.ICON}', '🔥');
  /// ```
  ///
  /// The `viewBox` ensures proper scaling, and the `font-size` controls how large the emoji renders.
  /// {@endtemplate}
  static const String FAVICON = "data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>$ICON</text></svg>";

  /// {@template html_constant_icon}
  /// The default icon used in [FAVICON] — a leaf emoji 🍃.
  ///
  /// You can override this to inject other emojis or characters into the SVG-based favicon.
  ///
  /// Example:
  /// ```dart
  /// const customIcon = HtmlConstant.FAVICON.replaceAll('${HtmlConstant.ICON}', '💡');
  /// ```
  /// {@endtemplate}
  static const String ICON = "🍃";

  /// Unique marker used to identify generated proxy classes.
  ///
  /// All proxy class names are prefixed with this identifier to distinguish
  /// them from user-defined types and to ensure uniqueness across generated
  /// code. For example, a class named `UserService` will produce a proxy named
  /// `$$JLInterfaced$$UserService`.
  ///
  /// This identifier also serves as a reliable tag for tooling or reflection
  /// to detect JetLeaf-generated proxies at runtime or during analysis.
  static const String PROXY_IDENTIFIER = '\$\$JLInterfaced\$\$';

  /// The standardized static method name used across all generated proxy classes
  /// to retrieve the JetLeaf runtime metadata representation of the underlying class.
  ///
  /// Each generated proxy class defines a static method named `getRealClass()`
  /// that returns a [`Class<T>`] instance representing the proxied type within
  /// the JetLeaf reflection system.
  ///
  /// This constant ensures consistency across generators and allows JetLeaf
  /// utilities to locate the method programmatically (e.g., via reflection)
  /// without hardcoding the string name.
  ///
  /// Example:
  /// ```dart
  /// final realClassMethod = proxyType.getMethod(ReflectionConstants.STATIC_REAL_CLASS_METHOD_NAME);
  /// ```
  static const String STATIC_REAL_CLASS_METHOD_NAME = "getRealClass";

  /// Name of the default asset directory within a package.
  ///
  /// This directory typically contains static or runtime assets (such as
  /// configuration files, templates, or data) that are bundled as part of a
  /// Dart or Flutter package.
  static const String PACKAGE_ASSET_DIR = 'assets';

  /// Name of the default global resources directory.
  ///
  /// This directory holds resources that are not tied to a specific package.
  /// It is often used for shared application-wide resources like configuration,
  /// templates, or localization files.
  static const String RESOURCES_DIR_NAME = 'resources';

  /// Name of the generated resources directory where JetLeaf stores
  /// intermediate build artifacts or metadata.
  ///
  /// Example: `_jetleaf/`
  static const String JETLEAF_GENERATED_DIR_NAME = '_jetleaf';

  /// Name of the generated resources directory where JetLeaf stores
  /// intermediate build artifacts or metadata.
  ///
  /// Example: `_jetleaf/`
  static const String GENERATED_DIR_NAME = "$LIB$JETLEAF_GENERATED_DIR_NAME";

  /// Base library directory for Dart source files.
  ///
  /// Typically used as a prefix for generated paths or relative imports.
  static const String LIB = 'lib/';

  /// Canonical name used to represent the Dart SDK package.
  ///
  /// This is used internally by the generator to identify elements originating
  /// from the Dart SDK and to exclude or treat them differently from user or
  /// third-party packages.
  static const String DART_PACKAGE_NAME = "dart-sdk";
}

/// {@template package_names}
/// A central collection of constant package name identifiers used
/// throughout the **Jetleaf framework**.
///
/// These names are used for namespacing, module organization,
/// and avoiding hard-coded strings in the codebase. By centralizing
/// them here, it ensures consistency and reduces the likelihood
/// of typos.
///
/// ### Example
/// ```dart
/// void main() {
///   print(PackageNames.MAIN);   // "jetleaf"
///   print(PackageNames.POD);   // "jetleaf_core"
///   print(PackageNames.LANG);   // "jetleaf_lang"
/// }
/// ```
/// {@endtemplate}
class PackageNames {
  /// {@macro package_names}
  ///
  /// The root name of the framework: `"jetleaf"`.
  static const String MAIN = "jetleaf";

  /// The package name for the **core** module.
  ///
  /// Value: `"jetleaf_core"`.
  static const String CORE = "${MAIN}_core";

  /// The package name for the **build** module.
  ///
  /// Value: `"jetleaf_build"`.
  static const String BUILD = "${MAIN}_build";

  /// The package name for the **type conversion** module.
  ///
  /// Value: `"jetleaf_convert"`.
  static const String CONVERT = "${MAIN}_convert";

  /// The package name for the **AOP** module.
  /// 
  /// Value: `"jetleaf_aop"`.
  static const String AOP = "${MAIN}_aop";

  /// The package name for the **language support** module.
  ///
  /// Value: `"jetleaf_lang"`.
  static const String LANG = "${MAIN}_lang";

  /// The package name for the **meta-programming** module.
  ///
  /// Value: `"jetleaf_meta"`.
  static const String META = "${MAIN}_meta";

  /// The package name for the **utility** module.
  ///
  /// Value: `"jetleaf_utils"`.
  static const String UTILS = "${MAIN}_utils";

  /// The package name for the **Dart SDK**.
  ///
  /// Value: `"dart_sdk"`.
  static const String DART = "dart_sdk";

  /// The package name for the **logging support** module
  /// 
  /// Value: `"jetleaf_logging"`
  static const String LOGGING = "${MAIN}_logging";

  /// The package name for the **web server** module
  /// 
  /// Value: `"jetleaf_web"`
  static const String WEB = "${MAIN}_web";

  /// The package name for the **pod** module
  /// 
  /// Value: `"jetleaf_pod"`
  static const String POD = "${MAIN}_pod";

  /// The package name for the **scheduler** module
  /// 
  /// Value: `"jetleaf_scheduler"`
  static const String SCHEDULER = "${MAIN}_scheduler";

  /// The package name for the **security** module
  /// 
  /// Value: `"jetleaf_security"`
  static const String SECURITY = "${MAIN}_security";

  /// The package name for the **testing** module
  /// 
  /// Value: `"jetleaf_test"`
  static const String TEST = "${MAIN}_test";

  /// The package name for the **data** module
  /// 
  /// Value: `"jetleaf_data"`
  static const String DATA = "${MAIN}_data";

  /// The package name for the **retry** module
  /// 
  /// Value: `"jetleaf_retry"`
  static const String RETRY = "${MAIN}_retry";

  /// The package name for the **cache** module
  /// 
  /// Value: `"jetleaf_cache"`
  static const String CACHE = "${MAIN}_cache";

  /// The package name for the **validation** module
  /// 
  /// Value: `"jetleaf_validation"`
  static const String VALIDATION = "${MAIN}_validation";

  /// The package name for the **jetson** module
  /// 
  /// Value: `"jetson"`
  static const String JETSON = "jetson";

  /// The package name for the **environment** module
  /// 
  /// Value: `"jetleaf_env"`
  static const String ENV = "${MAIN}_env";

  /// The package name for the **resource** module
  /// 
  /// Value: `"jetleaf_resource"`
  static const String RESOURCE = "${MAIN}_resource";
}

@internal
extension IterableExtension<T> on Iterable<T> {
  /// Flattens lists of items into a single iterable.
  ///
  /// This function allows you to extract an iterable of elements
  /// from each item in the original iterable, then flattens the result.
  ///
  /// Example:
  /// ```dart
  /// List<User> addons = [...];
  /// List<Card> cards = addons.flatMap((e) => e.card).toList();
  /// ```
  Iterable<E> flatMap<E>(Iterable<E> Function(T item) selector) sync* {
    for (final item in this) {
      yield* selector(item);
    }
  }
}