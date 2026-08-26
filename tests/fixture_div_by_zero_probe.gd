extends SceneTree

## Not a suite -- no `_finish()`, doesn't extend `test_base.gd`. A minimal standalone script whose only
## job is to call `Fx.div` by zero and exit, so `tests/test_fixed_point.gd`'s
## `_test_div_by_zero_logs_via_push_error()` can spawn it as a subprocess and grep its OWN stderr for
## the exact `push_error` message -- the only way to actually observe a `push_error` call from a test in
## stock GDScript, which has no in-process interception/callback for it. Kept as its own file rather
## than inlined, since `OS.execute` needs a real `res://` script path to run.


func _initialize() -> void:
	Fx.div(Fx.from_int(1), 0)
	quit(0)
