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
	game.hud.buttons=[{"rect":Rect2(555,610,156,75),"action":"fire"},{"rect":Rect2(390,610,156,75),"action":"reload"},{"rect":Rect2(225,610,156,75),"action":"brace"},{"rect":Rect2(886,29,83,42),"action":"pause"}]
	touch(Vector2(115,620),2); drag(Vector2(115,578),2)
	touch(Vector2(1155,620),3); drag(Vector2(1185,620),3)
	check(game.hud.joystick.y<-.6 and game.hud.aim_direction.x>.9,"Independent movement and aim sticks")
	check(not game.held("fire"),"Inner aim ring does not fire")
	drag(Vector2(1217,620),3); check(game.held("fire"),"Outer aim ring fires with two thumbs")
	game.refresh_aim(); check(game.aim_point.x>game.player.position.x,"Aim stick directs world aim")
	touch(Vector2(600,650),4); touch(Vector2(1217,620),3,false)
	check(game.held("fire") and game.hud.joystick.y<-.6,"Aim release preserves separate fire and movement")
	touch(Vector2(600,650),4,false); check(not game.held("fire"),"Last fire release stops shooting")
	game.gear.items[0].ammo=3; touch(Vector2(450,650),5)
	check(game.gear.action=="reload","Reload is a tap action")
	game.player.position=Vector3(-4,0,3.48); touch(Vector2(280,650),6)
	check(game.player.mode=="cover","Cover is a tap action")
	touch(Vector2(915,50),7); check(game.mode=="paused" and game.hud.joystick==Vector2.ZERO and not game.held("fire"),"Pause clears all touch state")
	game.mode="play"; game.hud.scale_ui=.5; game.hud.offset_ui=Vector2(40,0)
	touch(Vector2(97.5,310),8); drag(Vector2(128.5,310),8)
	check(game.hud.joystick.x>.95,"Scaled phone coordinates map to stick correctly")
	touch(Vector2(128.5,310),8,false); check(game.hud.joystick==Vector2.ZERO,"Scaled touch release stops movement")
	print("RESULT: %d passed, %d failed"%[passed,failed])
	game.queue_free(); await process_frame; await process_frame; quit(1 if failed else 0)
