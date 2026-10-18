extends Node
## Scenario-scoped map assets and a schematic annual sea-ice cycle.
const BASE := "assets/maps/earth_holocene"
const STOCK_INCLUDE := '#include "res://shaders/planet_surface.gdshaderinc"'
const CELL_AREA := 6371.0 * 6371.0 * (TAU / 4096.0) * (PI / 2048.0)
var owner_mod: Node
var game_ref: WeakRef
var materials: Array = []
var _flat_viewports: Array = []
var _albedo: Texture2D
var _ocean: Texture2D
var _ice: Texture2D
var _world_id := 0
var _changed_cells := 0
var _removed_area := 0.0
var _phase := 1.0
var _elapsed := 0.0
var _regions: RefCounted
var _original_regions: Dictionary = {}
var _original_map := ""
var model: Dictionary = {}
var _sources: RefCounted
var _sources_registered := false

func setup(owner: Node) -> void:
	owner_mod = owner; model = owner.load_json("data/holocene_world.json",{})
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sources = preload("res://mods/adam_eve/src/world/holocene_sources.gd").new(); _sources.setup(self)

static func applies(game: Object) -> bool:
	return game != null and bool(game.scene_root().model.preset.get("adam_eve_scenario",false)) and int(game.scene_root().model.preset.get("adam_eve_geography_version",0)) == 1

static func north_winter(day: float) -> float:
	# Day zero is March 1. Maximum near mid-March; opposite phase in Antarctica.
	return (1.0 + cos((day-14.0)/365.2422*TAU))*0.5

func world_ready(game: RefCounted) -> void:
	if not applies(game):
		dispose(); return
	var root: Node = game.scene_root()
	if _world_id == root.get_instance_id(): return
	if _world_id != 0: dispose()
	materials.clear(); _world_id = root.get_instance_id(); game_ref = weakref(game)
	_albedo = owner_mod.texture(BASE+"_albedo.webp")
	_ocean = owner_mod.texture(BASE+"_ocean.png")
	_ice = owner_mod.texture("assets/maps/sea_ice.png")
	if _albedo == null or _ocean == null or _ice == null:
		owner_mod.log_warning("Holocene map textures could not be loaded"); return
	_regions = root.model.earth_provinces
	_clip_water(_regions)
	var body: Dictionary = game.body("Земля")
	_original_map = str(body.get("map","earth"))
	body["map"] = owner_mod.path(BASE)
	var material: Material = game.body_material("Земля")
	if material is ShaderMaterial: _configure_material(material)
	update_season(game)
	owner_mod.log_info("Holocene geography ready: %d newly flooded pixels" % _changed_cells)

func _clip_water(regions: RefCounted) -> void:
	_changed_cells = 0; _removed_area = 0.0; _original_regions.clear()
	if regions == null or regions.map.is_empty(): return
	_original_regions = {"map":regions.map.duplicate(),"water":regions.water.duplicate(),"list":regions.list_.duplicate(true),"owners":regions.owner_of.duplicate()}
	regions.list_ = regions.list_.duplicate(true)
	var raw: PackedByteArray = owner_mod.read_bytes("assets/maps/water_cells.bin")
	var indices: PackedInt32Array = raw.to_int32_array()
	var area_lost: Dictionary = {}
	for index: int in indices:
		var x: int = index % 4096; var y: int = index / 4096
		var target_x: int = mini(regions.sh-1,int((x+0.5)*regions.sh/4096.0))
		var target_y: int = mini(regions.v_m-1,int((y+0.5)*regions.v_m/2048.0))
		var pixel: int = target_y*regions.sh+target_x
		var offset: int = pixel*2
		if offset+1 >= regions.map.size(): continue
		var id: int = int(regions.map[offset]) | (int(regions.map[offset+1]) << 8)
		if id <= 0: continue
		regions.map[offset] = 0; regions.map[offset+1] = 0
		if pixel < regions.water.size(): regions.water[pixel] = 255
		var area: float = CELL_AREA*cos((90.0-(y+0.5)*180.0/2048.0)*PI/180.0)
		area_lost[id] = float(area_lost.get(id,0.0))+area
		_changed_cells += 1; _removed_area += area
	for id: int in area_lost:
		var entry: Dictionary = regions.entry(id)
		entry["area"] = maxf(0.0,float(entry.get("area",0))-area_lost[id])
		entry["coast"] = true; entry["on_water"] = true
		if float(entry.area) == 0 and id < regions.owner_of.size(): regions.owner_of[id] = ""
	# Refresh existing texture objects too: HUD layers may already hold these references.
	if regions._textures.has("map"):
		regions._textures.map.update(Image.create_from_data(regions.sh,regions.v_m,false,Image.FORMAT_RG8,regions.map))
	if regions._textures.has("water"):
		regions._textures.water.update(Image.create_from_data(regions.sh,regions.v_m,false,Image.FORMAT_L8,regions.water))
	regions.version += 1

func _configure_material(material: ShaderMaterial) -> bool:
	if material == null or material.shader == null: return false
	var source: String = material.shader.code
	if material.get_meta("adam_eve_holocene",false): return true
	if not source.contains(STOCK_INCLUDE): return false
	var wrapper: String = '#define surface adam_eve_native_surface\n'+STOCK_INCLUDE+'\n#undef surface\n#include "'+owner_mod.path("shaders/holocene_surface.gdshaderinc")+'"'
	var original: Shader = material.shader
	var parameters: Dictionary = {}
	for key: String in ["map_albedo","map_ocean","use_map","use_ocean","use_height"]: parameters[key] = material.get_shader_parameter(key)
	# The flat-map style selector recognizes the native Shader by object identity.
	# Keep that identity; the added surface function is gated off by default, so
	# other materials sharing it retain the native appearance. Restore on disposal.
	var shared_flat: bool = source.begins_with("shader_type canvas_item")
	var shader: Shader = original if shared_flat else Shader.new()
	if shared_flat: wrapper = wrapper.replace('#include "'+owner_mod.path("shaders/holocene_surface.gdshaderinc"), '#define ADAM_EVE_FLAT\n#include "'+owner_mod.path("shaders/holocene_surface.gdshaderinc"))
	shader.code = source.replace(STOCK_INCLUDE,wrapper)
	material.shader = shader; material.set_meta("adam_eve_holocene",true)
	materials.append({"ref":weakref(material),"shader":original,"parameters":parameters,"source":source if shared_flat else ""})
	material.set_shader_parameter("map_albedo",_albedo)
	material.set_shader_parameter("map_ocean",_ocean)
	material.set_shader_parameter("use_map",1.0); material.set_shader_parameter("use_ocean",1.0)
	material.set_shader_parameter("use_height",0.0)
	material.set_shader_parameter("holocene_sea_ice",_ice)
	material.set_shader_parameter("holocene_north_winter",_phase)
	material.set_shader_parameter("holocene_enabled",1.0)
	return true

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.5 or game_ref == null: return
	_elapsed = 0.0
	var game: Object = game_ref.get_ref()
	if not is_instance_valid(game) or not applies(game): return
	if not _sources_registered and _sources != null: _sources_registered = _sources.register()
	# The native flat map is created lazily. Attach the same private shader wrapper.
	var root: Node = game.scene_root()
	var map: Variant = root.get("political_map")
	if map is Node and is_instance_valid(map):
		var earth: bool = bool(map.get("_is_earth"))
		var pending: Array = [map]
		while not pending.is_empty():
			var node: Node = pending.pop_back()
			pending.append_array(node.get_children())
			if not node is CanvasItem or not node.material is ShaderMaterial: continue
			if node.material.get_meta("adam_eve_holocene",false):
				var enabled: float = 1.0 if earth else 0.0
				if node.material.get_shader_parameter("holocene_enabled") != enabled:
					node.material.set_shader_parameter("holocene_enabled",enabled); _redraw_flat()
			elif earth:
				if _configure_material(node.material) and node.get_viewport() is SubViewport:
					_flat_viewports.append(weakref(node.get_viewport()))
					_redraw_flat()
	update_season(game)

func update_season(game: Object) -> void:
	var phase: float = north_winter(float(game.day()))
	if is_equal_approx(phase,_phase): return
	_phase = phase
	for record: Dictionary in materials:
		var material: Object = record.ref.get_ref()
		if is_instance_valid(material): material.set_shader_parameter("holocene_north_winter",_phase)
	_redraw_flat()

func _redraw_flat() -> void:
	for reference: WeakRef in _flat_viewports:
		var viewport: Object = reference.get_ref()
		if is_instance_valid(viewport): viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func dispose() -> void:
	if _sources != null: _sources.release()
	_sources_registered = false
	var game: Object = game_ref.get_ref() if game_ref != null else null
	if is_instance_valid(game) and is_instance_valid(game.scene_root()) and _original_map != "": game.body("Земля")["map"] = _original_map
	for record: Dictionary in materials:
		if str(record.get("source","")) != "": record.shader.code = record.source
		var material: Object = record.ref.get_ref()
		if not is_instance_valid(material): continue
		material.shader = record.shader
		material.set_shader_parameter("holocene_enabled",0.0)
		for key: String in record.get("parameters",{}): material.set_shader_parameter(key,record.parameters[key])
		material.remove_meta("adam_eve_holocene")
	materials.clear(); _flat_viewports.clear()
	if is_instance_valid(_regions) and not _original_regions.is_empty():
		_regions.map = _original_regions.map; _regions.water = _original_regions.water
		_regions.list_ = _original_regions.list; _regions.owner_of = _original_regions.owners
		if _regions._textures.has("map"): _regions._textures.map.update(Image.create_from_data(_regions.sh,_regions.v_m,false,Image.FORMAT_RG8,_regions.map))
		if _regions._textures.has("water"): _regions._textures.water.update(Image.create_from_data(_regions.sh,_regions.v_m,false,Image.FORMAT_L8,_regions.water))
		_regions.version += 1
	_original_regions.clear(); _regions = null; game_ref = null; _original_map = ""; _world_id = 0

func _exit_tree() -> void: dispose()

func describe() -> Dictionary:
	var game: Object = game_ref.get_ref() if game_ref != null else null
	if not is_instance_valid(game) or not applies(game): return {"ok":false,"code":"adam_eve.environment_not_active"}
	return {"ok":true,"result":{"period_bce":4000,"global_temperature_reference":model.get("global_anomaly_vs_1850_1900_c",{}),"temperature_reference_is_not_a_local_measurement":true,"features":model.get("features",[]),"north_winter_fraction":_phase,"south_winter_fraction":1.0-_phase,"permanent_ice":["Greenland","Antarctica"],"sea_ice_is_schematic":true,"new_water_pixels":_changed_cells,"new_water_area_km2":_removed_area,"render_materials":materials.size()}}

func narrative(language: String) -> String:
	if language == "ru": return "ПРИРОДА СЦЕНАРИЯ: приблизительный средний голоцен, около 4000 года до н. э. Сахара — мозаика степей, саванн, озёр и сухих участков; Мега-Чад около 350 тысяч км². Туркана крупнее, юг Аравии влажнее. Гренландия и Антарктида покрыты льдом, в Арктике и вокруг Антарктиды морской лёд меняется по противоположным сезонам. В марте северный лёд близок к максимуму, южный — к минимуму. Нет ледниковых щитов над Канадой и Скандинавией. Берега Персидского залива и Балтики показаны схематично. Диапазон +0,2…+1,0 °C — оценка глобального среднего относительно 1850–1900, не температура отдельной провинции; нельзя выдавать её за точные местные измерения. Сюжет двух первых людей — художественная условность, не историческая реконструкция населения."
	return "SCENARIO ENVIRONMENT: approximate mid-Holocene, around 4000 BCE. The Sahara contains steppe, savanna, lakes and drier patches; Mega-Chad is about 350,000 km². Turkana is larger and southern Arabia wetter. Greenland and Antarctica retain land ice; Arctic and Antarctic sea ice have opposite seasonal cycles. March is near the northern maximum and southern minimum. Canada and Scandinavia have no continental ice sheets. Persian Gulf and Baltic shorelines are schematic. The +0.2–1.0 °C range describes global mean temperature relative to 1850–1900, not measured local province temperatures. The two-first-humans story is fictional rather than a reconstruction of prehistoric populations."
