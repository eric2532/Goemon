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
	rarity_checks()
	var interrupted=load("res://tests/forest-shrine/legendary_reward_failure_fixture.gd").new();var prior=RewardUnit.new();interrupted.pool.append(prior)
	interrupted.spares=[RewardUnit.new(),RewardUnit.new()]
	var reward_rng=RandomNumberGenerator.new();reward_rng.seed=123;var reward_state=reward_rng.state
	check(not interrupted.grant_random(5,reward_rng) and interrupted.attempts==3,"A partially blocked legendary grant reports failure")
	check(interrupted.active_units()==[prior] and prior.live,"Failed batches retire only their own new recruits")
	check(reward_rng.state==reward_state and interrupted.summon_serial==0,"Failed grants restore reward randomness and accounting")
	interrupted.free()
	var p=Progression.new();p.rng.seed=42
	check(p.level==1 and p.kills_required()==20 and p.pending()==0,"New run starts at team level one")
	p.award_kills(-3);p.award_kills(0)
	check(p.total_kills==0,"Nonpositive XP is ignored")
	p.award_enemy(-12);p.award_enemy(0)
	check(p.experience()==0,"Nonpositive scaled rewards are ignored")
	for i in 5:p.award_enemy(12)
	check(p.experience()==6 and p.xp_remainder==0,"Five second-group defeats give exactly six XP")
	p.reset();p.award_kills(19);p.award_enemy(14)
	check(p.level==2 and is_equal_approx(p.experience(),.4) and p.pending()==1,"Fractional XP survives a level boundary and queues one choice")
	p.award_enemy(12);check(is_equal_approx(p.experience(),1.6) and is_equal_approx(p.progress(),1.6/30),"Gold bar includes fractional rewards")
	p.reset();check(p.experience()==0 and p.xp_remainder==0,"New runs clear fractional XP")
	p.award_kills(19);check(p.level==1 and is_equal_approx(p.progress(),.95),"Partial shared XP")
	p.award_kills(32)
	check(p.level==3 and p.kills_into_level==1 and p.pending()==2,"Batched kills preserve overflow and queue each choice")
	var offer=p.offer.duplicate();var level_=p.choice_level();var power=1 if p.offer[0].begins_with("legendary_") else p.offer_rarities[0]+1
	check(offer.size()==3 and p.CARDS[offer[0]].category=="Tower" and p.CARDS[offer[1]].category=="Worker" and p.CARDS[offer[2]].category=="Character","Exactly one card per category")
	check(not p.choose("invalid",level_) and p.pending()==2,"Unoffered card cannot be applied")
	check(p.choose(offer[0],level_) and not p.choose(offer[0],level_),"A stale click cannot consume the next choice")
	check(p.pending()==1 and p.ranks[offer[0]]==power,"One choice applies its rarity's ranks")
	p.choose(p.offer[1],p.choice_level());check(p.offer.is_empty() and p.pending()==0,"All choices drain exactly once")
	p.award_kills(1000000)
	check(p.level==99 and p.progress()==1 and p.kills_into_level==0 and p.pending()==96,"Maximum level preserves every earned choice")
	p.award_enemy(14);check(p.xp_remainder==0 and p.progress()==1,"Max level ignores further fractional rewards")
	while p.pending()>0:
		check(p.offer.size()==3,"Three valid cards at every level")
		if p.ranks.has("worker_revive"):check(not p.offer.has("worker_revive"),"Revival cannot be offered twice")
		p.choose(p.offer[1],p.choice_level())
	check(p.ranks.get("worker_revive",0) in [1,2,3,4],"Revival retains its selected rarity")
	p.reset();check(p.level==1 and p.total_kills==0 and p.ranks.is_empty() and p.offer.is_empty() and p.offer_rarities.is_empty() and p.pending()==0,"Reset clears all run state")
	for id in p.CARDS:check(p.multiplier(id)==1,"No starting bonus: "+id)
	var m=Model.new();preload("res://tests/forest-shrine/empty_settlement.gd").reset(m);m.trees.clear();m.rebuild_navigation()
	var base_balance=m.balance.duplicate(true);var team=m.team_progression
	var tower=m._make_building("tower",Vector2i(5,5),0);m.rebuild_navigation();m.phase="wave"
	team.ranks.tower_defense=1;var hp=tower.hp;m.damage_building(tower.id,120)
	check(is_equal_approx(tower.hp,hp-100),"Tower armor applies through authoritative incoming damage")
	var future=m._make_building("tower",Vector2i(-8,8),0);hp=future.hp;m.damage_building(future.id,120)
	check(is_equal_approx(future.hp,hp-100),"Future towers inherit the same armor")
	var guard:Dictionary=m.workers.values()[0];guard.job=tower.id;guard.state="garrison";guard.pos=m.center(tower);guard.timer=0
	var enemy=m.waves.spawn_enemy(0,m.center(tower)+Vector3(0,0,18));m.update_vision(guard.pos)
	team.ranks.tower_speed=2;team.ranks.tower_damage=2
	m.workforce.tick(.01,guard.pos)
	check(is_equal_approx(guard.timer,1.0/(m.balance.tower_attack_speed*1.3)) and not m.workforce.arrows.is_empty(),"Real tower volley uses team attack cadence")
	hp=enemy.hp;m.workforce.tick_arrows(1)
	check(is_equal_approx(enemy.hp,maxf(0,hp-m.balance.tower_damage*1.4)),"Real tower arrow delivers upgraded damage once")
	team.ranks.legendary_tower=1;enemy.hp=100000;guard.timer=0
	m.workforce.tick(.01,guard.pos);hp=enemy.hp;m.workforce.tick_arrows(1)
	check(is_equal_approx(enemy.hp,hp-m.balance.tower_damage*1.4*5),"Legendary towers multiply the complete upgraded arrow damage by five")
	m.enemies.clear()
	var w:Dictionary=m.workers.values()[0];w.state="idle";w.job=-1;w.pos=m.point(Vector2i(0,5));w.path=[]
	var start:Vector3=w.pos;m.workforce.move(w,Vector2i(0,7),.1);var base_distance=w.pos.distance_to(start)
	w.pos=start;w.destination=Vector2i(-999,-999);team.ranks.worker_speed=2;m.workforce.move(w,Vector2i(0,7),.1)
	check(is_equal_approx(w.pos.distance_to(start),base_distance*1.3),"Worker speed stacks additively in real movement")
	m.phase="preparing";var shrine=m.shrine();shrine.hp-=200;w.state="repair";w.job=shrine.id;w.timer=0;m.gold=100
	team.ranks.worker_repair=1;hp=shrine.hp;m.workforce.repairs.tick(w,shrine,1)
	check(shrine.hp==hp+62.5 and m.gold==95,"Repair upgrade adds its 25% cadence bonus to the stronger 12.5 HP pulses")
	m.phase="wave";w.state="idle";w.job=-1;m.workforce.damage(w.id,1000);m.workforce.tick(20,Vector3.ZERO)
	check(w.state=="wounded","Without the card wounds persist during battle")
	team.ranks.worker_revive=1;m.workforce.tick(11.9,Vector3.ZERO)
	check(w.state=="wounded","Revival waits the full duration")
	m.workforce.tick(.11,Vector3.ZERO)
	check(w.state=="idle" and w.hp==w.max_hp and w.job==-1 and w.path.is_empty() and w.timer==0,"Revival restores and clears worker state at the castle")
	m.workforce.damage(w.id,1000);m.workforce.tick(12,Vector3.ZERO)
	check(w.hp==w.max_hp and w.state=="idle","Repeated wounds can revive without stale state")
	for power_ in [2,3,4]:
		team.ranks.worker_revive=power_;m.workforce.damage(w.id,1000)
		m.workforce.tick(12.0/power_-.1,Vector3.ZERO)
		check(w.state=="wounded","Rare revival still waits its full duration")
		m.workforce.tick(.11,Vector3.ZERO)
		check(w.state=="idle" and w.hp==w.max_hp,"Rare revival uses 6 / 4 / 3 seconds")
	check(m.balance==base_balance,"Cards never mutate saved/base balance")
	var worker_count=m.workers.size();m.gold=0;m.starting_food=0
	check(not m.workforce.recruit(),"Paid worker recruitment remains blocked during battle")
	for i in 10:check(m.workforce.recruit(true),"A free worker reward can arrive during battle at full food")
	check(m.workers.size()==worker_count+10 and m.gold==0,"Ten workers arrive without currency or capacity charges")
	m.phase="defeat";check(not m.workforce.recruit(true),"Rewards cannot add workers after the battle ends")
	# The near damaged gate was inserted after the far one.
	m=Model.new();preload("res://tests/forest-shrine/empty_settlement.gd").reset(m);m.trees.clear()
	while m.workers.size()>1:m.workers.erase(m.workers.keys().back())
	var far=m._make_building("gate",Vector2i(15,15),0);var near=m._make_building("gate",Vector2i(0,7),0);far.hp-=100;near.hp-=100;m.rebuild_navigation()
	w=m.workers.values()[0];w.pos=m.point(Vector2i(0,5));w.state="idle";w.job=-1;m.workforce.auto_assign()
	check(w.job==near.id,"Workers choose the closest reachable damaged structure, independent of insertion order")
	m.team_progression.ranks.character_damage=3;m.team_progression.award_kills(80);m.reset(123)
	check(m.team_progression.ranks.is_empty() and m.team_progression.level==1 and m.team_progression.pending()==0,"Model reset owns fresh progression")
	native_combat()
	print("TEAM_PROGRESSION_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

func rarity_checks():
	var weights=[0,0,0,0,0]
	for roll in 10000:weights[Progression.rarity_from_roll(roll)]+=1
	check(weights==[8475,1000,400,100,25],"Exact independent rarity odds: 84.75 / 10 / 4 / 1 / 0.25 percent")
	var p=Progression.new();var twin=Progression.new();p.rng.seed=42;twin.rng.seed=42
	var seen=[[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0]];var rare_pairs=0;var same_seed=true;var matching_legends=true
	for sample in 10000:
		p.roll_offer();twin.roll_offer()
		same_seed=same_seed and p.offer==twin.offer and p.offer_rarities==twin.offer_rarities
		for slot in 3:
			seen[slot][p.offer_rarities[slot]]+=1
			matching_legends=matching_legends and (p.offer[slot].begins_with("legendary_")==(p.offer_rarities[slot]==4))
		if p.offer_rarities[0]>0 and p.offer_rarities[1]>0:rare_pairs+=1
	check(same_seed,"Card and rarity rolls reproduce from the run seed")
	check(matching_legends,"Only the three special rewards roll at legendary rarity")
	for slot in 3:
		for rarity in 5:check(seen[slot][rarity]>0 and abs(seen[slot][rarity]-weights[rarity])<180,"Every slot independently draws each rarity at its expected rate")
	check(rare_pairs>150 and rare_pairs<300,"Multiple rare cards coexist without a shared rarity roll")
	print("TEAM_RARITY_DRAWS ",seen," first_two_rare=",rare_pairs)
	for id in p.CARDS:
		if id.begins_with("legendary_"):continue
		for rarity in 4:
			p.reset();p.award_kills(20);p.offer[0]=id;p.offer_rarities[0]=rarity
			var power=rarity+1
			check(p.choose(id,2) and p.ranks[id]==power and p.pending()==0,"Rarity adds exactly its weighted ranks: "+id)
			check(p.offer.is_empty() and p.offer_rarities.is_empty(),"Spent offer clears both IDs and rarities")
			if id=="worker_revive":
				check(p.revival_seconds()==12.0/power and p.description(id,rarity).contains("%d seconds"%(12/power)),"Revival description matches actual rarity timing")
			else:
				check(is_equal_approx(p.multiplier(id),1+float(p.CARDS[id].step)*power),"Rarity scales the added bonus, not total base stats: "+id)
				check(p.description(id,rarity).contains("%d%%"%roundi(float(p.CARDS[id].step)*100*power)),"Card states the exact enhanced bonus: "+id)
				p.award_kills(30);p.offer[0]=id;p.offer_rarities[0]=0;p.choose(id,3)
				check(p.ranks[id]==power+1,"Mixed rarities stack additively: "+id)
	for id in p.CARDS:
		if not id.begins_with("legendary_"):continue
		p.reset();p.award_kills(20);p.offer[0]=id;p.offer_rarities[0]=4
		check(p.choose(id,2) and p.ranks[id]==1 and not p.choose(id,2),"Each legendary reward is consumed exactly once")
		check(p.description(id,4)==p.CARDS[id].description,"Legendary descriptions state their fixed reward")
	p.reset();p.ranks.tower_damage=2;p.ranks.legendary_tower=1
	check(is_equal_approx(p.multiplier("tower_damage"),7.0) and p.multiplier("character_damage")==1,"Fivefold damage includes ordinary tower bonuses and affects no fighters")
	p.ranks.tower_damage=3;p.ranks.legendary_tower=2
	check(is_equal_approx(p.multiplier("tower_damage"),40.0),"Later ordinary upgrades and repeated legendary towers stack correctly")
	p.reset();check(p.multiplier("tower_damage")==1,"Fresh run clears legendary tower damage")

func native_sample(damage_rank:int,speed_rank:int)->Vector2:
	var m=Model.new();m.reset(42);m.team_progression.ranks.character_damage=damage_rank;m.team_progression.ranks.character_speed=speed_rank
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
	check(baseline.x>0 and is_equal_approx(boosted.x,baseline.x*1.3),"Native allied melee lands the upgraded damage once")
	check(boosted.y>0 and boosted.y<baseline.y,"Native allied animation/contact cadence accelerates")
	var diamond=native_sample(4,4)
	check(is_equal_approx(diamond.x,baseline.x*1.6) and diamond.y<baseline.y,"Diamond ranks reach real native allied damage and attack timing")
