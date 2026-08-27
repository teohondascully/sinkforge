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
"""

UNIVERSAL_REQUIRED = ("id", "timestamp", "author", "commit")
UNIVERSAL_OPTIONAL = ("supersedes",)

# Each event type's OWN fields, beyond the universal ones above. "non_defaulting" fields are a subset of
# "required" -- listed separately only so a reader (and test_check_integrity.py) can find them without
# re-deriving which required fields carry the extra "no fallback may ever be written for this" promise.
EVENT_TYPES = {
    "CLAIM_AUTHORED": {
        "required": ("statement", "threshold", "method", "instrument_class", "decidability", "assumes",
                      "ttl"),
        "optional": (),
        "non_defaulting": (),
        "list_fields": ("assumes",),
    },
    "MEASUREMENT": {
        "required": ("claim_id", "value", "unit", "method", "source", "host", "ttl"),
        "optional": (),
        "non_defaulting": ("source",),
        "list_fields": (),
    },
    "FINDING": {
        "required": ("observation", "evidence", "severity", "confidence", "source_class", "invalidates",
                      "independent_of"),
        "optional": ("narrative",),
        "non_defaulting": ("independent_of",),
        "list_fields": ("evidence", "invalidates", "independent_of"),
    },
    "DECISION": {
        "required": ("choice", "alternative", "rationale", "reversal_cost"),
        "optional": ("expiry", "narrative"),
        "non_defaulting": (),
        "list_fields": (),
    },
    "ASSUMPTION": {
        "required": ("statement", "held_by", "challenged_by"),
        "optional": (),
        "non_defaulting": (),
        "list_fields": ("held_by", "challenged_by"),
    },
    "CONTENT_LINK": {
        "required": ("path", "serves_claims", "assumes"),
        "optional": (),
        "non_defaulting": (),
        "list_fields": ("serves_claims", "assumes"),
    },
    "OVERRIDE": {
        "required": ("target_event", "reason", "expiry"),
        "optional": (),
        "non_defaulting": (),
        "list_fields": (),
    },
}

MEASUREMENT_SOURCE_VALUES = ("measured", "inherited", "asserted")


def validate_event(event: dict) -> list[str]:
    """Return a list of validation error strings; empty list means the event is structurally valid.

    Checks ONLY what a single event can tell you about itself: required fields present, no unknown
    fields, list-typed fields actually lists, MEASUREMENT.source in the closed set. Cross-event checks
    (dangling references, duplicate ids) are check_integrity.py's job, not this function's -- a single
    event cannot know whether the id it points at exists.
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

    for field in event:
        if field not in allowed_fields:
            errors.append(f"unknown field {field!r} for {event_type} -- not in its schema")

    if event_type == "MEASUREMENT" and "source" in event:
        if event["source"] not in MEASUREMENT_SOURCE_VALUES:
            errors.append(f"MEASUREMENT.source must be one of {MEASUREMENT_SOURCE_VALUES}, got "
                           f"{event['source']!r}")

    return errors
