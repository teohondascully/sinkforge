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
import os, re, sys, glob

ref_path, slack = sys.argv[1], float(sys.argv[2])
EMDASH = "—"

# Comment-only text. A "#" inside a string literal is code, so trailing comments are found by scanning
# the line and tracking quote state rather than by splitting on the first "#".
def comment_text(src):
    out = []
    for line in src.split("\n"):
        s = line.lstrip()
        if s.startswith("#"):
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
            i += 1
    return out

def metrics(path):
    src = open(path, encoding="utf-8").read()
    cl = comment_text(src)
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
]

ref = metrics(ref_path)
ceiling = ref["comma"] * slack
print("reference  %-34s %5d comment lines  %.3f commas/line" % (ref_path, ref["comment_lines"], ref["comma"]))
print("ceiling    %.3f commas/line  (reference x %.2f)" % (ceiling, slack))
print()

paths = sorted(set(glob.glob("scenes/**/*.gd", recursive=True)
                 + glob.glob("scenes/**/*.gdshader", recursive=True)
                 + glob.glob("src/**/*.gd", recursive=True)))
ref_abs = os.path.abspath(ref_path)

fails, rows = [], []
for p in paths:
    m = metrics(p)
    if m["comment_lines"] == 0:
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

if fails:
    print("\n%d file(s) failed:" % len(fails))
    for p, bad in fails:
        print("  %-42s %s" % (p, "; ".join(bad)))
    sys.exit(1)

print("\ncheck_prose: %d file(s) clean" % len(rows))
PYEOF
