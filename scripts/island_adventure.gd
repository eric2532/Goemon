class_name IslandAdventure
extends Node
# Only nearby shrine objectives have scene nodes; progress lives in small dictionaries.
const AMBUSH_SECONDS=25.0
const UPGRADE_CAPS={"damage":10,"vitality":10,"tempo":5}
const TITLES=["DEFEAT THE ELITE","BREAK THE SHRINE","SURVIVE THE AMBUSH"]
const SHORT_NAMES=["ELITE","SHRINE","AMBUSH"]
var game: Node
var completed: Dictionary={}
var survival: Dictionary={}
var shrine_health: Dictionary={}
var shrines: Dictionary={}
var pending_rewards: Array[int]=[]
var choosing=false
var refresh_clock=0.0

func kind(index: int)->int:return posmod(index,3)
func is_complete(index: int)->bool:return completed.has(index)
func reset():
	for part in shrines.values():
		if is_instance_valid(part):
			part.world.breakable_buildings.erase(part);part.building.queue_free()
	shrines.clear();shrine_health.clear();completed.clear();survival.clear();pending_rewards.clear()
	refresh_clock=0;choosing=false

func _physics_process(delta):
	if not game.playing or game.paused or game.transitioning or game.player.hp<=0 or not game.descent_mode:return
	var run=game.encounters
	if not run.enabled or not run.active:return
	refresh_clock-=delta
	if refresh_clock<=0:refresh_clock=.5;sync_shrines()
	if run.completed:return
	var sky=game.world.sky_islands
	var index=sky.island_at(game.player.position,8)
	if index<0 or is_complete(index) or kind(index)!=2:return
	survival[index]=minf(AMBUSH_SECONDS,survival.get(index,0.0)+delta)
	if survival[index]>=AMBUSH_SECONDS:complete(index)

func sync_shrines():
	var wanted=game.encounters.spawned
	for index in shrines.keys():
		if wanted.has(index) and not is_complete(index):continue
		var part=shrines[index]
		if is_instance_valid(part):
			shrine_health[index]=part.hp
			part.world.breakable_buildings.erase(part);part.building.queue_free()
		shrines.erase(index)
	for index in wanted:
		if kind(index)!=1 or is_complete(index) or shrines.has(index):continue
		var root=Node3D.new();root.name="ObjectiveShrine_%d" % index
		game.world.add_child(root);root.global_position=game.world.sky_islands.islands[index]+Vector3(0,.02,-3)
		var visual=GameAssets.place(root,"town_props/wayside_shrine",Vector3.ZERO,Vector3.ONE*1.4)
		GameAssets.collision_for(visual,true)
		var part=BreakableBuilding.attach(root,game.world);part.objective_island=index
		part.max_hp=360;part.hp=shrine_health.get(index,part.max_hp);shrines[index]=part
		# Restore visible damage when an unfinished shrine is streamed back in.
		part.update_damage_visual(root.global_position+Vector3(0,1.5,1.1),Vector3.BACK)

func record_defeat(enemy: Ninja):
	if enemy.island_elite and enemy.island_index>=0:complete(enemy.island_index)

func complete(index: int):
	if is_complete(index) or index<0:return
	completed[index]=true;pending_rewards.append(index)
	if game.encounters.remaining_on(index)==0:game.encounters.cleared[index]=true
	game.hud.banner="OBJECTIVE COMPLETE · UPGRADE EARNED";game.hud.banner_time=3
	game.toast("F · Choose an island upgrade when you are ready")
	game.sound("spark",.65)

func objective_text(index: int)->String:
	if is_complete(index):return "OBJECTIVE COMPLETE"
	if kind(index)==2:return "%s · %ds / %ds" % [TITLES[2],floori(survival.get(index,0.0)),int(AMBUSH_SECONDS)]
	return TITLES[kind(index)]

func show_choices():
	if pending_rewards.is_empty() or choosing or game.player.hp<=0:return
	choosing=true;game.player.cancel_charge(true);game.paused=true;game.get_tree().paused=true
	Engine.time_scale=1;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var root=game.menu_base()
	game.label_at(root,"ISLAND UPGRADE",Vector2(92,140),40)
	game.label_at(root,"Choose one. Upgrades last until you restart or shuffle the map.",Vector2(96,204),20,Color("f4d38b"))
	game.label_at(root,"%d earned choice%s · Combat is paused" % [pending_rewards.size(),"s" if pending_rewards.size()!=1 else ""],Vector2(96,242),17)
	var row=0
	for upgrade in ["damage","vitality","tempo"]:
		var count=game.player.run_upgrades[upgrade];var capped=count>=UPGRADE_CAPS[upgrade]
		var title={"damage":"POWER · +10% damage","vitality":"VITALITY · +10% maximum health","tempo":"TEMPO · +5% attack speed"}[upgrade]
		var caption="Fully trained · Restore all health" if capped else "Current: %d / %d · Also restore 20 health" % [count,UPGRADE_CAPS[upgrade]]
		var button=game.button_at(root,title if not capped else upgrade.to_upper()+" · Full heal",Vector2(96,304+row*110),choose.bind(upgrade),570)
		if row==0:button.grab_focus()
		game.label_at(root,caption,Vector2(106,369+row*110),16,Color("d2ddd7"));row+=1
	game.button_at(root,"Choose later · Resume",Vector2(96,664),game.resume,350)

func choose(upgrade: String):
	if not choosing or pending_rewards.is_empty() or not UPGRADE_CAPS.has(upgrade):return
	pending_rewards.pop_front()
	var hero=game.player
	if hero.run_upgrades[upgrade]<UPGRADE_CAPS[upgrade]:
		hero.run_upgrades[upgrade]+=1;hero.refresh_max_health(true);hero.hp=minf(hero.max_hp,hero.hp+20)
	else:hero.hp=hero.max_hp
	choosing=false;game.resume()
	game.toast("UPGRADE APPLIED"+(" · F for another earned choice" if not pending_rewards.is_empty() else " · Lasts for this run"))

func building_reward(part: BreakableBuilding,point: Vector3):
	if part.objective_island>=0:
		complete(part.objective_island);return
	# One visible reward per building, with a hard world cap and existing pickup lifetime.
	if game.get_tree().get_nodes_in_group("energy_pickups").size()>=96:return
	var pickup=EnergyPickup.new();pickup.game=game
	pickup.kind=EnergyPickup.DROP_KINDS[(game.player.buildings_broken-1)%EnergyPickup.DROP_KINDS.size()]
	pickup.position=point;pickup.position.y=game.world.height_at(point.x,point.z)+.2
	game.add_child(pickup)
