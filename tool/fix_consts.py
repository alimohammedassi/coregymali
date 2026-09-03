import re, subprocess, sys, os
from collections import defaultdict

ROOT = r"C:\Users\mabou\coregymali"
IDENT = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")

def run_analyze():
    p = subprocess.run(["flutter", "analyze", "--no-pub"], cwd=ROOT,
                       capture_output=True, text=True, shell=True)
    errs = []
    for line in (p.stdout + p.stderr).splitlines():
        m = re.match(r"\s*error - (.+?) - (.+?):(\d+):(\d+) - (\w+)$", line)
        if m:
            msg, path, ln, col, code = m.groups()
            errs.append((os.path.join(ROOT, path.replace("\\", "/")),
                         int(ln), int(col), code, msg))
    return errs

def to_offset(text, line, col):
    # analyzer is 1-based line, 1-based col (in UTF-16 code units; our files are ASCII around code)
    lines = text.split("\n")
    off = sum(len(l) + 1 for l in lines[:line - 1])
    return off + col - 1

def find_declaration_const(text, err_off):
    """const X y = <err>;  -> position of the const keyword (walk back over type chars)."""
    i = err_off - 1
    while i >= 0:
        c = text[i]
        if c in IDENT or c in " \t\r\n<>,?." :
            i -= 1
            continue
        break
    # i now at char before the type annotation run; expect word 'const' ending here
    seg = text[max(0, i - 5):i + 1]
    if seg.endswith("const"):
        return i - 4
    return None

def find_enclosing_const(text, err_off):
    """Remove the OUTERMOST const whose construct encodes err_off."""
    i = err_off - 1
    depth = 0
    while i >= 0:
        c = text[i]
        if c in ")]}":
            depth += 1
            i -= 1
            continue
        if c in "([{":
            if depth == 0:
                # boundary: construct opener enclosing the error
                j = i - 1
                while j >= 0 and text[j] in " \t\r\n":
                    j -= 1
                # skip a chained identifier (e.g. Icon) or .member
                end = j
                while j >= 0 and (text[j] in IDENT or text[j] == "."):
                    j -= 1
                word = text[j + 1:end + 1]
                k = j
                while k >= 0 and text[k] in " \t\r\n":
                    k -= 1
                if word == "const":
                    return j + 1  # 'const Foo(' or 'const ['
                # check the token before the identifier is 'const'? word!=const,
                # maybe identifier itself is preceded by const already consumed:
                # e.g. boundary '[', word before is '' but text before is 'const'
                if word == "" and end < i:
                    pass
                if text[max(0, k - 4):k + 1] == "const":
                    return k - 4
                # not a const construct; keep scanning outward from boundary
                i -= 1
                continue
            else:
                depth -= 1
                i -= 1
                continue
        i -= 1
    return None

def fix_file(path, sites):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    fixes = []  # (start, end, replacement)
    for (ln, col, code, msg) in sites:
        off = to_offset(text, ln, col)
        if code == "const_initialized_with_non_constant_value":
            pos = find_declaration_const(text, off)
            if pos is not None:
                fixes.append((pos, pos + 5, "final"))
        else:
            pos = find_enclosing_const(text, off)
            if pos is not None and text[pos:pos + 5] == "const":
                fixes.append((pos, pos + 5, ""))
    if not fixes:
        return 0
    # dedupe + apply from the end so offsets stay valid
    fixes = sorted(set(fixes), key=lambda f: f[0], reverse=True)
    for start, end, repl in fixes:
        text = text[:start] + repl + text[end:]
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    return len(fixes)

for iteration in range(1, 11):
    errs = run_analyze()
    const_codes = {"invalid_constant", "const_initialized_with_non_constant_value",
                   "non_constant_map_value", "const_with_non_constant_argument"}
    sites = [e for e in errs if e[3] in const_codes]
    print(f"iteration {iteration}: {len(errs)} errors, {len(sites)} const-related")
    if not sites:
        break
    by_file = defaultdict(list)
    for path, ln, col, code, msg in sites:
        by_file[path].append((ln, col, code, msg))
    total = 0
    for path, ss in by_file.items():
        try:
            total += fix_file(path, ss)
        except Exception as ex:
            print("FAIL", path, ex)
    print("fixed:", total)
    if total == 0:
        print("no progress — stopping")
        break
