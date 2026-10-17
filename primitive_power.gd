extends RefCounted

# Only a world without electrical infrastructure may omit the modern baseline.
static func applies(model, body: String, economy: Dictionary, types: Dictionary, external: Dictionary) -> bool:
	if not bool(model.preset.get("adam_eve_scenario",false)) or model.world == null or not model.world.exists(body): return false
	# Native scales grow slightly even during the first day. Knowledge or a hut
	# alone is not evidence of electrification; require a real source/consumer.
	for key: String in ["capacity","vehicles","jobs_now"]:
		if float(external.get(key,0)) > 0: return false
	for key: String in ["capacity_old","capacity_stations"]:
		if float(economy.get(key,0)) > 0: return false
	for item: Dictionary in economy.get("enterprises",[]):
		if float(item.get("levels",0)) <= 0: continue
		var type: Dictionary = types.get(str(item.get("type","")),{})
		if float(type.get("entry",{}).get("energy",0)) > 0 or float(type.get("output",{}).get("energy",0)) > 0: return false
	return true

static func clear_baseline(economy: Dictionary) -> void:
	for key: String in ["capacity","capacity_total","load"]: economy[key] = 0.0
	if not economy.get("fulfilled_need") is Dictionary: economy["fulfilled_need"] = {}
	# With no electrical consumers there is no unmet electricity requirement.
	economy.fulfilled_need["energy"] = 1.0
