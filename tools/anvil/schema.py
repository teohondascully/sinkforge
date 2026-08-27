"""ANVIL step 2a. The seven event types, their fields, and per-event validation.

Seven is a constraint, not a starting point (`incoming/ANVIL_ARCHITECTURE.md` §3): if an eighth type
seems necessary later, that is a design signal to log and bring to the director, not to add here.

Transcription choices made resolving this module against the architecture doc's own field lists
(`docs/DECISIONS_LEDGER.md` D0064 has the full reasoning, not repeated here):
- `id`, `timestamp`, `author`, `commit` are UNIVERSAL and required on every event; `supersedes` is
  universal and optional. Several types list one or more of these again in their own field list in the
  architecture doc (e.g. CLAIM_AUTHORED lists `id`, DECISION lists `supersedes?`) -- read as emphasis,
  not a second, distinct field, so they are not duplicated here.
- `MEASUREMENT`'s own `commit` mention is the same field as the universal one (the commit the event was
  authored under), not a second field for what commit was measured against.
- `FINDING.independent_of` is defined in architecture doc §5 ("Safeguards"), not §3's summary table;
  folded into FINDING's required fields here because it is load-bearing (D0064, the director's own
  explicit instruction: no default, must be stated).
- `OVERRIDE.author` is the universal `author` field, not a second one.

Two fields are NON-DEFAULTING per the director's explicit instruction: `MEASUREMENT.source` and
`FINDING.independent_of`. "Non-defaulting" is enforced two ways -- both required (same as any other
required field, so an absent value is a validation error, not silently accepted) AND `append.py` contains
no fallback/default logic for either, which `tools/anvil/test_check_integrity.py` asserts directly by
mutation (submitting an event with the field omitted must fail, never silently pass with an inferred
value).

`DECISION` and `FINDING` both carry an optional `narrative` field (the director's own addition): one or
two sentences of why-this-then-that, so the connective tissue lost migrating the prose ledger has
somewhere to live inside the events themselves, rather than becoming a second, separate document.

REFERENCE TYPING, added after an external (Codex) audit found every reference untyped: a string in one
global id namespace, with nothing enforcing that a claim_id points at a CLAIM_AUTHORED, that supersedes
points at a compatible type, or that CONTENT_LINK.serves_claims was even traversed. `REFERENCE_FIELDS`
below is the typed-reference table; `SUPERSEDES_LEGAL_TARGETS` handles `supersedes` separately because its
legal targets depend on the SOURCE event's own type, not a fixed set. `docs/DECISIONS_LEDGER.md` D0069 has
the full reasoning per field, including two fields this module deliberately does NOT treat as references
(`ASSUMPTION.held_by` -- a list of authors/identities, not events; and the general principle that a field
absent from `REFERENCE_FIELDS` is a stated choice, not an oversight).
"""
import re

UNIVERSAL_REQUIRED = ("id", "timestamp", "author", "commit")
UNIVERSAL_OPTIONAL = ("supersedes",)

# Each event type's OWN fields, beyond the universal ones above. "non_defaulting" fields are a subset of
# "required" -- listed separately only so a reader (and test_check_integrity.py) can find them without
# re-deriving which required fields carry the extra "no fallback may ever be written for this" promise.
# "non_empty_list_fields" is a subset of "list_fields": empty is REJECTED, not just non-list rejected --
# used ONLY where an empty list is semantically meaningless (FINDING.evidence: a finding with no evidence
# isn't a finding). Deliberately NOT applied to independent_of, whose empty list IS a valid, meaningful
# statement ("independent of nothing stated") -- D0064's own explicit design, preserved here on purpose,
# not an inconsistency.
EVENT_TYPES = {
    "CLAIM_AUTHORED": {
        "required": ("statement", "threshold", "method", "instrument_class", "decidability", "assumes",
                      "ttl"),
        "optional": (),
        "non_defaulting": (),
        "list_fields": ("assumes",),
        "non_empty_list_fields": (),
    },
    "MEASUREMENT": {
        "required": ("claim_id", "value", "unit", "method", "source", "host", "ttl"),
        "optional": (),
        "non_defaulting": ("source",),
        "list_fields": (),
        "non_empty_list_fields": (),
    },
    "FINDING": {
        "required": ("observation", "evidence", "severity", "confidence", "source_class", "invalidates",
                      "independent_of"),
        "optional": ("narrative",),
        "non_defaulting": ("independent_of",),
        "list_fields": ("evidence", "invalidates", "independent_of"),
        "non_empty_list_fields": ("evidence",),
    },
    "DECISION": {
        "required": ("choice", "alternative", "rationale", "reversal_cost"),
        "optional": ("expiry", "narrative"),
        "non_defaulting": (),
        "list_fields": (),
        "non_empty_list_fields": (),
    },
    "ASSUMPTION": {
        "required": ("statement", "held_by", "challenged_by"),
        "optional": (),
        "non_defaulting": (),
        "list_fields": ("held_by", "challenged_by"),
        "non_empty_list_fields": (),
    },
    "CONTENT_LINK": {
        "required": ("path", "serves_claims", "assumes"),
        "optional": (),
        "non_defaulting": (),
        "list_fields": ("serves_claims", "assumes"),
        "non_empty_list_fields": (),
    },
    "OVERRIDE": {
        "required": ("target_event", "reason", "expiry"),
        "optional": (),
        "non_defaulting": (),
        "list_fields": (),
        "non_empty_list_fields": (),
    },
}

MEASUREMENT_SOURCE_VALUES = ("measured", "inherited", "asserted")

# architecture doc §5's closed set for FINDING.source_class. Also used to validate each entry of
# FINDING.independent_of, since that field names source CLASSES the finding is independent from, not
# event ids -- an easy field to mistake for a reference (it looks like one syntactically) and validate
# the wrong way, which the original implementation did (it checked list-of-strings, nothing more).
SOURCE_CLASS_VALUES = ("human-play", "design-instrument", "artifact-instrument", "trajectory-instrument",
                        "agent-review", "external-audit")

# Typed-reference table. (event_type, field_name) -> (is_list, legal target event types). A field absent
# from this table is either not a reference (ASSUMPTION.held_by: authors, not events) or has no reference
# semantics at all. `supersedes` is handled separately below since its legal targets depend on the event
# carrying it, not a fixed set for the field itself.
REFERENCE_FIELDS = {
    ("MEASUREMENT", "claim_id"): (False, ("CLAIM_AUTHORED",)),
    ("FINDING", "invalidates"): (True, ("CLAIM_AUTHORED", "ASSUMPTION")),
    ("CLAIM_AUTHORED", "assumes"): (True, ("ASSUMPTION",)),
    ("CONTENT_LINK", "assumes"): (True, ("ASSUMPTION",)),
    ("CONTENT_LINK", "serves_claims"): (True, ("CLAIM_AUTHORED",)),
    ("ASSUMPTION", "challenged_by"): (True, ("FINDING",)),
    ("OVERRIDE", "target_event"): (False, ("FINDING", "DECISION")),
}

# supersedes' legal targets, keyed by the SOURCE event's own type. Default is "same type as itself" --
# the one stated exception is architecture doc §8.6 ("A DECISION can supersede an ASSUMPTION"), which a
# same-type-only rule would have wrongly rejected.
SUPERSEDES_LEGAL_TARGETS = {
    "CLAIM_AUTHORED": ("CLAIM_AUTHORED",),
    "MEASUREMENT": ("MEASUREMENT",),
    "FINDING": ("FINDING",),
    "DECISION": ("DECISION", "ASSUMPTION"),
    "ASSUMPTION": ("ASSUMPTION",),
    "CONTENT_LINK": ("CONTENT_LINK",),
    "OVERRIDE": ("OVERRIDE",),
}

_UUID_RE = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")


def _is_valid_uuid(value) -> bool:
    return isinstance(value, str) and bool(_UUID_RE.match(value))


def iter_reference_targets(event: dict):
    """Yield (field_name, ref_id, legal_target_types) for every reference this event carries -- both the
    typed table above and the separately-keyed `supersedes`. Shared by validate_event's self-reference
    check and check_integrity.py's dangling/wrong-type checks, so the two never drift against each other
    about what counts as a reference.
    """
    event_type = event.get("type")

    supersedes = event.get("supersedes")
    if supersedes is not None and event_type in SUPERSEDES_LEGAL_TARGETS:
        yield ("supersedes", supersedes, SUPERSEDES_LEGAL_TARGETS[event_type])

    for (ref_type, field), (is_list, legal_targets) in REFERENCE_FIELDS.items():
        if ref_type != event_type or field not in event:
            continue
        value = event[field]
        if is_list:
            for ref_id in (value or []):
                yield (field, ref_id, legal_targets)
        else:
            if value is not None:
                yield (field, value, legal_targets)


def validate_event(event: dict) -> list[str]:
    """Return a list of validation error strings; empty list means the event is structurally valid.

    Checks ONLY what a single event can tell you about itself: required fields present and non-empty
    where that matters, no unknown fields, list-typed fields actually lists, closed-set fields in their
    set, id/reference fields UUID-shaped, and no reference field pointing at the event's own id.
    Cross-event checks (does a referenced id exist, is its TYPE legal for that field) are
    check_integrity.py's job, not this function's -- a single event cannot know what else is in the log.
    """
    errors = []

    event_type = event.get("type")
    if event_type not in EVENT_TYPES:
        return [f"unknown event type {event_type!r} -- must be one of {sorted(EVENT_TYPES)}"]

    spec = EVENT_TYPES[event_type]
    allowed_fields = set(UNIVERSAL_REQUIRED) | set(UNIVERSAL_OPTIONAL) | {"type"} \
        | set(spec["required"]) | set(spec["optional"])

    for field in UNIVERSAL_REQUIRED:
        if field not in event or event[field] in (None, ""):
            errors.append(f"missing universal required field {field!r}")

    for field in spec["required"]:
        if field not in event or event[field] in (None, ""):
            errors.append(f"missing required field {field!r} for {event_type}")

    for field in spec["list_fields"]:
        if field in event and not isinstance(event[field], list):
            errors.append(f"field {field!r} must be a list for {event_type} (got {type(event[field]).__name__})")

    for field in spec["non_empty_list_fields"]:
        if field in event and isinstance(event[field], list) and len(event[field]) == 0:
            errors.append(f"field {field!r} for {event_type} is present but empty -- an empty list is "
                           f"not a meaningful statement for this field (unlike independent_of, where it "
                           f"deliberately is)")

    for field in event:
        if field not in allowed_fields:
            errors.append(f"unknown field {field!r} for {event_type} -- not in its schema")

    if event_type == "MEASUREMENT" and "source" in event:
        if event["source"] not in MEASUREMENT_SOURCE_VALUES:
            errors.append(f"MEASUREMENT.source must be one of {MEASUREMENT_SOURCE_VALUES}, got "
                           f"{event['source']!r}")

    if event_type == "FINDING":
        if "source_class" in event and event["source_class"] not in SOURCE_CLASS_VALUES:
            errors.append(f"FINDING.source_class must be one of {SOURCE_CLASS_VALUES}, got "
                           f"{event['source_class']!r}")
        for entry in event.get("independent_of", None) or []:
            if entry not in SOURCE_CLASS_VALUES:
                errors.append(f"FINDING.independent_of entry {entry!r} is not one of {SOURCE_CLASS_VALUES}"
                               f" -- independent_of names source CLASSES, not event ids")

    if "id" in event and event["id"] not in (None, "") and not _is_valid_uuid(event["id"]):
        errors.append(f"id {event['id']!r} is not a valid UUID")

    own_id = event.get("id")
    for field, ref_id, _legal_targets in iter_reference_targets(event):
        if not _is_valid_uuid(ref_id):
            errors.append(f"{field} value {ref_id!r} is not a valid UUID")
        elif own_id is not None and ref_id == own_id:
            errors.append(f"{field} references the event's own id -- an event cannot reference itself")

    return errors
