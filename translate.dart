import 'dart:io';
import 'dart:convert';

void main() {
  final arbFile = File('lib/l10n/app_en.arb');
  final arbData = jsonDecode(arbFile.readAsStringSync()) as Map<String, dynamic>;

  // Build a mapping from String value to key
  final stringToKey = <String, String>{};
  for (final entry in arbData.entries) {
    if (!entry.key.startsWith('@') && !entry.value.contains('{')) {
      stringToKey[entry.value.replaceAll('\n', '\\n')] = entry.key;
    }
  }

  // Sort strings by length descending
  final sortedKeys = stringToKey.keys.toList()..sort((a, b) => b.length.compareTo(a.length));

  final dartFiles = [
    'lib/fitness_home_pages.dart',
    'lib/widgets/home_header.dart',
    'lib/screens/nutrition_screen.dart',
    'lib/screens/workout_screen.dart',
    'lib/screens/active_workout_screen.dart',
    'lib/profile.dart',
    'lib/login_sign_up.dart',
    'lib/screens/onboarding_flow.dart',
    'lib/widgets/core_gym_navbar.dart',
  ];

  for (final path in dartFiles) {
    final file = File(path);
    if (!file.existsSync()) {
      print('Skipping $path, does not exist');
      continue;
    }

    var content = file.readAsStringSync();

    if (!content.contains("flutter_gen/gen_l10n/app_localizations.dart")) {
      content = content.replaceFirst(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\nimport 'package:flutter_gen/gen_l10n/app_localizations.dart';"
      );
    }

    for (final val in sortedKeys) {
      final key = stringToKey[val]!;
      // Escape for regex
      final patternS = "(?<!\\w)'${RegExp.escape(val)}'";
      final patternD = '(?<!\\w)"${RegExp.escape(val)}"';
      final replacer = 'AppLocalizations.of(context)!.$key';

      content = content.replaceAllMapped(RegExp(patternS), (match) => replacer);
      content = content.replaceAllMapped(RegExp(patternD), (match) => replacer);
    }

    content = content.replaceAll(RegExp(r'const\s+Text\(\s*AppLocalizations'), 'Text(AppLocalizations');

    // RTL
    content = content.replaceAll('EdgeInsets.only(left:', 'EdgeInsetsDirectional.only(start:');
    content = content.replaceAll(', left:', ', start:');
    content = content.replaceAll('EdgeInsets.only(right:', 'EdgeInsetsDirectional.only(end:');
    content = content.replaceAll(', right:', ', end:');

    // Icons
    final arrowFwd = "Directionality.of(context) == TextDirection.rtl ? Icons.arrow_back_ios_rounded : Icons.arrow_forward_ios_rounded";
    final arrowBack = "Directionality.of(context) == TextDirection.rtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_rounded";
    content = content.replaceAll('Icons.arrow_forward_ios', arrowFwd);
    content = content.replaceAll('Icons.arrow_forward_ios_rounded', arrowFwd);
    content = content.replaceAll('Icons.arrow_back_ios', arrowBack);
    content = content.replaceAll('Icons.arrow_back_ios_rounded', arrowBack);

    file.writeAsStringSync(content);
  }

  print('Done dart script');
}
