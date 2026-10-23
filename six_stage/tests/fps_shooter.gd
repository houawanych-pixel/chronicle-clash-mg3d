extends SceneTree
## First-person shooter mode checks (Shooter.gd): view switch, move + look, hip fire,
## aim down sights, recoil and recovery, spread, reload, head shots, hit markers.
var game: Node3D
var failures: Array=[]
var checks: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,msg: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",msg)
	if not ok:failures.append(msg)
func step(n: int=1) -> void:
	for i in n:
		game._physics_process(1.0/60)
		await physics_frame
func lane(p: CharacterBody3D) -> Vector3:
	var eye: Vector3=p.global_position+Vector3.UP*1.62
	for i in 16:
		var dir: Vector3=Vector3(sin(i*TAU/16),0,cos(i*TAU/16))
		var at: Vector3=p.global_position+dir*6.0
		var down: Dictionary=game.ray(at+Vector3.UP*1.5,at-Vector3.UP*1.0,49)
		if down.is_empty() or absf(down.position.y-p.global_position.y)>.2: continue
		if not game.clear_sight(eye,at+Vector3.UP*1.6) or not game.clear_sight(eye,at+Vector3.UP*.9): continue
		return Vector3(at.x,down.position.y,at.z)
	return Vector3.INF
func run() -> void:
	game=load("res://scripts/Game.gd").new();root.add_child(game);await physics_frame
	game.set_physics_process(false);game.muted=true;game.stage01.fresh();game.mode="play"
	var p: CharacterBody3D=game.player
	var keep: Node3D=game.guards[0] if game.guards.size()>0 else null
	for g: Node3D in game.guards:
		if g!=keep: g.health=0
	for d: Node3D in game.drones:d.health=0
	if keep: keep.global_position=Vector3(500,0,500)
	await step(5)
	# --- view switch
	check(not game.fps.on and game.camera_controller.view!="fps","starts in third person")
	game.command("view");await step(3)
	check(game.fps.active() and game.camera_controller.view=="fps","VIEW switches to first person")
	check(game.camera.global_position.distance_to(game.fps.eye())<.05 and absf(game.fps.eye().y-p.global_position.y-1.62)<.01,"camera sits at eye height")
	check(not p.avatar.visible and is_instance_valid(game.fps.viewmodel) and game.fps.viewmodel.visible,"own body hidden, first-person gun shown")
	# --- look + move at the same time
	var yaw0: float=game.lab.yaw
	game.lab.look(Vector2(-120,0));await step(2)
	var fw: Vector3=game.fps.flat_dir()
	check(absf(game.lab.yaw-yaw0)>.3 and p.facing.dot(fw)>.99,"looking turns the view and the body")
	var start: Vector3=p.global_position
	game.hud.joystick=Vector2(0,-1);game.hud.joy_id=7
	await step(40)
	game.hud.joystick=Vector2.ZERO;game.hud.joy_id=-99
	var moved: Vector3=p.global_position-start;moved.y=0
	check(moved.length()>1.0 and moved.normalized().dot(fw)>.9,"stick forward walks where you look")
	# --- hip fire without AIM
	var shots: int=game.gear.shot_serial
	game.lab.pitch=0.0
	game.fire_tapped=true;await step(1)
	check(game.gear.shot_serial==shots+1 and not game.lab.aim,"hip fire shoots without AIM")
	# --- recoil kicks up then recovers
	var kicked_pitch: float=game.lab.pitch
	check(kicked_pitch>0.02,"recoil kicks the view up (%.3f)"%kicked_pitch)
	await step(40)
	check(absf(game.lab.pitch)<.005,"recoil recovers back to where you aimed")
	# --- ADS
	var hip_spread: float=game.fps.spread_deg();var hip_fov: float=game.camera.fov
	game.toggle_aim();await step(30)
	check(game.fps.ads and game.camera.fov<hip_fov-10 and game.fps.spread_deg()<hip_spread*.4,"AIM aims down sights: zoom in, tighter spread")
	check(game.hud.buttons.size()>=0 and game.lab.motion.speed(Vector2(0,-1))<2.0,"aiming down sights slows you to a walk")
	game.toggle_aim();await step(30)
	check(not game.fps.ads and absf(game.camera.fov-hip_fov)<1,"AIM again returns to hip")
	# --- automatic rifle: holding FIRE keeps shooting, recoil climbs
	game.gear.equip(1);await step(30)
	game.gear.jam_countdown=999
	var s0: int=game.gear.shot_serial
	game.lab.pitch=0.0
	game.hud.holds.fire=true;await step(60);game.hud.holds.fire=false
	var climbed: float=game.lab.pitch
	check(game.gear.shot_serial-s0>=8,"rifle fires automatically while FIRE is held (%d shots)"%(game.gear.shot_serial-s0))
	check(climbed>.03,"sustained fire climbs (%.3f)"%climbed)
	await step(5)
	check(game.fps.bloom>0,"spread opens up while firing")
	# --- reload
	var ammo0: int=int(game.gear.current().ammo)
	game.command("reload");await step(150)
	check(int(game.gear.current().ammo)==int(game.gear.current().capacity) and ammo0<int(game.gear.current().capacity),"RELOAD refills the magazine")
	# --- head shot vs body shot on a guard (pistol, ADS, no spread)
	game.gear.equip(0);await step(30)
	if keep:
		keep.health=100;keep.state="PATROL";keep.collision_layer=4
		# find a spot with an open, level lane 6 m out
		var front: Vector3=Vector3.INF
		for node: Vector3 in game.stage01.nodes:
			p.global_position=node+Vector3.UP*.05;p.velocity=Vector3.ZERO
			front=lane(p)
			if front!=Vector3.INF: break
		await step(3)
		if front!=Vector3.INF:
			var to: Vector3=front-p.global_position;to.y=0
			game.lab.yaw=atan2(-to.x,-to.z)
		check(front!=Vector3.INF,"found an open lane for the shooting test")
		keep.global_position=front;keep.velocity=Vector3.ZERO
		keep.set_physics_process(false)
		game.toggle_aim();await step(25)
		var body: Vector3=keep.global_position+Vector3.UP*1.0
		var d: Vector3=(body-game.fps.eye()).normalized()
		game.lab.yaw=atan2(-d.x,-d.z);game.lab.pitch=asin(d.y);game.fps.recoil=0;await step(2)
		game.fire_tapped=true;await step(1)
		var after_body: float=keep.health
		check(after_body<100 and after_body>0 and game.fps.hit_time>0 and not game.fps.hit_head,"body shot hurts (hp %d) and shows a hit marker"%after_body)
		await step(20)
		var head: Vector3=keep.global_position+Vector3.UP*1.58
		d=(head-game.fps.eye()).normalized()
		game.lab.yaw=atan2(-d.x,-d.z);game.lab.pitch=asin(d.y);game.fps.recoil=0;game.fps.bloom=0;await step(2)
		game.fire_tapped=true;await step(1)
		check(game.fps.hit_head and keep.health<=0 and game.fps.hit_kill,"head shot does triple damage and kills (hp %d)"%keep.health)
		game.toggle_aim();await step(5)
	else:
		check(false,"no guard on this stage for the head-shot test")
	# --- back to third person
	game.command("view");await step(30)
	check(not game.fps.on and game.camera_controller.view!="fps" and p.avatar.visible and not game.fps.viewmodel.visible,"VIEW returns to third person with the body shown")
	game.toggle_aim();await step(5)
	check(game.lab.aim,"third-person AIM still uses the old first-person aim")
	game.toggle_aim();await step(5)
	print("FPS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
