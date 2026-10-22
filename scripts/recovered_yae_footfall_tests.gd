extends SceneTree
## Catches fixed-Hz footsteps that drift from the recovered gait, missed cues
## during a long update, duplicate loop endpoints and footsteps during non-gaits.
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var model = load("res://scripts/recovered_yae_model.gd").new()
	root.add_child(model)
	await process_frame
	model.set_process(false)
	var locomotion = model.locomotion
	locomotion.reset()
	for i in 180:
		locomotion.update(1.0 / 120.0, Vector3(0, 0, .5), true, 0, 0, false)
	locomotion.evaluate()
	check(locomotion.source_action == 0x0c, "Slow walking uses native gait0C")
	check(locomotion.step_events == 1, "Slow gait emits only its opening footfall before native frame10")
	for i in 21:
		locomotion.update(1.0 / 120.0, Vector3(0, 0, .5), true, 0, 0, false)
	locomotion.evaluate()
	check(locomotion.step_events == 2, "Slow gait second footfall crosses source frame10 at1.6667 seconds")
	check(absf(locomotion.source_time * 6.0 - 10.05) < .0001, "Footfall clock and displayed native frame share the same gait time")
	for i in 201:
		locomotion.update(1.0 / 120.0, Vector3(0, 0, .5), true, 0, 0, false)
	check(locomotion.step_events == 3, "Loop endpoint20 and next frame0 produce one footfall")
	for sample in [[1.3, 0x0d, 2], [2.0, 0x0e, 2], [5.0, 0x0f, 5]]:
		locomotion.reset()
		for i in 120:
			locomotion.update(1.0 / 120.0, Vector3(0, 0, sample[0]), true, 0, 0, false)
		locomotion.evaluate()
		check(locomotion.source_action == sample[1] and locomotion.step_events == sample[2], "Native gait rate determines footfall count: " + str(sample[1]))
	for sample in [[1.3, .60], [2.0, .74], [5.0, .24]]:
		locomotion.reset()
		locomotion.update(sample[1], Vector3(0, 0, sample[0]), true, 0, 0, false)
		check(locomotion.step_events == 1, "No second footfall before native midpoint at speed " + str(sample[0]))
		locomotion.update(.02, Vector3(0, 0, sample[0]), true, 0, 0, false)
		check(locomotion.step_events == 2, "Second footfall crosses native midpoint at speed " + str(sample[0]))
	locomotion.reset()
	locomotion.update(1.25, Vector3(0, 0, 5), true, 0, 0, false)
	check(locomotion.step_events == 6, "Long updates retain all crossed native running footfalls")
	for mode in ["idle", "air", "dodge", "attack"]:
		locomotion.reset()
		locomotion.update(.75, Vector3.ZERO if mode == "idle" else Vector3(0, 0, 5), mode != "air", 5 if mode == "air" else 0, 1 if mode == "attack" else 0, mode == "dodge")
		check(locomotion.step_events == 0, "Non-gait does not emit footfalls: " + mode)
	locomotion.reset()
	locomotion.update(.3, Vector3(0, 0, 5), true, 0, 0, false)
	var before: int = locomotion.step_events
	for i in 5:
		locomotion.dirty = true
		locomotion.evaluate()
	check(locomotion.step_events == before, "Repeated rendering does not replay footfall cues")
	var combat=load("res://scripts/recovered_yae_combat.gd").new()
	root.add_child(combat);model.combat=combat
	combat.mode="bazooka_charge"
	locomotion.reset();locomotion.update(.75,Vector3(0,0,5),true,0,.05,false);locomotion.evaluate()
	check(locomotion.source_action==0x0f,"Holding bazooka charge keeps the original running pose")
	check(locomotion.step_events==4,"Moving bazooka charge retains all four visible native running footfalls")
	combat.mode="primary";combat.action_id=0x68;combat.elapsed=.1
	locomotion.reset();locomotion.update(.75,Vector3(0,0,5),true,0,.05,false);locomotion.evaluate()
	check(locomotion.step_events==0,"An owned katana pose still suppresses locomotion footfalls")
	model.combat=null;combat.queue_free()
	model.queue_free()
	await process_frame
	print("YAE_FOOTFALL_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
