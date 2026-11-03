extends RefCounted
## Builds an actor's AnimationTree from frame timings.
## Each clip is a real Animation: a method track fires hit_start / hit_end exactly at the
## move's active frames, and a position track on the actor's "RootMotion" node carries the
## attack lunge (read back as root motion). A StateMachine holds every clip; "locomote" is a
## BlendSpace2D (idle / walk / run, x = strafe, y = forward).
## The tree is advanced by hand (callback mode MANUAL) so hitstop can freeze it exactly.
## Today the visible body is posed by the procedural rig from the current state + clip time;
## real Mixamo / Tripo clips can later be added to the same states with the same tracks.

const FPS: float = 60.0
const LOCO: Array = [["idle", Vector2(0, 0)], ["walk_f", Vector2(0, 0.5)], ["walk_b", Vector2(0, -0.5)],
	["walk_l", Vector2(-0.5, 0)], ["walk_r", Vector2(0.5, 0)], ["run_f", Vector2(0, 1)]]

## clips: name -> {"frames": int, "loop": bool, "hit": [start_f, end_f] (optional),
##                 "lunge_m": float, "lunge_f": int}
static func build(actor: Node3D, clips: Dictionary) -> AnimationTree:
	var rm: Node3D = Node3D.new()
	rm.name = "RootMotion"
	actor.add_child(rm)
	var lib: AnimationLibrary = AnimationLibrary.new()
	for nm: String in clips:
		lib.add_animation(nm, make_clip(clips[nm]))
	for l: Array in LOCO:
		lib.add_animation(str(l[0]), make_clip({"frames": 60, "loop": true}))
	var sm: AnimationNodeStateMachine = AnimationNodeStateMachine.new()
	var bs: AnimationNodeBlendSpace2D = AnimationNodeBlendSpace2D.new()
	bs.min_space = Vector2(-1, -1)
	bs.max_space = Vector2(1, 1)
	for l: Array in LOCO:
		var an: AnimationNodeAnimation = AnimationNodeAnimation.new()
		an.animation = StringName(str(l[0]))
		bs.add_blend_point(an, l[1])
	sm.add_node("locomote", bs, Vector2(0, 0))
	var i: int = 1
	for nm: String in clips:
		var a: AnimationNodeAnimation = AnimationNodeAnimation.new()
		a.animation = StringName(nm)
		sm.add_node(nm, a, Vector2(200 * (i % 6), 120 * (i / 6)))
		# every state can go back to locomotion (and locomotion can reach it) for travel()
		sm.add_transition("locomote", nm, AnimationNodeStateMachineTransition.new())
		var back: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
		back.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		back.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
		if not bool((clips[nm] as Dictionary).get("loop", false)):
			sm.add_transition(nm, "locomote", back)
		i += 1
	sm.add_transition("Start", "locomote", AnimationNodeStateMachineTransition.new())
	var tree: AnimationTree = AnimationTree.new()
	tree.name = "AnimationTree"
	actor.add_child(tree)
	tree.add_animation_library("", lib)
	tree.tree_root = sm
	tree.root_node = NodePath("..")
	tree.root_motion_track = NodePath("RootMotion")
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	tree.active = true
	return tree

static func make_clip(c: Dictionary) -> Animation:
	var frames: int = int(c.get("frames", 30))
	var a: Animation = Animation.new()
	a.length = frames / FPS
	a.loop_mode = Animation.LOOP_LINEAR if bool(c.get("loop", false)) else Animation.LOOP_NONE
	var pt: int = a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(pt, NodePath("RootMotion"))
	var lunge: float = float(c.get("lunge_m", 0.0))
	var lf: int = int(c.get("lunge_f", frames))
	a.position_track_insert_key(pt, 0.0, Vector3.ZERO)
	a.position_track_insert_key(pt, maxf(lf / FPS, 0.001), Vector3(0, 0, -lunge))
	if lf < frames:
		a.position_track_insert_key(pt, a.length, Vector3(0, 0, -lunge))
	if c.has("hit"):
		var mt: int = a.add_track(Animation.TYPE_METHOD)
		a.track_set_path(mt, NodePath("."))
		var h: Array = c.hit
		a.track_insert_key(mt, int(h[0]) / FPS, {"method": &"hit_start", "args": []})
		a.track_insert_key(mt, int(h[1]) / FPS, {"method": &"hit_end", "args": []})
	return a
