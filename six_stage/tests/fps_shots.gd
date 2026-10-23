extends SceneTree
## Screenshots of first-person mode (needs a real renderer: run under xvfb).
## usage: godot --path . --script res://tests/fps_shots.gd -- --out=/dir
var game: Node3D
var out: String="/tmp"
func _initialize() -> void:run.call_deferred()
func shot(name: String) -> void:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out+"/"+name+".png")
func run() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out=a.trim_prefix("--out=")
	game=load("res://scripts/Game.gd").new();root.add_child(game);await physics_frame
	game.muted=true;game.stage01.fresh();game.mode="play"
	for i in 20: await physics_frame
	await shot("fp0_third")
	game.command("view")
	for i in 20: await physics_frame
	await shot("fp1_first_hip")
	game.gear.equip(1)
	for i in 30: await physics_frame
	await shot("fp2_rifle_hip")
	game.toggle_aim()
	for i in 30: await physics_frame
	await shot("fp3_rifle_ads")
	game.toggle_aim()
	game.gear.equip(2)
	for i in 30: await physics_frame
	game.toggle_aim()
	for i in 30: await physics_frame
	await shot("fp4_sniper_scope")
	game.toggle_aim()
	game.gear.equip(1)
	for i in 30: await physics_frame
	game.fps.hit_time=.2;game.fps.hit_head=true;game.fps.head_text_time=1.0;game.gear.muzzle_time=.12
	await shot("fp5_hitmarker")
	quit()
