/// {@template must_avoid_package}
/// Constant representing the package name that must be avoided during import
/// checks. Used by [forgetPackage] to detect and filter forbidden references.
/// {@endtemplate}
const String MUST_AVOID_PACKAGE = "dart:js_interop";

/// {@template forget_package}
/// Returns `true` if the provided [text] contains a reference to a package
/// that should be excluded.
///
/// This checks for:
/// - `"package:js"`
/// - the forbidden [MUST_AVOID_PACKAGE] value
/// - direct imports of the forbidden package
///
/// Used to prevent accidental inclusion of unsupported JS interop packages.
/// {@endtemplate}
bool forgetPackage(String text) {
  return text.contains("package:js")
    || text.contains(MUST_AVOID_PACKAGE)
    || text.contains("import '$MUST_AVOID_PACKAGE'");
}

/// {@template non_necessary_packages}
/// Returns a list of package names that are considered **non-essential** for
/// runtime analysis and should generally be excluded from scanning.
///
/// These packages are typically:
/// - build-system tooling (`build_runner`, `build_daemon`, `source_gen`)
/// - code-generation libraries (`code_builder`, `dart_style`)
/// - analysis and compiler internals (`analyzer`, `_fe_analyzer_shared`)
/// - testing and debugging utilities (`matcher`, `test_api`, `vm_service`)
/// - SDK support or meta packages (`package_config`, `pub_semver`)
///
/// JetLeaf uses this list to:
/// - reduce noise during dependency inspection
/// - avoid scanning files irrelevant to runtime execution
/// - improve performance when resolving user code
///
/// This list may evolve as Dart ecosystem tooling changes.
/// {@endtemplate}
List<String> getNonNecessaryPackages() => [
  "code_builder",
  "build_runner",
  "build_daemon",
  "built_value",
  "built_collection",
  "build_config",
  "fixnum",
  "dart_internal",
  "matcher",
  "string_scanner",
  "pub_semver",
  "analyzer",
  "pubspec_parse",
  "checked_yaml",
  "source_gen",
  "dart_style",
  "build",
  "source_span",
  "watcher",
  "test_api",
  "_fe_analyzer_shared",
  "package_config",
  "path",
  "term_glyph",
  "frontend_server_client",
  "vm_service"
];