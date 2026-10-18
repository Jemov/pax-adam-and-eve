extends RefCounted
## Presets can be updated independently of saves. Restore save-owned geography.
static func restored_preset(preset: Dictionary, state: Dictionary) -> Dictionary:
	var result: Dictionary = preset.duplicate(true)
	if not result.get("adam_eve_scenario",false): return result
	var version: int = int(state.get("geography_version",0))
	result["adam_eve_geography_version"] = version
	var start: Variant = state.get("calendar_start")
	if start is Dictionary and start.has_all(["year","month","day"]): result["start"] = start.duplicate(true)
	else: result["start"] = {"year":-4000 if version == 1 else 1,"month":3,"day":1}
	return result
