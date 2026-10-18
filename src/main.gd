extends PaxMod
const L = preload("res://mods/adam_eve/src/localization/localization.gd")
var _localization: Node

# All changes are conditional on the scenario marker. No global data patches.
var _restored := false
var _initialized := false
var _world_id := 0
var _saved_faction: Dictionary = {}

func _mod_loaded() -> void:
	L.configure(load_json("data/lang/ru.json",{}),load_json("data/lang/en.json",{}))
	_localization = L.new(); add_child(_localization); _localization.setup(_localization_roots)
	hook("ai_request", _narrator)
	hook("economy_week", _economy_week)
	Pax.replace_service("power_grid", path("src/simulation/power_grid.gd"))
	Pax.register_command("adam_eve_status", _status, "adam_eve_status — check the Adam and Eve scenario")

func _active(game: PaxGame) -> bool:
	return game != null and bool(game.scene_root().model.preset.get("adam_eve_scenario", false))

func _game_loaded(_game: PaxGame, state: Dictionary) -> void:
	_restored = bool(state.get("initialized", false))
	_saved_faction = state.get("faction", {}).duplicate(true) if state.get("faction", {}) is Dictionary else {}

func _world_ready(game: PaxGame) -> void:
	if not _active(game):
		_initialized = false
		_restored = false
		return
	var root: Node = game.scene_root()
	if root.get_instance_id() == _world_id and _initialized:
		return
	_world_id = root.get_instance_id()
	_initialized = _restored or game.day() > 0
	_restored = false
	_restore_lone_faction(game)
	_keep_founders_in_memory(game)
	_refresh_primitive_power(game,game.home_body())
	if not _initialized:
		# WayOfLife.start is queued by the game before world_ready. Run after it,
		# so its economy and government seeding cannot recreate starting goods.
		call_deferred("_initialize", game, _world_id)

func _initialize(game: PaxGame, world_id: int) -> void:
	if not _active(game) or game.scene_root().get_instance_id() != world_id or _initialized:
		return
	var root: Node = game.scene_root()
	var model = root.model
	var earth: String = game.home_body()
	model.sim.res["humans"] = 2.0
	model.sim.res["energy"] = 0.0
	model.sim.res["raw_materials"] = 0.0
	model.sim.res["trust"] = 0.7
	var stock: Dictionary = game.resources(earth)
	for key in stock.keys():
		if stock[key] is float or stock[key] is int:
			stock[key] = 0.0
	stock["humans"] = 2.0
	stock["production"] = {}
	stock["upkeep"] = {}
	var economy: Dictionary = game.econ.of(earth)
	if not economy.is_empty():
		economy["enterprises"] = []
		economy["capacity_old"] = 0.0
		economy["capacity_stations"] = 0.0
		preload("res://mods/adam_eve/src/simulation/primitive_power.gd").clear_baseline(economy)
	model.mines.clear()
	model.laws.clear()
	model.research_list.clear()
	model.organization_list.clear()
	if model.armies != null:
		model.armies.units.clear()
		model.armies.off_earth.clear()
	if model.earth_provinces != null:
		model.earth_provinces.survivors.fill(0.0)
		model.earth_provinces.survivors_distributed = true
		model.earth_provinces.capacity_.fill(0.0)
	if model.world != null and model.world.exists(earth):
		var colony: Dictionary = model.world.colonies[earth]
		for key in colony["scales"]:
			colony["scales"][key] = 0.0
		colony["machinery"] = 0.0
		colony["budget_year"] = 0.0
		colony["corruption"] = 0.0
		colony["corruption_base"] = 0.0
		colony["record_people"] = 2.0
	model.hotspots.clear()
	model.developed = 0.0
	game.set_body_param(earth, "urban", 0.0)
	root.world_genesis().send_hearths()
	# The player is an abstract controller, never a third resident.
	var old_hero: String = str(root.player.hero.get("name", ""))
	var memory = model.get("memory")
	if memory != null and old_hero != "" and old_hero not in ["Адам", "Ева"]:
		memory.refresh_header("person", old_hero, {"gone": "Условный образ игрока; отдельным жителем мира не является"})
	model.sim.leader = {"name": "Адам", "age": 25, "who": "Первый мужчина"}
	root.player.hero = model.sim.leader.duplicate()
	_prune_government(root)
	for person in [
		{"name": "Адам", "who": "Первый мужчина", "age": 25, "lore": "Живёт с Евой. На всей Земле только два человека. Готовых технологий и инструментов не знает.", "character": "Любознательный, деятельный, учится на собственных опытах", "wants": "Найти воду, еду и безопасное укрытие"},
		{"name": "Ева", "who": "Первая женщина", "age": 24, "lore": "Живёт с Адамом. На всей Земле только два человека. Готовых технологий и инструментов не знает.", "character": "Наблюдательная, самостоятельная, внимательная к растениям и животным", "wants": "Узнать окружающий мир и научиться жить в нём"}
	]:
		if not game.has_character(str(person["name"])):
			game.add_character(earth, person)
	_keep_founders_in_memory(game)
	_initialized = true
	_refresh_primitive_power(game,earth)
	game.chronicle(earth, "Первый день человечества. Адам и Ева стоят у реки. Вокруг — лес, звери и никем не заселённая Земля. Ни запасов, ни орудий, ни укрытия. Игрок направляет их первые шаги.", "neutral", 4)
	root.lore_builder().refresh()
	root.hud().refresh_header()
	log_info("Adam and Eve initialized: 2 humans, 1 faction, no starting supplies or enterprises")

func _refresh_primitive_power(game: PaxGame, body: String) -> void:
	if not _active(game): return
	var root: Node = game.scene_root()
	var economy: Dictionary = game.econ.of(body)
	var policy: Script = preload("res://mods/adam_eve/src/simulation/primitive_power.gd")
	if policy.applies(root.model,body,economy,root.econ.types,root.power_grid().load_without_economy(body)):
		policy.clear_baseline(economy)

func _economy_week(data: Dictionary) -> void:
	if _active(Pax.game): _refresh_primitive_power(Pax.game,str(data.get("body",Pax.game.home_body())))

func _keep_founders_in_memory(game: PaxGame) -> void:
	var root: Node = game.scene_root()
	var memory = root.model.get("memory")
	if memory == null:
		return
	for person: String in ["Адам", "Ева"]:
		if game.has_character(person):
			# Pin contacts against Memory.thin_out; do not alter age or revive anyone.
			memory.refresh_header("person", person, {"not_forget": "true", "last_conversation": str(root.model.sim.turn)})

func _restore_lone_faction(game: PaxGame) -> void:
	var root: Node = game.scene_root()
	if not root.model.factions.is_empty():
		return
	# Native saves omit the player's row. With zero foreign factions the native
	# loader leaves the whole list empty; restore only our identity, not economy.
	var profile: Dictionary = root.model.preset.get("factions", [{}])[0]
	var point: Array = profile.get("capital", [37.61,39.65])
	var latitude: float = deg_to_rad(float(point[0]))
	var longitude: float = deg_to_rad(float(point[1]))
	var capital := Vector3(cos(latitude)*sin(longitude),sin(latitude),cos(latitude)*cos(longitude))
	var stored_point: Array = _saved_faction.get("capital",[])
	if stored_point.size() == 3: capital = Vector3(stored_point[0],stored_point[1],stored_point[2])
	var tint: Array = _saved_faction.get("colour",profile.get("colour",[0.42,0.75,0.4]))
	root.model.factions.append({"name":str(_saved_faction.get("name",profile.get("name","Эдем"))),"type":"ours","ours":true,
		"capital":capital,"colour":Color(tint[0],tint[1],tint[2]),"radius":0.0,"description":str(_saved_faction.get("description",profile.get("lore",""))),
		"met":true,"polity":true,"level":float(profile.get("level",0)),"fighters":0.0})
	root.model.our_faction = 0

func _prune_government(root: Node) -> void:
	var state: Dictionary = root.power.state_
	if state.is_empty():
		return
	var people: Dictionary = state.get("humans", {})
	for key in people.keys():
		if str(key) not in ["Адам", "Ева"]:
			people.erase(key)
	state["ministries"] = []
	state["ministers"] = {}
	state["prisoners"] = 0.0
	state["political_prisoners"] = []
	state["head_of_it"]["name"] = "Адам"
	for key in ["parliament", "upper"]:
		if state.get(key) is Dictionary:
			state[key]["parties"] = []
			state[key]["exists"] = false
	state["elections"] = {}

func _save_state(game: PaxGame) -> Dictionary:
	if not _active(game): return {}
	var ours: Dictionary = game.player_faction()
	var point: Vector3 = ours.get("capital",Vector3.ZERO)
	var tint: Color = ours.get("colour",Color(0.42,0.75,0.4))
	return {"initialized": _initialized, "faction":{"name":str(ours.get("name","Эдем")),"description":str(ours.get("description","")),"capital":[point.x,point.y,point.z],"colour":[tint.r,tint.g,tint.b]}}

func _narrator(d: Dictionary) -> void:
	if not _active(Pax.game):
		return
	var rules: Dictionary = Pax.game.scene_root().model.preset.get("story", {})
	d["system"] = str(d.get("system", "")) + "\n\n" + L.text(str(rules.get("rules_for_ai", "")))

func _status(_args: PackedStringArray) -> String:
	if not _active(Pax.game):
		return "Adam and Eve is installed; this game uses another scenario."
	var game: PaxGame = Pax.game
	var earth: String = game.home_body()
	return JSON.stringify({"initialized": _initialized, "people": game.people(earth), "other_countries": game.countries(), "stock": game.resources(earth), "enterprises": game.econ.of(earth).get("enterprises", []), "adam": game.has_character("Адам"), "eve": game.has_character("Ева")})

func _localization_roots() -> Array:
	if not _active(Pax.game): return []
	return Pax.game.scene_root().get_children().filter(func(node: Node): return node is CanvasLayer or node is Control or node is Window)

func _mod_unloaded() -> void:
	if is_instance_valid(_localization): _localization.queue_free()
	_localization = null
