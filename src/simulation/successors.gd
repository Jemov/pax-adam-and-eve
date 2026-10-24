extends "res://src/sim/Successors.gd"

const KEY = "adam_eve_continuation"
var _dialog_up := false
var _running := false

static func declare_state(fs: Object) -> void:
	fs.declare(KEY, {}, {"personal":false,"rollback":"keep","epoch":"keep"})

func _scenario() -> bool:
	return bool(model.preset.get("adam_eve_scenario", false))

func _state() -> Dictionary:
	if not model.features.get(KEY) is Dictionary: model.features[KEY] = {}
	return model.features[KEY]

# Use native population counts, not food/money balances or named contacts.
# Earth uses sim.res: loading an empty stock can recreate its preset dictionary
# even though its canonical population remains zero.
func people_remain() -> bool:
	for body in model.resources.stock_:
		if float(game.colony_state().body_people(str(body))) > 0.0: return true
	if float(model.sim.res.get("humans", 0.0)) > 0.0: return true
	if model.factions_sim != null:
		for f: Dictionary in model.factions_sim.foreign_ones():
			if not bool(f.get("perished", false)) and float(f.get("humans", 0.0)) > 0.0: return true
	if model.earth_provinces != null:
		for count: float in model.earth_provinces.survivors:
			if count > 0.0: return true
	return false

func _restore_extinct_colonies() -> void:
	# Preserve a saved, genuine extinction when the native loader reconstructs
	# an empty stock from the starting preset. Never touch a living colony.
	if _state().is_empty() or not model.humanity_perished: return
	for body in model.resources.stock_.keys():
		if model.world.perished_f(str(body)) and float(game.colony_state().body_people(str(body))) <= 0.0:
			model.resources.stock_.erase(body)

func _say(ru: String, en: String) -> String:
	return ru if Pax.game != null and Pax.game.language() == "ru" else en

func _event() -> Dictionary:
	var state := _state()
	if state.is_empty() or bool(state.get("completed", false)):
		var learned: Array = []
		for n: Dictionary in model.features.get("research_tree", {}).get("nodes", []):
			if str(n.get("state", "")) == "done": learned.append(str(n.get("name", "")))
		var development := {}
		for body in model.world.colonies:
			development[str(body)] = model.world.colonies[body].get("scales", {}).duplicate(true)
		state.clear()
		state.merge({"decision":"pending","day":model.sim.day,"completed":false,"learned":learned,"development":development})
		if model.memory != null:
			model.memory.remember_it("system", "Солнечная система", model.sim.turn,
				_say("История этого мира началась с Адама и Евы. Сейчас все люди действительно исчезли. Их фактически достигнутые знания: ", "This world began with Adam and Eve. All humans have now actually disappeared. Their achieved knowledge: ")
				+ str(learned) + "; " + str(development), 5)
	return state

func humans_died_out() -> void:
	if not _scenario():
		super.humans_died_out()
		return
	if people_remain():
		model.humanity_perished = false
		rewind_state._waiting_evolution = false
		return
	_event()
	if model.player_species.is_empty() and model.memory != null:
		for founder: String in ["Адам", "Ева"]:
			if Pax.game.has_character(founder):
				model.memory.refresh_header("person", founder, {"gone":_say("Прежнее человечество полностью исчезло", "Former humanity is completely extinct")})
	super.humans_died_out()

func resume_choice() -> void:
	if not _scenario(): return
	_restore_extinct_colonies()
	if people_remain() or not model.humanity_perished: return
	var state := _state()
	if not state.is_empty() and not bool(state.get("completed", false)) and str(state.get("decision", "")) != "end":
		evolution()

func evolution() -> void:
	if not _scenario():
		await super.evolution()
		return
	_restore_extinct_colonies()
	if people_remain():
		model.humanity_perished = false
		rewind_state._waiting_evolution = false
		return
	rewind_state._waiting_evolution = false
	if _running or _dialog_up: return
	var state := _event()
	if str(state.get("decision", "")) == "end": return
	if str(state.get("decision", "")) == "continue":
		_run_native()
		return
	_dialog_up = true
	game.save_game().store()
	Pax.game.show_choice(
		_say("История общины закончилась. История мира может продолжиться", "The community's story has ended. The world's story can continue"),
		_say("Людей больше не осталось ни в наших колониях, ни в других живых общинах. Гибель одних Адама и Евы при живых потомках не приводит к этому выбору.\n\nМожно завершить эту историю или продолжить штатную историю мира после людей. Игра сама рассчитает большой промежуток эволюции и покажет свои карточки о новом разумном виде и его развитии. Это не воскресшие основатели и не незаметно появившиеся дети. Следы прежней общины зависят от того, что она действительно успела создать. До вашего выбора время не переносится.",
		"No people remain in our colonies or other living communities. The founders' deaths alone do not cause this choice while descendants survive.\n\nYou can end this story or continue the game's native world history after humanity. The game calculates its own long evolutionary interval and shows its existing cards about a new intelligent species and its development. They are neither resurrected founders nor unseen children. Traces depend on what the previous community actually achieved. Time does not jump before your choice."),
		PackedStringArray([_say("Завершить историю этой общины", "End this community's story"), _say("Продолжить штатную историю мира", "Continue the native world history")]),
		func(index: int):
			_dialog_up = false
			state["decision"] = "continue" if index == 1 else "end"
			game.save_game().store()
			if index == 1: call_deferred("_run_native"))

func _run_native() -> void:
	if _running or people_remain(): return
	_running = true
	await super.evolution()
	_state()["completed"] = true
	_running = false
	game.save_game().store()

func successors_appeared(i: int, years_after: float) -> void:
	super.successors_appeared(i, years_after)
	if not _scenario(): return
	# Keep all native populations, times, random choices, portraits and cards.
	# Offline native cards otherwise have no history text at all.
	if game.provider == null or not game.provider.connected():
		model.player_species["history"] = _say(
			"Мир, начавшийся с Адама и Евы, пережил настоящее исчезновение прежнего человечества. После рассчитанного игрой промежутка эволюции здесь появился новый разумный вид. Это новая история жизни, а не воскрешение первой пары. Память о прежней общине и её знаниях сохранена в хронике.",
			"The world that began with Adam and Eve outlived the actual extinction of its former humanity. After the game's calculated evolutionary interval, a new intelligent species arose. This is a new history of life, not the founders' resurrection. The previous community and its knowledge remain in the chronicle.")

static func context(model_: Variant, russian: bool) -> String:
	var people: float = float(model_.sim.res.get("humans", 0.0))
	if not model_.player_species.is_empty():
		return ("ТЕКУЩИЙ ЭТАП ВАЖНЕЕ ОПИСАНИЯ СТАРТА: прежнее человечество действительно вымерло, и игрок выбрал штатное продолжение истории мира. Сейчас существует новый разумный вид, созданный механизмом игры. Адам и Ева — исторические основатели прежнего человечества, не живые участники и не предки этого нового вида. Используй настоящие календарь, численность, уровни и сохранённые следы; не навязывай развитые руины маленькой неразвитой общине. " if russian else
		"CURRENT PHASE OVERRIDES STARTING LORE: former humanity actually became extinct and the player chose the game's native continuation. A new intelligent species now exists through the native mechanism. Adam and Eve are historical founders of former humanity, not living characters or ancestors of this new species. Use the actual calendar, populations, levels and preserved traces; do not invent advanced ruins for a community that never developed them. ") + str(model_.features.get(KEY, {}))
	return ("ОПИСАНИЕ ДВУХ ЛЮДЕЙ — УСЛОВИЕ НАЧАЛА, НЕ ВЕЧНЫЙ ЛИМИТ. Текущая численность главной общины по модели: " if russian else
		"TWO PEOPLE DESCRIBES THE START, NOT A PERMANENT LIMIT. Current main-community population in the model: ") + str(people) + (". Рост и потомки разрешены. Смерть основателей не означает вымирание человечества при живых людях. Список контактов не заменяет учёт населения; не воскрешай умерших и не выдумывай отдельных детей из дробной демографической величины." if russian else
		". Growth and descendants are allowed. The founders' deaths do not mean humanity is extinct while people survive. Contacts are not a population census; never resurrect the dead or invent individual children from fractional demographic accounting.")
