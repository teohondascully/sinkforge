#!/usr/bin/env python3
"""ANVIL step 2c. Referential integrity across the whole event log. `docs/QUALITY.md`-shaped: a
structural check, run against every event in `.anvil/log/`, not a single event's own shape (that's
`schema.validate_event`, which this script also calls per event -- a log full of individually-valid
events can still be referentially broken, and a single corrupt event is still worth naming precisely).

    python3 tools/anvil/check_integrity.py

What "referential integrity" means here, concretely, per `incoming/ANVIL_ARCHITECTURE.md` §3
("Referential integrity, enforced in CI"):
- every event is individually schema-valid (`schema.validate_event`)
- no two events share an `id`
- `supersedes` (universal, optional) resolves to a real event id if present
- `FINDING.invalidates`, `CLAIM_AUTHORED.assumes`, `CONTENT_LINK.assumes` each resolve every id they name
- `OVERRIDE.target_event` resolves to a real event id
- `CONTENT_LINK.path` resolves to a real file in the working tree, not just a plausible-looking string

Each finding is reported with the specific event file it came from -- "a claim whose assumes[] names an
unknown assumption fails the build" (architecture doc) is only useful in CI if it also says WHICH claim.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from schema import validate_event  # noqa: E402

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


def check_integrity(log_dir: Path) -> list[str]:
    """Return a list of error strings; empty means the log is referentially sound. Pure function of
    what's on disk under log_dir -- no global state, so test_check_integrity.py can point it at a
    scratch directory per mutation case without touching the real .anvil/log/.
    """
    errors: list[str] = []
    events = load_events(log_dir)

    ids_seen: dict[str, Path] = {}
    all_ids: set[str] = set()
    for path, event in events:
        if "_unparseable" in event:
            errors.append(f"{path.name}: not valid JSON ({event['_unparseable']})")
            continue
        event_id = event.get("id")
        if event_id:
            all_ids.add(event_id)

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

        supersedes = event.get("supersedes")
        if supersedes and supersedes not in all_ids:
            errors.append(f"{path.name}: supersedes unknown event id {supersedes!r}")

        target_event = event.get("target_event")
        if target_event and target_event not in all_ids:
            errors.append(f"{path.name}: target_event references unknown event id {target_event!r}")

        for field in ("invalidates", "assumes"):
            for ref_id in event.get(field, None) or []:
                if ref_id not in all_ids:
                    errors.append(f"{path.name}: {field}[] references unknown event id {ref_id!r}")

        if event.get("type") == "CONTENT_LINK":
            content_path = event.get("path")
            if content_path and not (ROOT / content_path).exists():
                errors.append(f"{path.name}: CONTENT_LINK.path {content_path!r} does not exist in the "
                               f"working tree")

    return errors


def main() -> int:
    if not DEFAULT_LOG_DIR.is_dir() or not any(DEFAULT_LOG_DIR.glob("*.json")):
        print("check_integrity: PASS -- no events in .anvil/log/ yet, nothing to check.")
        return 0

    errors = check_integrity(DEFAULT_LOG_DIR)
    if errors:
        print(f"check_integrity: FAIL -- {len(errors)} referential integrity error(s):")
        for error in errors:
            print(f"  {error}")
        return 1

    print(f"check_integrity: PASS -- {len(list(DEFAULT_LOG_DIR.glob('*.json')))} event(s), "
          f"referentially sound.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
