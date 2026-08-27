#!/usr/bin/env python3
"""ANVIL step 2b. Append one event to the log. `.anvil/log/<iso8601>-<uuid8>.json`, per
`incoming/ANVIL_ARCHITECTURE.md` §3. One event per file, immutable -- this tool only ever creates a new
file, never edits or deletes an existing one.

    python3 tools/anvil/append.py TYPE --author=NAME --data='{"statement": "...", ...}'
    python3 tools/anvil/append.py TYPE --author=NAME --data-file=path/to/payload.json

`--data`/`--data-file` supplies exactly the type's OWN fields (schema.EVENT_TYPES[TYPE]) -- never `id`,
`timestamp`, `commit`, or `author`, which this tool derives itself (`id`: uuid4; `timestamp`: UTC
ISO 8601, now; `commit`: `git rev-parse HEAD`; `author`: the required `--author` flag, not inferred, on
the same "state it or error" principle as `MEASUREMENT.source` and `FINDING.independent_of` -- there is
no environment variable or default identity for this tool to guess from). `--supersedes=EVENT_ID` sets
the one universal optional field.

Deliberately no `--force`/`--skip-validation` escape hatch: a payload that fails `schema.validate_event`
is not written, full stop. Referential integrity (does a `supersedes`/`invalidates`/`assumes` id
actually exist) is `check_integrity.py`'s job, checked across the whole log, not here -- this tool cannot
know at append time whether a forward reference will resolve, since nothing requires the target event to
already exist.
"""
import argparse
import json
import subprocess
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from schema import EVENT_TYPES, validate_event  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
LOG_DIR = ROOT / ".anvil" / "log"


def _current_commit() -> str:
    result = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        return "UNKNOWN"
    return result.stdout.strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("type", choices=sorted(EVENT_TYPES), help="one of the seven event types")
    parser.add_argument("--author", required=True, help="session id, human name, or instrument name -- required, not inferred")
    parser.add_argument("--data", help="JSON object with the event's own fields (not id/timestamp/commit/author)")
    parser.add_argument("--data-file", help="path to a JSON file, same content as --data")
    parser.add_argument("--supersedes", default=None, help="id of the event this one supersedes, if any")
    args = parser.parse_args()

    if bool(args.data) == bool(args.data_file):
        print("anvil append: FAIL -- pass exactly one of --data or --data-file")
        return 1

    payload_text = args.data if args.data else Path(args.data_file).read_text(encoding="utf-8")
    try:
        payload = json.loads(payload_text)
    except json.JSONDecodeError as exc:
        print(f"anvil append: FAIL -- --data/--data-file is not valid JSON: {exc}")
        return 1

    for reserved in ("id", "timestamp", "commit", "author", "type", "supersedes"):
        if reserved in payload:
            print(f"anvil append: FAIL -- {reserved!r} is derived by this tool, not part of --data")
            return 1

    event = dict(payload)
    event["type"] = args.type
    event["id"] = str(uuid.uuid4())
    event["timestamp"] = datetime.now(timezone.utc).isoformat()
    event["author"] = args.author
    event["commit"] = _current_commit()
    if args.supersedes:
        event["supersedes"] = args.supersedes

    errors = validate_event(event)
    if errors:
        print(f"anvil append: FAIL -- {len(errors)} validation error(s), nothing written:")
        for error in errors:
            print(f"  {error}")
        return 1

    LOG_DIR.mkdir(parents=True, exist_ok=True)
    ts_for_filename = event["timestamp"].replace("+00:00", "Z").replace(":", "")
    filename = f"{ts_for_filename}-{event['id'][:8]}.json"
    out_path = LOG_DIR / filename
    out_path.write_text(json.dumps(event, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print(f"anvil append: PASS -- wrote {out_path.relative_to(ROOT)} (id {event['id']})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
