import 'dart:io';

import 'dart:mirrors';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/physical_file_system.dart';

import 'package:jetleaf_build/src/declaration/declaration.dart';
import 'package:jetleaf_build/src/utils/constant.dart';

import '../utils/generic_type_parser.dart';
import '../utils/must_avoid.dart';
import 'abstract_library_declaration_support.dart';
import 'declaration_file_writer.dart';
import 'tree_shaker.dart';

base class DefaultLibraryGenerator extends AbstractLibraryDeclarationSupport {
  /// Analysis context collection for static analysis
  AnalysisContextCollection? _analysisContextCollection;

  /// Tree shaker instance for dependency analysis
  TreeShaker? _treeShaker;
  
  /// Declaration file writer for organized output
  DeclarationFileWriter? _fileWriter;

  final bool refresh;
  
  DefaultLibraryGenerator({
    required super.mirrorSystem,
    required super.forceLoadedMirrors,
    required super.onInfo,
    required super.onWarning,
    required super.onError,
    required super.configuration,
    required super.packages,
    this.refresh = true
  });

  @override
  Future<List<LibraryDeclaration>> generate(List<File> dartFiles) async {
    // Initialize analyzer
    await _initializeAnalyzer(dartFiles);
    
    // Initialize tree shaker if needed
    if (configuration.enableTreeShaking) {
      _treeShaker = TreeShaker();
    }
    
    // Create package lookup
    for (final package in packages) {
      packageCache[package.getName()] = package;
    }

    final libraries = <LibraryDeclaration>[];
    final processedLibraries = <String>{};

    onInfo('Generating declaration metadata with analyzer integration...');
    final nonNecessaryPackages = getNonNecessaryPackages();
    
    for (final libraryMirror in this.libraries) {
      final fileUri = libraryMirror.uri;
      final filePath = libraryMirror.uri.toString();

      try {
        final mustSkip = "jetleaf_build/src/runtime/";
        if(filePath == "dart:mirrors" || filePath.startsWith("package:$mustSkip") || filePath.contains(mustSkip)) {
          continue;
        }

        if (!processedLibraries.add(filePath) || forgetPackage(filePath)) {
          continue;
        }

        final pkg = nonNecessaryPackages.where((pkg) => filePath.startsWith('package:$pkg/')).firstOrNull;
        if (pkg != null && !configuration.packagesToScan.contains(pkg)) {
          // Skip this file
          continue;
        }

        onInfo('Processing library: $filePath');
        LibraryDeclaration libDecl;
        
        if (isBuiltInDartLibrary(fileUri)) {
          // Handle built-in Dart libraries (dart:core, dart:io, etc.)
          libDecl = await generateBuiltInLibrary(libraryMirror);
        } else {
          // Handle user libraries and package libraries
          if (await shouldNotIncludeLibrary(fileUri, configuration) || isSkippableJetLeafPackage(fileUri)) {
            continue;
          }

          String? fileContent;
          try {
            fileContent = await readSourceCode(fileUri);
            if ((isTest(fileContent) && configuration.skipTests) || hasMirrorImport(fileContent) || forgetPackage(fileContent)) {
              continue;
            }
          } catch (e) {
            onError('Could not read file content for $fileUri: $e');
            continue;
          }
          
          libDecl = await generateLibrary(libraryMirror);
        }

        libraries.add(libDecl);
        libraryCache[fileUri.toString()] = libDecl;
      } catch (e, stackTrace) {
        onError('Error processing library ${fileUri.toString()}: $e\n$stackTrace');
      }
    }

    // Apply tree-shaking if enabled
    Set<String> usedClasses = {};
    if (configuration.enableTreeShaking && _treeShaker != null) {
      final userPackageNames = packages
          .where((p) => p.getIsRootPackage())
          .map((p) => p.getName())
          .toSet();
      
      usedClasses = _treeShaker!.shake(libraries, userPackageNames);
      onInfo('Tree-shaking enabled: ${usedClasses.length} classes marked as used');
    }

    // Write declarations to files if configured
    if (configuration.writeDeclarationsToFiles) {
      _fileWriter = DeclarationFileWriter(configuration.outputPath, refresh);
      await _fileWriter!.writeDeclarations(libraries, usedClasses, configuration.enableTreeShaking);
      onInfo('Declarations written to ${configuration.outputPath}/classes/');
    }

    // Check for unresolved generic classes
    final unresolvedClasses = libraries
      .where((l) => l.getIsPublic() && !l.getIsSynthetic() && l.getPackage().getIsRootPackage())
      .flatMap((l) => l.getDeclarations())
      .whereType<TypeDeclaration>()
      .where((d) => GenericTypeParser.shouldCheckGeneric(d.getType()) && d.getIsPublic() && !d.getIsSynthetic());

    if (unresolvedClasses.isNotEmpty) {
      final warningMessage = '''
⚠️ Generic Class Discovery Issue ⚠️
Found ${unresolvedClasses.length} classes with unresolved runtime types:
${unresolvedClasses.map((d) => "• ${d.getSimpleName()} (${d.getQualifiedName()})").join("\n")}

These classes may need manual type resolution or have complex generic constraints.
      ''';
      onWarning(warningMessage);
    }

    return libraries;
  }

  /// Initialize the analyzer context collection
  Future<void> _initializeAnalyzer(List<File> dartFiles) async {
    try {
      final resourceProvider = PhysicalResourceProvider.INSTANCE;
      if (dartFiles.isNotEmpty) {
        _analysisContextCollection = AnalysisContextCollection(
          includedPaths: dartFiles.map((f) => f.path).toList(),
          resourceProvider: resourceProvider,
        );
        onInfo('Analyzer initialized with ${dartFiles.length} dart files');
      } else {
        onWarning('No dart files found');
      }
    } catch (e) {
      onWarning('Failed to initialize analyzer: $e');
    }
  }

  @override
  Future<LibraryElement?> getLibraryElement(Uri uri) async {
    final uriString = uri.toString();
    if (libraryElementCache.containsKey(uriString)) {
      return libraryElementCache[uriString];
    }

    if (_analysisContextCollection == null) {
      return null;
    }

    try {
      final filePath = uri.toFilePath();
      final context = _analysisContextCollection!.contextFor(filePath);
      final result = await context.currentSession.getResolvedLibrary(filePath);
      
      if (result is ResolvedLibraryResult) {
        final libraryElement = result.element;
        libraryElementCache[uriString] = libraryElement;
        return libraryElement;
      }
    } catch (e) {
      // Analyzer not available or file not found
    }

    return null;
  }

  @override
  List<LibraryMirror> get libraries => refresh ? [...mirrorSystem.libraries.values, ...forceLoadedMirrors] : [...forceLoadedMirrors];
}