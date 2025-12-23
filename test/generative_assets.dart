// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
//
// This source file is part of the JetLeaf Framework and is protected
// under copyright law. You may not copy, modify, or distribute this file
// except in compliance with the JetLeaf license.
//
// For licensing terms, see the LICENSE file in the root of this project.
// ---------------------------------------------------------------------------
// 
// 🔧 Powered by Hapnium — the Dart backend engine 🍃

import 'dart:typed_data';
import 'package:jetleaf_build/jetleaf_build.dart';

class SimpleUserHtml extends GenerativeAsset {
  @override
  Uint8List getContentBytes() {
    const html = "<html><body><h1>User Page</h1><p>Dummy user data.</p></body></html>";
    return Uint8List.fromList(html.codeUnits);
  }

  @override
  String getFileName() => "user.html";

  @override
  String getFilePath() => "assets/generated/html/";

  @override
  String? getPackageName() => "simple_user_html";

  @override
  String getUniqueName() => "simple_user_html_asset";

  @override
  Map<String, Object> toJson() {
    return {
      "fileName": getFileName(),
      "filePath": getFilePath(),
      "packageName": getPackageName()!,
      "uniqueName": getUniqueName(),
    };
  }
}

class SimpleAdminHtml extends GenerativeAsset {
  @override
  Uint8List getContentBytes() {
    const html =
        "<html><body><h1>Admin Dashboard</h1><p>Dummy admin content.</p></body></html>";
    return Uint8List.fromList(html.codeUnits);
  }

  @override
  String getFileName() => "admin.html";

  @override
  String getFilePath() => "assets/generated/html/";

  @override
  String? getPackageName() => "simple_admin_html";

  @override
  String getUniqueName() => "simple_admin_html_asset";

  @override
  Map<String, Object> toJson() {
    return {
      "fileName": getFileName(),
      "filePath": getFilePath(),
      "packageName": getPackageName()!,
      "uniqueName": getUniqueName(),
    };
  }
}

class SimpleReportHtml extends GenerativeAsset {
  @override
  Uint8List getContentBytes() {
    const html =
        "<html><body><h1>Monthly Report</h1><p>Report placeholder text.</p></body></html>";
    return Uint8List.fromList(html.codeUnits);
  }

  @override
  String getFileName() => "report.html";

  @override
  String getFilePath() => "assets/generated/reports/";

  @override
  String? getPackageName() => "simple_report_html";

  @override
  String getUniqueName() => "simple_report_html_asset";

  @override
  Map<String, Object> toJson() {
    return {
      "fileName": getFileName(),
      "filePath": getFilePath(),
      "packageName": getPackageName()!,
      "uniqueName": getUniqueName(),
    };
  }
}

class SimpleEmailTemplateHtml extends GenerativeAsset {
  @override
  Uint8List getContentBytes() {
    const html = """
    <html>
      <body>
        <h2>Email Template</h2>
        <p>This is a dummy email template for testing.</p>
      </body>
    </html>
    """;
    return Uint8List.fromList(html.codeUnits);
  }

  @override
  String getFileName() => "email_template.html";

  @override
  String getFilePath() => "assets/generated/email/";

  @override
  String? getPackageName() => "simple_email_template_html";

  @override
  String getUniqueName() => "simple_email_template_html_asset";

  @override
  Map<String, Object> toJson() {
    return {
      "fileName": getFileName(),
      "filePath": getFilePath(),
      "packageName": getPackageName()!,
      "uniqueName": getUniqueName(),
    };
  }
}
