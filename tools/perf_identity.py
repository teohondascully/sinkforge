"""Identity for performance evidence, not a verification cache.

Hash the runtime inputs (including untracked additions) before/after each seat. Documentation-only
work can continue. An edit reverted between snapshots is not detectable: benchmark on a quiet tree.
Record preferences by hash only; never copy the user's settings or environment into the report.
"""
import hashlib
import os
from pathlib import Path
import platform
import shutil
import subprocess

RUNTIME = ("assets", "core", "data", "interface", "shell", "sim", "view", "project.godot",
           "tools/perf_fixture.py", "tools/perf_identity.py")
MATCH = ("zoom", "ticks", "regime", "engine_sha256", "platform", "host", "settings_sha256",
         "graphics_env_sha256", "renderer")


def digest_file(path):
    if not path.exists():
        return "absent"
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def source_state(root):
    def git(*args):
        return subprocess.check_output(["git", *args], cwd=root, stderr=subprocess.DEVNULL)
    names = sorted(set(git("ls-files", "-z", "--cached", "--others", "--exclude-standard",
                           "--", *RUNTIME).decode().split("\0")) - {""})
    digest = hashlib.sha256()
    for name in names:
        digest.update(name.encode() + b"\0" + digest_file(root / name).encode() + b"\0")
    try:
        head = git("rev-parse", "HEAD").decode().strip()
    except subprocess.CalledProcessError:
        head = None
    return {"head": head, "source_sha256": digest.hexdigest(),
            "dirty_tree": bool(git("status", "--porcelain", "--untracked-files=all").strip())}


def settings_path():
    # project.godot uses Godot's default user-data directory and config/name="Sinkforge".
    if platform.system() == "Darwin":
        base = Path.home() / "Library/Application Support"
    elif platform.system() == "Windows":
        base = Path(os.environ["APPDATA"])
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
    return base / "Godot/app_userdata/Sinkforge/settings.cfg"


def capture(root, godot):
    executable = Path(shutil.which(godot) or godot).resolve()
    version = subprocess.check_output([str(executable), "--version"], text=True).strip()
    env = "\0".join(k + "=" + v for k, v in sorted(os.environ.items())
                     if k.startswith(("MTL", "VK_", "GODOT", "MESA", "DRI"))
                     or k in ("DISPLAY", "WAYLAND_DISPLAY"))
    return dict(source_state(root), identity_version=1, engine=str(executable), engine_version=version,
                engine_sha256=digest_file(executable), platform=platform.platform(),
                host=hashlib.sha256(platform.node().encode()).hexdigest(),
                settings_sha256=digest_file(settings_path()),
                graphics_env_sha256=hashlib.sha256(env.encode()).hexdigest())


def verify_unchanged(before, after, settings_hash):
    if before["source_sha256"] != after["source_sha256"] or before["settings_sha256"] != settings_hash:
        raise RuntimeError("VOID: runtime sources or player settings changed during the seat run")


def incompatible(before, after, allow_seat_change=False):
    if before.get("identity_version") != 1 or after.get("identity_version") != 1:
        return "saved run lacks verified provenance; re-record both sides"
    for key in MATCH:
        if key not in before or key not in after or before[key] != after[key]:
            return "run configuration differs or is missing: " + key
    if not allow_seat_change and before.get("seat") != after.get("seat"):
        return "seat flags differ; declare the treatment with --allow-seat-change"
    return ""
