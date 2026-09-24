extends SceneTree
const Game=preload("res://scripts/Game.gd")
var game: Node3D
var passed: int=0
var failed: int=0
func check(value: bool,label: String) -> void:
	if value: passed+=1; print("PASS ",label)
	else: failed+=1; push_error("FAIL "+label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	game=Game.new(); game.muted=true; root.add_child(game); game.set_physics_process(false)
	await physics_frame; await physics_frame
	game.mode="play"
	check(game.rooms.size()==18 and game.guards.size()==1,"Eighteen selectable chambers; baseline has one guard")
	check(game.gear.items.size()==7,"Seven-weapon integrated scope")
	var avatar: Node3D=game.player.avatar
	check(avatar.rig.get_bone_count()==16,"16-bone 3D character")
	check(avatar.rig.get_bone_global_pose(avatar.bones.head).origin.y>1.5,"Skeleton rest pose places head above torso")
	check(avatar.find_children("*","Sprite3D",true,false).is_empty(),"No billboard sprites")
	check(avatar.animation.has_animation("walk") and avatar.animation.has_animation("reload"),"Native animation clips exist")
	avatar.animation.play("walk"); avatar.animation.advance(.18)
	check(absf(avatar.rig.get_bone_pose_rotation(avatar.bones.thigh_l).x)>.1,"Walk clip drives skeleton")
	avatar.animation.play("reload"); avatar.animation.advance(.4)
	check(absf(avatar.rig.get_bone_pose_rotation(avatar.bones.arm_r).x)>.1,"Reload clip moves arm")
	game.player.position=Vector3(-4,0,5)
	for i in range(55): game.player.tick(1.0/60,Vector2(0,-1)); await physics_frame
	check(game.player.mode=="cover","Physical wall pressure enters cover")
	check(game.player.position.z>3.25,"Capsule stays outside cover wall")
	game.update_camera(1)
	check(game.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Wall camera is perspective")
	game.command("knock"); check(game.goals.has("knock"),"Knock works in cover")
	for i in range(110): game.player.tick(1.0/60,Vector2(1,0)); await physics_frame
	check(game.player.peek.length()>.5,"Corner shuffle reaches peek")
	game.player.toggle_cover(); game.update_camera(1)
	check(game.camera_controller.mode=="overhead","Leaving cover restores overhead")
	game.player.position=Vector3(-1,0,0); game.player.mode="ground"
	game.guards[0].position=Vector3(-1,0,-4)
	await physics_frame; await physics_frame
	game.aim_point=game.guards[0].global_position+Vector3.UP
	for i in range(3): game.gear.cooldown=0; game.gear.switch_time=0; game.gear.fire()
	check(game.guards[0].health<=0 and game.goals.has("guard_down"),"Three pistol hits defeat guard")
	check(game.gear.current().ammo==9,"Shots consume magazine ammo")
	game.gear.reload(); check(game.gear.current().ammo==9,"Reload transfer waits for completion")
	game.player._update_visual(.1); check(avatar.current_clip=="reload","Reload state selects 3D clip")
	game.gear.tick(2); check(game.gear.current().ammo==12 and game.gear.current().reserve==141,"Reload conserves ammunition")
	check(game.mission_ready(),"Four objectives satisfied")
	game.player.position=game.rooms[0].exit; game.update_objectives(); check(game.mode=="complete","Extraction completes room")
	game.command("confirm"); check(game.room==0 and game.mode=="brief","Completion restarts valid single room")
	game.mode="play"; game.command("hook"); check(game.player.mode=="ground","Deferred mechanics are disabled")
	game.hud.holds.fire=true; game.command("pause"); check(game.hud.holds.is_empty(),"Pause releases held fire")
	print("RESULT: %d passed, %d failed"%[passed,failed])
	game.queue_free(); await process_frame; await process_frame
	quit(1 if failed>0 else 0)
