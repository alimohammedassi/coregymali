import 'dart:io';

void main() {
  final dir = Directory('lib');
  final entities = dir.listSync(recursive: true);
  for (final e in entities) {
    if (e is File && e.path.endsWith('.dart')) {
      var content = e.readAsStringSync();
      if (content.contains("package:flutter_gen/gen_l10n/app_localizations.dart")) {
        content = content.replaceAll(
          "package:flutter_gen/gen_l10n/app_localizations.dart",
          "package:coregym2/l10n/app_localizations.dart"
        );
        e.writeAsStringSync(content);
        print('Fixed ${e.path}');
      }
    }
  }
}
