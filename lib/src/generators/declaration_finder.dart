// import 'dart:io';
// import 'dart:mirrors' as mirrors;

// import 'package:analyzer/dart/analysis/analysis_context_collection.dart' show AnalysisContextCollection;
// import 'package:analyzer/dart/element/element.dart' show LibraryElement;
// import 'package:analyzer/file_system/physical_file_system.dart' show PhysicalResourceProvider;

// import '../declaration/declaration.dart';
// import '../runtime_scanner/runtime_scanner_configuration.dart' show RuntimeScannerConfiguration;
// import '../utils/file_utility.dart';
// import '../utils/must_avoid.dart';
// import '../utils/utils.dart';

// final class DeclarationFinder {
//   /// Analysis context collection for static analysis
//   static AnalysisContextCollection? _analysisContextCollection;
  
//   /// Cache of library declarations
//   static final Map<String, LibraryDeclaration> _libraryCache = {};
  
//   /// Cache of type declarations
//   static final Map<Type, TypeDeclaration> _typeCache = {};
  
//   /// Cache of package declarations
//   static final Map<String, Package> _packageCache = {};
  
//   /// Cache of source code
//   static final Map<String, String> _sourceCache = {};
  
//   /// Cache of analyzer elements by URI
//   static final Map<String, LibraryElement> _libraryElementCache = {};

//   /// Type variable cache
//   static final Map<String, TypeVariableDeclaration> _typeVariableCache = {};

//   /// Cache for DartType to Type mapping
//   static final Map<String, Type> _dartTypeToTypeCache = {};

//   /// Cache for preventing infinite recursion in LinkDeclaration generation
//   static final Set<String> _linkGenerationInProgress = {};

//   /// Cached link declarations
//   static final Map<String, LinkDeclaration?> _linkDeclarationCache = {};

//   /// Already processed libraries
//   static final processedLibraries = <String>{};

//   /// Loaded mirrors
//   static List<mirrors.LibraryMirror> _mirrorLibraries = [];

//   /// The runtime config to use
//   static RuntimeScannerConfiguration _configuration = RuntimeScannerConfiguration();

//   /// The mirror system used for reflection
//   static late mirrors.MirrorSystem _mirrorSystem;

//   /// Callback for informational messages
//   static OnLogged _onInfo = print;

//   /// Callback for error messages
//   static OnLogged _onError = print;

//   /// Callback for warning messages
//   static OnLogged _onWarning = print;

//   /// List of packages to process
//   static List<Package> _packages = [];

//   static late FileUtility _FileUtils;

//   static 

//   /// Whether the finder is initialized
//   static bool _isInitialized = false;

//   DeclarationFinder._();

//   static Future<void> load({
//     required mirrors.MirrorSystem system,
//     required List<mirrors.LibraryMirror> libraries,
//     required List<File> dartFiles, 
//     RuntimeScannerConfiguration? config,
//     List<Package>? packages,
//     Directory? directory,
//     OnLogged? onInfo,
//     OnLogged? onWarning,
//     OnLogged? onError
//   }) async {
//     if (_isInitialized) {
//       return;
//     }
    
//     if (config != null) {
//       _configuration = config;
//     }

//     _mirrorLibraries = [...system.libraries.values, ...libraries];
//     _mirrorSystem = system;

//     if (onInfo != null) {
//       _onInfo = onInfo;
//     }

//     if (onWarning != null) {
//       _onWarning = onWarning;
//     }

//     if (onError != null) {
//       _onError = onError;
//     }

//     _FileUtils = FileUtility(_onInfo, _onWarning, _onError, _configuration, !_configuration.skipTests);

//     if (packages == null) {
//       _packages = await _FileUtils.readPackageGraphDependencies(directory ?? Directory.current, system);
//     } else {
//       _packages = packages;
//     }

//     // Initialize analyzer
//     await _initializeAnalyzer(dartFiles);

//     _isInitialized = true;
//   }

//   /// Initialize the analyzer context collection
//   static Future<void> _initializeAnalyzer(List<File> dartFiles) async {
//     try {
//       final resourceProvider = PhysicalResourceProvider.INSTANCE;
//       if (dartFiles.isNotEmpty) {
//         _analysisContextCollection = AnalysisContextCollection(
//           includedPaths: dartFiles.map((f) => f.path).toList(),
//           resourceProvider: resourceProvider,
//         );
//         _onInfo('Analyzer initialized with ${dartFiles.length} dart files');
//       } else {
//         _onWarning('No dart files found');
//       }
//     } catch (e) {
//       _onWarning('Failed to initialize analyzer: $e');
//     }
//   }

//   static /// Read source code with caching
//   Future<String> _readSourceCode(Uri uri) async {
//     try {
//       if (_sourceCache.containsKey(uri.toString())) {
//         return _sourceCache[uri.toString()]!;
//       }

//       final filePath = (await RuntimeUtils.resolveUri(uri) ?? uri).toFilePath();
//       String fileContent = await File(filePath).readAsString();
//       _sourceCache[uri.toString()] = fileContent;
//       return RuntimeUtils.stripComments(fileContent);
//     } catch (_) {
//       return "";
//     }
//   }

//   static Future<LibraryDeclaration?> findLibrary(mirrors.LibraryMirror libraryMirror) async {
//     final nonNecessaryPackages = getNonNecessaryPackages();
//     final libraryUri = libraryMirror.uri;
//     final filePath = libraryUri.toString();

//     try {
//       final mustSkip = "jetleaf_build/src/runtime/";
//       if(filePath == "dart:mirrors" || filePath.startsWith("package:$mustSkip") || filePath.contains(mustSkip)) {
//         return null;
//       }

//       if (!processedLibraries.add(filePath) || forgetPackage(filePath)) {
//         return null;
//       }

//       if (nonNecessaryPackages.any((pkg) => filePath.startsWith('package:$pkg/') && !_configuration.packagesToScan.contains(pkg))) {
//         // Skip this file
//         return null;
//       }

//       _onInfo('Processing library: $filePath');
//       LibraryDeclaration libDecl;
      
//       if (libraryUri.scheme == "dart") {
//         // Handle built-in Dart libraries (dart:core, dart:io, etc.)
//         libDecl = await generateBuiltInLibrary(libraryMirror);
//       } else {
//         // Handle user libraries and package libraries
//         if (await RuntimeUtils.shouldNotIncludeLibrary(libraryUri, _configuration) || RuntimeUtils.isSkippableJetLeafPackage(libraryUri)) {
//           return null;
//         }

//         String? fileContent;
//         try {
//           fileContent = await _readSourceCode(libraryUri);
//           if ((RuntimeUtils.isTest(fileContent) && _configuration.skipTests) || RuntimeUtils.hasMirrorImport(fileContent) || forgetPackage(fileContent)) {
//             return null;
//           }
//         } catch (e) {
//           _onError('Could not read file content for $libraryUri: $e');
//           return null;
//         }
        
//         libDecl = await generateLibrary(libraryMirror);
//       }

//       _libraryCache[libraryUri.toString()] = libDecl;
//       return libDecl;
//     } catch (e, stackTrace) {
//       _onError('Error processing library ${libraryUri.toString()}: $e\n$stackTrace');
//     }

//     return null;
//   }
// }