extends "res://tests/test_world_six_full_runs.gd"
## Reuses the certified solo leader's ordinary-input route controller. Production
## CPU chooses its own source controls. The only assist is refreshed invulnerability
## on both actors; normal falls can clear that protection. No teleport/timer/HP/
## wave/enemy/pickup/clear mutation and no test-only integration gate.
var pair_reports: Array = []
var report_path := ""
var runtime_source_hashes: Dictionary = {}
func run() -> void:
	for path in ["main", "party_session", "party_combat", "party_actor", "companion_ai", "companion_context", "world_six", "billing_combat", "sir_charge", "abilities", "movement_skills"]:
		runtime_source_hashes[path] = FileAccess.get_file_as_string("res://src/%s.gd" % path).sha256_text()
	var game = load("res://main.tscn").instantiate()
	if game.get_script() == null:
		game.free(); printerr("Billing party blocked: main preload failed, no gameplay ran."); quit(1); return
	root.add_child(game); game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var stages: Array = ["6-1","6-2","6-3","6-4","6-5","6-6","6-S"]
	var characters: Array = ["jp"]
	for arg in OS.get_cmdline_user_args():
		if arg == "--trace": trace = true
		if arg == "--all-characters": characters = game.CHARACTERS.duplicate()
		if arg.begins_with("--character="): characters = [arg.trim_prefix("--character=")]
		if arg.begins_with("--stage="): stages = [arg.trim_prefix("--stage=")]
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
	var passed := true
	for character in characters:
		var mate: String = game.CHARACTERS[(game.CHARACTERS.find(character)+1)%game.CHARACTERS.size()]
		for stage in stages:
			if not run_pair(game, stage, character, mate): passed = false
			await process_frame
	game.queue_free(); await process_frame; await process_frame
	quit(0 if passed else 1)
func run_pair(g, id: String, character: String, mate: String) -> bool:
	failures.clear(); climb_target = Vector2.ZERO
	g._show_menu(); g.character = character
	g.save = {"schema":1,"receipts":{},"skills":[],"kitty":0,"seen":{}}
	check(SaveStore.write_save(g.save)==OK,"isolated save")
	check(g.configure_party("cpu",mate),"CPU distinct roster configuration")
	check(g.load_level(id),"stage load")
	var s = g.party_session
	check(s.active and s.runtime.actors.size()==2,"production hidden W6 allowlist not enabled")
	if not failures.is_empty():
		printerr("Billing party BLOCKED ",id,"/",character," ",failures)
		return false
	var leader=s.runtime.actors[0]; var cpu=s.runtime.actors[1]
	check(cpu.cpu and leader.character!=cpu.character and g.combat.participant_count==2,"source pair identity and wave scaling")
	check(leader.movement_skills.skills.is_empty() and cpu.movement_skills.skills.is_empty(),"no unearned skills")
	var source := JSON.stringify(g.meta)
	var planned := 0
	for wave in g.combat.waves: planned += wave.group.size()
	var completed: Array = []; var mini_kind := ""; var phases: Array = []
	var end_frame := -1; var ticks := 0; var catchups := 0; var down_frames := [0,0]; var down_events := [0,0]
	var live_revives := [0,0]; var clear_rescues := [0,0]; var fall_hits := [0,0]; var shot_frames := [0,0]
	var source_spawned := 0
	for frame in range(60000):
		stage_frames=frame; ticks=frame+1
		# Explicit invulnerability-only assist. No health or position writes.
		g.invincible=999; leader.invincible=999; cpu.invincible=999
		var was_down := [leader.down,cpu.down]
		var previous_hp := [leader.hearts,cpu.hearts]
		var cpu_ran: bool = cpu.is_alive()
		g.step(DT, controls_for(g,frame))
		if cpu_ran:
			for event in s.ai.events:
				if event.kind=="catch_up":catchups+=1
		for slot in [0,1]:
			var actor=s.runtime.actors[slot]
			if actor.down:down_frames[slot]+=1
			if actor.down and not was_down[slot]:down_events[slot]+=1
			if not actor.down and was_down[slot]:
				if g.mode=="clear":clear_rescues[slot]+=1
				else:live_revives[slot]+=1
			if actor.hearts<previous_hp[slot]:fall_hits[slot]+=previous_hp[slot]-actor.hearts
			if g.bullets.any(func(b):return not b.enemy and b.get("owner_slot",-1)==slot):shot_frames[slot]+=1
		for i in g.combat.waves.size():
			if g.combat.waves[i].done and i not in completed:completed.append(i)
		if not g.world_six.mini_boss.is_empty():mini_kind=g.world_six.mini_boss.kind
		if g.boss!=null and g.boss.state.phase not in phases:phases.append(g.boss.state.phase)
		if g.world_six.end_time>0 and end_frame<0:end_frame=frame
		check(absf(g.elapsed-ticks*DT)<0.00001 and absf(g.world_six.level_time-ticks*DT)<0.00001 and absf(g.world_six.world_time-ticks*DT)<0.00001,"shared clock not once per source frame")
		if trace and frame%1800==0:print("BILLING PARTY ",id,"/",character,"+",mate," f=",frame," p=",leader.player," cpu=",cpu.player," down=",cpu.down," cam=",g.camera," waves=",completed.size()," enemies=",g.enemies.filter(func(b):return b.state!="pop").map(func(b):return [b.p,b.hp,b.state])," fliers=",g.world_six.fliers.map(func(f):return [f.p,f.hp])," mini=",g.world_six.mini_boss," boss=",g.boss.state if g.boss!=null else {}," hold=",g.world_six.hold)
		if g.mode!="play":break
	check(g.mode=="clear","normal party clear not reached")
	check(JSON.stringify(g.meta)==source,"imported metadata changed")
	if id!="6-S":check(completed.size()==g.combat.waves.size(),"not all authored waves completed")
	check(SaveStore.read_save().get("cleared",{}).get(id,false),"normal clear not persisted")
	check(g.world_six.doors_used.size()==g.level.get("doors",[]).size(),"not all authored doors traversed")
	for index in g.world_six.RECEIPT_REPAIRS.get(id,{}):
		check(g.receipts[index].taken,"repaired receipt %d not physically collected"%index)
		check(index in SaveStore.read_save().receipts.get(id,[]),"repaired receipt %d not persisted"%index)
	if id=="6-1":check(mini_kind=="franker" and g.world_six.mini_boss.state=="down","franker not defeated")
	if id=="6-3":check(mini_kind=="jammer" and g.world_six.mini_boss.state=="down","jammer not defeated")
	if id=="6-2":check(g.world_six.hold.done,"hold not survived")
	if id=="6-4":check(leader.movement_skills.has_skill("super") and cpu.movement_skills.has_skill("super"),"physical super card not shared with both actors")
	if id=="6-6":check(phases.size()==3 and g.boss.state.jar.get("got",false),"all boss phases and real jar not completed")
	else:check(end_frame>=0 and ticks-1-end_frame>=155,"source delayed ending skipped")
	for wave in g.combat.waves:source_spawned+=wave.index
	var report := {"stage":id,"leader":character,"mate":mate,"pass":failures.is_empty(),"ticks":ticks,"waves":completed.size(),"planned_entries":planned,"spawned_entries":source_spawned,"receipts":g.receipts.filter(func(r):return r.taken).size(),"score":g.score,"catchups":catchups,"down_frames":down_frames,"down_events":down_events,"live_revives":live_revives,"clear_rescues":clear_rescues,"fall_health_losses":fall_hits,"shot_frames":shot_frames,"pops":[leader.pop_count,cpu.pop_count],"coins":[leader.coins,cpu.coins],"boss_phases":phases,"failures":failures.duplicate()}
	report.runtime_source_hashes = runtime_source_hashes
	pair_reports.append(report)
	if not report_path.is_empty():
		var output:=FileAccess.open(report_path,FileAccess.WRITE)
		if output!=null:output.store_string(JSON.stringify(pair_reports,"  "))
	var summary := report.duplicate()
	summary.erase("runtime_source_hashes")
	print("Billing party ",JSON.stringify(summary))
	return failures.is_empty()
