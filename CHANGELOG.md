# Changelog

All notable changes to this project will be documented in this file. This project adheres to a simple, human-readable changelog format.

## [1.0.5]

- Updated dependencies
- Fixed `analyzer` issue

## [1.0.4]

- Deprecated the use of `getNonDartFiles()` method
- Increased the number of search directories for project resources
- Added release-on-merge.yml ci/cd

## [1.0.3]

- Fixed declaration issue

## [1.0.2]

- Fixed issues on production

## [1.0.1]

- Fixed JitRuntimeResolver
- Added new checks in FileUtility

## [1.0.0]

Initial stable release.

### Added

- Runtime scanning infrastructure (ApplicationRuntimeScanner and `runScan`) to discover annotated types, pods and runtime metadata.
- Generators for producing application libraries and declaration files, including:
	- Application library generator
	- Declaration file writer
	- Library generator and mock library generator
	- Tree shaker and resource generator helpers
- Runtime provider implementations and resolvers (configurable, standard, meta providers; AOT/JIT/fallback resolvers).
- Utility helpers for code generation and scanning (type resolution, file utilities, generic type parsing, reflection utilities).
- Public API surface exports for annotations, constants, exceptions, helpers, runners and runtime generators (see `lib/jetleaf_build.dart`).
- Documentation site and initial examples (see package `documentation` in `pubspec.yaml`).
- Basic test coverage and linting setup (using `test` and `lints`).

### Changed

- N/A (initial release)

### Fixed

- N/A (initial release)

### Removed

- N/A (initial release)

### Security

- No security advisories for this release.

### Notes

- This release stabilizes the build/generation APIs used by JetLeaf tooling. If you rely on internal or non-exported internals, treat this release as the baseline for future compatibility notices.

### Links

- Documentation: https://jetleaf.hapnium.com/docs/build
- Repository: https://github.com/jetleaf/jetleaf_build
- Issues: https://github.com/jetleaf/jetleaf_build/issues

Contributors: Hapnium & JetLeaf contributors
