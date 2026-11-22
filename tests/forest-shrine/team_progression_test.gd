extends SceneTree
const Progression=preload("res://scripts/forest/team_progression.gd")
const Model=preload("res://tests/forest-shrine/reference/forest_model.gd")
class RewardUnit extends RefCounted:
	var live=true
	func park():live=false
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label_)
func run():
	card_bag_checks()
	var interrupted=load("res://tests/forest-shrine/legendary_reward_failure_fixture.gd").new();var prior=RewardUnit.new();interrupted.pool.append(prior)
	interrupted.spares=[RewardUnit.new(),RewardUnit.new()]
	var reward_rng=RandomNumberGenerator.new();reward_rng.seed=123;var reward_state=reward_rng.state
	check(not interrupted.grant_company(0,0) and not interrupted.grant_company(5,-1) and not interrupted.grant_company(5,5) and interrupted.attempts==0,"Invalid company requests cannot recruit")
	check(not interrupted.grant_hero(-1),"Unknown hero IDs cannot be granted")
	check(not interrupted.grant_company(5,0) and interrupted.attempts==3,"A partially blocked legendary grant reports failure")
	check(interrupted.active_units()==[prior] and prior.live,"Failed batches retire only their own new recruits")
	check(reward_rng.state==reward_state and interrupted.summon_serial==0,"Failed grants leave randomness unchanged and restore recruitment accounting")
	interrupted.free()
	var p=Progression.new();p.rng.seed=42
	check(p.level==1 and p.kills_required()==16 and p.pending()==0,"Main character starts at level one and needs 16 XP")
	p.award_kills(-3);p.award_kills(0)
	check(p.total_kills==0,"Nonpositive XP is ignored")
	p.award_enemy(-12);p.award_enemy(0)
	check(p.experience()==0,"Nonpositive scaled rewards are ignored")
	for i in 5:p.award_enemy(12)
	check(p.experience()==6 and p.xp_remainder==0,"Five second-group defeats give exactly six XP")
	p.reset();p.award_kills(15);p.award_enemy(14)
	check(p.level==2 and is_equal_approx(p.experience(),.4) and p.pending()==1,"Fractional XP survives a level boundary and queues one choice")
	p.award_enemy(12);check(is_equal_approx(p.experience(),1.6) and is_equal_approx(p.progress(),1.6/32),"Level two needs 32 XP and displays fractional rewards")
	p.reset();check(p.experience()==0 and p.xp_remainder==0,"New runs clear fractional XP")
	p.award_kills(15);check(p.level==1 and is_equal_approx(p.progress(),15.0/16),"15 XP leaves the main character at level one")
	p.award_kills(34)
	check(p.level==3 and p.kills_required()==48 and p.kills_into_level==1 and p.pending()==2,"Batched XP reaches level three at 48 total, preserving overflow and both choices")
	var targets:Array[String]=["kazi/qigong","kazi/fire|original:2818","kazi/ice|puk2:703"]
	p.roll_offer(targets)
	var offer=p.offer.duplicate();var level_=p.choice_level()
	check(offer.size()==3 and {offer[0]:true,offer[1]:true,offer[2]:true}.size()==3,"Draft contains three distinct targets")
	check(not p.choose("invalid",level_) and p.pending()==2,"Unoffered card cannot be applied")
	check(p.choose(offer[0],level_) and not p.choose(offer[0],level_),"A stale click cannot consume the next choice")
	check(p.pending()==1 and p.stat_points==2,"One choice advances the queue and retains the two stat points")
	p.roll_offer(targets);p.choose(p.offer[1],p.choice_level())
	check(p.offer.is_empty() and p.pending()==0,"All choices drain exactly once")
	p.award_kills(1000000)
	check(p.level==99 and p.progress()==1 and p.kills_into_level==0 and p.pending()==96,"Maximum level preserves every earned choice")
	p.award_enemy(14);check(p.xp_remainder==0 and p.progress()==1,"Max level ignores further fractional rewards")
	while p.pending()>0:
		p.roll_offer(targets)
		check(p.offer.size()==3,"Three valid targets at every level")
		p.choose(p.offer[1],p.choice_level())
	p.reset();check(p.level==1 and p.total_kills==0 and p.ranks.is_empty() and p.offer.is_empty() and p.offer_rarities.is_empty() and p.pending()==0,"Reset clears all run state")
	check(p.award_kills(719)==8 and p.level==9 and p.award_kills(1)==1 and p.level==10,"Level ten requires exactly 720 XP")
	var patrols=preload("res://scripts/forest/crowd/falan_frontier_sprites.gd")
	check(patrols.progression(0,0).xp_reward_tenths==10 and patrols.progression(0,4).xp_reward_tenths==50,"Outdoor XP uses the final monster level after area scaling")
	for id in p.CARDS:check(p.multiplier(id)==1,"No starting bonus: "+id)
	# The near damaged gate was inserted after the far one.
	var m=Model.new();preload("res://tests/forest-shrine/empty_settlement.gd").reset(m);m.trees.clear()
	while m.workers.size()>1:m.workers.erase(m.workers.keys().back())
	var far=m._make_building("gate",Vector2i(15,15),0);var near=m._make_building("gate",Vector2i(0,7),0);far.hp-=100;near.hp-=100;m.rebuild_navigation()
	var w=m.workers.values()[0];w.pos=m.point(Vector2i(0,5));w.state="idle";w.job=-1;m.workforce.auto_assign()
	check(w.job==near.id,"Workers choose the closest reachable damaged structure, independent of insertion order")
	m.team_progression.ranks.character_damage=3;m.team_progression.award_kills(80);m.reset(123)
	check(m.team_progression.ranks.is_empty() and m.team_progression.level==1 and m.team_progression.pending()==0,"Model reset owns fresh progression")
	native_combat()
	print("TEAM_PROGRESSION_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

func card_bag_checks():
	var p=Progression.new();p.rng.seed=42
	var twin=Progression.new();twin.rng.seed=42
	var identical=true
	for refill in 20:
		var counts=[0,0,0]
		for i in 20:
			var rarity=p.draw_rarity()
			counts[rarity]+=1
			identical=identical and rarity==twin.draw_rarity()
		check(counts==[7,9,4],"Every batch matches 35% Silver, 45% Gold, 20% Diamond")
	check(identical,"The run seed reproduces the draw order")

func native_sample(damage_rank:int,speed_rank:int)->Vector2:
	var m=load("res://scripts/forest/forest_model.gd").new();m.reset(42);m.team_progression.ranks.character_damage=damage_rank;m.team_progression.ranks.character_speed=speed_rank
	var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
	runtime.configure_kits(preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(m))
	runtime.set_navigation(1,{"width":0})
	var enemy=runtime.spawn(100,0,0,Vector3(0,0,2),100000,.4);runtime.spawn(-100,1,11,Vector3.ZERO,100000,.4)
	runtime.apply_hit(enemy,{"element":"ice","status_seconds":60.0});runtime.take_events()
	var result=Vector2.ZERO
	for i in 240:
		runtime.step(1.0/60,{})
		for event in runtime.native.take_events():
			if event.kind=="damage" and event.team==0 and result==Vector2.ZERO:result=Vector2(event.amount,(i+1)/60.0)
		if result!=Vector2.ZERO:break
	runtime.free();return result
func native_combat():
	var baseline=native_sample(0,0);var boosted=native_sample(2,5)
	print("NATIVE_TEAM_CONTACT baseline=",baseline," boosted=",boosted)
	check(baseline.x>0 and is_equal_approx(boosted.x,baseline.x*1.6),"Native allied melee lands the upgraded damage once")
	check(boosted.y>0 and boosted.y<baseline.y,"Native allied animation/contact cadence accelerates")
	var diamond=native_sample(4,4)
	check(is_equal_approx(diamond.x,baseline.x*2.2) and diamond.y<baseline.y,"Diamond ranks reach real native allied damage and attack timing")
