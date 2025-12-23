import 'equals_and_hash_code.dart';

/// {@template qualified_name}
/// Defines a contract for objects that expose a **fully-qualified, stable name**
/// within the JetLeaf type and metadata system.
///
/// A **qualified name** uniquely identifies an entity across:
/// - Packages
/// - Libraries
/// - Runtime and build-time reflection contexts
///
/// Unlike simple names (e.g. `User`), a qualified name encodes **ownership
/// and location**, ensuring there are no collisions even when multiple entities
/// share the same simple identifier.
///
/// ---
///
/// ### What a Qualified Name Represents
///
/// A qualified name typically combines:
/// - The **package URI**
/// - The **library path**
/// - The **declared symbol name**
///
/// Example format:
/// ```text
/// package:example/src/my_pod.dart.MyPod
/// ```
///
/// This format is intentionally:
/// - **Deterministic** — same input yields the same identifier
/// - **Stable** — safe for caching, hashing, and persistence
/// - **Globally unique** within a JetLeaf runtime
///
/// ---
///
/// ### Why This Matters
///
/// Qualified names are used as the **primary identity key** for:
/// - Class and declaration lookups
/// - Runtime ↔ source linking
/// - Cache keys and garbage collection
/// - Equality and hash code derivation
///
/// Many JetLeaf systems assume that:
/// ```dart
/// a.getQualifiedName() == b.getQualifiedName()
/// ```
/// implies the two objects represent the **same semantic entity**.
///
/// ---
///
/// ### Example
///
/// ```dart
/// class MyPod implements QualifiedName {
///   @override
///   String getQualifiedName() =>
///       'package:example/src/my_pod.dart.MyPod';
/// }
///
/// void main() {
///   final pod = MyPod();
///   print(pod.getQualifiedName());
///   // → package:example/src/my_pod.dart.MyPod
/// }
/// ```
///
/// ---
///
/// ### Equality Contract
///
/// Implementations mix in [EqualsAndHashCode], meaning:
/// - Equality **must** be derived from the qualified name
/// - Hash codes **must** remain stable across executions
///
/// This allows qualified-name-based objects to be safely used in:
/// - Sets
/// - Maps
/// - Caches
///
/// ---
///
/// ### Implementation Notes
///
/// Implementors should ensure:
/// - The returned value is **never empty**
/// - The value does **not change over time**
/// - The value is safe to use as a cache or lookup key
///
/// {@endtemplate}
abstract interface class QualifiedName with EqualsAndHashCode {
  /// {@macro qualified_name}
  const QualifiedName();

  /// Returns the **fully-qualified identifier** for this object.
  ///
  /// This value must uniquely and stably identify the object within the
  /// current JetLeaf runtime and across build-time metadata.
  ///
  /// Implementations should return a string that includes enough contextual
  /// information (package, library, symbol name) to avoid collisions.
  String getQualifiedName();
}