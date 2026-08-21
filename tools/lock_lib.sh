# THE MACHINE LOCK PROTOCOL, IN ONE PLACE.
#
# Anything that boots Godot takes a machine-wide lock, because `user://` is keyed on the project NAME and
# because a layer that measures a duration measures the box rather than the code. Three scripts take it:
# `with_machine.sh`, `run_harness.sh` and `seed_corpus.sh`.
#
# WHY THIS FILE EXISTS. Until it did, all three carried their own copy of the protocol. Two safety defects
# were found in one night and each had to be fixed three times by hand, which is three chances to get it
# right and one file's worth of test coverage. The copies were already diverging in a way nobody had
# noticed: `lock_release` and `lock_steal` were byte-identical, but `seed_corpus.sh` wrote a TWO-line owner
# file where the others wrote four, so `lock_claim` rendered a seed_corpus holder with an empty description
# and an empty timestamp — the waiter was told a run was in progress and not told what it was.
#
# Identical-today is a snapshot. A protocol with three copies has no invariant, only a habit.
#
# THE OWNER FILE, and every rule below depends on its shape:
#
#     line 1   the holder's pid          line 3   what it is running
#     line 2   the tree it runs in       line 4   the unix time it started
#
# Callers must set LOCK before sourcing this file. ROOT is used if set and falls back to $PWD.

# --- the claim ------------------------------------------------------------------------------------------

## Write the owner file. Called immediately after a successful `mkdir "$LOCK"`, and never otherwise: the
## directory IS the lock, and this only describes who holds it.
lock_claim_write() {
	printf '%s\n%s\n%s\n%s\n' "$$" "${ROOT:-$PWD}" "${1:-?}" "$(date +%s)" > "$LOCK/owner"
}

## A human-readable description of the current holder, for the waiter to print. A lock that makes you run
## `ps` on another terminal to find out what is running is a lock that gets cleared by hand.
lock_claim() {
	_p="$(sed -n 1p "$LOCK/owner" 2>/dev/null)"
	_t="$(sed -n 2p "$LOCK/owner" 2>/dev/null)"
	_w="$(sed -n 3p "$LOCK/owner" 2>/dev/null)"
	_s="$(sed -n 4p "$LOCK/owner" 2>/dev/null)"
	if [ -z "$_p" ]; then
		printf 'held by nobody it will name'
		return 0
	fi
	_msg="held by pid $_p"
	[ -n "$_w" ] && [ "$_w" != "?" ] && _msg="$_msg running $_w"
	[ -n "$_t" ] && _msg="$_msg in $(basename "$_t")"
	if [ -n "$_s" ]; then
		_e=$(( $(date +%s) - _s ))
		[ "$_e" -ge 0 ] && _msg="$_msg for ${_e}s"
	fi
	printf '%s' "$_msg"
}

# --- release --------------------------------------------------------------------------------------------

## RELEASE ONLY A LOCK WE STILL OWN, and the distinction is the difference between one run on this box and
## two. A `LOCK_HELD=1` flag records that we acquired the lock ONCE; it does not record that we still hold
## it, and the stale sweep below pulls those apart on purpose:
##
##   A is killed hard, so its trap never runs and its lock directory outlives it.
##   B waits, sees A's pid is gone, clears the lock as stale, and takes it. The directory is B's now.
##   A's trap fires late and deletes the directory. It is B's.
##   C finds no lock, takes it, and boots Godot beside B's still-running Godot.
##
## One hard kill was enough to make every honest release after it delete a stranger's lock.
lock_release() {
	if [ "$(sed -n 1p "$LOCK/owner" 2>/dev/null)" = "$$" ]; then
		rm -rf "$LOCK"
	fi
}

# --- the stale sweep ------------------------------------------------------------------------------------

## How many consecutive observations of an unnamed gc directory before it is treated as debris. The waiter
## polls about once a second, so this is the same "ten seconds and it has named nobody" rule the main lock
## already applies to itself. Counted rather than timed because `find -mmin` and `stat` formats differ
## across the platforms this has to run on, and a portability bug in a recovery path is a wedged machine.
LOCK_GC_DEBRIS_POLLS="${LOCK_GC_DEBRIS_POLLS:-10}"
_lock_gc_unnamed=0

## Clear a stale lock. Returns 0 if it cleared one, 1 if it declined, so the CALLER CAN LOG THE OUTCOME
## RATHER THAN THE INTENTION — the message "clearing a stale lock" used to be printed before this ran and
## was frequently a description of something that did not happen.
##
##   lock_steal dead      the owner's pid is gone
##   lock_steal unowned   the directory has named no owner at all
##
## SWEEPING IS A MUTATION OF SHARED STATE, SO IT HAPPENS UNDER ITS OWN MUTEX. Removing a stale lock looks
## safe because the holder is provably dead, but the proof and the removal are two steps and a waiter can
## be descheduled between them. An atomic rename does NOT fix that, and it was the first thing tried: `mv`
## makes one winner among SIMULTANEOUS sweepers, and the failure is a LATE one, whose rename succeeds
## against a live directory because rename cannot tell whose directory it is. Staged with one waiter
## delayed, the rename version still put two engines on the box 5 times in 5.
##
## Inside this mutex the argument is airtight: to ACQUIRE the lock a process must `mkdir` it, which requires
## it not to exist; it does exist until we remove it; and we are the only party permitted to remove it. So
## an owner that reads as dead in here cannot have been replaced by a live one before the `rm`.
lock_steal() {
	_gc="$LOCK.gc"
	# RECOVERING THE MUTEX IS ITSELF A SWEEP, and the first version of it repeated the exact bug above:
	# it renamed a gc directory it had decided was dead, and a late actor's rename lands on a LIVE one.
	# So the recoverer now VERIFIES what it took and puts it back if it guessed wrong.
	_gp="$(cat "$_gc/pid" 2>/dev/null)"
	# A NAMED gc RESETS THE DEBRIS COUNTER. Without this the unnamed-observation tally survives across a
	# healthy sweeper's whole lifetime and a slow peer could eventually reach the debris threshold against
	# a mutex that is perfectly alive, which is the very failure the mutex exists to prevent.
	[ -n "$_gp" ] && _lock_gc_unnamed=0
	if [ -n "$_gp" ] && ! kill -0 "$_gp" 2>/dev/null; then
		rm -rf "$_gc.dead.$$" 2>/dev/null
		if mv "$_gc" "$_gc.dead.$$" 2>/dev/null; then
			if [ "$(cat "$_gc.dead.$$/pid" 2>/dev/null)" = "$_gp" ]; then
				rm -rf "$_gc.dead.$$"          # it really was the dead one
			else
				# We took a mutex somebody else had just claimed. Put it back and stand down; the
				# alternative is proceeding to sweep beside them, which is the failure this guards.
				mv "$_gc.dead.$$" "$_gc" 2>/dev/null || rm -rf "$_gc.dead.$$"
				return 1
			fi
		fi
	elif [ ! -s "$_gc/pid" ] && [ -d "$_gc" ]; then
		# A SWEEPER KILLED BETWEEN `mkdir` AND ITS PID WRITE leaves a directory nothing can classify:
		# not dead, because there is no pid to test, and so left alone forever while every later run
		# times out. Unrecoverable without a human until this branch existed.
		_lock_gc_unnamed=$((_lock_gc_unnamed + 1))
		if [ "$_lock_gc_unnamed" -ge "$LOCK_GC_DEBRIS_POLLS" ]; then
			rm -rf "$_gc"
			_lock_gc_unnamed=0
		fi
		return 1
	fi
	if ! mkdir "$_gc" 2>/dev/null; then
		return 1                                   # somebody else is sweeping; loop and re-read
	fi
	echo "$$" > "$_gc/pid"
	_lock_gc_unnamed=0
	_h="$(sed -n 1p "$LOCK/owner" 2>/dev/null)"
	_did=1
	if [ "${1:-dead}" = "unowned" ]; then
		if [ -z "$_h" ]; then rm -rf "$LOCK"; _did=0; fi
	else
		if [ -n "$_h" ] && ! kill -0 "$_h" 2>/dev/null; then rm -rf "$LOCK"; _did=0; fi
	fi
	rm -rf "$_gc"
	return "$_did"
}

# WHAT IS STILL NOT CLOSED, stated here rather than discovered later.
#
#   Pid REUSE. `kill -0` on a recycled pid reports a live holder, so a genuinely stale lock can wedge every
#   run until the wait expires. That is liveness rather than safety and it fails loudly with NOTHING RAN.
#   Line 2 of the owner file records the tree if somebody wants to tighten it.
#
#   A sweeper killed inside the gc mutex — one `sed`, one `kill -0`, one `rm` — still leaves the directory
#   behind. The unnamed-debris branch above recovers it after LOCK_GC_DEBRIS_POLLS observations, so it is no
#   longer permanent, but there is a window in which the machine is serialised harder than it needs to be.
