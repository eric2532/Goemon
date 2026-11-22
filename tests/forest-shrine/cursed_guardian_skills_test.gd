extends "res://tests/forest-shrine/cursed_maze_recovery_test.gd"
const Spells=preload("res://scripts/forest/crowd/cursed_guardian_spells.gd")
var casts={}
var impacts={}
var photos={}
var recovered_fx={}
func run():
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/cursed-guardian-skills.cfg";root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true
 Engine.time_scale=4.0
 set_meta(Winter.SLAIN,{})
 for floor_index in ([1,3,5,6] if "--effects-only" in OS.get_cmdline_user_args() else range(7)):
  var id:int=Decree.GUARDIAN_FLOORS[mini(floor_index,5)]
  if floor_index==6:
   var slain:Dictionary=get_meta(Winter.SLAIN,{})
   for slot in slain.keys():
    if slot.x==id:slain.erase(slot)
   set_meta(Winter.SLAIN,slain)
  var previous=Decree.floor_id((mini(floor_index,5)+1)*10-1)
  var entry=Original.links(previous).filter(func(l):return l.get("floor")==id)[0]
  Tour.travel(game,Original.layout(id),{"arrival":entry.arrival,"yaw":0.0,"velocity":Vector3.ZERO})
  for i in 8:await physics_frame
  var runtime=game.army_runtime
  var bosses=game.model.enemies.values().filter(func(row):return row.get("boss",false))
  var boss:Dictionary=bosses.filter(func(row):return row.enemy_name=="帕布提斯馬")[0] if floor_index==5 else bosses[0]
  for row in game.model.enemies.values():
   runtime.damage_enemy(row.id,row.max_hp*.35)
   if not row.get("boss",false):runtime.apply_hit(runtime.handles[row.id],{"element":"ice","status_seconds":300.0})
  var at=Vector2(boss.pos.x,boss.pos.z)/game.model.falan_scale
  var state=Original.state(id)
  var candidates=[]
  for cell in Decree.maze(id,game.model.seed_value).eligible:
   var point=Decree.point(cell,id)
   if point.distance_to(at)>3.0 and point.distance_to(at)<6.5:candidates.append(point)
  check(not candidates.is_empty(),"Guardian chamber has source-open combat ground")
  if not candidates.is_empty():
   game.player.position=game.model.world_point(candidates[0],.15);game.player.velocity=Vector3.ZERO
  if floor_index==0:
   var attendant=game.model.enemies.values().filter(func(row):return not row.get("boss",false))[0]
   runtime.damage_enemy(attendant.id,attendant.max_hp*4)
  runtime.record_events=true;runtime.event_log.clear()
  var batches_before:int=game.crowd.army.presentation.get_child_count()
  var initially:int=game.model.enemies.size()
  for i in 4:await physics_frame
  initially=game.model.enemies.size()
  var local={}
  for tick in 1800:
   await physics_frame
   await observe_guardians(local)
   if local.size()>=3 and tick>600:break
  check(local.size()>=2,"Guardian uses distinct recovered actions on floor "+str((floor_index+1)*10))
  check(game.crowd.army.presentation.get_child_count()==batches_before,"Repeated guardian spells reuse prepared batches")
  check(game.crowd.army.presentation.effects.size()<=game.crowd.army.presentation.MAX_EFFECTS,"Existing effect pool remains bounded")
  if floor_index==0:
   check(game.model.enemies.size()>initially,"Napa restores a fallen source-roster attendant through the native arrival owner")
   check(recovered_fx.has(Spells.ARRIVAL),"Actual Napa summon resolves the recovered native reinforcement entry")
   var count_=game.model.enemies.size();game.model.waves.reinforce_decree(boss.id)
   check(game.model.enemies.size()==count_,"Summoning does not duplicate living attendants")
  if floor_index>=5:
   check(not local.has(8850) and not local.has(8652),"Both living kings suppress their conditional attacks")
   var king:Dictionary=bosses.filter(func(row):return row.enemy_name==("凱法" if floor_index==5 else "帕布提斯馬"))[0]
   for attempt in 4:
    if not game.model.enemies.has(king.id):break
    runtime.damage_enemy(king.id,king.max_hp*4)
    for i in 4:await physics_frame
   for tick in 2400:
    await physics_frame
    await observe_guardians(local)
    if local.has(8652 if floor_index==5 else 8850) and impacts.has(8652 if floor_index==5 else 8850):break
   check(local.has(8652 if floor_index==5 else 8850),"The surviving king unlocks Death or Magic Seal after its partner dies")
   check(recovered_fx.has(774 if floor_index==5 else 706),"The surviving king resolves its recovered original Death/Seal effect")
  print("CURSED_GUARDIAN_FLOOR ",Decree.floor_number(id)," skills=",local.keys())
 check_spell_bank_reentry()
 await check_player_afflictions()
 Engine.time_scale=1.0
 print("CURSED_GUARDIAN_GAMEPLAY_RESULT casts=",casts.keys()," impacts=",impacts.keys()," checks=",checks," failures=",failures)
 await finish()

func observe_guardians(local:Dictionary):
 var events=game.army_runtime.event_log.duplicate();game.army_runtime.event_log.clear()
 for event in events:
  if event.kind!="status":continue
  if event.get("action_index")==Spells.ARRIVAL and not recovered_fx.has(Spells.ARRIVAL):
   game.army_runtime.flush_presentation()
   var p=game.crowd.army.presentation
   check(event.get("ticket_id",0)==game.army_runtime.handles.get(event.source_id,0),"Compact reinforcement cue retains its native generation")
   check(p.effects.any(func(e):return str(e.kind).begins_with("guardian-arrival-") and e.owner_id==event.source_id),"Napa's live battle uses the prepared growing source body")
   check(p.effects.any(func(e):return e.kind=="ruby-native-110096" and e.owner_id==event.source_id),"Napa's live battle uses the recovered looping source light")
   recovered_fx[Spells.ARRIVAL]=true
  if event.get("action_index") in [774,706] and not recovered_fx.has(event.action_index):
   game.army_runtime.flush_presentation()
   var p=game.crowd.army.presentation
   var ref=Spells.manifest.death if event.action_index==774 else Spells.manifest.magic_seal.resource
   check(p.effects.any(func(e):return e.kind=="ruby-native-"+ref),"Native king resolution presents its verified original effect")
   if event.action_index==774:check(event.has("target_id") and event.has("external_kind"),"Compact Death result retains its actual victim identity")
   recovered_fx[event.action_index]=true
  if event.get("unit_kind")==19 and event.get("action_index") in [702,767,769] and event.get("amount",0)>0:
   check(event.has("source_id") and event.source_id!=0,"Attendant support effects retain their real native owner and clock")
  if event.get("action_index")==Spells.IMPACT:
   var impact_tech=int(event.amount);impacts[impact_tech]=true
   if DisplayServer.get_name()!="headless" and impact_tech in [2702,2802,2902,3002,2705,2805,2905,3005] and not photos.has(impact_tech):
    photos[impact_tech]=true
    game.paused=true
    game.army_runtime.flush_presentation()
    var presentation=game.crowd.army.presentation
    var spec=Spells.visual(impact_tech)
    var effects=presentation.effects.filter(func(e):return e.kind=="ruby-native-"+spec.targets[0])
    check(not effects.is_empty(),"A resolved elemental attack presents its original target effect")
    # Inspect the middle source frame while the existing game pause holds the actual impact.
    for effect in presentation.effects:
     if str(effect.kind).begins_with("ruby-native-"):effect.age=effect.life*.5
    await photograph(impact_tech,game.model.enemies.values().filter(func(row):return row.get("boss",false)))
    check(presentation.batches["ruby-native-"+spec.targets[0]].multimesh.visible_instance_count>0,"Original elemental sheet reaches a visible pooled draw")
    game.paused=false

  if event.get("action_index")!=Spells.CAST:continue
  var tech=int(event.amount);local[tech]=true;casts[tech]=true
  check(Spells.NAMES.has(tech),"Native guardian action has a recovered source skill name")
  if DisplayServer.get_name()!="headless" and not photos.has(game.model.falan_floor):
   photos[game.model.falan_floor]=true
   await photograph(Decree.floor_number(game.model.falan_floor),game.model.enemies.values().filter(func(row):return row.get("boss",false)))

func check_player_afflictions():
 var hero=game.player
 game.paused=true
 game.tuning.invincible=false;hero.invuln=0
 for status in 6:
  hero.clear_cursed_afflictions();hero.invuln=0;hero.apply_cursed_affliction(status,1.0,0)
  check(hero.cursed_afflictions[status]>0,"Player receives actual "+Spells.STATUSES[status])
  if status in [1,2]:check(hero.combat_hold_left>0,"Sleep/Stone blocks movement and casting")
  if status==4:check(hero.confusion_left>0,"Confusion changes actual steering")
  hero.tick_cursed_afflictions(.1)
  if status==5:check(hero.spell_loadout.magic_seal_left>0,"Forget seals actual skill casting")
  hero.tick_cursed_afflictions(1.1)
  check(not hero.cursed_status_active,"Status expires on the existing player clock")
 hero.clear_cursed_afflictions();hero.confusion_left=0;game.tuning.invincible=true

func check_spell_bank_reentry():
 var presentation=game.crowd.army.presentation
 var falken=preload("res://scripts/forest/crowd/falken_sprites.gd")
 var count_=presentation.get_child_count()
 presentation.cave_sprites=falken;presentation.prepare_ruby()
 check(not falken.spell_art.is_empty(),"Entering Falken after the maze initializes its own spell metadata")
 presentation.cave_sprites=Cursed;presentation.prepare_ruby()
 check(Spells.manifest.clips.keys().all(func(ref):return presentation.batches.has("ruby-native-"+ref)),"Returning from another dungeon keeps every guardian spell sheet")
 check(presentation.get_child_count()==count_,"Dungeon spell-bank changes reuse their identical existing batches")
