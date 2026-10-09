extends SceneTree

var failures=0
var checks=0

func check(ok: bool, label: String):
	checks+=1
	if not ok:
		failures+=1
		push_error("FAIL: "+label)

func near(a: float,b: float)->bool:return absf(a-b)<.000001

func _initialize():
	if not ResourceLoader.exists("res://scripts/fire_siege_state.gd"):
		check(false,"Fire Siege deterministic runtime exists")
		finish();return
	var State=load("res://scripts/fire_siege_state.gd")
	var s=State.new()
	# Catches carried confirmation and advancing while interrupted/dead.
	check(not s.update_start(3,true,true),"A carried Y hold cannot start the opening setup")
	s.update_start(0,false,true)
	check(not s.update_start(1.5,true,true) and near(s.start_progress,.5),"Y needs a complete three-second confirmation")
	s.update_start(.6,false,true)
	check(near(s.start_progress,.3),"Released start confirmation decays")
	check(s.update_start(2.1,true,true),"Reholding finishes the remaining confirmation")
	check(s.get("start_permit")==true,"Completed confirmation grants one manual wave launch")
	check(not s.update_start(30,true,true),"A completed hold requires release before reuse")
	s.interrupt_inputs();s.update_start(0,false,true);s.update_start(2,true,true)
	s.interrupt_inputs()
	check(s.get("start_permit")==false,"Interruption revokes any stale wave launch")
	check(near(s.start_progress,0) and not s.update_start(3,true,true),"Interruption clears progress and requires release")
	s.update_start(0,false,true)
	check(not s.update_start(3,true,false),"Dead or unavailable heroes cannot confirm")
	# Catches skipped demand, zero-time spawning, and spawning beyond 60 seconds.
	s.start_wave()
	check(s.advance_wave(.199).due==0,"No enemy arrives before 0.2 seconds")
	check(s.advance_wave(.001).due==1,"The first enemy arrives at 0.2 seconds")
	check(s.advance_wave(59.8).due==299,"A delayed update emits all demand through 60 seconds")
	check(s.advance_wave(500).due==0 and near(s.wave_elapsed,60),"Spawning stops permanently at 300")
	for step in [1.0/30,1.0/60,1.0/144,.37]:
		s.start_wave();var count=0;var remaining=60.0
		while remaining>0.00000001:
			var dt=minf(step,remaining);count+=s.advance_wave(dt).due;remaining-=dt
		check(count==300,"Frame partitions preserve 300 scheduled enemies at step %.6f" % step)
	# Catches integer truncation, clearance farming, idle-free towers, and debt.
	for step in [1.0/30,1.0/60,1.0/144,.37]:
		var gold=10.0;var paid=0.0;var remaining=60.0
		while remaining>0.00000001:
			var dt=minf(step,remaining);var ledger=s.economy(gold,dt,dt,12,true)
			gold=ledger.money;paid+=ledger.powered_delta;remaining-=dt
		check(near(gold,58) and near(paid,60),"Mine/upkeep ledger is frame independent at step %.6f" % step)
	var ledger=s.economy(0,10,0,12,true)
	check(near(ledger.money,0) and near(ledger.powered_delta,0),"Clearance provides no mine income and never incurs debt")
	ledger=s.economy(.06,1,0,12,false)
	check(near(ledger.powered_delta,.05) and near(ledger.money,0),"Insufficient money buys equal partial power for all twelve towers")
	ledger=s.economy(0,1,1,1,true)
	check(near(ledger.money,1.9) and near(ledger.powered_delta,1),"Mine income restores power before upkeep")
	ledger=s.economy(0,2.5,2.5,2,3)
	check(near(ledger.money,14.5) and near(ledger.powered_delta,2.5),"Each of three mines earns independently before two towers pay fractional upkeep")
	ledger=s.economy(14.5,2,0,2,3)
	check(near(ledger.money,14.1),"All mine income stops during clearance while tower upkeep continues")
	# Catches completion charging early, release losing all work, affordability bypass.
	var build=s.build_step(0,1.5,true,true,3)
	check(near(build.progress,.5) and not build.completed,"Tower is unpurchased while half assembled")
	build=s.build_step(build.progress,1,false,true,3)
	check(near(build.progress,.25),"Released construction decays without discarding remaining work")
	build=s.build_step(build.progress,2.25,true,true,3)
	check(build.completed and near(build.progress,1),"Reholding finishes remaining construction")
	build=s.build_step(.8,1,true,false,3)
	check(not build.completed and near(build.progress,.55),"Unaffordable held construction decays")
	# Catches duplicate rewards and terminal ordering, including dead final victory.
	s.reset();var reward=0
	for wave in range(1,11):
		check(s.settle(wave,100,1,0,true)==0,"Wave %d cannot settle before clearance" % wave)
		reward+=s.settle(wave,100,0,0,true)
		check(s.settle(wave,100,0,0,true)==0,"Wave %d reward cannot repeat" % wave)
	check(reward==550,"Ten settlements pay exactly 550 including the final 100")
	s.reset();check(s.settle(10,0,0,0,true)==0,"Base failure wins over simultaneous final clearance")
	# Catches stacked death timers, duplicate revival and stale run resurrection.
	var old_generation=s.generation
	check(s.hero_died() and not s.hero_died() and near(s.revive_left,5),"Repeated death callbacks never stack or reset the five-second timer")
	check(not s.advance_revive(4.9) and s.hero_dead,"Hero stays dead before five active seconds")
	check(s.advance_revive(.1) and not s.hero_dead,"Five seconds triggers one automatic revival")
	check(not s.advance_revive(5) and not s.revive_now(),"A living hero cannot revive twice")
	s.hero_died();check(s.revive_now() and not s.hero_dead,"Revive Now skips the remaining delay once")
	s.hero_died();s.terminate()
	check(not s.advance_revive(100) and not s.revive_now(),"Terminal transition cancels pending revival")
	s.reset()
	check(s.generation>old_generation and not s.hero_dead and near(s.start_progress,0),"Reset invalidates the old generation and clears transient state")
	actor_resolution()
	finish()

func actor_resolution():
	var director=load("res://scripts/fire_siege.gd").new()
	var actor=load("res://scripts/enemy.gd").new()
	director.active=true;director.money=10;director.alive_count=1
	actor.defense_lane=1;actor.encounter_id="test_current"
	actor.set_meta("siege_generation",director.generation)
	director.wave_actors[actor.encounter_id]=weakref(actor)
	director.record_defeat(actor)
	check(director.alive_count==1 and director.wave_kills==0,"Living actors cannot resolve as kills")
	actor.dead=true;director.record_defeat(actor);director.record_defeat(actor)
	check(director.alive_count==0 and director.wave_kills==1 and director.run_kills==1 and director.money==10,"A real actor resolves once without kill gold")
	director.runtime.reset();director.alive_count=1
	check(not director.owns(actor),"Previous-generation actors lose ownership immediately")
	director.record_defeat(actor)
	check(director.alive_count==1 and director.wave_kills==1,"Stale deaths cannot alter replacement-run accounting")
	var speed=director.defense_speed(actor)
	director.runtime.hero_died()
	check(near(director.defense_speed(actor),speed*1.35),"Hero death speeds actual route actors by exactly 35 percent")
	director.runtime.revive_now()
	check(near(director.defense_speed(actor),speed),"Revival restores the original route speed")
	actor.free();director.free()

func finish():
	print("FIRE_SIEGE_STATE_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
