#!/usr/bin/env python3
"""No engine coupling in core/ or sim/. See docs/ARCHITECTURE.md §3, §4.

    python3 tools/layer_lint/no_engine_imports.py

Grep-level, not a parser, and deliberately conservative: every pattern below
is something docs/ARCHITECTURE.md states outright as forbidden in these two
layers. A file tripping this check is not "maybe fine" — read the offending
line before assuming the pattern is a false positive, because loosening a
pattern here is exactly how the sim quietly regains engine coupling.

The other direction is just as real and was the actual finding that provoked
this rewrite (docs/DECISIONS_LEDGER.md D0023, D0026): a category nobody has
tripped on YET is not a category that's fine, it's a gap. This file's pattern
list used to grow only when someone happened to write the exact line that
tripped it. A gate is only as good as its pattern list, and a missing pattern
is a gate that reports green on the exact thing it exists to catch — when a
gate passes on code you expected it to flag, the gate is the suspect, not the
code (docs/QUALITY.md §2). So as of this rewrite, the scene-tree category is
derived directly from Godot's own ClassDB rather than accumulated by memory:
_NODE_DERIVED_CLASSES below is every class descending from Node in Godot
4.6.2.stable, dumped via `ClassDB.get_class_list()` + `get_parent_class()`
walked to the root (see the commit message for the exact one-off script).
Regenerate it the same way if the engine version changes meaningfully.

Categories checked, each mapped to the architecture rule it enforces:
  - scene-tree coupling       ("no engine imports") — extends OR instantiates
                                any Node-derived class, not just the handful
                                someone had already written by hand.
  - scene/resource references ("no engine imports" — a .tscn/.tres path is a
                                reference to something Godot, not the sim)
  - file IO                   ("no file IO") — FileAccess/DirAccess, plus
                                ResourceLoader/ResourceSaver, which are file
                                IO through the engine's resource system.
  - wall clock / engine time  ("no wall clock") — OS/Time/Engine/Performance
                                getters that reflect real machine/frame state.
  - unseeded randomness       (determinism: "seeded, split RNG... no global
                                random", docs/ARCHITECTURE.md §4) — the global
                                rand* functions, RandomNumberGenerator, and
                                Crypto (a real, easy-to-reach-for alternate
                                unseeded RNG source).
  - noise resources           (determinism + engine-free: an opaque, version-
                                pinned algorithm sim/ cannot own — write a
                                deterministic noise function instead, see
                                sim/terrain_gen/value_noise.gd).
  - input devices             (docs/ARCHITECTURE.md's per-module Must-not,
                                "read input devices", made a project-wide
                                automated rule rather than one module's prose)
  - engine subsystem servers  (rendering/audio/physics/navigation servers —
                                the sim has its own fixed-point physics and no
                                engine-owned rendering or audio state)
  - threading / concurrency   (determinism: the sim's tick order is fixed and
                                single-threaded; Thread/Mutex/Semaphore/
                                WorkerThreadPool introduce real ordering
                                nondeterminism)
  - network IO                ("no file IO"'s sibling — sockets and HTTP are
                                the same category of non-deterministic,
                                side-effecting IO, just not to a file)
  - OS-level side effects     (OS.execute() et al. run arbitrary subprocesses
                                or show OS UI — engine coupling and IO both)
  - autoloads / singletons    ("no global mutable state", CONTEXT.md)

Deliberately NOT blocked, considered and rejected: Geometry2D/Geometry3D and
Marshalls (pure deterministic math/encoding utilities, no engine state
involved), ProjectSettings (reads the exported project's own config, which is
deterministic given a fixed project file — not named as forbidden by any
category above; revisit if a real use ever depends on a value that varies
between machines), and the ~130 editor-only Node subclasses in
_NODE_DERIVED_CLASSES (EditorPlugin, EditorFileDialog, GridMapEditorPlugin,
etc.) — included anyway rather than hand-filtered out, because filtering them
would have reintroduced exactly the "accumulate a list by judgment" problem
this rewrite exists to fix, and matching them costs nothing at scan time.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gd_scan import gd_files_in  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
POLICED_DIRS = ("core", "sim")

# Every class descending from Node in Godot 4.6.2.stable's ClassDB. See the
# module docstring for how this was generated and when to regenerate it.
_NODE_DERIVED_CLASSES = (
    "AcceptDialog", "AimModifier3D", "AnimatableBody2D", "AnimatableBody3D", "AnimatedSprite2D", "AnimatedSprite3D", "AnimationMixer", "AnimationPlayer",
    "AnimationTree", "Area2D", "Area3D", "AspectRatioContainer", "AudioListener2D", "AudioListener3D", "AudioStreamPlayer", "AudioStreamPlayer2D",
    "AudioStreamPlayer3D", "BackBufferCopy", "BaseButton", "Bone2D", "BoneAttachment3D", "BoneConstraint3D", "BoneTwistDisperser3D", "BoxContainer",
    "Button", "CCDIK3D", "CPUParticles2D", "CPUParticles3D", "CSGBox3D", "CSGCombiner3D", "CSGCylinder3D", "CSGMesh3D",
    "CSGPolygon3D", "CSGPrimitive3D", "CSGShape3D", "CSGSphere3D", "CSGTorus3D", "Camera2D", "Camera3D", "CanvasGroup",
    "CanvasItem", "CanvasLayer", "CanvasModulate", "CenterContainer", "ChainIK3D", "CharacterBody2D", "CharacterBody3D", "CheckBox",
    "CheckButton", "CodeEdit", "CollisionObject2D", "CollisionObject3D", "CollisionPolygon2D", "CollisionPolygon3D", "CollisionShape2D", "CollisionShape3D",
    "ColorPicker", "ColorPickerButton", "ColorRect", "ConeTwistJoint3D", "ConfirmationDialog", "Container", "Control", "ConvertTransformModifier3D",
    "CopyTransformModifier3D", "DampedSpringJoint2D", "Decal", "DirectionalLight2D", "DirectionalLight3D", "EditorCommandPalette", "EditorDock", "EditorFileDialog",
    "EditorFileSystem", "EditorInspector", "EditorPlugin", "EditorProperty", "EditorResourcePicker", "EditorResourcePreview", "EditorScriptPicker", "EditorSpinSlider",
    "EditorToaster", "FABRIK3D", "FileDialog", "FileSystemDock", "FlowContainer", "FogVolume", "FoldableContainer", "GPUParticles2D",
    "GPUParticles3D", "GPUParticlesAttractor3D", "GPUParticlesAttractorBox3D", "GPUParticlesAttractorSphere3D", "GPUParticlesAttractorVectorField3D", "GPUParticlesCollision3D", "GPUParticlesCollisionBox3D", "GPUParticlesCollisionHeightField3D",
    "GPUParticlesCollisionSDF3D", "GPUParticlesCollisionSphere3D", "Generic6DOFJoint3D", "GeometryInstance3D", "GraphEdit", "GraphElement", "GraphFrame", "GraphNode",
    "GridContainer", "GridMap", "GridMapEditorPlugin", "GrooveJoint2D", "HBoxContainer", "HFlowContainer", "HScrollBar", "HSeparator",
    "HSlider", "HSplitContainer", "HTTPRequest", "HingeJoint3D", "IKModifier3D", "ImporterMeshInstance3D", "InstancePlaceholder", "ItemList",
    "IterateIK3D", "JacobianIK3D", "Joint2D", "Joint3D", "Label", "Label3D", "Light2D", "Light3D",
    "LightOccluder2D", "LightmapGI", "LightmapProbe", "LimitAngularVelocityModifier3D", "Line2D", "LineEdit", "LinkButton", "LookAtModifier3D",
    "MarginContainer", "Marker2D", "Marker3D", "MenuBar", "MenuButton", "MeshInstance2D", "MeshInstance3D", "MissingNode",
    "ModifierBoneTarget3D", "MultiMeshInstance2D", "MultiMeshInstance3D", "MultiplayerSpawner", "MultiplayerSynchronizer", "NavigationAgent2D", "NavigationAgent3D", "NavigationLink2D",
    "NavigationLink3D", "NavigationObstacle2D", "NavigationObstacle3D", "NavigationRegion2D", "NavigationRegion3D", "NinePatchRect", "Node", "Node2D",
    "Node3D", "OccluderInstance3D", "OmniLight3D", "OpenXRBindingModifierEditor", "OpenXRCompositionLayer", "OpenXRCompositionLayerCylinder", "OpenXRCompositionLayerEquirect", "OpenXRCompositionLayerQuad",
    "OpenXRHand", "OpenXRInteractionProfileEditor", "OpenXRInteractionProfileEditorBase", "OpenXRRenderModel", "OpenXRRenderModelManager", "OpenXRVisibilityMask", "OptionButton", "Panel",
    "PanelContainer", "Parallax2D", "ParallaxBackground", "ParallaxLayer", "Path2D", "Path3D", "PathFollow2D", "PathFollow3D",
    "PhysicalBone2D", "PhysicalBone3D", "PhysicalBoneSimulator3D", "PhysicsBody2D", "PhysicsBody3D", "PinJoint2D", "PinJoint3D", "PointLight2D",
    "Polygon2D", "Popup", "PopupMenu", "PopupPanel", "ProgressBar", "Range", "RayCast2D", "RayCast3D",
    "ReferenceRect", "ReflectionProbe", "RemoteTransform2D", "RemoteTransform3D", "ResourcePreloader", "RetargetModifier3D", "RichTextLabel", "RigidBody2D",
    "RigidBody3D", "RootMotionView", "ScriptCreateDialog", "ScriptEditor", "ScriptEditorBase", "ScrollBar", "ScrollContainer", "Separator",
    "ShaderGlobalsOverride", "ShapeCast2D", "ShapeCast3D", "Skeleton2D", "Skeleton3D", "SkeletonIK3D", "SkeletonModifier3D", "Slider",
    "SliderJoint3D", "SoftBody3D", "SpinBox", "SplineIK3D", "SplitContainer", "SpotLight3D", "SpringArm3D", "SpringBoneCollision3D",
    "SpringBoneCollisionCapsule3D", "SpringBoneCollisionPlane3D", "SpringBoneCollisionSphere3D", "SpringBoneSimulator3D", "Sprite2D", "Sprite3D", "SpriteBase3D", "StaticBody2D",
    "StaticBody3D", "StatusIndicator", "SubViewport", "SubViewportContainer", "TabBar", "TabContainer", "TextEdit", "TextureButton",
    "TextureProgressBar", "TextureRect", "TileMap", "TileMapLayer", "Timer", "TouchScreenButton", "Tree", "TwoBoneIK3D",
    "VBoxContainer", "VFlowContainer", "VScrollBar", "VSeparator", "VSlider", "VSplitContainer", "VehicleBody3D", "VehicleWheel3D",
    "VideoStreamPlayer", "Viewport", "VisibleOnScreenEnabler2D", "VisibleOnScreenEnabler3D", "VisibleOnScreenNotifier2D", "VisibleOnScreenNotifier3D", "VisualInstance3D", "VoxelGI",
    "Window", "WorldEnvironment", "XRAnchor3D", "XRBodyModifier3D", "XRCamera3D", "XRController3D", "XRFaceModifier3D", "XRHandModifier3D",
    "XRNode3D", "XROrigin3D",
)
_NODE_CLASS_ALT = "|".join(_NODE_DERIVED_CLASSES)

PATTERNS = [
    (re.compile(r'\bextends\s+(Node\w*|CanvasItem|Control|Sprite2D|RefCounted\b.*Node|' + _NODE_CLASS_ALT + r')\b'),
     "extends a scene-tree (Node-derived) class"),
    (re.compile(r'\b(' + _NODE_CLASS_ALT + r')\.new\s*\('),
     "instantiates a scene-tree (Node-derived) class directly"),
    (re.compile(r'\bget_tree\s*\('), "get_tree() — scene-tree access"),
    (re.compile(r'\bget_viewport\s*\('), "get_viewport() — engine viewport access"),
    (re.compile(r'res://[\w./-]+\.(tscn|tres)\b'), "references a .tscn/.tres scene resource"),

    (re.compile(r'\bFileAccess\.'), "FileAccess — file IO"),
    (re.compile(r'\bDirAccess\.'), "DirAccess — file IO"),
    (re.compile(r'\bResourceLoader\.(load|load_threaded_request)\b'), "ResourceLoader — file IO via the engine's resource system"),
    (re.compile(r'\bResourceSaver\.save\b'), "ResourceSaver.save — file IO via the engine's resource system"),

    (re.compile(r'\bOS\.get_ticks_(msec|usec)\s*\('), "OS.get_ticks_* — wall clock"),
    (re.compile(r'\bOS\.get_(unix_time|system_time_msecs|system_time_secs)\b'), "OS.get_*time* — wall clock"),
    (re.compile(r'\bTime\.get_(ticks|unix_time|datetime)'), "Time.get_* — wall clock"),
    (re.compile(r'\bEngine\.get_(process|physics)_frames\s*\('), "Engine.get_*_frames() — wall/frame clock"),
    (re.compile(r'\bPerformance\.get_monitor\b'), "Performance.get_monitor — reflects real machine/runtime state"),

    (re.compile(r'\b(randi|randf|randomize)\s*\('), "unseeded global RNG (use core's seeded RNG)"),
    (re.compile(r'\bRandomNumberGenerator\b'),
     "RandomNumberGenerator — engine RNG class (use core/SplitRng: one stream per subsystem, serializable)"),
    (re.compile(r'\bCrypto\b'), "Crypto — an alternate unseeded RNG source (generate_random_bytes et al.)"),

    (re.compile(r'\bFastNoiseLite\b'),
     "FastNoiseLite — engine noise resource (sim/ is engine-free; write a deterministic noise function)"),

    (re.compile(r'\bInput\.'), "Input — reads input devices (sim/ must not; see per-module Must-not rows)"),
    (re.compile(r'\bInputMap\.'), "InputMap — reads input device bindings"),

    (re.compile(r'\b(DisplayServer|RenderingServer|AudioServer)\.'),
     "direct engine rendering/audio server access — view/ territory, not sim/"),
    (re.compile(r'\b(PhysicsServer2D|PhysicsServer2DManager|PhysicsServer3D|PhysicsServer3DManager)\.'),
     "engine physics server — the sim has its own fixed-point physics, not Godot's"),
    (re.compile(r'\b(NavigationServer2D|NavigationServer2DManager|NavigationServer3D|NavigationServer3DManager|NavigationMeshGenerator)\.'),
     "engine navigation/navmesh server — not part of this project's sim"),

    (re.compile(r'\b(Thread|Mutex|Semaphore|WorkerThreadPool)\b'),
     "threading primitive — the sim's tick order is fixed and single-threaded; this introduces real ordering nondeterminism"),

    (re.compile(r'\b(HTTPClient|HTTPRequest|TCPServer|UDPServer|StreamPeerTCP|PacketPeerUDP)\b'),
     "network IO class — same category as file IO, just not to a file"),
    (re.compile(r'\bIP\.'), "IP — network host resolution"),

    (re.compile(r'\bOS\.(execute|create_process|create_instance|shell_open|shell_show_in_file_manager|alert)\b'),
     "OS subprocess/UI side effect — engine coupling and IO both"),

    (re.compile(r'^\s*@onready\b'), "@onready — implies scene-tree membership"),
]


def find_gd_files():
    return gd_files_in(ROOT, POLICED_DIRS)


def main() -> int:
    files = list(find_gd_files())
    if not files:
        print("no_engine_imports: core/ and sim/ have no .gd files yet — nothing to check.")
        print("no_engine_imports: PASS (vacuously)")
        return 0

    violations = []
    for path in files:
        rel = path.relative_to(ROOT)
        for lineno, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            for pattern, label in PATTERNS:
                if pattern.search(line):
                    violations.append(f"{rel}:{lineno}: {label} — {stripped[:80]}")

    print(f"no_engine_imports: {len(files)} files scanned under core/, sim/ ({len(_NODE_DERIVED_CLASSES)} Node-derived class names checked)")
    if violations:
        print(f"no_engine_imports: FAIL — {len(violations)} violation(s)")
        for v in violations:
            print(f"  FAIL  {v}")
        return 1

    print("no_engine_imports: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
