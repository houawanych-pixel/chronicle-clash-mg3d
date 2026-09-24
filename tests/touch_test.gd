extends SceneTree
const Game=preload("res://scripts/Game.gd")
var game: Node3D
var passed: int=0
var failed: int=0
func check(ok: bool,label: String) -> void:
	if ok: passed+=1; print("PASS ",label)
	else: failed+=1; push_error("FAIL "+label)
func touch(at: Vector2,id: int,down: bool=true) -> void:
	var e: InputEventScreenTouch=InputEventScreenTouch.new(); e.position=at; e.index=id; e.pressed=down; game.hud._input(e)
func drag(at: Vector2,id: int) -> void:
	var e: InputEventScreenDrag=InputEventScreenDrag.new(); e.position=at; e.index=id; game.hud._input(e)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	game=Game.new(); game.muted=true; root.add_child(game); game.set_physics_process(false)
	await process_frame; await process_frame
	game.hud.buttons=[{"rect":Rect2(174,525,360,57),"action":"confirm"}]
	touch(Vector2(250,550),1); check(game.mode=="brief","Touch start opens briefing")
	touch(Vector2(250,550),1,false); touch(Vector2(250,550),1); check(game.mode=="play","Touch Play starts room")
	touch(Vector2(250,550),1,false)
	game.hud.buttons=[{"rect":Rect2(1070,522,180,180),"action":"fire"},{"rect":Rect2(1153,217,86,86),"action":"reload"},{"rect":Rect2(880,400,110,110),"action":"action"},{"rect":Rect2(892,28,80,80),"action":"pause"}]
	touch(Vector2(170,570),2);drag(Vector2(170,512),2)
	game.command("aim");touch(Vector2(720,430),3);drag(Vector2(780,430),3)
	check(game.hud.joystick.y<-.6 and game.lab.yaw!=0,"Independent movement stick and look drag")
	check(not game.held("fire"),"Look drag does not fire")
	touch(Vector2(1160,612),4);check(game.held("fire"),"Large FIRE button shoots")
	game.refresh_aim();check(game.aim_point.distance_to(game.player.position)>1,"Look drag directs world aim")
	touch(Vector2(780,430),3,false)
	check(game.held("fire") and game.hud.joystick.y<-.6,"Look release preserves separate fire and movement")
	touch(Vector2(1160,612),4,false);check(not game.held("fire"),"Last fire release stops shooting")
	game.gear.items[0].ammo=3;touch(Vector2(1196,260),5)
	check(game.gear.action=="reload","Reload is a tap action")
	game.player.position=Vector3(-4,0,3.48);game.player.toggle_cover();touch(Vector2(935,455),6)
	check(game.goals.has("knock"),"Context ACTION knocks in wall cover")
	touch(Vector2(932,68),7);check(game.mode=="paused" and game.hud.joystick==Vector2.ZERO and not game.held("fire"),"Pause clears all touch state")
	game.mode="play";game.hud.scale_ui=.5;game.hud.offset_ui=Vector2(40,0)
	touch(Vector2(125,285),8);drag(Vector2(163,285),8)
	check(game.hud.joystick.x>.95,"Scaled phone coordinates map to stick correctly")
	touch(Vector2(163,285),8,false);check(game.hud.joystick==Vector2.ZERO,"Scaled touch release stops movement")
	print("RESULT: %d passed, %d failed"%[passed,failed])
	game.queue_free(); await process_frame; await process_frame; quit(1 if failed else 0)
