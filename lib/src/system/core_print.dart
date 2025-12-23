import 'dart:core' as dev;

/// Overrides the global [print] function to allow intercepting or
/// redirecting output while still delegating to [dev.print].
///
/// This can be useful if you want to:
/// - Add logging hooks
/// - Preprocess messages
/// - Redirect all output to another sink
///
/// Example:
/// ```dart
/// print("Hello, world!");
/// ```
void print(dev.Object? message) {
  dev.print(message);
}