extends Node
const Data = preload("res://scripts/Data.gd")
var game: Node
var items: Array = []
var selected: int = 0
var cooldown: float = 0.0
var action_time: float = 0.0
var action_total: float = 0.0
var action: String = ""
var muzzle_time: float = 0.0
var switch_time: float = 0.0
var scope: bool = false
var zoom: int = 0
var jam_countdown: int = 260
var fail_clear: bool = false
var shot_serial: int = 0
func _ready() -> void: reset()
func reset() -> void:
	items = Data.equipment()
	for item: Dictionary in items:
		item.ammo = item.capacity
		item.heat = 0.0
		item.jammed = false
	selected = 0
	cooldown = 0
	action_time = 0
	action = ""
	scope = false
	fail_clear = false
	muzzle_time = 0
	switch_time = 0
	jam_countdown = randi_range(240,300)
func current() -> Dictionary: return items[selected]
func equip(index: int) -> void:
	selected = posmod(index,items.size())
	action_time = 0
	action = ""
	scope = false
	switch_time = .35
	game.sound("cover",-13)
func tick(delta: float) -> void:
	cooldown = maxf(0,cooldown-delta)
	muzzle_time = maxf(0,muzzle_time-delta)
	switch_time = maxf(0,switch_time-delta)
	for item: Dictionary in items: item.heat = maxf(0,item.heat-delta*2.5)
	if action_time > 0:
		action_time = maxf(0,action_time-delta)
		if action_time == 0: finish_action()
func finish_action() -> void:
	var item: Dictionary = current()
	if action == "reload":
		var amount: int = mini(item.capacity-item.ammo,item.reserve)
		item.ammo += amount
		item.reserve -= amount
		game.mark_goal("reload")
		game.sound("reload",-8)
	elif action == "clear":
		if fail_clear:
			fail_clear = false
			game.toast("Still jammed! Switching to sidearm.")
			equip(0)
		else:
			item.jammed = false
			item.heat = 20.0
			jam_countdown = randi_range(240,300)
			game.toast("Weapon cleared. Ready.")
			game.sound("reload",-8)
	action = ""
func reload() -> void:
	var item: Dictionary = current()
	if action_time > 0: return
	if bool(item.jammed):
		action = "clear"
		action_total = 2.0
	elif selected < 4 and item.ammo < item.capacity and item.reserve > 0:
		action = "reload"
		action_total = float(item.reload)
	else: return
	action_time = action_total
	game.sound("reload",-12)
func force_jam(persistent: bool) -> void:
	equip(1)
	items[1].jammed = true
	fail_clear = persistent
	game.toast("Oh, F—! Rifle jammed. RELOAD to clear, or switch.")
	game.sound("bleep",-7)
func toggle_scope() -> void:
	if selected == 2 or selected == 7:
		scope = not scope
		if selected == 7 and scope: game.mark_goal("binoculars")
	else: game.toast("Select binoculars or the sniper to use the scope.")
func fire() -> void:
	if action_time > 0 or cooldown > 0 or switch_time > 0: return
	var item: Dictionary = current()
	if selected == 7:
		scope = true
		game.mark_goal("binoculars")
		game.mark_aimed_guard()
		cooldown = .3
		return
	if selected == 8:
		if game.player.health >= 100: game.toast("Health is full."); return
		if item.ammo <= 0: game.toast("No rations left. Resupply at the console."); return
		item.ammo -= 1
		game.player.health = minf(100,game.player.health+45)
		game.mark_goal("ration")
		game.sound("chip")
		cooldown = .6
		return
	if item.jammed:
		game.toast("JAMMED — RELOAD to clear, or equip a sidearm.")
		game.sound("empty",-13)
		cooldown = .5
		return
	if item.ammo <= 0:
		game.sound("empty",-12)
		game.toast("Empty. RELOAD or switch equipment.")
		cooldown = .5
		return
	if selected == 1 and jam_countdown <= 0 and item.heat > 45:
		force_jam(false)
		return
	item.ammo -= 1
	shot_serial += 1
	cooldown = float(item.get("interval",.65))
	game.player.exposed_time = 1.5
	var origin: Vector3 = game.player.target_point()
	var target: Vector3 = game.aim_point
	var direction: Vector3 = (target-origin).normalized()
	if direction.length()<.5: direction = game.player.facing
	if selected < 3:
		var hit: Dictionary = game.ray(origin,origin+direction*65,29,[game.player.get_rid()])
		var end: Vector3 = hit.get("position",origin+direction*65)
		game.tracer(origin,end,Color("ffcf75"),.07)
		game.flash_at(origin+direction*.55)
		game.eject_case(origin,direction)
		muzzle_time = .13
		game.sound("rifle" if selected==1 else ("sniper" if selected==2 else "pistol"),-9)
		game.emit_noise(origin,float(item.noise))
		if hit.has("collider") and hit.collider.has_method("receive_hit"):
			hit.collider.receive_hit(float(item.damage),str(item.id),end)
		if selected==1:
			jam_countdown -= 1
			item.heat = minf(100,item.heat+1.1)
	elif selected == 3:
		game.spawn_projectile("rocket",origin+direction*.6,direction*17)
		game.sound("rocket",-9)
		game.emit_noise(origin,20)
	elif selected == 4:
		var flat: Vector3 = direction
		flat.y = 0
		var distance: float = clampf(origin.distance_to(target),3,12)
		game.spawn_projectile("grenade",origin+flat.normalized()*.6,flat.normalized()*distance+Vector3.UP*7)
		game.mark_goal("grenade")
		game.sound("cover")
	else:
		game.place_mine("claymore" if selected==5 else "remote")
		if selected==5: game.mark_goal("claymore")
func detonate() -> void:
	var detonated: bool = false
	for mine: Node3D in game.mines.duplicate():
		if is_instance_valid(mine) and mine.kind == "remote":
			mine.explode()
			detonated = true
	if detonated: game.mark_goal("detonate")
	else: game.toast("Place a remote mine first.")
func replenish() -> void:
	for item: Dictionary in items:
		item.ammo = item.capacity
		if item.has("damage"): item.reserve = int(Data.equipment()[items.find(item)].reserve)
	game.player.cloak_energy = 100
	game.toast("Ammo, tools and camouflage recharged.")
