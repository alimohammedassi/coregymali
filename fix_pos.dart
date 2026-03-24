import 'dart:io';

void main() {
  final files = [
    'lib/widgets/home_header.dart',
    'lib/profile.dart',
    'lib/login_sign_up.dart',
  ];

  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) continue;
    var c = file.readAsStringSync();

    // The incorrect replacements were `, start:` and `start: ` and `, end:` and `end: `. 
    // They are inside `Positioned(...)` calls.
    // Instead of parsing, we can just replace textDirection for Positioned.directional
    c = c.replaceAll(RegExp(r'const\s+Positioned\('), 'Positioned(');
    
    // We can add directional parameters to Positioned if they have start/end.
    // Or we can just use `Positioned.directional(textDirection: Directionality.of(context),`
    c = c.replaceAllMapped(RegExp(r'Positioned\(([^)]*?)(start:|end:)([^)]*?)\)'), (match) {
      return 'Positioned.directional(textDirection: Directionality.of(context), ${match[1]}${match[2]}${match[3]})';
    });

    file.writeAsStringSync(c);
  }
}
