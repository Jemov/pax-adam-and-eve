extends RefCounted
## Optional standard Harness providers. No hard dependency and no eager geometry.
const L = preload("res://mods/adam_eve/src/localization/localization.gd")
const LABELS := {"mega_chad":["Мега-Чад","Mega-Chad"],"turkana":["Озеро Туркана","Lake Turkana"],"persian_gulf":["Персидский залив: древний северный берег","Persian Gulf: northern palaeoshore"],"bothnian_bay":["Ботнический залив: древний берег","Bothnian Bay: palaeoshore"],"arabian_lake":["Древнее озеро Южной Аравии","Southern Arabian palaeolake"]}
var world: Node
var api: Node

func setup(environment: Node) -> void:
	world = environment; api = environment.get_node_or_null("/root/Pax")

func register() -> bool:
	var harness: Node = api.get_mod("pax_harness") if api != null else null
	if harness == null or not harness.has_method("register_analytics_source") or not harness.has_method("register_map_source"): return false
	# Duplicate registration is harmless when the game notifies mods more than once.
	harness.register_analytics_source("adam_eve.geography","Adam and Eve: scenario geography","Approximate 4000 BCE scenario water features, aliases, coordinates, bounds and confidence. Query before drawing; use map provider adam_eve.holocene with feature_ids. Not active in other scenarios.",{"type":"object","properties":{"query":{"type":"string","maxLength":100}},"additionalProperties":false},_read)
	harness.register_map_source("adam_eve.holocene","Adam and Eve: water features (discover via analytics source adam_eve.geography)","Земля",_map)
	return true

func release() -> void:
	var harness: Node = api.get_mod("pax_harness") if is_instance_valid(api) else null
	if harness == null: return
	if harness.has_method("unregister_map_source"): harness.unregister_map_source("adam_eve.holocene",_map)
	if harness.has_method("unregister_analytics_source"): harness.unregister_analytics_source("adam_eve.geography",_read)

func _rows(query: String = "") -> Array:
	var result: Array = []
	for feature: Dictionary in world.model.get("features",[]):
		var id: String = str(feature.id); var names: Array = LABELS.get(id,[id,id])
		if query != "" and not (id+" "+str(names)).to_lower().contains(query.to_lower()): continue
		var bounds: Array = _bounds([feature],0.0)
		result.append({"id":id,"label":names[0] if L.language() == "ru" else names[1],"aliases":names,"kind":"scenario_water_feature","center_lon_lat":[(bounds[0]+bounds[2])*0.5,(bounds[1]+bounds[3])*0.5],"bounds":bounds,"drawn_area_km2":feature.area_km2,"approximate":true,"confidence":feature.confidence,"map_provider":"adam_eve.holocene"})
	return result

func _read(game: Object, parameters: Dictionary, page: Dictionary) -> Dictionary:
	if not world.applies(game): return {"rows":[],"source":"Adam and Eve geography is not active in this campaign","has_more":false}
	var rows: Array = _rows(str(parameters.get("query","")))
	var offset: int = int(page.get("offset",0)); var limit: int = int(page.get("limit",20))
	var finish: int = mini(rows.size(),offset+limit)
	return {"rows":rows.slice(offset,finish),"source":"Adam and Eve 1.2 · approximate mid-Holocene scenario geography; drawn areas are game geometry, not surveyed palaeoshore measurements","has_more":finish < rows.size(),"next_offset":finish}

func _bounds(features: Array, padding: float) -> Array:
	var west := 180.0; var south := 90.0; var east := -180.0; var north := -90.0
	for feature: Dictionary in features:
		for point: Array in feature.polygon:
			west = minf(west,point[0]); east = maxf(east,point[0]); south = minf(south,point[1]); north = maxf(north,point[1])
	return [maxf(-180,west-padding),maxf(-90,south-padding),minf(180,east+padding),minf(90,north+padding)]

func _map(game: Object, args: Dictionary) -> Dictionary:
	if not world.applies(game): return {"ok":false,"code":"adam_eve.environment_not_active"}
	var ids: Array = args.get("feature_ids",[])
	if ids.is_empty() or ids.size() > 16: return {"ok":false,"code":"adam_eve.select_features","result":{"message":"Query analytics source adam_eve.geography, then supply feature_ids from its rows."}}
	var features: Array = []; var labels: PackedStringArray = []
	for id: Variant in ids:
		var found := false
		for feature: Dictionary in world.model.get("features",[]):
			if feature.id != id: continue
			features.append(feature); labels.append(LABELS.get(str(id),[id,id])[0 if L.language() == "ru" else 1]); found = true; break
		if not found: return {"ok":false,"code":"adam_eve.unknown_feature","result":{"id":id}}
	var harness: Node = api.get_mod("pax_harness") if api != null else null
	if harness == null: return {"ok":false,"code":"adam_eve.harness_unavailable"}
	var request: Dictionary = {"body":"Земля","type":args.get("type","choropleth"),"include_water":true,"bounds":_bounds(features,1.0),"title":args.get("title",", ".join(labels))}
	var result: Dictionary = harness.map_provider_tool("charts.map",request)
	if not result.get("ok",false): return result
	result.result.chart["source"] = ("Адам и Ева: приближённая карта около 4000 до н. э.; текущая маска воды игры" if L.language() == "ru" else "Adam and Eve: approximate 4000 BCE geography; live game water mask")
	result.result["selected_feature_ids"] = ids
	return result
