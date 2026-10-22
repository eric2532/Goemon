extends SceneTree
## Breaks caught: duplicated logical time, stale live targets, and lost actors
## when one authoritative world step spans several physics frames.
const Model=preload("res://scripts/forest/forest_model.gd")
const EMPTY={"format":"forest_shrine_map","schema":1,"title":"Sliced world","buildings":[],"trees":[],"deposits":[]}
const HERO=Vector3(0,0,-120)
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
func fresh():
	var m=Model.new();m.reset(42,{},EMPTY);m.workers.clear();m.phase="wave"
	m.waves.pending=999;m.waves.spawn_clock=10;m.workforce.assignment_clock=5;m.sight_clock=5
	return m
func frozen_actor(m,x:float):
	var e=m.waves.spawn_enemy(0,Vector3(x,0,90));e.frozen=.8;return e
func drain(m,limit:int=1,hero:Vector3=HERO):
	var attempts=0
	while m.wave_step_active() and attempts<1000:m.advance_wave_slice(limit,hero);attempts+=1
	check(not m.wave_step_active(),"A bounded drain completes the captured world step")
func cycle_time():
	var m=fresh();var actors=[]
	for x in 5:actors.append(frozen_actor(m,60+x*4))
	var shooter=m.waves.spawn_enemy(1,Vector3(120,0,120));shooter.frozen=.8
	m.waves.arrows.launch(m.waves.projectiles,shooter,"hero",0,Vector3(180,2.2,120))
	var arrow:Dictionary=m.waves.projectiles.values()[0];var start:Vector3=arrow.pos
	m.begin_wave_step(.1,HERO)
	check(m.wave_step_active() and m.wave_step_count()==6,"Begin captures the complete stable roster")
	check(absf(arrow.pos.distance_to(start)-3.6)<.001,"Projectile flight advances once at cycle begin")
	check(is_equal_approx(m.waves.spawn_clock,9.9),"Spawn clock consumes one logical delta at begin")
	check(is_equal_approx(actors[0].frozen,.8),"Begin defers actor simulation")
	check(not m.advance_wave_slice(2,HERO),"A partial slice reports pending work")
	for index in 5:
		check(is_equal_approx(actors[index].frozen,.7 if index<2 else .8),"Slice advances only its bounded actors %d"%index)
	check(is_equal_approx(m.workforce.assignment_clock,5) and is_equal_approx(m.sight_clock,5),"Partial slices defer workforce and sight clocks")
	check(not m.waves.defender_snapshot_active,"A partial slice releases its defender snapshot")
	m.begin_wave_step(.4,HERO)
	check(m.wave_step_count()==6,"A repeated begin preserves pending captured work")
	drain(m,2)
	for actor in actors:
		check(is_equal_approx(actor.frozen,.7),"Every captured actor consumes the same delta exactly once")
		check(actor.get("simulation_revision",0)==1,"Only processed sliced actors acquire one local revision")
	check(is_equal_approx(m.workforce.assignment_clock,4.9) and is_equal_approx(m.sight_clock,4.9),"Finishing advances workforce and sight exactly once")
	check(absf(arrow.pos.distance_to(start)-3.6)<.001 and is_equal_approx(m.waves.spawn_clock,9.9),"Additional slices do not advance projectile or spawn time")
	check(m.advance_wave_slice(2,HERO) and is_equal_approx(m.sight_clock,4.9),"Advancing a finished cycle has no side effects")
	m.tick(.2,HERO)
	check(is_equal_approx(actors[0].frozen,.5) and not actors[0].has("simulation_revision"),"Direct ticks stay synchronous and restore global revision fallback")

func live_roster():
	var m=fresh();var first=frozen_actor(m,60);var killed=frozen_actor(m,70);var removed=frozen_actor(m,80);var last=frozen_actor(m,90)
	m.begin_wave_step(.1,HERO);m.advance_wave_slice(1,HERO)
	m.damage_enemy(killed.id,10000);m.enemies.erase(removed.id)
	var newborn=frozen_actor(m,100)
	drain(m)
	check(is_equal_approx(first.frozen,.7) and is_equal_approx(last.frozen,.7),"Removal between slices neither repeats nor loses surviving actors")
	check(not m.enemies.has(killed.id) and not killed.has("simulation_revision"),"An enemy killed between slices is cleaned without being simulated")
	check(is_equal_approx(removed.frozen,.8) and is_equal_approx(newborn.frozen,.8),"Removed actors and post-capture arrivals do not consume the old delta")
	m.begin_wave_step(.1,HERO);drain(m)
	check(is_equal_approx(newborn.frozen,.7),"A post-capture arrival joins the next cycle")
	check(first.simulation_revision==2 and last.simulation_revision==2,"Survivors receive exactly one new revision per cycle")

func live_targets():
	var m=fresh();var a=m.waves.spawn_enemy(0,Vector3(0,0,90));var b=m.waves.spawn_enemy(0,Vector3(0,0,90))
	m.defenders[201]={"id":201,"pos":Vector3(8,0,90),"hp":100,"targetable":true,"taunting":true}
	m.begin_wave_step(.05,HERO);m.advance_wave_slice(1,HERO)
	check(a.target_kind=="defender" and a.target_id==201,"First slice acquires the live taunting defender")
	# The native helper replaces dictionaries each frame, so mutating the old
	# row would fail to reproduce the actual stale snapshot bug.
	m.defenders={202:{"id":202,"pos":Vector3(-8,0,90),"hp":100,"targetable":true}}
	m.advance_wave_slice(1,HERO)
	check(b.target_kind=="defender" and b.target_id==202,"A later slice sees replaced defender rows and forgets the stale taunt")
	check(not m.waves.defender_snapshot_active,"The final slice releases its defender snapshot")
	m.defenders.clear();a.action="walk";b.action="walk"
	m.begin_wave_step(.05,HERO);m.advance_wave_slice(1,HERO);m.advance_wave_slice(1,Vector3(0,0,85))
	check(b.target_kind=="hero" and b.target_id==0,"A later slice uses the current hero position for acquisition")
	check(m.hero_position==Vector3(0,0,85),"The model retains the latest slice hero position")

func cancel_reset_and_direct():
	var m=fresh();var a=frozen_actor(m,60);var b=frozen_actor(m,70)
	m.begin_wave_step(.1,HERO);m.advance_wave_slice(1,HERO);m.cancel_wave_step()
	check(not m.wave_step_active() and m.advance_wave_slice(1,HERO),"Cancellation discards pending actor work")
	check(is_equal_approx(b.frozen,.8) and is_equal_approx(m.workforce.assignment_clock,5),"Cancellation never ticks an unprocessed actor or workforce")
	m.begin_wave_step(.1,HERO);m.advance_wave_slice(1,HERO);m.tick(.2,HERO)
	check(is_equal_approx(a.frozen,.4) and is_equal_approx(b.frozen,.5),"A direct tick first finishes pending work then consumes its own requested time")
	check(is_equal_approx(m.workforce.assignment_clock,4.7),"Pending completion plus direct tick each advance workforce once")
	check(not a.has("simulation_revision") and not b.has("simulation_revision"),"Direct simulation clears prior sliced revision keys")
	m.begin_wave_step(.1,HERO);m.advance_wave_slice(1,HERO);m.reset(43,{},EMPTY)
	check(not m.wave_step_active() and m.advance_wave_slice(1,HERO),"Reset cannot resume work captured by the previous run")
	check(m.enemies.is_empty() and m.phase=="preparing","Reset preserves the new run after stale continuation")
	m=fresh();a=frozen_actor(m,60);m.begin_wave_step(0,HERO)
	check(not m.wave_step_active() and is_equal_approx(a.frozen,.8),"A zero-duration begin cannot create work")

func direct_actor_revision():
	var m=fresh();var sliced=frozen_actor(m,60);var waiting=frozen_actor(m,70)
	m.begin_wave_step(.1,HERO);m.advance_wave_slice(1,HERO)
	m.waves.tick_enemy(sliced,.05,HERO)
	check(sliced.simulation_revision==2 and is_equal_approx(sliced.frozen,.65),"A public actor tick invalidates a previously sliced actor during pending work")
	check(not waiting.has("simulation_revision"),"A public actor tick leaves untouched pending actors without revision keys")
	drain(m)
	m.waves.tick_enemy(sliced,.05,HERO)
	check(sliced.simulation_revision==3 and is_equal_approx(sliced.frozen,.6),"A public actor tick invalidates a sliced actor after cycle completion")
	var ordinary=frozen_actor(m,80);m.waves.tick_enemy(ordinary,.05,HERO)
	check(not ordinary.has("simulation_revision") and is_equal_approx(ordinary.frozen,.75),"Ordinary direct actor ticks retain global revision fallback")
	m.tick(.1,HERO)
	check(not sliced.has("simulation_revision") and not waiting.has("simulation_revision"),"A full synchronous tick restores global fallback after public actor ticks")

func defeat_and_finish():
	var m=fresh();var giant=m.waves.spawn_enemy(2,Vector3(0,0,12));var survivor=frozen_actor(m,90)
	m.shrine().hp=1;m.waves.start_attack(giant,"building",1,HERO);giant.action_left=.01
	m.begin_wave_step(.1,HERO)
	check(m.advance_wave_slice(2,HERO) and m.phase=="defeat","Shrine destruction aborts the cycle immediately")
	check(is_equal_approx(survivor.frozen,.8) and not survivor.has("simulation_revision"),"Actors after a fatal shrine strike remain unprocessed")
	check(is_equal_approx(m.workforce.assignment_clock,5) and is_equal_approx(m.sight_clock,5),"Defeat skips workforce and sight completion")
	check(m.waves.projectiles.is_empty() and not m.waves.defender_snapshot_active,"Defeat clears projectiles and snapshot state")
	m=fresh();frozen_actor(m,60);frozen_actor(m,70);m.begin_wave_step(.1,HERO);m.advance_wave_slice(1,HERO)
	m.waves.projectiles[999]={};m.phase="defeat"
	check(m.advance_wave_slice(1,HERO) and not m.wave_step_active() and m.waves.projectiles.is_empty(),"An external phase change aborts pending work before projectile or actor access")
	m=fresh();m.waves.pending=0;var dead=frozen_actor(m,60);dead.hp=0;var gold:int=m.gold
	m.begin_wave_step(.1,HERO);m.advance_wave_slice(1,HERO)
	check(m.phase=="preparing" and m.gold==gold+100,"The completed empty wave gives exactly one reward and phase transition")
	check(m.events.filter(func(event):return event.kind=="preparing").size()==1,"Wave completion dispatches one phase event")
	m.advance_wave_slice(1,HERO)
	check(m.gold==gold+100 and is_equal_approx(m.workforce.assignment_clock,5),"Repeated completion does not reward or advance workforce again")

func spawn_once():
	var m=fresh();m.waves.pending=12;m.waves.remaining_counts=[12,0,0,0];m.waves.spawn_clock=0
	m.begin_wave_step(.1,HERO);var spawned:int=m.waves.spawned
	check(spawned>0 and m.wave_step_count()==spawned,"Actors spawned at begin are included in that cycle's stable roster")
	drain(m)
	check(m.waves.spawned==spawned and is_equal_approx(m.waves.spawn_clock,.13),"Draining a cycle cannot spawn a second batch")

func run():
	var m=fresh()
	for method in ["begin_wave_step","advance_wave_slice","cancel_wave_step","wave_step_active","wave_step_count"]:
		check(m.has_method(method),"Model exposes resumable world API: "+method)
	if failures:print("ENEMY_SLICED_STEP_RESULT checks=%d failures=%d"%[checks,failures]);quit(1);return
	cycle_time();live_roster();live_targets();cancel_reset_and_direct();direct_actor_revision();defeat_and_finish();spawn_once()
	print("ENEMY_SLICED_STEP_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
