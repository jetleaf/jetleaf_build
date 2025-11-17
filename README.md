# jetleaf_build

Build module for the JetLeaf framework — generates application libraries, runtime declarations and runtime scanning utilities.

Package: `jetleaf_build`
Version: 1.0.0

Homepage: https://jetleaf.hapnium.com
Repository: https://github.com/jetleaf/jetleaf_build
Documentation: https://jetleaf.hapnium.com/docs/build

## What this package provides

- Runtime scanning utilities to discover annotated types, pods and runtime metadata.
- Generators that produce application libraries and declaration files from discovered runtime metadata.
- Helpers and runtime provider implementations used by the JetLeaf toolchain.

This package is a core piece of the JetLeaf code-generation and build tooling. It's primarily consumed by JetLeaf tooling and other JetLeaf packages, but can also be used directly by applications that need to run the JetLeaf scanner or programmatically generate declaration libraries.

## Quick install

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  jetleaf_build: ^1.0.0
```

Or reference the package via git when using the repository directly:

```yaml
dependencies:
  jetleaf_build:
    git:
      url: https://github.com/jetleaf/jetleaf_build.git
      ref: main
```

## Basic usage

Import the package's main library and call the scanner helper to obtain a `RuntimeProvider`:

```dart
import 'package:jetleaf_build/jetleaf_build.dart';

Future<void> main() async {
  // Perform a runtime scan (scans the current project packages by default)
  final runtimeProvider = await runScan();

  // Access discovered metadata via the returned RuntimeProvider
  print('Discovered runtime provider: $runtimeProvider');
}
```

The package also exports generators and runtime provider implementations which can be used to produce application libraries and declaration files. See the package documentation for advanced examples and generator configuration options.

## Development

Run analysis and tests from the package root:

```bash
dart analyze
dart test
```

Dev dependencies include `lints` and `test` as specified in `pubspec.yaml`.

## Contributing

See the main repository for contribution guidelines. When contributing:

- Keep changes focused and add tests for new behavior.
- Follow the existing lint rules (project uses `lints`).
- Update documentation and `CHANGELOG.md` when adding or changing public APIs.

## Links

- Documentation: https://jetleaf.hapnium.com/docs/build
- Repository: https://github.com/jetleaf/jetleaf_build
- Issue tracker: https://github.com/jetleaf/jetleaf_build/issues

## License

This project includes a `LICENSE` file in the repository root — please consult it for licensing details.