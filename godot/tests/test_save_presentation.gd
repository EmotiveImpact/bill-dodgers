extends SceneTree
const Save = preload("res://src/save_store.gd")
const Campaign = preload("res://src/campaign_progression.gd")
var checks := 0
var failures := 0
const PATH := "user://presentation-save-fixture.json"
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: ", message)
func _initialize() -> void:
	var value := {"schema":1,"receipts":{},"cleared":{},"skills":[],"friend":"maya","map_at":"6-6","map_shown":[0,1,1,127,-1,128,2.2,"3",true,null,{},3.0]}
	check(Save.write_save(value,PATH) == OK, "Presentation preferences write atomically")
	var saved := Save.read_save(PATH)
	check(saved.friend == "maya" and saved.map_at == "6-6" and saved.map_shown == [0,1,127,3], "Cast, stage and bounded integer reveal IDs sanitize")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/catalog.json"))
	var state := Campaign.snapshot(saved,catalog)
	check(state.verified_cleared.is_empty() and not state.credits_unlocked and not state.levels["6-6"].playable, "Forged map position/reveals never grant a stage or credits")
	for who in ["jp","maya","ama","leo","theo","mei"]:
		value.friend = who; Save.write_save(value,PATH)
		check(Save.read_save(PATH).friend == who, "Valid chosen housemate " + who)
	for invalid in ["bot","JP","",true,8,[],{},null]:
		value.friend = invalid; Save.write_save(value,PATH)
		check(not Save.read_save(PATH).has("friend"), "Invalid cast preference rejected: " + str(invalid))
	for id in ["HOME","1-1","6-6","4-S"]:
		value.map_at = id; Save.write_save(value,PATH)
		check(Save.read_save(PATH).map_at == id, "Valid map identifier " + id)
	for id in ["home","0-1","7-1","6-7","6-S/../../file",true,null,12,{},[]]:
		value.map_at = id; Save.write_save(value,PATH)
		check(not Save.read_save(PATH).has("map_at"), "Invalid map position rejected: " + str(id))
	value.map_shown = "all"; Save.write_save(value,PATH)
	check(not Save.read_save(PATH).has("map_shown"), "Non-array reveals cannot enable all")
	value.map_shown = range(10000); Save.write_save(value,PATH)
	check(Save.read_save(PATH).map_shown.size() == 128, "Reveal state stays bounded")
	# Party preferences never provide campaign authority. Old saves remain solo
	# unless a supported mode and two distinct original housemates survive read.
	value = {"schema":1,"receipts":{},"cleared":{},"skills":[],"friend":"jp"}
	Save.write_save(value,PATH)
	check(not Save.read_save(PATH).has("party_mode") and not Save.read_save(PATH).has("party_mate"), "Legacy save has no inferred co-op preference")
	for first in ["jp","maya","ama","leo","theo","mei"]:
		for second in ["jp","maya","ama","leo","theo","mei"]:
			for mode in ["solo","cpu","p2"]:
				value.friend = first; value.party_mode = mode; value.party_mate = second
				Save.write_save(value,PATH); saved = Save.read_save(PATH)
				if first == second:
					check(not saved.has("party_mate") and (saved.get("party_mode", "") == "solo" if mode == "solo" else not saved.has("party_mode")), "Duplicate party identity rejected: %s / %s" % [mode,first])
				else:
					check(saved.friend == first and saved.party_mode == mode and saved.party_mate == second, "Distinct party roundtrip: %s / %s / %s" % [mode,first,second])
	value.friend = "jp"; value.party_mate = "maya"
	for invalid in ["online","CPU","",true,8,[],{},null]:
		value.party_mode = invalid; Save.write_save(value,PATH)
		check(not Save.read_save(PATH).has("party_mode"), "Invalid party mode rejected: " + str(invalid))
	for invalid in ["bot","Maya","",true,8,[],{},null]:
		for mode in ["solo","cpu","p2"]:
			value.party_mode = mode; value.party_mate = invalid; Save.write_save(value,PATH); saved = Save.read_save(PATH)
			check(not saved.has("party_mate") and (saved.get("party_mode", "") == "solo" if mode == "solo" else not saved.has("party_mode")), "Invalid party mate rejected: %s / %s" % [mode,str(invalid)])
	value.erase("friend"); value.party_mode = "cpu"; value.party_mate = "jp"; Save.write_save(value,PATH)
	check(not Save.read_save(PATH).has("party_mode") and not Save.read_save(PATH).has("party_mate"), "Absent P1 validates mate against safe JP default")
	value.party_mate = "maya"; Save.write_save(value,PATH); saved = Save.read_save(PATH)
	check(saved.party_mode == "cpu" and saved.party_mate == "maya" and not saved.has("friend"), "Absent P1 permits distinct mate with safe default")
	state = Campaign.snapshot(saved,catalog)
	check(state.verified_cleared.is_empty() and not state.credits_unlocked and not state.levels["1-2"].playable, "Valid party preference grants no clears, unlocks or credits")
	check(not saved.party_confirmed,"Legacy party fields do not forge explicit official selection")
	for flag in [true,false]:
		value.party_confirmed = flag; Save.write_save(value,PATH)
		check(Save.read_save(PATH).party_confirmed == flag,"Explicit boolean selection marker roundtrips: " + str(flag))
	for flag in [1,0,"true","false",[],{},null]:
		value.party_confirmed = flag; Save.write_save(value,PATH)
		check(not Save.read_save(PATH).party_confirmed,"Nonboolean confirmation marker rejected: " + str(flag))
	DirAccess.remove_absolute(PATH)
	print("Presentation save validation: %d checks, %d failures" % [checks,failures]); quit(0 if failures == 0 else 1)
