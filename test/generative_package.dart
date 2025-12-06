import 'package:jetleaf_build/src/declaration/generative.dart';

class BuildGenerativePackage implements GenerativePackage {
  @override
  String? getFilePath() => "lib/src/generated/";

  @override
  bool getIsRootPackage() => true;

  @override
  String? getLanguageVersion() => "3.4";

  @override
  String getName() => "dummy_package";

  @override
  String? getRootUri() => "package:dummy_package/";

  @override
  String getVersion() => "1.0.0";

  @override
  Map<String, Object> toJson() {
    return {
      "name": getName(),
      "version": getVersion(),
      "isRoot": getIsRootPackage(),
      "languageVersion": getLanguageVersion() ?? "",
      "filePath": getFilePath() ?? "",
      "rootUri": getRootUri() ?? "",
    };
  }
}

class BuildGenerativePackageA implements GenerativePackage {
  @override
  String? getFilePath() => "packages/a/lib/";

  @override
  bool getIsRootPackage() => false;

  @override
  String? getLanguageVersion() => "3.2";

  @override
  String getName() => "package_a";

  @override
  String? getRootUri() => "package:package_a/";

  @override
  String getVersion() => "0.9.1";

  @override
  Map<String, Object> toJson() {
    return {
      "name": getName(),
      "version": getVersion(),
      "isRoot": getIsRootPackage(),
      "languageVersion": getLanguageVersion() ?? "",
      "filePath": getFilePath() ?? "",
      "rootUri": getRootUri() ?? "",
    };
  }
}

class BuildGenerativePackageB implements GenerativePackage {
  @override
  String? getFilePath() => "packages/b/lib/src/";

  @override
  bool getIsRootPackage() => false;

  @override
  String? getLanguageVersion() => "3.1";

  @override
  String getName() => "package_b";

  @override
  String? getRootUri() => "package:package_b/";

  @override
  String getVersion() => "2.3.0-dev";

  @override
  Map<String, Object> toJson() {
    return {
      "name": getName(),
      "version": getVersion(),
      "isRoot": getIsRootPackage(),
      "languageVersion": getLanguageVersion() ?? "",
      "filePath": getFilePath() ?? "",
      "rootUri": getRootUri() ?? "",
    };
  }
}

class BuildGenerativePackageC implements GenerativePackage {
  @override
  String? getFilePath() => "modules/c/generated/";

  @override
  bool getIsRootPackage() => false;

  @override
  String? getLanguageVersion() => "3.0";

  @override
  String getName() => "package_c";

  @override
  String? getRootUri() => "package:package_c/";

  @override
  String getVersion() => "0.1.0-alpha";

  @override
  Map<String, Object> toJson() {
    return {
      "name": getName(),
      "version": getVersion(),
      "isRoot": getIsRootPackage(),
      "languageVersion": getLanguageVersion() ?? "",
      "filePath": getFilePath() ?? "",
      "rootUri": getRootUri() ?? "",
    };
  }
}
