extends "res://tests/forest-shrine/original_maps_test.gd"
## Native integration evidence. Direct placement and injected lethal hits are NOT gameplay completion.
const Region=preload("res://scripts/forest/forest_university_region.gd")
const Bank=Region.Bank
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")

func _initialize():
 create_timer(1200).timeout.connect(func():printerr("UNIVERSITY_POPULATION_TIMEOUT");quit(1))
 run.call_deferred()

func run():
 var rng=RandomNumberGenerator.new();rng.seed=341;var bags={}
 var dimensions=preload("res://scripts/forest/crowd/pet_dimensions.gd")
 var profiles=dimensions.geometry(Bank,true,1.)
 check(Bank.motions().variants.size()==17,"Seventeen recovered appearances share one existing native sprite bank")
 check(Bank.timelines().size()==29*32*8,"The shared bank retains the native 29-skin wire contract")
 for i in Bank.data().species.size():
  var species:Dictionary=Bank.data().species[i]
  if species.bank=="unavailable":
   check(species.has("reason"),"Unavailable final-phase art/behavior is an explicit blocker");continue
  var role=Roles.GATEKEEPER_HOUND if Bank.companion(i) else Roles.SLIME
  check(dimensions.bounds(profiles,role,int(species.skin)).size.y>0,"Every regional species has a native fitted body "+species.name)
 for branch_ in Bank.data().generated:
  var id:int=Original.generated().floor_id(branch_,1)
  var zone=Bank.zone_at(id,Vector2i.ZERO)
  var observed={}
  for n in 200:
   var members=Bank.group(zone,bags,rng)
   check(not members.is_empty() and members.size()<=int(zone.maximum),"Source group maximum "+branch_)
   for member in members:
    observed[member[0]]=true
    check(int(member[1])>=int(zone.levels[0]) and int(member[1])<=int(zone.levels[1]),"Source dungeon level bounds "+branch_)
  for row in zone.groups:
   for member in Bank.data().groups[row[0]].members:check(observed.has(int(member[0])),"Every documented dungeon species is drawable "+branch_)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-university-population.cfg"
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.run_seed=341
 for key in ["lizard","dijiro","altar","ruby","fribo","doctor","abyss"]:
  print("UNIVERSITY_BATTLE_ENTER ",key)
  var spec:Dictionary=Region.specification(key,341);var id:int=spec.map
  var cell:Vector2i=Original.safe_cell(id,spec.cell+Vector2i.DOWN,341)
  Tour.travel(game,Original.layout(id),{"arrival":Original.point(id,cell,341),"yaw":0.,"velocity":Vector3.ZERO})
  for i in 6:await physics_frame
  if key=="abyss":Region.item(self,"god_eye")
  check(Region.begin(game,key),"Source boss trigger accepts the required local state "+key)
  for i in 12:await physics_frame
  var phases=0
  for phase_ in 4:
   var battle:Dictionary=get_meta(Region.BATTLES,{})[key]
   if battle.complete:break
   phases+=1
   var enemies:Array=game.model.enemies.values().filter(func(enemy):return enemy.get("university_battle","")==key)
   check(enemies.size()==battle.members.size(),"Native owner spawns the complete source boss/retinue %s phase %d"%[key,phase_])
   check(enemies.any(func(enemy):return enemy.get("boss",false)),"The source encounter contains its boss "+key)
   if key=="altar" and phase_==0:enemies=enemies.slice(0,2)
   for enemy in enemies:
    check(game.army_runtime.native.can_reach(game.player.position,enemy.pos,.45),"Source boss chamber connects its actors to the approach "+key)
    var handle:int=game.army_runtime.handles.get(enemy.id,0)
    check(handle>0,"Source actor has a live native handle "+key)
    for attempt in 16:
     if game.army_runtime.unit_state(handle).get("hp",0.)<=0.:break
     game.army_runtime.apply_hit(handle,{"amount":enemy.max_hp*4,"direction":Vector3.FORWARD})
   for i in 12:await physics_frame
  check(phases==2 if key=="altar" else phases==1,"Every source chained battle runs before the victory exit "+key)
  check(get_meta(Region.BATTLES,{})[key].complete,"Victory comes through the shared native death callback "+key)
  if not spec.win.is_empty():check(game.model.falan_floor==Original.runtime_id(spec.win[0]),"Native victory takes the original post-fight exit "+key)
  else:check(Region.has_item(self,"world_heart"),"Black altar awards the World Heart")
 set_meta(Region.ITEMS,{"signed_stamps":5})
 check(not Region.begin(game,"sylph"),"Do not expose an incomplete three-phase Sylph fight")
 print("UNIVERSITY_POPULATION_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
