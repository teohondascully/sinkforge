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
# THE CEILING IS DERIVED FROM THE REFERENCE, SO THE REFERENCE CAN RAISE THE CEILING WITHOUT ANYONE SAYING
# SO. That is the one hole in the relative design above, and it is not the quantile-that-moves-its-own-
# threshold -- the ceiling moves with a THIRD file, not with the file under test, and deriving it from a
# file a person actually wrote is a deliberate choice (see the note at the top). What was missing is any
# statement of where that anchor is allowed to be.
#
# A RATCHET, NOT A BOUND, and the direction is the whole point. The reference may become LEANER freely:
# that only tightens every other file's ceiling, which is the direction we want and would otherwise be
# punished. It may not become COMMA-DENSER than the value recorded here without somebody editing this
# line, because that silently relaxes the gate for the entire tree. Recorded rather than guessed: this is
# what shipping already decided, measured off the tree at f097834.
REF_COMMA_MAX="0.705"                 # ratchet: `scenes/fine_terrain.gd` measured 0.700 on 2026-08-21

cd "$(dirname "$0")/.."

[ -f "$REF_FILE" ] || { echo "check_prose: reference $REF_FILE is missing; cannot derive a ceiling" >&2; exit 2; }

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown ref')"
SHA="$(git rev-parse --short HEAD 2>/dev/null || echo '????')"
DIRTY=""
[ -n "$(git status --porcelain 2>/dev/null)" ] && DIRTY=" +uncommitted"

echo "check_prose: $BRANCH @ $SHA$DIRTY"
echo "check_prose: a file named here may be absent or already correct on another ref."
echo

python3 - "$REF_FILE" "$COMMA_SLACK" "$REF_COMMA_MAX" <<'PYEOF'
import os, re, sys, subprocess

ref_path, slack, ref_max = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
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
print("ceiling    %.3f commas/line  (reference x %.2f, anchor ratchet %.3f)" % (ceiling, slack, ref_max))
drifted = ref["comma"] > ref_max
# AND THE RATCHET DOES NOT TIGHTEN, WHICH IS THE DEFECT IT WAS MODELLED ON. The anchor is a constant and
# the per-file ceiling is still computed live off the reference, so the reference may be scrubbed to 0.500
# (every ceiling drops to 0.550, silently and correctly) and then drift back to 0.700 (every ceiling rises
# to 0.770) without ever crossing 0.705. That is 0.205 of permanent slack on the bound that sets every
# other file's, and it is the same object as a warp entry left at 7 against a real count of 0. A review
# finding, on a guard written four hours after I wrote that sentence down.
#
# A NUDGE AND NOT A FAILURE, deliberately: a stale anchor is slack, not a breach, and failing a clean tree
# because somebody improved the reference is how a gate gets switched off. The line says the number and
# what to do with it, which is all a ratchet can honestly ask for.
stale = (not drifted) and (ref_max - ref["comma"]) > 0.02
if stale:
    print()
    print("   note: the anchor is stale. %s measures %.3f against a recorded maximum of %.3f, so every"
          % (ref_path, ref["comma"], ref_max))
    print("         file is being judged %.3f looser than the reference currently earns. Tighten"
          % ((ref_max - ref["comma"]) * slack))
    print("         REF_COMMA_MAX toward the measured value; it is slack, not a breach, so this is a note.")
if drifted:
    print()
    print("!! THE ANCHOR HAS DRIFTED UP: %s is at %.3f commas/line against a recorded maximum of %.3f,"
          % (ref_path, ref["comma"], ref_max))
    print("   so the ceiling every other file is judged against has risen to %.3f with nothing saying so."
          % ceiling)
    print("   Either that file's comment style moved and should be looked at, or the move is intended and")
    print("   REF_COMMA_MAX in this script should be raised deliberately. A ceiling derived from a subject")
    print("   that is free to move is not a ceiling.")
print()

# TRACKED FILES ONLY, HERE TOO. The wide sweep below has always done this and says why; this sweep globbed
# the filesystem instead, and the two happened to name the same 47 files on the day it was checked. That is
# a fact with a date on it, not a property: a generated `.gd`, a scratch copy, or anything a worktree left
# behind under `scenes/` or `src/` would be judged by a gate about what SHIPS. Hardening rather than a
# repair, and said as such — nothing untracked was found there, and the measurement is the reason the
# change is small.
_tracked = subprocess.run(["git", "ls-files", "-z"], capture_output=True, text=True, check=True)
_tracked = set(_tracked.stdout.split("\0")) - {""}
paths = sorted(f for f in _tracked
               if (f.startswith(("scenes/", "src/"))
                   and (f.endswith(".gd") or (f.startswith("scenes/") and f.endswith(".gdshader")))))
if not paths:
    print("check_prose: the tracked-file scan of scenes/ and src/ found NOTHING, which is a statement")
    print("             about the scan and not about the tree. Nothing was measured.")
    sys.exit(2)

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
# repository written by one person.
#
# AND THAT LIST LIVES OUTSIDE THIS FILE, which is a publication decision rather than a code one. A
# banned-word list is a statement about what its author expects to find, so shipping one is shipping that
# expectation -- and this one had already done its work: every word on it occurs zero times in the tracked
# tree, so the only remaining instance of each was the line here forbidding it. A rule that is the sole
# surviving example of what it prohibits is not protecting anything, it is describing its author. Same
# reason the file already excludes itself from its own scan, carried one step further.
#
# One word per line, `#` comments and blanks ignored, matched whole-word and case-insensitively. Point
# SF_PROSE_WORDS at any file; the default is untracked, so a clean clone has no list and says so rather
# than reporting a silent pass over an empty one.
# `__file__` is not this .sh (the python arrives on stdin), so the default is resolved against the tree
# the layer already runs from. The first draft used `__file__` and silently pointed one directory too
# high, which the "list present" control caught by naming a path that did not exist.
WORDS_PATH = os.environ.get("SF_PROSE_WORDS") or os.path.join(os.getcwd(), "tools", "prose_words.txt")
WIDE_TOKENS = []
if os.path.isfile(WORDS_PATH):
    for _w in open(WORDS_PATH, encoding="utf-8").read().splitlines():
        _w = _w.split("#", 1)[0].strip()
        if _w:
            # ANCHORING IS WHAT HID ONE, so it is now applied only where it is needed. A whole-word
            # matcher cannot see a listed word written inside a REGEX LITERAL: in `\b<listed-word>`
            # the character before it is the `b` of `\b`, which is a word character, so the
            # lookbehind rejects it. The public tree carries exactly that, in a token list, inside the
            # gate that hunts these words -- found by a peer scanning without anchors and missed by
            # three separately built scans that all had them. The precision was the blind spot.
            #
            # Short tokens still need both anchors, because they occur inside ordinary English: the
            # two-letter one matches "remains", "available", "again". Longer ones are matched as plain
            # substrings, which is strictly more sensitive and cannot be evaded by any prefix.
            #
            # THE LENGTH RULE IS A PROXY AND IT HAS A KNOWN EXCEPTION, named here rather than left for
            # whoever next writes the word in a document. The first draft of this comment claimed that
            # longer vendor names do not occur inside ordinary words. That is false at nine letters:
            # prefixing one of the tokens with `phil` or `mis`, or suffixing it with `al`, gives three
            # ordinary English adjectives. A peer found it by testing the invariant instead of reading
            # it. Written as prefixes rather than spelled out because spelling them turns this comment
            # into three hits -- which is the collision demonstrating itself, and the reason the
            # placeholder convention above exists.
            #
            # It stays a substring anyway, and the honest statement of the trade is not "no collisions"
            # but this: a short token collides so often that anchoring is the only way it is usable at
            # all, while a long one collides rarely and LOUDLY. The list already makes that trade
            # explicitly for the two-letter entry, whose note says a loud wrong answer is what it is
            # buying. A false positive here reds the gate and gets read; a false negative is silent and
            # ships. The whole reason this line changed is that the anchors were producing the silent
            # kind.
            #
            # Measured: 0 hits from substring-matching every longer token across the whole tracked tree,
            # and 0 occurrences of the three colliding forms on either tree, so this hardens the gate
            # and moves no verdict today. If a document ever legitimately needs one of them, the fix is
            # a word-specific exception with the reason beside it, never a return to blanket anchoring.
            if len(_w) <= 3:
                WIDE_TOKENS.append((r"(?<![A-Za-z0-9_])" + re.escape(_w) + r"s?(?![A-Za-z0-9_])", _w))
            else:
                WIDE_TOKENS.append((re.escape(_w), _w))
# TRACKED FILES ONLY, and this is the difference between a gate and a nuisance. The working tree carries
# coordination documents that are deliberately kept out of the repository through `.git/info/exclude`
# rather than `.gitignore` (because the ignore file itself ships). Those are exactly where process and
# authorship vocabulary is SUPPOSED to live, and scanning them would fail this gate permanently on files
# no clone will ever see. What ships is what `git ls-files` says ships.
# AND THE POPULATION IS THE WHOLE TRACKED TREE, because the enumerated directory list this replaced was
# a second hole of the same kind. It read `tools/`, `.github/`, `docs/*.md` and two root files, so
# `tests/` -- five tracked .gd files, 264KB, one of them 117KB -- plus both git hooks, project.godot and
# the LICENSE were read by NEITHER sweep, ever. `scenes/` and `src/` were read only by the narrow sweep,
# which sees comment BODIES and not string literals, and whose token list carries none of the eight
# vendor words. Measured, with a control leg, by planting three lines in scenes/player.gd:
#
#     # <listed-word> probe.          exit 1   caught      <- control: file is in population, gate is live
#     # <vendor-name> wrote this.      exit 0   MISSED
#     print("<listed-word> probe")     exit 0   MISSED
#
# The words are written as placeholders on purpose, and the reason is a defect this file committed twice
# tonight. THIS FILE IS TRACKED AND IT EXCLUDES ITSELF FROM ITS OWN SCAN, which is correct -- it would
# match its own literals -- and which makes it the one shipped file no gate reads. Spelling the evidence
# out here put five occurrences of the vocabulary into the only place nothing would ever catch them:
# 0 on origin/main, 2 after the case-fold repair, 5 after the population repair, every one added by the
# commits whose subject was removing exactly this. Self-exclusion is necessary and it is also an
# unmonitored surface; write about the words here, never in them.
#
# The two misses are the hole; the control is what makes them mean blindness rather than a broken probe.
# Note which one nearly shipped: the instance that started this was a print() banner, the highest-value
# surface there is, and it was caught only because it happened to live under `tools/`.
#
# The list's own premise is vocabulary wrong ANYWHERE in a repository written by one person, so any
# population narrower than the tree is a claim that some corner is exempt, and no such corner was ever
# argued for. Measured before the change: 0 hits across the 58 text files it adds, so this hardens the
# gate and moves no verdict.
WIDE_PATHS = sorted(_tracked)
# AND NOTHING IS EXCLUDED, WHICH IS A CHANGE. This set held `tools/check_prose.sh` for as long as this
# file spelled the words it hunts for: a file reporting on the list matches anything the list names, so
# it had to be exempt. That exemption made it the one tracked, shipped file no gate read -- and the
# comments above then filled it, 0 occurrences on origin/main to 5, added by the very commits removing
# the vocabulary elsewhere. The self-exclusion was correct and the surface it created was not.
#
# Rewriting those comments to placeholders took this file to 0, which removes the reason for the
# exemption, so the exemption goes. Named on both axes rather than called an improvement: better on
# coverage, because the last unscanned tracked file is now scanned; worse on freedom of expression in
# this one file, because writing about a listed word here now fails the gate and the author must reach
# for `<listed-word>`. That is the trade, and it is the right way round -- the alternative is a blind
# spot precisely where someone is thinking hardest about the vocabulary.
#
# The set and its counter stay so the mechanism exists and prints; an exclusion nobody can see is
# indistinguishable from a scan that missed, and so is an empty one nobody mentions.
#
# (The comment here also used to claim `.gitignore` was excluded. It never was, in this set or any
# other; the old population simply never reached it. It is in scope now and measures clean.)
WIDE_SKIP = set()
# A LIST THAT IS NOT THERE IS NOT A CLEAN SWEEP, AND SAYING SO IN PROSE IS NOT ENOUGH. The first version
# of this printed a warning and then exited 0 with no marker, so the runner scored the layer a plain PASS,
# byte-indistinguishable from a run that tested every word -- and since the list is deliberately untracked,
# that is the PERMANENT state in CI, which is the one environment where the tree becomes public. A gate
# that stands an assertion down silently, forever, in exactly the place it matters, is the quiet green
# this repository is built around catching, one level up from the leg it was written to fix.
#
# So it declares itself through the registry instead: `SKIP: [id]` when the sweep is declined, `HELD: [id]`
# when it ran. tools/stand_downs.txt carries the row and tools/harness_verdict.sh resolves it, so the
# verdict reads PASS* and names which assertion did not happen. Same three-valued accounting a check_base
# layer gets, spelled out by hand because this layer is a shell script and has no base class.
if not WIDE_TOKENS:
    print("  SKIP: [prose.wide-word-list] no wide word list at %s, so no authorship vocabulary was"
          % WORDS_PATH)
    print("        tested. Point SF_PROSE_WORDS at a file with one word per line to enable it.")
else:
    print("  HELD: [prose.wide-word-list] this run asserted it (%d word(s))" % len(WIDE_TOKENS))
wide_fails, wide_read, wide_skipped = [], 0, 0
wide_emdash, wide_emdash_files = 0, 0
_emdash_gated = set(paths)   # the population the categorical em-dash rule already covers
wide_binary, wide_absent, wide_unreadable = 0, 0, []
for wp in WIDE_PATHS:
    if wp in WIDE_SKIP:
        wide_skipped += 1
        continue
    if not os.path.isfile(wp):
        wide_absent += 1      # tracked but not in the worktree: counted, because it was not scanned
        continue
    try:
        raw = open(wp, "rb").read()
    except OSError as exc:
        # A TRACKED FILE THE GATE CANNOT OPEN IS A HOLE, NOT A PASS. The line this replaced swallowed
        # OSError next to a comment claiming the file was "not silently counted as clean either" -- and
        # `continue` is exactly that: no counter, no output, nothing in the summary. It described a
        # property the code did not have, which is the same defect as the case-insensitivity one below
        # and was written the same night. Never taken while the population was 152 curated text files;
        # taken ~250 times a run now, so it had to be right before the population grew.
        wide_unreadable.append((wp, str(exc)))
        continue
    # Git's own text/binary heuristic: a NUL byte near the head. Reading 8KB of each of 247 PNGs costs
    # nothing, and it means the binary decision is made by inspection rather than by an extension
    # allowlist -- which would be the same enumerated-set mistake one level down.
    if b"\0" in raw[:8192]:
        wide_binary += 1
        continue
    try:
        wsrc = raw.decode("utf-8")
    except UnicodeDecodeError:
        wide_binary += 1
        continue
    wide_read += 1
    # EM-DASH CENSUS, COUNTED HERE AND FAILING NOTHING. The em-dash rule twelve screens down is
    # categorical -- this file's own header says "the character is the tell" -- and its population is
    # `scenes/` and `src/` COMMENT BODIES, which is 314 of the 1902 em-dashes in origin/main's tracked
    # text. The other 1588 are in tools/, docs/, tests/ and the root, where nothing has ever counted
    # them, so a clean run has always been able to read as "this tree has no em-dashes" while carrying
    # 84% of them one directory across.
    #
    # It reports and does not fail, deliberately. Turning it into a gate would go red on 1772 lines
    # tonight, which is a backlog decision and not a repair, and a gate that arrives already red gets
    # switched off. What it removes is the INVISIBILITY, which is the half that was never anyone's
    # decision. Counted on the read the wide sweep already did, so it costs nothing.
    if wp not in _emdash_gated:
        _n_em = wsrc.count(EMDASH)
        if _n_em:
            wide_emdash += _n_em
            wide_emdash_files += 1
    hits = []
    for pat, name in WIDE_TOKENS:
        # CASE-INSENSITIVE, like the narrow sweep twelve lines down and unlike the first version of
        # this line. The word list's own header promised whole-word AND case-insensitive matching while
        # the code did neither half of the second part, so the CAPITALISED spelling of a listed word
        # passed a gate that stopped its lowercase form. origin/main carries exactly that pair in one
        # file: a docstring spells it capitalised, a print() twelve lines later spells it lowercase, and
        # only the second was reachable. A rule documented one way and implemented another is the quieter half of a guard
        # that cannot be false.
        k = len(re.findall(pat, wsrc, re.IGNORECASE))
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

print("\nwide sweep: %d word(s) tested over %d text file(s) -- every tracked file in the repository"
      % (len(WIDE_TOKENS), wide_read))
print("            %d binary, %d excluded by name, %d tracked-but-absent,"
      % (wide_binary, wide_skipped, wide_absent))
print("            %d unreadable" % len(wide_unreadable))
if wide_emdash:
    print("\n   note: %d em-dash(es) in %d tracked file(s) OUTSIDE the categorical rule's population"
          % (wide_emdash, wide_emdash_files))
    print("         (that rule reads scenes/ and src/ comment bodies only). Counted, not gated: this")
    print("         is a backlog, and a report of 0 em-dashes above is a statement about %d file(s),"
          % len(paths))
    print("         not about the tree.")
# THE POPULATION HAS TO ADD UP. Every path out of the loop above increments exactly one counter, so if
# these do not sum to the population then a file left through a path nobody counts -- which is precisely
# the bug this block replaced, and precisely the thing that makes a small sweep read as a clean one.
_acct = wide_read + wide_binary + wide_skipped + wide_absent + len(wide_unreadable)
if _acct != len(WIDE_PATHS):
    print("\n!! POPULATION DOES NOT ADD UP: %d accounted for against %d tracked. A file left the wide"
          % (_acct, len(WIDE_PATHS)))
    print("   sweep through an uncounted path, so this sweep's silence is not evidence about anything.")
    sys.exit(2)
if wide_unreadable:
    print("\n%d tracked file(s) could not be opened, so they were NOT scanned:" % len(wide_unreadable))
    for wp, why in wide_unreadable:
        print("  %-42s %s" % (wp, why))
if wide_fails:
    print("\n%d file(s) carry authorship vocabulary:" % len(wide_fails))
    for wp, hits in wide_fails:
        print("  %-42s %s" % (wp, "; ".join(hits)))

if fails or wide_fails or drifted or wide_unreadable:
    if drifted:
        print("\nthe comma ceiling's anchor drifted above its recorded maximum (see the banner above).")
    if fails:
        print("\n%d file(s) failed:" % len(fails))
        for p, bad in fails:
            print("  %-42s %s" % (p, "; ".join(bad)))
    sys.exit(1)

# WHAT THE WIDE SWEEP ASSERTED, not how many files it opened. With no word list it opens all 151 and
# tests nothing, and the first version of this line called that "clean" -- a quiet green printed by the
# gate whose whole job is to stop one.
print("\ncheck_prose: %d file(s) clean, %s" % (len(rows),
    "%d more clean on the wide sweep" % wide_read if WIDE_TOKENS
    else "and the wide sweep ASSERTED NOTHING (no word list; %d file(s) read, 0 words tested)" % wide_read))
PYEOF
