extends "res://scripts/recovered_leaders_tests.gd"
const Model=preload("res://scripts/forest/forest_model.gd")

func run():
	var model=Model.new()
	model.reset(42,{},JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_wind_meadow.json")),false)
	var waves=model.waves
	check(waves.countdown_text().contains("ONE ARRIVAL EVERY 00:03"),"Preparation shows the spawn interval")
	model.start_wave()
	var totals=[29,58,116,174,261,348,464,580]
	for index in totals.size():
		check(waves.slime_scheduled_total()==totals[index],"Wave %d has the exact cumulative fresh total"%(index+1))
		check(waves.slime_active_sides()==mini(4,index/2+1),"A new side opens every minute")
		waves.tick(19.9,Vector3.ZERO)
		check(not waves.countdown_text().contains("OPENS"),"Entrance warning never appears early")
		waves.tick(.1,Vector3.ZERO)
		check(waves.countdown_text().contains("OPENS")== (index in [1,3,5]),"Only an upcoming entrance gets a ten-second warning")
		waves.tick(10,Vector3.ZERO)
	model.phase="preparing";waves.begin();waves.tick(180,Vector3.ZERO)
	check(model.wave==7 and waves.slime_scheduled_total()==464 and waves.wave_clock==30,"A long tick carries all due waves without adding locked-side backlog")
	waves.enemy_defeated({"variant":20,"skin":9,"slime_side":3,"level":2,"health_scale":1.1,"damage_scale":1.1})
	var return_record:Dictionary=waves.slime_rebirths[3][0]
	check(return_record.wave==8 and return_record.level==3 and is_equal_approx(return_record.health_scale,1.21),"Each slime death raises its own level for the next-wave return")
	model.phase="preparing";waves.begin()
	check(waves.slime_arrivals==[0,0,0,0] and waves.slime_rebirth_pending==0 and waves.slime_scheduled_total()==29,"Restart clears arrivals, return queues and side unlocks")
	check(waves.role_stats(20).hp==700 and waves.role_stats(20).damage==20,"Fresh default is 700 HP and 20 damage")
	model.balance.enemy_profiles={"20":{"hp":124.0,"damage":6.0}}
	waves.stats_cache.clear()
	check(waves.role_stats(20).hp==124 and waves.role_stats(20).damage==6,"Explicit user balance overrides still win")
	print("SLIME_PROGRESSION_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
