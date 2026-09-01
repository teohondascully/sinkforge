#!/usr/bin/env python3
"""Mutation tests for tools/formatter/formatter.py.

Same discipline as every other gate's test file in this repository (`docs/QUALITY.md` §2: "a check that
has never been observed failing is not a check"): each rule gets a positive control (it fires on a
violation), a negative control (it does not fire on clean input), and the edge cases that would let a
broken implementation pass silently. The formatter is also tested against ITSELF -- `docs/QUALITY.md`
§2's own load-bearing rule: "where a gate measures a property of the codebase, the gate is itself part
of the codebase and is not exempt from its own property."

    python3 tools/formatter/test_formatter.py

Synthetic fixtures throughout for the pure-function tests (no git, no real tree). The self-inclusion
and exit-code branches use the real repository, the same way `test_quality_check.py`'s
`branch_find_gd_files_reaches_whole_tree` and `branch_dashboard_runs_end_to_end` do.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import formatter as F  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "layer_lint"))
from gate_test_support import Observations  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]

LOG = Observations("test_formatter")


# --- charset -----------------------------------------------------------------------------------------

def branch_charset() -> None:
    bom_crlf = "\ufeffvar x := 1\r\nvar y := 2\r\n"
    fixed, fired, _ = F.format_text(bom_crlf, "gd")
    LOG.observe("charset: BOM stripped and CRLF rewritten to LF",
          fixed == "var x := 1\nvar y := 2\n", detail=repr(fixed))
    LOG.observe("charset: the rule is reported as fired", "charset" in fired, detail=str(fired))

    bare_cr = "var x := 1\rvar y := 2\n"
    fixed2, _, _ = F.format_text(bare_cr, "gd")
    LOG.observe("charset: bare CR also rewritten to LF", fixed2 == "var x := 1\nvar y := 2\n",
          detail=repr(fixed2))

    clean = "var x := 1\nvar y := 2\n"
    fixed3, fired3, _ = F.format_text(clean, "gd")
    LOG.observe("charset: already-clean text is not changed", fixed3 == clean and "charset" not in fired3)


# --- trailing whitespace -----------------------------------------------------------------------------

def branch_trailing_whitespace() -> None:
    dirty = "var x := 1   \nvar y := 2\t\n"
    fixed, fired, _ = F.format_text(dirty, "gd")
    LOG.observe("trailing-ws: trailing spaces and tabs stripped from code lines",
          fixed == "var x := 1\nvar y := 2\n", detail=repr(fixed))
    LOG.observe("trailing-ws: reported as fired", "trailing-whitespace" in fired)

    clean = "var x := 1\nvar y := 2\n"
    _, fired2, _ = F.format_text(clean, "gd")
    LOG.observe("trailing-ws: clean text not changed", "trailing-whitespace" not in fired2)

    # The string-awareness property: trailing whitespace inside a multi-line literal is DATA, not noise.
    src = 'var s := """keep   \nthese   \n"""\nvar y := 2   \n'
    fixed3, _, _ = F.format_text(src, "gd")
    LOG.observe("trailing-ws: trailing spaces inside a triple-quoted literal are PRESERVED",
          fixed3 == 'var s := """keep   \nthese   \n"""\nvar y := 2\n', detail=repr(fixed3))

    # Same property for a single-line string with trailing space before the closing quote.
    single = 'var s := "keep "   \n'
    fixed4, _, _ = F.format_text(single, "gd")
    LOG.observe("trailing-ws: trailing space inside a single-line string is preserved, space AFTER the "
          "string is stripped", fixed4 == 'var s := "keep "\n', detail=repr(fixed4))


# --- blank run ---------------------------------------------------------------------------------------

def branch_blank_run() -> None:
    dirty = "func a():\n\tpass\n\n\n\n\nfunc b():\n\tpass\n"
    fixed, fired, _ = F.format_text(dirty, "gd")
    LOG.observe("blank-run: 4 consecutive blank lines collapsed to 2",
          fixed == "func a():\n\tpass\n\n\nfunc b():\n\tpass\n", detail=repr(fixed))
    LOG.observe("blank-run: reported as fired", "blank-run" in fired)

    two = "func a():\n\tpass\n\n\nfunc b():\n\tpass\n"
    _, fired2, _ = F.format_text(two, "gd")
    LOG.observe("blank-run: exactly 2 blank lines is NOT collapsed (2 is the ceiling, not a violation)",
          "blank-run" not in fired2)

    # The `inside` flag: blank lines inside a triple-quoted literal are not "blank lines between
    # functions" and must survive. This is the property that keeps a module docstring intact.
    py_doc = '"""doc\n\n\n\n\nend"""\nx = 1\n'
    fixed3, _, _ = F.format_text(py_doc, "py")
    LOG.observe("blank-run: blank lines inside a triple-quoted literal are NOT collapsed",
          fixed3 == py_doc, detail=repr(fixed3))

    # Text ruleset: .sh/.yml/.yaml do NOT get blank-run collapse.
    text_dirty = "a:\n\n\n\n  b: 1\n"
    fixed4, fired4, _ = F.format_text(text_dirty, "text")
    LOG.observe("blank-run: text ruleset does NOT collapse blank runs",
          fixed4 == text_dirty and "blank-run" not in fired4, detail=repr(fixed4))


# --- file edges --------------------------------------------------------------------------------------

def branch_file_edges() -> None:
    dirty = "\n\nfunc a():\n\tpass\n\n\n"
    fixed, fired, _ = F.format_text(dirty, "gd")
    LOG.observe("file-edges: blank lines at BOF and EOF stripped, exactly one final newline",
          fixed == "func a():\n\tpass\n", detail=repr(fixed))
    LOG.observe("file-edges: reported as fired", "file-edges" in fired)

    clean = "func a():\n\tpass\n"
    _, fired2, _ = F.format_text(clean, "gd")
    LOG.observe("file-edges: already-clean text not changed", "file-edges" not in fired2)

    no_final_nl = "var x := 1"
    fixed3, fired3, _ = F.format_text(no_final_nl, "gd")
    LOG.observe("file-edges: missing final newline added", fixed3 == "var x := 1\n" and
          "file-edges" in fired3, detail=repr(fixed3))

    empty = ""
    fixed4, _, _ = F.format_text(empty, "gd")
    LOG.observe("file-edges: empty file stays empty (not a single newline)", fixed4 == "",
          detail=repr(fixed4))

    # Blank line inside a literal at BOF must survive (the `inside` flag again, from the other end).
    py_literal_bof = '"""\n\nbody\n"""\nx = 1\n'
    fixed5, _, _ = F.format_text(py_literal_bof, "py")
    LOG.observe("file-edges: blank line at BOF inside a literal is NOT stripped",
          fixed5 == py_literal_bof, detail=repr(fixed5))


# --- indent ------------------------------------------------------------------------------------------

def branch_indent_gd_spaces_to_tabs() -> None:
    dirty = "func a():\n        return 1\n"
    fixed, fired, _ = F.format_text(dirty, "gd")
    LOG.observe("indent (gd): 8 spaces (2 levels) converted to 2 tabs",
          fixed == "func a():\n\t\treturn 1\n", detail=repr(fixed))
    LOG.observe("indent (gd): reported as fired", "indent" in fired)

    clean = "func a():\n\treturn 1\n"
    _, fired2, _ = F.format_text(clean, "gd")
    LOG.observe("indent (gd): already-tabbed text not changed", "indent" not in fired2)


def branch_indent_py_tabs_to_spaces() -> None:
    dirty = "def a():\n\treturn 1\n"
    fixed, fired, _ = F.format_text(dirty, "py")
    LOG.observe("indent (py): 1 tab converted to 4 spaces",
          fixed == "def a():\n    return 1\n", detail=repr(fixed))
    LOG.observe("indent (py): reported as fired", "indent" in fired)

    clean = "def a():\n    return 1\n"
    _, fired2, _ = F.format_text(clean, "py")
    LOG.observe("indent (py): already-spaced text not changed", "indent" not in fired2)


def branch_indent_wrapped_trailing_comment() -> None:
    """The eight real lines this exemption protects (module docstring). A naive spaces-to-tabs pass
    corrupts every one of them; the exemption is what prevents that."""
    aligned = (
        "var dig := false   ## true only on the tick the button\n"
        "                   ## transitioned to held\n"
    )
    fixed, fired, _ = F.format_text(aligned, "gd")
    LOG.observe("indent (gd): wrapped trailing comment (spaces aligned to a column) is NOT converted to "
          "tabs", fixed == aligned and "indent" not in fired, detail=repr(fixed))

    # Negative control: a comment-only line indented with spaces whose PREVIOUS line has NO trailing
    # comment is NOT a wrapped trailing comment -- it is a standalone indented comment and the
    # exemption does not apply. But since it IS a comment-only line with spaces, and the indent rule
    # only converts whole-multiple-of-4 space groups, a 19-space indent (not a multiple of 4) would
    # be refused. A 20-space indent (5 levels) WOULD be converted to tabs. Test the 20-space case to
    # prove the exemption is specifically about the trailing-comment relationship, not about
    # comment-only lines in general.
    standalone_comment = "func a():\n                    ## standalone comment\n\tpass\n"
    fixed2, fired2, _ = F.format_text(standalone_comment, "gd")
    # 20 spaces = 5 levels of 4 → 5 tabs. The comment is NOT exempt (previous line has no trailing
    # comment), so it IS converted.
    LOG.observe("indent (gd): a standalone comment indented with 20 spaces (5 levels, no trailing comment "
          "above) IS converted to tabs -- the exemption is about the trailing-comment relationship, "
          "not about comment-only lines in general",
          fixed2 == "func a():\n\t\t\t\t\t## standalone comment\n\tpass\n" and "indent" in fired2,
          detail=repr(fixed2))


def branch_indent_mixed_refused() -> None:
    """The tool refuses rather than guesses. Mixed tabs and spaces, or a space count not a multiple of
    4, is reported with its line number and left exactly as it is."""
    mixed = "func a():\n\t   return 1\n"
    fixed, fired, errors = F.format_text(mixed, "gd", "test.gd")
    LOG.observe("indent (gd): mixed tab+space indentation is NOT rewritten", fixed == mixed,
          detail=repr(fixed))
    LOG.observe("indent (gd): mixed indentation IS reported as an error", len(errors) == 1,
          detail=str(errors))
    LOG.observe("indent (gd): the error names the file and line number", "test.gd:2" in errors[0],
          detail=str(errors))

    # A space count that is not a multiple of 4 is also refused, not guessed.
    non_multiple = "func a():\n     return 1\n"  # 5 spaces
    fixed2, _, errors2 = F.format_text(non_multiple, "gd", "test.gd")
    LOG.observe("indent (gd): 5 spaces (not a multiple of 4) is refused, not guessed",
          fixed2 == non_multiple and len(errors2) == 1, detail=repr(fixed2))

    # Python: tabs are always wrong (every tab count is refused), but spaces are always right.
    py_tab = "def a():\n\t\treturn 1\n"
    fixed3, fired3, _ = F.format_text(py_tab, "py")
    LOG.observe("indent (py): 2 tabs converted to 8 spaces",
          fixed3 == "def a():\n        return 1\n" and "indent" in fired3, detail=repr(fixed3))


# --- comment space -----------------------------------------------------------------------------------

def branch_comment_space() -> None:
    dirty = "var x := 1  #foo\n"
    fixed, fired, _ = F.format_text(dirty, "gd")
    LOG.observe("comment-space: #foo becomes # foo", fixed == "var x := 1  # foo\n",
          detail=repr(fixed))
    LOG.observe("comment-space: reported as fired", "comment-space" in fired)

    # ## doc comments keep both marks.
    doc = "##doc\n"
    fixed2, _, _ = F.format_text(doc, "gd")
    LOG.observe("comment-space: ##doc becomes ## doc (both marks kept, space added)",
          fixed2 == "## doc\n", detail=repr(fixed2))

    # A line of nothing but # is a separator, left alone.
    sep = "#####\n"
    fixed3, _, _ = F.format_text(sep, "gd")
    LOG.observe("comment-space: ##### separator is left alone", fixed3 == "#####\n",
          detail=repr(fixed3))

    # Shebang at column 0 is left alone.
    shebang = "#!/usr/bin/env python3\nx = 1\n"
    fixed4, _, _ = F.format_text(shebang, "py")
    LOG.observe("comment-space: #! shebang is left alone", fixed4 == shebang, detail=repr(fixed4))

    # #region/#endregion are left alone.
    region = "#region grid\n#endregion\n"
    fixed5, _, _ = F.format_text(region, "gd")
    LOG.observe("comment-space: #region/#endregion are left alone", fixed5 == region,
          detail=repr(fixed5))

    # The critical string-awareness property: a # inside a string literal is NOT a comment. This tree
    # has GDScript fixtures with ASCII-art grids full of lines like "#....####",.
    art = 'var rows := [\n\t"#....####",\n\t"#########",\n]\n'
    fixed6, _, _ = F.format_text(art, "gd")
    LOG.observe("comment-space: # inside a string literal is NOT treated as a comment (ASCII-art fixture)",
          fixed6 == art, detail=repr(fixed6))

    # Already correct: # foo (with space) is not changed.
    clean = "var x := 1  # foo\n"
    _, fired7, _ = F.format_text(clean, "gd")
    LOG.observe("comment-space: already-correct # foo not changed", "comment-space" not in fired7)


# --- scan -------------------------------------------------------------------------------------------

def branch_scan_hash_in_literal() -> None:
    """The scan function must classify a # inside a string literal as `s` (string), not `#` (comment).
    This is the property that keeps the ASCII-art fixtures and the comment-space rule from corrupting
    string content."""
    text = 'var s := "#not a comment"\n'
    masks, _ = F.scan(text)
    line = text.split("\n")[0]
    line_mask = masks[0]
    hash_idx = line.index("#")
    LOG.observe("scan: # inside a single-line string is classified as string, not comment",
          line_mask[hash_idx] == "s", detail=line_mask)

    text2 = 'var s := """\n#not a comment\n"""\n'
    masks2, inside2 = F.scan(text2)
    LOG.observe("scan: # inside a multi-line string is classified as string",
          masks2[1].startswith("s"), detail=masks2[1])
    LOG.observe("scan: the line after the opening triple-quote is marked as inside a literal",
          inside2[1] is True, detail=str(inside2))


def branch_scan_mask_length() -> None:
    """Every mask line must be the same length as its source line, or the whole tool's column-level
    reasoning is wrong. This is the alignment assertion in scan() itself, tested here explicitly."""
    text = 'var s := "hello"\nvar x := 1  # comment\n\n\t"tabbed"\n'
    masks, _ = F.scan(text)
    lines = text.split("\n")
    for i, (line, mask) in enumerate(zip(lines, masks)):
        LOG.observe(f"scan: mask line {i} matches source line {i} length",
              len(mask) == len(line), detail=f"mask={len(mask)} line={len(line)}")


# --- idempotence -------------------------------------------------------------------------------------

def branch_idempotence() -> None:
    """format_text applies the pipeline twice and raises Unstable if the second pass changes anything.
    A formatter whose output is not its own fixed point turns --check into a coin flip."""
    # A realistic GDScript snippet with several violations: the first pass fixes them, the second
    # must be a no-op.
    dirty = (
        "func a():\n"
        "        var x := 1   #missing space\n"
        "\n\n\n\n"
        "func b():\n"
        "\tpass\n"
        "\n\n"
    )
    once, fired, errors = F.format_text(dirty, "gd")
    twice, fired2, errors2 = F.format_text(once, "gd")
    LOG.observe("idempotence: a second pass over the first pass's output changes nothing",
          twice == once, detail=f"first fired {fired}, second fired {fired2}")
    LOG.observe("idempotence: the second pass reports no rules fired", fired2 == [],
          detail=str(fired2))
    LOG.observe("idempotence: no errors on either pass", errors == [] and errors2 == [])


def branch_instability_detected() -> None:
    """If a rule's output is not a fixed point, format_text must raise Unstable rather than return a
    result that a second run would contradict. This is tested by replacing RULES with a single
    toggling rule -- the exact failure mode the idempotence check exists to catch. A single-rule
    pipeline is used so no later rule can undo the toggle and mask the instability."""
    original_rules = F.RULES

    call_count = [0]
    def toggling(text, lang, rel):
        call_count[0] += 1
        # Alternate between two states that no other rule would touch, so the instability is
        # visible to format_text's second-pass comparison rather than being silently undone.
        if call_count[0] % 2 == 1:
            return text.replace("x", "y", 1), []
        return text.replace("y", "x", 1), []

    F.RULES = (("toggle", toggling),)
    try:
        raised = False
        try:
            F.format_text("var x := 1\n", "gd", "test.gd")
        except F.Unstable:
            raised = True
        LOG.observe("idempotence: Unstable is raised when a rule's output is not a fixed point",
              raised, detail="no exception was raised")
    finally:
        F.RULES = original_rules


# --- text ruleset ------------------------------------------------------------------------------------

def branch_text_ruleset() -> None:
    """The text ruleset (.sh/.yml/.yaml) gets only the four byte-level rules. No blank-run collapse,
    no indent conversion, no comment-space. This is because a YAML block scalar or a shell heredoc
    carries indentation this tool has no grammar for and should not be guessing about."""
    yaml_with_blank_run = "a:\n\n\n\n  b: 1\n  c: 2\n"
    fixed, fired, _ = F.format_text(yaml_with_blank_run, "text")
    LOG.observe("text ruleset: blank runs NOT collapsed", "blank-run" not in fired and fixed == yaml_with_blank_run,
          detail=repr(fixed))

    yaml_with_indent = "a:\n    b: 1\n"
    fixed2, fired2, _ = F.format_text(yaml_with_indent, "text")
    LOG.observe("text ruleset: indent NOT converted", "indent" not in fired2 and fixed2 == yaml_with_indent,
          detail=repr(fixed2))

    # But byte-level rules DO fire: trailing whitespace is stripped, final newline is added.
    yaml_trailing = "a: 1   \nb: 2"
    fixed3, fired3, _ = F.format_text(yaml_trailing, "text")
    LOG.observe("text ruleset: trailing whitespace IS stripped and final newline IS added",
          fixed3 == "a: 1\nb: 2\n" and "trailing-whitespace" in fired3 and "file-edges" in fired3,
          detail=repr(fixed3))


# --- self-inclusion ----------------------------------------------------------------------------------

def branch_self_inclusion() -> None:
    """QUALITY.md §2: "where a gate measures a property of the codebase, the gate is itself part of the
    codebase and is not exempt from its own property." The formatter must discover its own source
    file in its own population, and that file must already pass its own formatting check."""
    population = F.discover(ROOT)
    rels = {rel.as_posix() for rel, _ in population}

    LOG.observe("self-inclusion: formatter.py is in the discovered population",
          "tools/formatter/formatter.py" in rels, detail="not in population")
    LOG.observe("self-inclusion: test_formatter.py is in the discovered population",
          "tools/formatter/test_formatter.py" in rels, detail="not in population")

    # The formatter's own source must pass its own formatting check. This is the ultimate
    # self-inclusion test: a formatter that cannot format itself is not a formatter.
    src = (ROOT / "tools/formatter/formatter.py").read_text(encoding="utf-8")
    formatted, fired, errors = F.format_text(src, "py", "tools/formatter/formatter.py")
    LOG.observe("self-inclusion: formatter.py passes its own formatting check (0 rules fired, 0 errors)",
          formatted == src and fired == [] and errors == [],
          detail=f"fired={fired}, errors={errors}")

    # Same for the test file itself.
    test_src = (ROOT / "tools/formatter/test_formatter.py").read_text(encoding="utf-8")
    formatted2, fired2, errors2 = F.format_text(test_src, "py", "tools/formatter/test_formatter.py")
    LOG.observe("self-inclusion: test_formatter.py passes its own formatting check",
          formatted2 == test_src and fired2 == [] and errors2 == [],
          detail=f"fired={fired2}, errors={errors2}")

    # The README is NOT in the population (it's .md, not in scope), which is correct.
    LOG.observe("self-inclusion: README.md is NOT in the population (out of scope by extension)",
          "tools/formatter/README.md" not in rels)


# --- run / exit codes --------------------------------------------------------------------------------

def _init_scratch(root: Path) -> None:
    subprocess.run(["git", "init", "-q"], cwd=root, check=True)
    subprocess.run(["git", "config", "user.email", "scratch@test"], cwd=root, check=True)
    subprocess.run(["git", "config", "user.name", "scratch"], cwd=root, check=True)
    (root / ".gitignore").write_text("scratch/\n", encoding="utf-8")


def branch_run_clean() -> None:
    """A scratch repo with only clean files exits 0."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _init_scratch(root)
        (root / "core").mkdir()
        (root / "core" / "clean.gd").write_text("func a():\n\tpass\n", encoding="utf-8")
        (root / "tools").mkdir()
        (root / "tools" / "clean.py").write_text("x = 1\n", encoding="utf-8")
        exit_code = F.run(root, write=False, only=[])
        LOG.observe("run: clean tree exits 0", exit_code == 0, detail=f"exit={exit_code}")


def branch_run_violations_check() -> None:
    """A scratch repo with violations, in --check mode, exits 1 and changes nothing."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _init_scratch(root)
        (root / "core").mkdir()
        dirty_gd = "func a():\n\tpass\n\n\n\n\n"
        (root / "core" / "dirty.gd").write_text(dirty_gd, encoding="utf-8")
        original = (root / "core" / "dirty.gd").read_text()
        exit_code = F.run(root, write=False, only=[])
        LOG.observe("run: violations in --check mode exit 1", exit_code == 1, detail=f"exit={exit_code}")
        LOG.observe("run: --check mode does NOT modify the file",
              (root / "core" / "dirty.gd").read_text() == original, detail="file was modified")


def branch_run_violations_write() -> None:
    """A scratch repo with violations, in --write mode, exits 0 and fixes the file."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _init_scratch(root)
        (root / "core").mkdir()
        dirty_gd = "func a():\n\tpass\n\n\n\n\n"
        (root / "core" / "dirty.gd").write_text(dirty_gd, encoding="utf-8")
        exit_code = F.run(root, write=True, only=[])
        LOG.observe("run: --write mode exits 0 after fixing", exit_code == 0, detail=f"exit={exit_code}")
        fixed = (root / "core" / "dirty.gd").read_text()
        LOG.observe("run: --write mode actually fixed the file",
              fixed == "func a():\n\tpass\n", detail=repr(fixed))
        # A second run in --check mode must now exit 0 (idempotence at the file level).
        exit_code2 = F.run(root, write=False, only=[])
        LOG.observe("run: after --write, a --check run exits 0 (file-level idempotence)",
              exit_code2 == 0, detail=f"exit={exit_code2}")


def branch_run_void_empty() -> None:
    """An empty population exits 2 (VOID), never 0 -- "I could not compare" and "nothing was wrong"
    must not look alike. Per docs/QUALITY.md §2."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _init_scratch(root)
        exit_code = F.run(root, write=False, only=[])
        LOG.observe("run: empty population exits 2 (VOID)", exit_code == 2, detail=f"exit={exit_code}")


def branch_run_refused_indent() -> None:
    """A file with mixed indentation exits 1 in --check mode (the tool refuses to guess), and the file
    is NOT modified even in --write mode."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _init_scratch(root)
        (root / "core").mkdir()
        mixed = "func a():\n\t   return 1\n"
        (root / "core" / "mixed.gd").write_text(mixed, encoding="utf-8")
        exit_code = F.run(root, write=False, only=[])
        LOG.observe("run: mixed indentation exits 1 in --check mode", exit_code == 1,
              detail=f"exit={exit_code}")
        # Even --write does not fix the refused indentation.
        exit_code2 = F.run(root, write=True, only=[])
        LOG.observe("run: --write does NOT fix refused indentation (still exits 1)",
              exit_code2 == 1, detail=f"exit={exit_code2}")
        LOG.observe("run: the file with mixed indent is NOT modified by --write",
              (root / "core" / "mixed.gd").read_text() == mixed, detail="file was modified")


def branch_run_path_filter() -> None:
    """The `paths` argument limits the population to the named files."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _init_scratch(root)
        (root / "core").mkdir()
        (root / "core" / "clean.gd").write_text("func a():\n\tpass\n", encoding="utf-8")
        (root / "core" / "dirty.gd").write_text("func a():\n\tpass\n\n\n\n\n", encoding="utf-8")
        # Only check the clean file: should exit 0.
        exit_code = F.run(root, write=False, only=["core/clean.gd"])
        LOG.observe("run: path filter limits to the named file (clean file → exit 0)",
              exit_code == 0, detail=f"exit={exit_code}")
        # Only check the dirty file: should exit 1.
        exit_code2 = F.run(root, write=False, only=["core/dirty.gd"])
        LOG.observe("run: path filter limits to the named file (dirty file → exit 1)",
              exit_code2 == 1, detail=f"exit={exit_code2}")


# --- discover scope ----------------------------------------------------------------------------------

def branch_discover_excludes_legacy() -> None:
    """legacy/ is excluded from the .gd population (same as check_size_limits.py and duplication.py).
    A .gd file under legacy/ must NOT appear in the discovered population."""
    population = F.discover(ROOT)
    rels = {rel.as_posix() for rel, _ in population}
    legacy_files = [r for r in rels if r.startswith("legacy/")]
    LOG.observe("discover: no .gd file under legacy/ is in the population",
          len(legacy_files) == 0, detail=str(legacy_files[:3]))


def branch_discover_includes_generated() -> None:
    """data/<kind>/generated.gd is IN scope on purpose -- the formatter also fails the day the
    generator starts emitting something that is not canonical."""
    population = F.discover(ROOT)
    rels = {rel.as_posix() for rel, _ in population}
    generated = [r for r in rels if r.endswith("generated.gd")]
    LOG.observe("discover: data/*/generated.gd files are in the population",
          len(generated) >= 1, detail=str(generated))


def branch_discover_includes_harness_yml() -> None:
    """harness.yml is in the text-ruleset population (byte-level rules only)."""
    population = F.discover(ROOT)
    rels = {rel.as_posix() for rel, _ in population}
    LOG.observe("discover: .github/workflows/harness.yml is in the population (text ruleset)",
          ".github/workflows/harness.yml" in rels)


# --- main --------------------------------------------------------------------------------------------

def main() -> int:
    branches = (
        branch_charset,
        branch_trailing_whitespace,
        branch_blank_run,
        branch_file_edges,
        branch_indent_gd_spaces_to_tabs,
        branch_indent_py_tabs_to_spaces,
        branch_indent_wrapped_trailing_comment,
        branch_indent_mixed_refused,
        branch_comment_space,
        branch_scan_hash_in_literal,
        branch_scan_mask_length,
        branch_idempotence,
        branch_instability_detected,
        branch_text_ruleset,
        branch_self_inclusion,
        branch_run_clean,
        branch_run_violations_check,
        branch_run_violations_write,
        branch_run_void_empty,
        branch_run_refused_indent,
        branch_run_path_filter,
        branch_discover_excludes_legacy,
        branch_discover_includes_generated,
        branch_discover_includes_harness_yml,
    )
    for branch in branches:
        branch()

    return LOG.summarise()


if __name__ == "__main__":
    sys.exit(main())
