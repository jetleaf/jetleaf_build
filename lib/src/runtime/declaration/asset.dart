part of 'declaration.dart';

/// The default character encoding used for JSON serialization and deserialization.
///
/// Jetson uses UTF-8 as the standard encoding for all JSON input and output
/// operations to ensure full compatibility with the JSON specification
/// (RFC 8259) and cross-platform interoperability.
///
/// ### Details
/// - All string data written by Jetson components is encoded using UTF-8.
/// - Input streams are decoded using UTF-8 unless another encoding is
///   explicitly configured.
/// - This constant provides a single reference point for encoding decisions
///   throughout the Jetson pipeline.
///
/// ### Example
/// ```dart
/// final encoded = DEFAULT_ENCODING.encode('{"name":"JetLeaf"}');
/// final decoded = DEFAULT_ENCODING.decode(encoded);
/// print(decoded); // {"name":"JetLeaf"}
/// ```
@internal
const Utf8Codec DEFAULT_ENCODING = utf8;

/// {@template asset}
/// Represents a non-Dart static resource (e.g., HTML, CSS, images).
///
/// The compiler generates implementations of this class to expose metadata
/// and raw content for embedded or served assets during runtime.
///
/// Represents a static asset (e.g., HTML, CSS, JS, images, or any binary file)
/// that is bundled with the project but not written in Dart code.
///
/// This is typically used in frameworks like JetLeaf for handling:
/// - Static web resources (HTML templates, stylesheets)
/// - Server-rendered views
/// - Embedded images or configuration files
///
/// These assets are typically provided via compiler-generated implementations
/// and may be embedded in memory or referenced via file paths.
///
/// ### Example
/// ```dart
/// final asset = MyGeneratedAsset(); // implements Asset
/// print(asset.getFilePath()); // "resources/index.html"
/// print(Closeable.DEFAULT_ENCODING.decode(asset.getContentBytes())); // "<html>...</html>"
/// ```
/// {@endtemplate}
abstract class Asset extends BaseDeclaration {
  /// The relative file path of the asset (e.g., `'resources/index.html'`).
  final String _filePath;

  /// The name of the asset file (e.g., `'index.html'`).
  final String _fileName;

  /// The name of the package this asset belongs to (e.g., `'jetleaf'`).
  final String _packageName;

  /// The raw binary contents of this asset.
  final Uint8List _contentBytes;

  /// {@macro asset}
  const Asset({
    required String filePath,
    required String fileName,
    required String packageName,
    required Uint8List contentBytes,
  }) : _filePath = filePath, _fileName = fileName, _packageName = packageName, _contentBytes = contentBytes;

  /// Returns a **unique name for the asset**, combining the package name and
  /// the base file name (without extension).
  ///
  /// Example:
  /// ```dart
  /// final uniqueName = asset.getUniqueName(); // 'jetleaf_config'
  /// ```
  String getUniqueName() => "${_packageName}_${_fileName.split(".").first}";

  /// Returns the **name of the file** represented by this asset.
  ///
  /// Example:
  /// ```dart
  /// final fileName = asset.getFileName(); // 'config.json'
  /// ```
  String getFileName() => _fileName;

  /// Returns the **full path to the file** on disk or in the package.
  ///
  /// Example:
  /// ```dart
  /// final path = asset.getFilePath(); // '/packages/jetleaf/config.json'
  /// ```
  String getFilePath() => _filePath;

  /// Returns the **name of the package** from which this asset originates.
  ///
  /// Example:
  /// ```dart
  /// final packageName = asset.getPackageName(); // 'jetleaf'
  /// ```
  String? getPackageName() => _packageName;

  /// Returns the **binary content** of the asset as a [Uint8List].
  ///
  /// Example:
  /// ```dart
  /// final bytes = asset.getContentBytes(); // <Uint8List of file contents>
  /// ```
  Uint8List getContentBytes() => _contentBytes;

  /// {@macro asset_extension}
  /// 
  /// ## Example
  /// ```dart
  /// final asset = Asset.fromFile('index.html');
  /// final content = asset.getContentAsString();
  /// print(content);
  /// ```
  String getContentAsString() {
    try {
      final file = File(getFilePath());
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        return content;
      }

      return DEFAULT_ENCODING.decode(getContentBytes());
    } catch (e) {
      try {
        return DEFAULT_ENCODING.decode(getContentBytes());
      } catch (e) {
        try {
          return String.fromCharCodes(getContentBytes());
        } catch (e) {
          throw BuildException('Failed to parse asset ${getFileName()}: $e');
        }
      }
    }
  }

  @override
  List<Object?> equalizedProperties() => [_filePath, _fileName, _packageName, _contentBytes];

  @override
  Map<String, Object> toJson() {
    return {
      'filePath': getFilePath(),
      'fileName': getFileName(),
      'packageName': getPackageName() ?? "Unknown",
      'contentBytes': getContentBytes()
    };
  }
}

/// {@template asset_implementation}
/// A concrete, immutable implementation of the [Asset] interface.
///
/// This class represents a single asset in the system, containing the
/// file path, file name, package name, and binary content.
///
/// Typically used in scenarios where reflective or dynamic loading
/// of files and packages is required.
///
/// ### Example
/// ```dart
/// final asset = MaterialAsset(
///   filePath: 'lib/resources/logo.png',
///   fileName: 'logo.png',
///   packageName: 'my_package',
///   contentBytes: await File('lib/resources/logo.png').readAsBytes(),
/// );
/// print(asset.fileName); // logo.png
/// ```
/// {@endtemplate}
@internal
final class MaterialAsset extends Asset with EqualsAndHashCode {
  /// {@macro asset_implementation}
  const MaterialAsset({
    required super.filePath,
    required super.fileName,
    required super.packageName,
    required super.contentBytes,
  });

  @override
  Map<String, Object> toJson() {
    Map<String, Object> result = {};
    result['filePath'] = _filePath;
    result['fileName'] = _fileName;
    result['packageName'] = _packageName;
    result['contentBytes'] = _contentBytes.toString();
    return result;
  }
}

/// {@template jetleaf_generative_asset}
/// Base class representing a **resource asset with a no-args constructor**.
///
/// Designed primarily for **code generation scenarios**, where subclasses
/// are instantiated reflectively (e.g., via mirrors or generated code).
///
/// Subclasses are expected to override the core getters to provide asset
/// metadata and content:
/// - [_filePath] — the asset's relative or absolute path  
/// - [_fileName] — the asset's file name  
/// - [_packageName] — the package the asset belongs to  
/// - [_contentBytes] — the raw byte content of the asset  
///
/// Generated subclasses typically provide these as `final` fields for
/// immutable, compile-time-safe assets.
///
/// ### Usage Example
/// ```dart
/// class GeneratedAssetExample extends GenerativeAsset {
///   @override
///   String getFilePath() => "assets/config.json";
///
///   @override
///   String getFileName() => "config.json";
///
///   @override
///   String? getPackageName() => "my_package";
///
///   @override
///   Uint8List getContentBytes() => Uint8List.fromList([1, 2, 3]);
/// }
///
/// final asset = GeneratedAssetExample();
/// print(asset.getFilePath()); // "assets/config.json"
/// ```
///
/// ### Design Notes
/// - Must have a **no-args constructor** to support reflective instantiation.  
/// - Serves as a base for code-generated asset classes, ensuring a uniform
///   API across all assets.  
/// - Provides default dummy values in the constructor to satisfy the base
///   [Asset] class; actual values must be supplied by overriding getters.
///
/// ### See Also
/// - [Asset]
/// - [Uint8List]
/// {@endtemplate}
abstract class GenerativeAsset extends Asset {
  /// Default no-args constructor.
  ///
  /// Subclasses should override the getters to provide actual asset data.
  /// 
  /// {@macro jetleaf_generative_asset}
  GenerativeAsset() : super(
    filePath: '',
    fileName: '',
    packageName: '',
    contentBytes: Uint8List(0),
  );

  @override
  String getFilePath();

  @override
  String getFileName();

  @override
  String? getPackageName();

  @override
  Uint8List getContentBytes();
}