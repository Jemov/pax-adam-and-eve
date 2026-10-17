extends "res://src/economy/PowerGrid.gd"
const Primitive = preload("res://mods/adam_eve/primitive_power.gd")

func _primitive(body: String, external: Dictionary) -> bool:
	return Primitive.applies(model,body,model.economies.get(body,{}),game.econ.types,external)

func load_without_economy(body: String, without_order: int = -1) -> Dictionary:
	var result: Dictionary = super.load_without_economy(body,without_order)
	if _primitive(body,result): result["built"] = 0.0
	return result

func power_load(body: String, without_order: int = -1) -> Dictionary:
	if _primitive(body,super.load_without_economy(body,without_order)):
		return {"capacity":0.0,"household":0.0,"built":0.0,"vehicles":0.0,"jobs_now":0.0,"total":0.0,"freely":0.0}
	return super.power_load(body,without_order)
