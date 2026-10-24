extends RefCounted

const Native = preload("res://src/preset/PresetSession.gd")
const Meta = preload("res://src/preset/PresetMeta.gd")
const RulesFile = preload("res://src/preset/WorldRulesFile.gd")
const BUNDLED = "res://mods/adam_eve/presets/Адам и Ева — с нуля/"
const FILES = ["development", "events_bodies", "guests", "mysteries", "prologue", "start", "world_formulas"]

# Existing full installations and versioned saves may still carry 1.2.1's
# two low-population freezes. Migrate exactly those expressions in memory;
# preserve all other custom rules and the user's files.
static func read(file: String) -> Dictionary:
	var data: Dictionary = RulesFile._base_read(file)
	if file.ends_with("data/world_formulas.json") and bool(Meta.migrated(file.trim_suffix("data/world_formulas.json")).get("adam_eve_scenario", false)):
		var rules: Dictionary = data.get("rules", {})
		for point: String in ["people.birthrate", "people.mortality"]:
			if str(rules.get(point, "")) == "default * min(1, max(0, people - 19))": rules.erase(point)
	return data

# 0.32.6 installs a mod preset's top-level files without its data directory.
# Keep complete installed/versioned presets; use the shipped layer only when
# this scenario is missing data. Other worlds always use the native path.
static func activate(folder: String, slot: String) -> Array:
	if bool(Meta.migrated(folder).get("adam_eve_scenario", false)):
		for name: String in FILES:
			if RulesFile.read(folder + "data/" + name + ".json").is_empty():
				return Native._base_activate(BUNDLED, slot)
	return Native._base_activate(folder, slot)
