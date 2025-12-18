import 'dart:collection';
import 'dart:io';

/// {@template located_files}
/// A **file–classification and scheduling model** used by JetLeaf to
/// efficiently control *what gets processed* during a build.
///
/// As of **JetLeaf v1.1.0**, [LocatedFiles] is the **primary and stable
/// tree-shaking mechanism** used by the framework. While the `TreeShaker`
/// subsystem remains experimental, this class provides a deterministic,
/// production-ready way to limit analysis and scanning to only the files
/// that actually matter.
///
/// ## Role in Tree-Shaking
/// Instead of eagerly analyzing every Dart file in a project, JetLeaf
/// separates files into two independent processing paths:
///
/// | Path | Purpose | Cost |
/// |-----|--------|------|
/// | **Scanning** | Annotation discovery, symbol indexing | Low |
/// | **Analysis** | Type resolution, semantic analysis | High |
///
/// By controlling these sets independently, JetLeaf:
/// - Avoids unnecessary analyzer passes
/// - Reduces memory usage
/// - Improves build and startup performance
/// - Enables fine-grained dependency pruning
///
/// ## Why Two Sets?
/// A file may need:
/// - **Scanning only** (e.g. contains annotations or declarations)
/// - **Analysis only** (e.g. referenced types with no annotations)
/// - **Both scanning and analysis**
///
/// [LocatedFiles] makes this distinction explicit and enforceable.
///
/// ## Stability Guarantee
/// - This API is **stable and supported**
/// - Safe for use in custom build steps and tooling
/// - Backward-compatible across JetLeaf 1.x
///
/// ## Typical Usage
/// ```dart
/// final located = LocatedFiles({}, {});
///
/// located.add(File('lib/controllers/user_controller.dart'));
/// located.addToAnalyzer(File('lib/models/user.dart'));
///
/// for (final file in located.getScannableDartFiles()) {
///   scanAnnotations(file);
/// }
///
/// for (final file in located.getAnalyzeableDartFiles()) {
///   analyzeTypes(file);
/// }
/// ```
///
/// ## Design Notes
/// - This class is **intentionally simple**
/// - No implicit inference or magic behavior
/// - Higher-level planners and resolvers decide *which* files belong where
///
/// ## See Also
/// - `TreeShaker` (experimental)
/// - `LibraryDeclaration`
/// - `BuildPlanner`
/// {@endtemplate}
final class LocatedFiles {
  /// Files scheduled for **full semantic analysis**.
  ///
  /// These files are typically passed through the Dart analyzer and deeper
  /// resolution pipelines, including:
  /// - Type checking
  /// - Class and method resolution
  /// - Inheritance and interface linking
  ///
  /// A file in this set is *not required* to be scanned for annotations.
  Set<String> _filesToAnalyze = {};

  /// Files scheduled for **lightweight structural scanning**.
  ///
  /// Scanning generally includes:
  /// - Annotation discovery
  /// - Declaration indexing
  /// - Symbol extraction
  ///
  /// Files in this set may or may not be fully analyzed.
  Set<String> _filesToScan = {};

  /// Creates a new [LocatedFiles] container with pre-initialized file sets.
  ///
  /// Both sets must be:
  /// - Mutable
  /// - Exclusively owned by this instance
  ///
  /// Callers **must not** reuse or mutate the provided sets after passing
  /// them into this constructor.
  ///
  /// {@macro located_files}
  LocatedFiles();

  /// Creates an **empty, immutable** [LocatedFiles] instance.
  ///
  /// This constructor initializes both the *analysis* and *scanning* sets
  /// as empty, constant collections.
  ///
  /// ## Intended Use
  /// [LocatedFiles.empty] is primarily designed for:
  /// - Default or placeholder initialization
  /// - Safe return values when no files are discovered
  /// - Read-only contexts where file scheduling must be explicitly disabled
  ///
  /// Because the internal sets are `const`, this instance is **fully immutable**.
  /// Any attempt to add files using [add] or [addToAnalyzer] will result in a
  /// runtime error.
  ///
  /// ## Behavior
  /// - `getScannableDartFiles()` returns an empty set
  /// - `getAnalyzeableDartFiles()` returns an empty set
  /// - No files can be added after construction
  ///
  /// ## Design Rationale
  /// This constructor provides a lightweight, allocation-free representation
  /// of “no work to perform”, which is useful in:
  /// - Early-exit build paths
  /// - Feature-gated pipelines
  /// - Testing and diagnostics
  ///
  /// ## Example
  /// ```dart
  /// final located = LocatedFiles.empty();
  ///
  /// assert(located.getScannableDartFiles().isEmpty);
  /// assert(located.getAnalyzeableDartFiles().isEmpty);
  /// ```
  LocatedFiles.empty() : _filesToAnalyze = UnmodifiableSetView({}), _filesToScan = UnmodifiableSetView({});

  /// Adds a file to **both** the analysis and scanning pipelines.
  ///
  /// This is the most common operation and indicates that the file:
  /// - Declares relevant symbols or annotations
  /// - Requires full semantic understanding
  ///
  /// Duplicate additions are ignored.
  void add(File file) {
    _filesToAnalyze.add(file.path);
    _filesToScan.add(file.path);
  }

  /// Adds a file **only** to the analysis pipeline.
  ///
  /// This is used when a file:
  /// - Is referenced by other code
  /// - Contains types needed for resolution
  /// - Does *not* declare annotations or metadata of interest
  ///
  /// The file will not be included in scanning operations.
  void addToAnalyzer(File file) {
    _filesToAnalyze.add(file.path);
  }

  /// Returns an **immutable view** of all files scheduled for scanning.
  ///
  /// This set is typically consumed by:
  /// - Annotation scanners
  /// - Symbol registries
  /// - Metadata extractors
  ///
  /// Mutating the returned set will throw at runtime.
  Set<File> getScannableDartFiles() => UnmodifiableSetView(_filesToScan.map((f) => File(f)).toSet());

  /// Returns an **immutable view** of all files scheduled for analysis.
  ///
  /// This set is typically consumed by:
  /// - Analyzer integrations
  /// - Type resolution pipelines
  /// - Dependency graph builders
  ///
  /// Mutating the returned set will throw at runtime.
  Set<File> getAnalyzeableDartFiles() => UnmodifiableSetView(_filesToAnalyze.map((f) => File(f)).toSet());
}