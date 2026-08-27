#!/usr/bin/env python3
"""ANVIL step 2c. Referential integrity across the whole event log. `docs/QUALITY.md`-shaped: a
structural check, run against every event in `.anvil/log/`, not a single event's own shape (that's
`schema.validate_event`, which this script also calls per event -- a log full of individually-valid
events can still be referentially broken, and a single corrupt event is still worth naming precisely).

    python3 tools/anvil/check_integrity.py

What "referential integrity" means here, concretely, per `incoming/ANVIL_ARCHITECTURE.md` §3
("Referential integrity, enforced in CI") and the typed-reference table an external audit found this
module needed (`docs/DECISIONS_LEDGER.md` D0069):
- every event is individually schema-valid (`schema.validate_event`, including UUID shape and self-
  reference, which need no cross-event lookup and live there)
- no two events share an `id`
- every reference (`supersedes`, `MEASUREMENT.claim_id`, `FINDING.invalidates`, `CLAIM_AUTHORED.assumes`,
  `CONTENT_LINK.assumes`, `CONTENT_LINK.serves_claims`, `ASSUMPTION.challenged_by`,
  `OVERRIDE.target_event`) resolves to a real event id in the log AND that event's TYPE is in the field's
  legal-target set (`schema.REFERENCE_FIELDS`/`schema.SUPERSEDES_LEGAL_TARGETS`) -- a `claim_id` pointing
  at a real event that happens to be a `DECISION`, not a `CLAIM_AUTHORED`, is exactly as wrong as pointing
  at nothing, and is now caught the same way
- `CONTENT_LINK.path` resolves to a real file in the working tree, not just a plausible-looking string

**Known scope, stated here so an absence is a documented limit, not an undetected gap:**
- **`supersedes`-cycle detection is NOT implemented.** Two events superseding each other (or a longer
  cycle) pass today. This needs graph traversal over the whole supersession chain, which is the same
  machinery the `graph`/`suspect` projections (step 4) will need anyway -- deferred to land once, there,
  rather than duplicated here first and reconciled later.
- **`commit` field existence against real git history is NOT verified.** `append.py` always writes a real
  `git rev-parse HEAD` output, but a hand-authored or migrated event can name any nonempty string and pass.
  Resolving this means shelling out to `git cat-file -e <sha>` per event, which is correct but slow at log
  scale and deserves its own decision about when/how often to pay that cost, not a default added quietly.
- **Timestamp ordering is NOT checked.** Events are processed in filename-sort order today
  (`load_events`'s `sorted(log_dir.glob("*.json"))`), which happens to match creation order because
  `append.py` embeds the timestamp in the filename -- but nothing verifies a hand-authored or migrated
  event's `timestamp` field agrees with its filename, or that the log is free of out-of-order entries.
  Real event ordering semantics (does order matter for resolution, and if so which order) is a step-4
  projection question, not something this checker should decide unilaterally.

Each finding is reported with the specific event file it came from -- "a claim whose assumes[] names an
unknown assumption fails the build" (architecture doc) is only useful in CI if it also says WHICH claim.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from schema import iter_reference_targets, validate_event  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_LOG_DIR = ROOT / ".anvil" / "log"


def load_events(log_dir: Path) -> list[tuple[Path, dict]]:
    events = []
    for path in sorted(log_dir.glob("*.json")):
        try:
            events.append((path, json.loads(path.read_text(encoding="utf-8"))))
        except json.JSONDecodeError as exc:
            events.append((path, {"_unparseable": str(exc)}))
    return events


def check_integrity(log_dir: Path) -> tuple[list[str], int]:
    """Return (errors, event_count). Pure function of what's on disk under log_dir -- no global state,
    so test_check_integrity.py can point it at a scratch directory per mutation case without touching the
    real .anvil/log/. event_count is returned alongside errors so a caller can distinguish "0 events,
    nothing validated" from "N events, all valid" -- the same number, "PASS", used to mean both, which is
    exactly the vacuous-empty-success class this project's own retrospective documents (D0072).
    """
    errors: list[str] = []
    events = load_events(log_dir)

    ids_seen: dict[str, Path] = {}
    id_to_type: dict[str, str] = {}
    for path, event in events:
        if "_unparseable" in event:
            errors.append(f"{path.name}: not valid JSON ({event['_unparseable']})")
            continue
        event_id = event.get("id")
        if event_id:
            id_to_type[event_id] = event.get("type")

    for path, event in events:
        if "_unparseable" in event:
            continue

        for schema_error in validate_event(event):
            errors.append(f"{path.name}: {schema_error}")

        event_id = event.get("id")
        if event_id:
            if event_id in ids_seen:
                errors.append(f"{path.name}: duplicate id {event_id!r}, already used by "
                               f"{ids_seen[event_id].name}")
            else:
                ids_seen[event_id] = path

        for field, ref_id, legal_targets in iter_reference_targets(event):
            if ref_id not in id_to_type:
                errors.append(f"{path.name}: {field} references unknown event id {ref_id!r}")
            elif id_to_type[ref_id] not in legal_targets:
                errors.append(f"{path.name}: {field} references {ref_id!r}, which is a "
                               f"{id_to_type[ref_id]}, not one of the legal target types {legal_targets}")

        if event.get("type") == "CONTENT_LINK":
            content_path = event.get("path")
            if content_path and not (ROOT / content_path).exists():
                errors.append(f"{path.name}: CONTENT_LINK.path {content_path!r} does not exist in the "
                               f"working tree")

    return errors, len(events)


def main() -> int:
    if not DEFAULT_LOG_DIR.is_dir() or not any(DEFAULT_LOG_DIR.glob("*.json")):
        print("check_integrity: 0 events in .anvil/log/ -- bootstrap state, not evaluated as healthy or "
              "unhealthy, since there was nothing to check.")
        return 0

    errors, count = check_integrity(DEFAULT_LOG_DIR)
    if errors:
        print(f"check_integrity: FAIL -- {count} event(s) checked, {len(errors)} referential integrity "
              f"error(s):")
        for error in errors:
            print(f"  {error}")
        return 1

    print(f"check_integrity: PASS -- {count} event(s) checked, referentially sound.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
