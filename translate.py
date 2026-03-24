import json
import os
import re

arb_file = r'c:\Users\mabou\coregymali\lib\l10n\app_en.arb'
with open(arb_file, 'r', encoding='utf-8') as f:
    arb_data = json.load(f)

# Sort strings by length descending to avoid substring overlapping replacements
string_to_key = [(v.replace('\n', '\\n'), k) for k, v in arb_data.items() if not k.startswith('@') and not '{' in v]
string_to_key.sort(key=lambda x: len(x[0]), reverse=True)

dart_files = [
    r'c:\Users\mabou\coregymali\lib\fitness_home_pages.dart',
    r'c:\Users\mabou\coregymali\lib\widgets\home_header.dart',
    r'c:\Users\mabou\coregymali\lib\screens\nutrition_screen.dart',
    r'c:\Users\mabou\coregymali\lib\screens\workout_screen.dart',
    r'c:\Users\mabou\coregymali\lib\screens\active_workout_screen.dart',
    r'c:\Users\mabou\coregymali\lib\profile.dart',
    r'c:\Users\mabou\coregymali\lib\login_sign_up.dart',
    r'c:\Users\mabou\coregymali\lib\screens\onboarding_flow.dart',
    r'c:\Users\mabou\coregymali\lib\widgets\core_gym_navbar.dart',
]

def escape_regex(s):
    return re.escape(s)

for file in dart_files:
    if not os.path.exists(file):
        print(f"Skipping {file}, does not exist")
        continue

    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Add import if missing
    if "flutter_gen/gen_l10n/app_localizations.dart" not in content:
        content = re.sub(r"import 'package:flutter/material\.dart';", r"import 'package:flutter/material.dart';\nimport 'package:flutter_gen/gen_l10n/app_localizations.dart';", content)
        
    for string_val, key in string_to_key:
        encoded_val = string_val
        # Match EXACT string literals in single quotes
        pattern_s = r"(?<!\w)'" + escape_regex(encoded_val) + r"'"
        content = re.sub(pattern_s, f"AppLocalizations.of(context)!.{key}", content)
        # Match EXACT string literals in double quotes
        pattern_d = r'(?<!\w)"' + escape_regex(encoded_val) + r'"'
        content = re.sub(pattern_d, f"AppLocalizations.of(context)!.{key}", content)

    # Convert const Text(AppLoc...) to Text(AppLoc...)
    content = re.sub(r'const\s+Text\(\s*AppLocalizations', r'Text(AppLocalizations', content)

    # RTL replacements
    content = content.replace("EdgeInsets.only(left:", "EdgeInsetsDirectional.only(start:")
    content = content.replace(", left:", ", start:")
    content = content.replace("EdgeInsets.only(right:", "EdgeInsetsDirectional.only(end:")
    content = content.replace(", right:", ", end:")

    # Icons that indicate direction (like arrow_forward_ios) -> arrow_forward_ios_rounded
    # Actually, the user asked to replace Icons.arrow_forward_ios -> Directionality based
    # "Directionality.of(context) == TextDirection.rtl ? Icons.arrow_back_ios_rounded : Icons.arrow_forward_ios_rounded"
    arrow_fwd = r"Directionality.of(context) == TextDirection.rtl ? Icons.arrow_back_ios_rounded : Icons.arrow_forward_ios_rounded"
    arrow_back = r"Directionality.of(context) == TextDirection.rtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_rounded"
    content = content.replace("Icons.arrow_forward_ios", arrow_fwd)
    content = content.replace("Icons.arrow_forward_ios_rounded", arrow_fwd)
    content = content.replace("Icons.arrow_back_ios", arrow_back)
    content = content.replace("Icons.arrow_back_ios_rounded", arrow_back)

    
    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)

print("Done python script")
