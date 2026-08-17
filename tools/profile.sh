#!/usr/bin/env bash
# PROFILE THE FRAME, WITHOUT STANDING ON ANOTHER RUN.
#
# tools/profile_frame.gd boots a real window, digs a few hundred cells and does full-texture uploads. That
# is a genuine CPU+GPU load, so running it beside a harness makes BOTH results fiction — the harness times
# the profiler's contention, and the profiler times the harness's.
#
# This existed as a rule that a person had to remember, and it was broken within the hour by the person who
# wrote it: I checked the lock, saw another session holding it, said out loud that I was queued behind it,
# and then ran the profiler twice anyway. A convention only one of the two tools enforces is not a
# convention.
#
# The lock lives in tools/with_machine.sh now, which is the general answer: this script used to carry its
# own copy of the waiting loop, and a copy is how the hole stayed open. Closing it here left every OTHER
# ad-hoc `godot --script ...` — single layers, captures — running unlocked, which put eight of my processes
# on a busy box a second and third time. One implementation, used by everything that boots Godot.
#
#   GODOT=/opt/homebrew/bin/godot bash tools/profile.sh
#
# SF_LOCK overrides the lock path (must match the runner's). Exit 5 = gave up waiting for the lock.

set -uo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/with_machine.sh" --script res://tools/profile_frame.gd
