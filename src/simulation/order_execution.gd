extends "res://src/ai/OrderExecution.gd"

# PlanetSim drops one-time yields below 0.5, even though stocks and consumption
# are floats. Preserve only food/water actually awarded by its existing roll.
# Costs, workers, chance, deadlines and the native upper yield cap are unchanged.
func _roll_order(p: Dictionary, report: Dictionary, i, body: String, request: Dictionary) -> Array:
	var result: Array = super._roll_order(p, report, i, body, request)
	return _retain_fractional_food_water(p, body, request, result)

func _retain_fractional_food_water(p: Dictionary, body: String, request: Dictionary, result: Array) -> Array:
	if not bool(model.preset.get("adam_eve_scenario", false)): return result
	var before: Dictionary = Pax.game.econ.snapshot()
	var stock: Dictionary = result[0]
	var outcome: Dictionary = result[1]
	var yields: Dictionary = request.get("yields", {}) if request.get("yields") is Dictionary else {}
	var gained: Dictionary = outcome.get("gained", {})
	var ceiling: float = clampf(float(p["days"]) * 1.5, 10.0, 400.0)
	for resource: String in ["food", "water"]:
		if gained.has(resource): continue
		var amount: float = minf(float(yields.get(resource, 0.0)), ceiling) * float(outcome.get("share", 0.0))
		if is_finite(amount) and amount > 0.0 and amount < 0.5:
			stock[resource] = float(stock.get(resource, 0.0)) + amount
			gained[resource] = amount
	outcome["gained"] = gained
	Pax.game.econ.account_since(before, "orders")
	return result
