# Changelog

All notable changes to this project will be documented in this file.  
This project follows a simple, human-readable changelog format inspired by
[Keep a Changelog](https://keepachangelog.com/) and adheres to semantic versioning.

## [1.1.0]

This release is a major architectural improvement to the `Runtime` and scanning model.

Since `1.0.0`, using `Runtime` required `runScan` or `runTestScan` to eagerly build the *entire* application into `Declaration` objects. While functional, this approach introduced significant drawbacks:

- Long build times, even for small projects
- Excessive and often multiplied memory usage for larger applications

These limitations motivated a redesign in **1.1.0**, focusing on **on-demand resolution**, reduced memory pressure, and clearer runtime boundaries.

### Added
- `ClosureDeclaration` to support `ClosureMirror` types.
- `MaterialLibrary`, `SourceLibrary`, and `UnresolvedClass` to simplify how `Runtime` interacts with Dart mirrors.
- `ClassReference` to help in sub class searching
- `AnnotatedMethodReference` for annotated method search. _Internal_
- Periodic cache cleanup via `Runtime.enablePeriodicCleanup()`.
- `System`, `SystemDetector`, `SystemProperties`, `StdExtension`, `SystemExtension`

### Changed
- `FunctionLinkDeclaration` → `FunctionDeclaration`.
- `RecordLinkDeclaration` → `RecordDeclaration`.
- `PackageImplementation` → `MaterialPackage`.
- `AssetImplementation` → `MaterialAsset`.

- `RecordDeclaration`, `FunctionDeclaration`, `MixinDeclaration`,
  `EnumDeclaration`, and `ClosureDeclaration` are now full
  `ClassDeclaration` subtypes, distinguished using `TypeKind`.
  - This unifies previously fragmented APIs under a single, consistent model.
  - `RecordDeclaration` and `FunctionDeclaration` remain subtypes of `LinkDeclaration`.

- `AnnotationFieldDeclaration`, `EnumFieldDeclaration`, and `RecordFieldDeclaration`
  are now subtypes of `FieldDeclaration`, unifying field access and behavior
  across declaration types.

- `Runtime` now operates entirely **on-demand**:
  - It no longer holds all discovered classes, enums, or declarations in memory.
  - Aggressive cache eviction is applied after use.
  - Optional periodic cleanup can be enabled.

- Scans (`runScan`, `runTestScan`) now return **summary results only**.
  Runtime context is populated *after* scanning completes.

### Removed
- `TypeDiscovery`; key APIs were migrated into `MaterialLibrary`.
- Support for external `RuntimeProvider` designs.

### Notes
- This release significantly reduces memory usage and improves scalability.
- The new runtime model favors lazy resolution over eager graph construction.
- Consumers relying on internal runtime behavior should review the updated APIs carefully, as this release introduces intentional breaking changes.

---

## [1.0.9]

### Changed
- Reduced memory usage by switching from full analyzer resolution to **AST-only parsing** for reflection and declaration analysis.


---

## [1.0.8]

### Added
- `FunctionLinkDeclaration` class specialized for function parameters, fields, and other function designs _(functional)_.
- Comprehensive test coverage for all declaration classes.
- `Hint` abstraction for AOT runtime resolving.
- `ExecutableArgument` to simplify argument access and design.
- `RuntimeHintProvider` as a lazy provider for runtime hints.
- Analyzer-awareness across all declarations.
- Dedicated exception classes for clearer and more accurate error handling.
- Command-line argument support for `runScan` and `runTestScan`, including configurable `RuntimeScanner` and logging.
- `RuntimeBuilder` to expose logs generated during runtime scanning.
- `LocatedFiles` as the recommended tree-shaking mechanism as of `1.0.8`.

### Changed
- Renamed `RuntimeHint` class to `TypedRuntimeHint` and introduced a new `RuntimeHint` interface.
- Renamed `RuntimeResolver` to `RuntimeExecutor`.
- Redesigned `RecordDeclaration` as `RecordLinkDeclaration` with a new API and access model.
- `TypedefDeclaration` is now fully functional and no longer experimental.

### Fixed
- Parameter resolution issues for argument invocation in methods and constructors.

### Removed
- `ExtensionDeclaration`, as it is not fully supported at this time.

### Notes
- `TreeShaker` remains experimental; prefer `LocatedFiles` for production use.

---

## [1.0.7]

### Fixed
- Issues with parameter nullability detection.

### Changed
- Expanded the `RuntimeHint` design.

---

## [1.0.6]

### Added
- New RuntimeScanConfiguration API with `TryOutsideIsolate`.

### Fixed
- Issues with `runTestScan`.
- Discovery problems where `GenerativePackage` or `GenerativeAsset` were not detected by the runtime design.

### Changed
- Updated dependencies.

---

## [1.0.5]

### Fixed
- Analyzer-related issues.

### Changed
- Updated dependencies.

---

## [1.0.4]

### Added
- `release-on-merge.yml` CI/CD workflow.
- Increased search directories for project resources.

### Deprecated
- `getNonDartFiles()` method.

---

## [1.0.3]

### Fixed
- Declaration-related issues.

---

## [1.0.2]

### Fixed
- Production issues.

---

## [1.0.1]

### Added
- Additional checks in `FileUtility`.

### Fixed
- `JitRuntimeResolver` issues.

---

## [1.0.0]

Initial stable release.

### Added
- Runtime scanning infrastructure (`ApplicationRuntimeScanner`, `runScan`) for discovering annotated types, pods, and runtime metadata.
- Generators for application libraries and declaration files, including:
  - Application library generator
  - Declaration file writer
  - Library and mock library generators
  - Tree-shaker and resource generator helpers
- Runtime provider implementations and resolvers (configurable, standard, meta providers; AOT/JIT/fallback resolvers).
- Utility helpers for code generation and scanning:
  - Type resolution
  - File utilities
  - Generic type parsing
  - Reflection utilities
- Public API exports for annotations, constants, exceptions, helpers, runners, and runtime generators  
  (see `lib/jetleaf_build.dart`).
- Documentation site and initial examples (see `documentation` package in `pubspec.yaml`).
- Basic test coverage and linting setup using `test` and `lints`.

### Changed
- N/A (initial release)

### Fixed
- N/A (initial release)

### Removed
- N/A (initial release)

### Security
- No security advisories for this release.

### Notes
- This release stabilizes the build and generation APIs used by JetLeaf tooling.
  If you rely on internal or non-exported APIs, treat this version as the
  compatibility baseline for future releases.

---

## Links

- Documentation: https://jetleaf.hapnium.com/docs/build  
- Repository: https://github.com/jetleaf/jetleaf_build  
- Issues: https://github.com/jetleaf/jetleaf_build/issues  

---

**Contributors:** Hapnium & JetLeaf contributors