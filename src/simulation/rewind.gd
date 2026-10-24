extends "res://src/sim/RewindSystem.gd"

func _people_elsewhere() -> bool:
	if bool(model.preset.get("adam_eve_scenario", false)):
		# Check before native report cards are composed, including positive
		# fractional communities that the native >= 1 check would round away.
		return game.successors().people_remain()
	return super._people_elsewhere()
