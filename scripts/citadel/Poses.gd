extends RefCounted
## Key poses for the procedural rig. Directions are model space:
## +X forward, +Y up, +Z the character's right side.

static func d(f: float, u: float, r: float) -> Vector3:
	return Vector3(f, u, r).normalized()

static func leg(angle: float, side: float) -> Vector3:
	return Vector3(sin(angle), -cos(angle), side).normalized()

static func yaw(a: float) -> Quaternion:
	## Positive turns the chest toward the character's left.
	return Quaternion(Vector3.UP, a)

static func lean(a: float) -> Quaternion:
	## Positive leans forward.
	return Quaternion(Vector3(0, 0, 1), -a)

static func base_legs(p: Dictionary, wide: float = 0.12) -> void:
	p["L_Thigh"] = leg(0.04, -wide)
	p["L_Calf"] = leg(-0.02, -0.04)
	p["R_Thigh"] = leg(-0.04, wide)
	p["R_Calf"] = leg(-0.06, 0.04)

static func idle(t: float, guard_up: bool) -> Dictionary:
	var b: float = sin(t * 2.2) * 0.03
	var p: Dictionary = {}
	base_legs(p, 0.16)
	p["L_Upperarm"] = d(0.12, -1, -0.32 - b)
	p["L_Forearm"] = d(0.55, -1, -0.15)
	p["R_Upperarm"] = d(0.25, -1, 0.34 + b)
	p["R_Forearm"] = d(1, -0.25, 0.18)
	p["blade"] = d(0.9, 0.55, -0.1) if guard_up else d(0.7, -0.25, 0.25)
	p["Spine02"] = lean(0.04 + b)
	return p

static func run(phase: float, speed: float) -> Dictionary:
	var s: float = sin(phase)
	var amp: float = 0.75 * speed
	var p: Dictionary = {}
	var al: float = amp * s
	var ar: float = -amp * s
	p["L_Thigh"] = leg(al, -0.1)
	p["R_Thigh"] = leg(ar, 0.1)
	p["L_Calf"] = leg(al - (0.25 + 1.0 * maxf(0.0, -cos(phase))) * speed, -0.05)
	p["R_Calf"] = leg(ar - (0.25 + 1.0 * maxf(0.0, cos(phase))) * speed, 0.05)
	p["L_Upperarm"] = d(-0.6 * s * speed, -1, -0.3)
	p["L_Forearm"] = d(0.7 - 0.4 * s, -0.6, -0.15)
	p["R_Upperarm"] = d(0.1 + 0.35 * s * speed, -1, 0.35)
	p["R_Forearm"] = d(1, -0.45, 0.25)
	p["blade"] = d(-0.6, 0.35, 0.3)
	p["Waist"] = yaw(0.12 * s * speed)
	p["Spine01"] = lean(0.16 * speed)
	return p

static func airborne(vy: float) -> Dictionary:
	var p: Dictionary = {}
	var tuck: float = clampf(0.6 - vy * 0.05, 0.2, 0.9)
	p["L_Thigh"] = leg(tuck, -0.12)
	p["L_Calf"] = leg(-0.5, -0.05)
	p["R_Thigh"] = leg(tuck * 0.4, 0.12)
	p["R_Calf"] = leg(-0.9, 0.05)
	p["L_Upperarm"] = d(0.2, -0.2, -1)
	p["L_Forearm"] = d(0.5, 0.2, -1)
	p["R_Upperarm"] = d(0.1, -0.3, 1)
	p["R_Forearm"] = d(0.8, 0.3, 0.6)
	p["blade"] = d(-0.3, 0.6, 0.6)
	return p

## Three-hit sword combo. t runs 0..1 over the swing.
static func slash(step: int, t: float) -> Dictionary:
	var p: Dictionary = {}
	base_legs(p, 0.22)
	p["L_Thigh"] = leg(0.35, -0.2)
	p["L_Calf"] = leg(0.05, -0.1)
	p["R_Thigh"] = leg(-0.35, 0.2)
	p["R_Calf"] = leg(-0.5, 0.1)
	var w: float = smoothstep(0.0, 0.32, t)
	var s: float = smoothstep(0.3, 0.58, t)
	match step:
		0:
			p["R_Upperarm"] = d(-0.1, 0.55, 1).slerp(d(1, 0.15, -0.55), s)
			p["R_Forearm"] = d(-0.6, 0.6, 0.6).slerp(d(0.6, 0.0, -1), s)
			p["blade"] = d(-0.8, 0.3, 0.5).slerp(d(0.2, 0.1, -1), s)
			p["Spine02"] = yaw(lerpf(-0.55 * w, 0.65, s))
			p["L_Upperarm"] = d(0.5, -0.6, -0.8)
			p["L_Forearm"] = d(0.9, -0.2, -0.4)
		1:
			p["R_Upperarm"] = d(0.7, 0.35, -0.9).slerp(d(0.8, 0.0, 1), s)
			p["R_Forearm"] = d(0.1, 0.4, -1).slerp(d(0.7, -0.1, 1), s)
			p["blade"] = d(-0.3, 0.4, -1).slerp(d(0.3, 0.1, 1), s)
			p["Spine02"] = yaw(lerpf(0.6 * w, -0.65, s))
			p["L_Upperarm"] = d(0.3, -0.8, -0.6)
			p["L_Forearm"] = d(0.8, -0.3, -0.5)
		_:
			p["R_Upperarm"] = d(0.15, 1, 0.3).slerp(d(1, -0.5, 0.1), s)
			p["R_Forearm"] = d(-0.6, 1, 0.1).slerp(d(1, -0.9, 0), s)
			p["L_Upperarm"] = d(0.15, 1, -0.2).slerp(d(1, -0.45, -0.1), s)
			p["L_Forearm"] = d(-0.5, 1, 0.3).slerp(d(1, -0.8, 0.2), s)
			p["blade"] = d(-1, 0.4, 0).slerp(d(1, -0.35, 0), s)
			p["Spine01"] = lean(lerpf(-0.2 * w, 0.35, s))
	return p

static func plunge(t: float) -> Dictionary:
	var p: Dictionary = airborne(-4.0)
	p["R_Upperarm"] = d(0.6, 0.6, 0.2).slerp(d(0.7, -0.9, 0.1), t)
	p["R_Forearm"] = d(0.2, 1, 0).slerp(d(0.6, -1, 0), t)
	p["L_Upperarm"] = d(0.6, 0.6, -0.2).slerp(d(0.7, -0.9, -0.1), t)
	p["L_Forearm"] = d(0.2, 1, 0).slerp(d(0.6, -1, 0), t)
	p["blade"] = d(0.3, -1, 0)
	p["Spine01"] = lean(0.35 * t)
	return p

static func block(t: float) -> Dictionary:
	var p: Dictionary = {}
	base_legs(p, 0.26)
	p["L_Thigh"] = leg(0.3, -0.25)
	p["R_Thigh"] = leg(-0.3, 0.25)
	p["R_Calf"] = leg(-0.45, 0.1)
	p["R_Upperarm"] = d(0.75, -0.35, 0.55)
	p["R_Forearm"] = d(0.35, 0.15, -1)
	p["L_Upperarm"] = d(0.75, -0.35, -0.55)
	p["L_Forearm"] = d(0.4, 0.3, 1)
	p["blade"] = d(0.25, 1, -0.45)
	p["Spine01"] = lean(0.12 + sin(t * 9.0) * 0.01)
	return p

static func windup(t: float) -> Dictionary:
	## Enemy telegraph: sword raised high over the right shoulder.
	var p: Dictionary = idle(0.0, true)
	p["R_Upperarm"] = d(0.1, 0.4, 1).slerp(d(-0.2, 1, 0.6), t)
	p["R_Forearm"] = d(-0.2, 1, 0.4).slerp(d(-0.8, 0.7, 0.2), t)
	p["blade"] = d(-0.6, 0.7, 0.2)
	p["Spine02"] = yaw(-0.4 * t)
	p["Spine01"] = lean(-0.15 * t)
	return p

static func strike(t: float) -> Dictionary:
	## Enemy downward diagonal cut.
	var p: Dictionary = slash(0, 0.3 + t * 0.7)
	p["R_Upperarm"] = d(-0.2, 1, 0.6).slerp(d(1, -0.4, -0.3), t)
	p["R_Forearm"] = d(-0.8, 0.7, 0.2).slerp(d(0.8, -0.7, -0.5), t)
	p["blade"] = d(-0.4, 0.9, 0.2).slerp(d(0.5, -0.6, -0.6), t)
	return p

static func hurt(t: float) -> Dictionary:
	var p: Dictionary = idle(0.0, false)
	p["Spine01"] = lean(-0.35 * (1.0 - t))
	p["Head"] = lean(-0.3 * (1.0 - t))
	p["L_Upperarm"] = d(-0.2, -0.6, -1)
	p["R_Upperarm"] = d(-0.2, -0.6, 1)
	return p

static func stagger(t: float) -> Dictionary:
	var p: Dictionary = hurt(0.2)
	p["Spine01"] = lean(-0.25 + sin(t * 14.0) * 0.08)
	p["blade"] = d(0.3, -1, 0.3)
	return p

static func dead() -> Dictionary:
	var p: Dictionary = hurt(0.0)
	p["L_Upperarm"] = d(0.0, 0.2, -1)
	p["R_Upperarm"] = d(0.0, 0.2, 1)
	p["blade"] = d(0, 0, 1)
	return p

static func cast(t: float) -> Dictionary:
	## Ally spell: both hands raised forward.
	var p: Dictionary = idle(t, false)
	p["L_Upperarm"] = d(1, 0.5, -0.4)
	p["L_Forearm"] = d(1, 0.7, -0.1)
	p["R_Upperarm"] = d(1, 0.5, 0.4)
	p["R_Forearm"] = d(1, 0.7, 0.1)
	p["Spine01"] = lean(-0.1)
	return p

static func crouch(phase: float, speed: float) -> Dictionary:
	## Low sneaking stance; knees bent, sword held low and back.
	var s: float = sin(phase) * speed
	var p: Dictionary = {}
	p["L_Thigh"] = leg(1.15 + 0.35 * s, -0.22)
	p["L_Calf"] = leg(-0.55 + 0.25 * s, -0.1)
	p["R_Thigh"] = leg(0.85 - 0.35 * s, 0.22)
	p["R_Calf"] = leg(-0.8 - 0.25 * s, 0.1)
	p["L_Upperarm"] = d(0.6, -0.8, -0.4)
	p["L_Forearm"] = d(1, -0.3, -0.1)
	p["R_Upperarm"] = d(0.1, -1, 0.45)
	p["R_Forearm"] = d(-0.2, -1, 0.3)
	p["blade"] = d(-0.6, -0.7, 0.25)
	p["Spine01"] = lean(0.45)
	p["Head"] = lean(-0.35)
	return p

static func crawl(phase: float, speed: float) -> Dictionary:
	## Prone: the rig is tilted face-down, so model "up" points along the ground ahead.
	var s: float = sin(phase) * speed
	var p: Dictionary = {}
	p["L_Upperarm"] = d(0.55, 0.8 + 0.3 * s, -0.5)
	p["L_Forearm"] = d(0.2, 0.9 - 0.3 * s, -0.2)
	p["R_Upperarm"] = d(0.55, 0.8 - 0.3 * s, 0.5)
	p["R_Forearm"] = d(0.2, 0.9 + 0.3 * s, 0.2)
	p["L_Thigh"] = d(0.15 + 0.2 * s, -1, -0.15)
	p["L_Calf"] = d(-0.1, -1, -0.12)
	p["R_Thigh"] = d(0.15 - 0.2 * s, -1, 0.15)
	p["R_Calf"] = d(-0.1, -1, 0.12)
	p["blade"] = d(-0.2, -1, 0.4)
	p["Head"] = lean(-0.9)
	return p

static func hug(side: float, moving: bool, peeking: bool) -> Dictionary:
	## Back flat to the wall (the hero faces away from it), sword tucked in.
	var p: Dictionary = {}
	base_legs(p, 0.22)
	if moving:
		p["L_Thigh"] = leg(0.1, -0.35 * side)
		p["R_Thigh"] = leg(-0.1, 0.35 * side)
	p["L_Upperarm"] = d(-0.35, -1, -0.55)
	p["L_Forearm"] = d(-0.2, -1, -0.15)
	p["R_Upperarm"] = d(-0.3, -1, 0.5)
	p["R_Forearm"] = d(0.3, -1, 0.2)
	p["blade"] = d(0.15, -1, 0.35)
	p["Spine02"] = lean(-0.06)
	p["Head"] = yaw((0.9 if peeking else 0.5) * -side)
	return p

# ---------------------------------------------------------------- village work poses

static func chop(t: float) -> Dictionary:
	## Two-handed swing from over the right shoulder down to the left. t loops 0..1.
	var k: float = smoothstep(0.0, 0.55, t) - smoothstep(0.62, 1.0, t)
	var p: Dictionary = {}
	base_legs(p, 0.24)
	p["L_Thigh"] = leg(0.25, -0.22)
	p["R_Thigh"] = leg(-0.2, 0.22)
	var hand_up: Vector3 = d(0.1, 1, 0.55)
	var hand_dn: Vector3 = d(1, -0.4, -0.35)
	var arm: Vector3 = hand_dn.slerp(hand_up, k)
	p["R_Upperarm"] = arm.slerp(d(0.3, -0.4, 1), 0.25)
	p["R_Forearm"] = arm
	p["L_Upperarm"] = arm.slerp(d(0.3, -0.4, -1), 0.3)
	p["L_Forearm"] = arm
	p["blade"] = d(-0.6, 0.8, 0.4).slerp(d(0.9, -0.1, -0.5), 1.0 - k)
	p["Spine02"] = yaw(-0.5 * k + 0.35 * (1.0 - k))
	p["Spine01"] = lean(0.1 + 0.25 * (1.0 - k))
	return p

static func mine(t: float) -> Dictionary:
	## Overhead pick swing straight down in front.
	var k: float = smoothstep(0.0, 0.55, t) - smoothstep(0.6, 1.0, t)
	var p: Dictionary = {}
	base_legs(p, 0.26)
	p["L_Thigh"] = leg(0.3, -0.24)
	p["R_Thigh"] = leg(-0.25, 0.24)
	p["R_Calf"] = leg(-0.4, 0.1)
	var arm: Vector3 = d(1, -0.7, 0.05).slerp(d(-0.15, 1, 0.1), k)
	p["R_Upperarm"] = arm.slerp(d(0.2, -0.3, 1), 0.2)
	p["R_Forearm"] = arm
	p["L_Upperarm"] = arm.slerp(d(0.2, -0.3, -1), 0.2)
	p["L_Forearm"] = arm
	p["blade"] = d(-0.9, 0.5, 0).slerp(d(1, -0.2, 0), 1.0 - k)
	p["Spine01"] = lean(-0.2 * k + 0.45 * (1.0 - k))
	return p

static func hoe(t: float) -> Dictionary:
	var p: Dictionary = mine(t)
	p["Spine01"] = lean(0.3 + 0.15 * sin(t * TAU))
	return p

static func fish(t: float) -> Dictionary:
	## Rod held out over the water, slow bob.
	var b: float = sin(t * TAU) * 0.05
	var p: Dictionary = {}
	base_legs(p, 0.18)
	p["R_Upperarm"] = d(0.8, -0.35 + b, 0.35)
	p["R_Forearm"] = d(1, 0.25 + b, 0.05)
	p["L_Upperarm"] = d(0.8, -0.4, -0.2)
	p["L_Forearm"] = d(1, 0.15, 0.35)
	p["blade"] = d(1, 0.7 + b, 0)
	p["Spine01"] = lean(0.08)
	p["Head"] = lean(0.25)
	return p

static func carry(phase: float, speed: float) -> Dictionary:
	## Walking with a load held at the chest.
	var p: Dictionary = run(phase, speed * 0.6)
	p["R_Upperarm"] = d(0.35, -1, 0.3)
	p["R_Forearm"] = d(1, 0.15, -0.35)
	p["L_Upperarm"] = d(0.35, -1, -0.3)
	p["L_Forearm"] = d(1, 0.15, 0.35)
	p["blade"] = d(0, -1, 0.2)
	p["Spine01"] = lean(-0.06)
	return p

static func sit(t: float) -> Dictionary:
	var b: float = sin(t * 1.2) * 0.02
	var p: Dictionary = {}
	p["L_Thigh"] = d(1, 0.05, -0.12)
	p["L_Calf"] = d(0.1, -1, -0.05)
	p["R_Thigh"] = d(1, 0.05, 0.12)
	p["R_Calf"] = d(0.1, -1, 0.05)
	p["L_Upperarm"] = d(0.35, -1, -0.25)
	p["L_Forearm"] = d(1, -0.2, 0.25)
	p["R_Upperarm"] = d(0.35, -1, 0.25)
	p["R_Forearm"] = d(1, -0.2, -0.25)
	p["blade"] = d(0, -1, 0)
	p["Spine01"] = lean(0.05 + b)
	return p

static func talk(t: float) -> Dictionary:
	## Standing chat with a small hand gesture.
	var p: Dictionary = idle_free(t)
	p["R_Upperarm"] = d(0.45, -1, 0.35)
	p["R_Forearm"] = d(1, 0.35 + sin(t * 5.0) * 0.25, 0.1)
	p["blade"] = d(0, -1, 0)
	return p

## Unarmed (sword on the back): arms hang loose instead of holding a guard.
static func idle_free(t: float) -> Dictionary:
	var b: float = sin(t * 2.0) * 0.025
	var p: Dictionary = {}
	base_legs(p, 0.13)
	p["L_Upperarm"] = d(0.04, -1, -0.24 - b)
	p["L_Forearm"] = d(0.28, -1, -0.12)
	p["R_Upperarm"] = d(0.04, -1, 0.24 + b)
	p["R_Forearm"] = d(0.28, -1, 0.12)
	p["blade"] = d(0, -1, 0)
	p["Spine02"] = lean(0.02 + b)
	return p

static func run_free(phase: float, speed: float) -> Dictionary:
	## Both arms swing opposite the legs.
	var p: Dictionary = run(phase, speed)
	var s: float = sin(phase)
	p["L_Upperarm"] = d(-0.65 * s * speed, -1, -0.24)
	p["L_Forearm"] = d(0.35 - 0.55 * s * speed + 0.4 * speed, -0.8, -0.1)
	p["R_Upperarm"] = d(0.65 * s * speed, -1, 0.24)
	p["R_Forearm"] = d(0.35 + 0.55 * s * speed + 0.4 * speed, -0.8, 0.1)
	p["blade"] = d(0, -1, 0)
	return p

static func reach_back(t: float) -> Dictionary:
	## Right hand up over the shoulder to the sword on the back (draw/sheathe).
	## t 0..1: reach up, hold at the hilt, bring forward.
	var p: Dictionary = idle_free(0.0)
	var up: float = sin(clampf(t, 0, 1) * PI)
	p["R_Upperarm"] = d(0.2 - 0.25 * up, -1.0 + 2.1 * up, 0.35)
	p["R_Forearm"] = d(-0.25 * up, -1.0 + 1.6 * up, -0.35 * up)
	p["blade"] = d(-0.2, -1, -0.3)
	p["Spine02"] = yaw(-0.18 * up)
	return p
