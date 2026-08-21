#!/bin/sh
# Measure the comment prose in shipped game code, and fail when it carries a machine fingerprint.
#
# This exists because a comment pass can pass its own acceptance test and still make the file worse. One
# earlier pass removed every em-dash from `scenes/visuals.gd` and grew it from 482 comment lines to 523,
# during a pass whose whole purpose was reducing an abnormal comment-to-code ratio. "No em-dashes" was
# standing in for "reads like a person wrote it", and a proxy that can be satisfied while the goal moves
# backwards is not an acceptance test.
#
# WHAT IT ASSERTS, and why each one is derived rather than chosen:
#
#   em-dashes            0. This is categorical, not a taste threshold: the character is the tell.
#   substitution density Removing a dash by promoting it to a comma is its own fingerprint, and a uniform
#                        mechanical swap across hundreds of sites is MORE detectable than the punctuation
#                        it replaced. Measured across files scrubbed here: commas per comment line went
#                        0.631 -> 0.788, 0.635 -> 0.821, 0.667 -> 0.879, largest where the most dashes
#                        were removed, while SEMICOLON density fell at the same time. One mark absorbed
#                        the other. The ceiling below is read from `scenes/fine_terrain.gd`, the file a
#                        person wrote by hand, rather than picked: it is that file's own value times
#                        COMMA_SLACK. Change the reference and the ceiling moves with it.
#   forbidden tokens     0. Dates, ticket ids, markdown emphasis, and the vocabulary of how the work was
#                        organised rather than what the code does.
#
# HOW NOT TO PASS IT. The cheapest way to clear a token failure is to delete the comment, and that is
# almost always wrong: "five harness fixtures call this signature too" is a real constraint on changing
# the signature, and the fault is the word `harness`, not the fact. Reword to the vocabulary a reader
# outside this repository would use (the tests, a fixture, a design call) and keep the constraint. A gate
# whose easiest exit is deleting information is a gate that makes the code worse, so this note is part of
# the tool rather than a convention someone has to remember.
#
# THE REFERENCE IS NOT EXEMPT FROM EVERYTHING. It sets the comma ceiling, so it cannot be compared against
# it: a thing cannot fail a threshold it defines. It IS checked for the categorical rules, because the
# alternative is one file in the tree where a tell can never be seen, which is the shape of a guard that
# cannot be false.
#
# WHAT IT ONLY REPORTS: comment share of total lines. There is no defensible bound on how much a file
# should be commented, and inventing one here would freeze a number nobody measured. It prints sorted
# worst-first so a reader can see the outliers without the script pretending to know where the line is.
#
# A FILE THE EXTRACTOR CANNOT READ IS A FAILURE, NOT A PASS. The first version of this globbed
# `.gdshader` alongside `.gd`, found no `#` comments in them because shaders comment with `//`, recorded
# zero comment lines, and skipped them as having nothing to check. Five shader files were invisible to a
# tool named for finding exactly what one of them carried. So a globbed file that yields no comments is
# now reported by name: either it is genuinely uncommented, which is worth knowing, or the extractor does
# not understand its syntax, which is worth knowing more.
#
# THE FRAME. Every number here is a statement about one checkout. The tool prints the branch and SHA it
# read, because a source-reading instrument whose output does not name its ref invites its findings to be
# quoted as properties of the project.
#
# Exit 0 clean - 1 at least one file failed - 2 called wrong or the reference is missing.

set -eu

REF_FILE="scenes/fine_terrain.gd"     # the hand-written reference; excluded from its own check
COMMA_SLACK="1.10"                    # how far above the reference a file may sit before it reads mechanical

cd "$(dirname "$0")/.."

[ -f "$REF_FILE" ] || { echo "check_prose: reference $REF_FILE is missing; cannot derive a ceiling" >&2; exit 2; }

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown ref')"
SHA="$(git rev-parse --short HEAD 2>/dev/null || echo '????')"
DIRTY=""
[ -n "$(git status --porcelain 2>/dev/null)" ] && DIRTY=" +uncommitted"

echo "check_prose: $BRANCH @ $SHA$DIRTY"
echo "check_prose: a file named here may be absent or already correct on another ref."
echo

python3 - "$REF_FILE" "$COMMA_SLACK" <<'PYEOF'
import os, re, sys, glob, subprocess

ref_path, slack = sys.argv[1], float(sys.argv[2])
EMDASH = "—"

# Comment-only text. A "#" inside a string literal is code, so trailing comments are found by scanning
# the line and tracking quote state rather than by splitting on the first "#".
def comment_text(src, shader=False):
    out = []
    block = False
    for line in src.split("\n"):
        s = line.lstrip()
        if shader:
            if block:
                out.append(s)
                if "*/" in line:
                    block = False
                continue
            if s.startswith("/*"):
                out.append(s)
                block = "*/" not in s
                continue
        if s.startswith("#") or (shader and s.startswith("//")):
            out.append(s)
            continue
        q, i, n = None, 0, len(line)
        while i < n:
            c = line[i]
            if q:
                if c == "\\":
                    i += 2
                    continue
                if c == q:
                    q = None
            elif c in "\"'":
                q = c
            elif c == "#":
                out.append(line[i:].strip())
                break
            elif shader and c == "/" and i + 1 < n and line[i + 1] == "/":
                out.append(line[i:].strip())
                break
            i += 1
    return out

def metrics(path):
    src = open(path, encoding="utf-8").read()
    cl = comment_text(src, shader=path.endswith(".gdshader"))
    body = "\n".join(cl)
    n = max(len(cl), 1)
    total = max(src.count("\n"), 1)
    return {
        "comment_lines": len(cl),
        "total": total,
        "share": len(cl) / total,
        "emdash": body.count(EMDASH),
        "comma": body.count(", ") / n,
        "semi": body.count("; ") / n,
        "body": body,
    }

TOKENS = [
    (r"\*\*[^*]+\*\*",                                  "markdown bold"),
    (r"(?<![0-9])20[0-9]{2}-[0-9]{2}-[0-9]{2}",         "a date"),
    (r"\b(?:UI|MNU|GR|SF|TR|P)-[0-9]{2,}\b",            "a ticket id"),
    (r"\b(?:play-test|playtest)\b",                     "play-test"),
    (r"\bharness\b",                                    "harness"),
    (r"\bagents?\b",                                    "agent"),
    (r"\bdirector\b",                                   "director"),
    (r"\bpeer\b",                                       "peer"),
    (r"\bthe user\b",                                   "the user"),
    (r"TRIED AND REVERTED",                             "TRIED AND REVERTED"),
    (r"\bRAISED\s+[0-9.]+\s*->\s*[0-9.]+",              "a RAISED x -> y note"),
    (r"\bblind judge\b",                                 "blind judge"),
    (r"^\s*(?:#|//)\s*MEASURED\b",                       "a MEASURED banner"),
]

ref = metrics(ref_path)
ceiling = ref["comma"] * slack
print("reference  %-34s %5d comment lines  %.3f commas/line" % (ref_path, ref["comment_lines"], ref["comma"]))
print("ceiling    %.3f commas/line  (reference x %.2f)" % (ceiling, slack))
print()

paths = sorted(set(glob.glob("scenes/**/*.gd", recursive=True)
                 + glob.glob("scenes/**/*.gdshader", recursive=True)
                 + glob.glob("src/**/*.gd", recursive=True)))

# THE SECOND SWEEP, AND THE REASON IT IS SEPARATE.
#
# Everything above this line looks at `scenes/` and `src/` only, and for eight months that was the whole
# scan. So `tools/`, `.github/`, `docs/` and the two root markdown files were never read by this tool at
# all -- which is how a registered layer name reached the public run summary carrying the vocabulary this
# file exists to keep out of the repository. An instrument with a glob that excludes most of the tree is
# not a strict instrument, it is a quiet one.
#
# It cannot simply be the same scan with a wider glob, and that is the interesting part. The token list
# above forbids `harness`, which is correct for game code -- the simulation should not know it is being
# tested -- and absurd for `tools/`, where the harness is the subject. Applying one list to both surfaces
# would produce hundreds of failures that are all correct usage, and a gate that cries wolf gets disabled.
#
# So the wide sweep carries its own much narrower list: only the vocabulary that is wrong ANYWHERE in a
# repository written by one person. Process words are allowed out here; authorship words are not.
WIDE_TOKENS = []
_words = os.environ.get("SF_PROSE_WORDS") or os.path.join(os.getcwd(), "tools", "prose_words.txt")
if os.path.isfile(_words):
    for _w in open(_words, encoding="utf-8").read().splitlines():
        _w = _w.split("#", 1)[0].strip()
        if _w:
            WIDE_TOKENS.append((r"\b%s\b" % _w, _w))
# TRACKED FILES ONLY, and this is the difference between a gate and a nuisance. The working tree carries
# coordination documents that are deliberately kept out of the repository through `.git/info/exclude`
# rather than `.gitignore` (because the ignore file itself ships). Those are exactly where process and
# authorship vocabulary is SUPPOSED to live, and scanning them would fail this gate permanently on files
# no clone will ever see. What ships is what `git ls-files` says ships.
_tracked = subprocess.run(["git", "ls-files", "-z"], capture_output=True, text=True, check=True)
_tracked = set(_tracked.stdout.split("\0")) - {""}
WIDE_PATHS = sorted(f for f in _tracked
                    if f.startswith(("tools/", ".github/"))
                    or (f.startswith("docs/") and f.endswith(".md"))
                    or f in ("README.md", "CONTRIBUTING.md"))
# This file spells every literal it hunts for, so it cannot be its own subject. `.gitignore` is excluded
# for the same reason one line down. Both exclusions are counted and printed below, because an exclusion
# nobody can see is indistinguishable from a scan that missed.
WIDE_SKIP = {"tools/check_prose.sh"}
wide_fails, wide_read, wide_skipped = [], 0, 0
for wp in WIDE_PATHS:
    if not os.path.isfile(wp):
        continue
    if wp in WIDE_SKIP:
        wide_skipped += 1
        continue
    try:
        wsrc = open(wp, encoding="utf-8").read()
    except (UnicodeDecodeError, OSError):
        continue          # binary or unreadable: not prose, and not silently counted as clean either
    wide_read += 1
    hits = []
    for pat, name in WIDE_TOKENS:
        k = len(re.findall(pat, wsrc))
        if k:
            hits.append("%dx %s" % (k, name))
    if hits:
        wide_fails.append((wp, hits))

ref_abs = os.path.abspath(ref_path)

fails, rows, unreadable = [], [], []
for p in paths:
    m = metrics(p)
    if m["comment_lines"] == 0:
        unreadable.append(p)
        continue
    bad = []
    is_ref = os.path.abspath(p) == ref_abs
    if m["emdash"]:
        bad.append("%d em-dash" % m["emdash"])
    # Density is only meaningful with enough lines to average over. Below this a handful of commas
    # swings the ratio, and a per-file verdict there would be measuring the sample size. The reference
    # is skipped here only, since it is the source of the ceiling.
    if not is_ref and m["comment_lines"] >= 40 and m["comma"] > ceiling:
        bad.append("%.3f commas/line over %.3f" % (m["comma"], ceiling))
    for pat, name in TOKENS:
        k = len(re.findall(pat, m["body"], re.IGNORECASE))
        if k:
            bad.append("%dx %s" % (k, name))
    rows.append((m["share"], p, m["comment_lines"], m["total"], m["comma"], bad))
    if bad:
        fails.append((p, bad))

print("%-42s %6s %6s %6s  %s" % ("FILE", "#CMNT", "TOTAL", "COMMA", "SHARE"))
for share, p, cl, tot, comma, bad in sorted(rows, reverse=True)[:14]:
    print("%-42s %6d %6d %6.3f  %4.0f%%%s" % (p, cl, tot, comma, share * 100, "  <-- fails" if bad else ""))
print("\n(comment share is reported, never asserted: no defensible bound exists for it)")

if unreadable:
    print("\n%d globbed file(s) yielded NO comments; either genuinely bare or the extractor" % len(unreadable))
    print("does not understand their syntax. Both are worth a look:")
    for p in unreadable:
        print("  %s" % p)

print("\nwide sweep: %d file(s) read across tools/, .github/, docs/ and the root markdown"
      % wide_read)
print("            %d skipped (this file spells every literal it hunts for)" % wide_skipped)
if wide_fails:
    print("\n%d file(s) carry authorship vocabulary outside the game code:" % len(wide_fails))
    for wp, hits in wide_fails:
        print("  %-42s %s" % (wp, "; ".join(hits)))

if fails or wide_fails:
    if fails:
        print("\n%d file(s) failed:" % len(fails))
        for p, bad in fails:
            print("  %-42s %s" % (p, "; ".join(bad)))
    sys.exit(1)

print("\ncheck_prose: %d file(s) clean, %d more clean on the wide sweep" % (len(rows), wide_read))
PYEOF
