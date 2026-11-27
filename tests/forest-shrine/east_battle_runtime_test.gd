extends "res://tests/forest-shrine/east_region_review.gd"
## Source formations and victory routes through the existing native lifecycle.
const EastBattle=preload("res://scripts/forest/forest_east_battles.gd")
const Bank=preload("res://scripts/forest/crowd/east_region_sprites.gd")
const University=preload("res://scripts/forest/forest_university_region.gd")
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const REPORT="res://build/Other Files/Asset Toolkit/East Gate Region/Verification/battle-runtime.json"
var battles=[]
func run():
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-battles-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 for id in ["5635","5679"]:await source_battle(id)
 await legacy_habaru()
 var file=FileAccess.open(REPORT,FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"observations":observations,"battles":battles,"scope":"Actual map setup, source native formations, native lethal-hit retirement and explicit source victory routes; legacy Habaru owner retention. Direct source-room spawns and native injected lethal hits qualify lifecycle/routes only, not player combat balance or visual appearance."},"  "));file.close()
 print("EAST_BATTLE_RUNTIME_RESULT checks=",checks," failures=",errors)
 await finish()

func source_battle(actor_id:String):
 var population=Bank.data();var actor:Dictionary={};var command:Dictionary={}
 for row in population.actors:
  if str(row.id)==actor_id:actor=row;break
 for row in population.scripted_battles:
  if str(row.actor)==actor_id:command=row;break
 check(not actor.is_empty() and not command.is_empty(),"Pinned source actor/battle "+actor_id)
 if actor.is_empty() or command.is_empty():return
 var source=int(actor.source);var id=Maps.runtime_id(source);var cell=Vector2i(actor.cell[0],actor.cell[1])
 var stand=Maps.safe_cell(id,cell+Vector2i.DOWN*2)
 Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Maps.point(id,stand),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 8:await physics_frame
 var args=str(command.command).strip_edges()
 if args.to_lower().begins_with("encount"):args=args.substr(7).strip_edges()
 check(EastBattle.begin(game,actor,args),"Source battle enters the existing regional owner "+actor_id)
 var key=""
 for i in 180:
  await physics_frame
  key=University.active(self,id,"interior")
  if not key.is_empty() and game.model.enemies.values().any(func(enemy):return enemy.get("university_battle","")==key):break
 var rows=game.model.enemies.values().filter(func(enemy):return enemy.get("university_battle","")==key)
 check(not key.is_empty() and not rows.is_empty(),"Complete source formation reaches native spawn loop "+actor_id)
 if key.is_empty() or rows.is_empty():return
 var battle:Dictionary=get_meta(University.BATTLES)[key]
 check(rows.size()==battle.members.size(),"Native formation retains every selected source member "+actor_id)
 check(rows.all(func(enemy):return game.army_runtime.handles.has(enemy.id)),"Every formation member belongs to native lifecycle "+actor_id)
 var win:Array=EastBattle.specification(key).win
 var phases={};var retired=0
 for i in 1200:
  await physics_frame
  if game.model.falan_floor!=id:break
  var pending=game.model.enemies.values().filter(func(enemy):return enemy.get("university_battle","")==key)
  for enemy in pending:
   var handle:int=game.army_runtime.handles.get(enemy.id,0)
   if handle==0:continue
   phases[int(enemy.university_slot)/1000]=true
   var result:Dictionary=game.army_runtime.native.apply_hit(handle,{"amount":1000000000.,"provoke":false})
   if result.get("dead",false):retired+=1
  if get_meta(University.BATTLES,{})[key].complete and not has_meta("university_victory"):break
 for i in 120:
  await physics_frame
  if not game.transitioning:break
 check(get_meta(University.BATTLES,{})[key].complete,"Native retirement completes the source formation "+actor_id)
 if not win.is_empty():
  check(game.model.falan_floor==Maps.runtime_id(int(win[0])),"Victory reaches the original explicit endpoint "+actor_id)
  check(Vector2(Bank.source_cell(game.model,map_position())-Vector2i(win[1],win[2])).length()<=2.1,"Victory retains the original source landing cell "+actor_id)
 check(not game.model.enemies.values().any(func(enemy):return enemy.get("university_battle","")==key),"No obsolete source formation survives the victory transition "+actor_id)
 battles.append({"actor":actor_id,"source":source,"encounter":command.encounter,"retired":retired,"phases":phases.keys(),"win":win,"actual_floor":game.model.falan_floor})

func legacy_habaru():
 var id=11004;var at=Tour.Indoor.safe_point(id,Vector2(66,45),game.model.seed_value)
 Tour.travel(game,Tour.Indoor.layout(id),{"arrival":at,"yaw":0.,"velocity":Vector3.ZERO})
 await position_at(Tour.Regions.Sites.HABARU_FORMATION[0]+Vector2(0,7))
 check(game.habaru_dialogue_seen,"Legacy Habaru still requires its existing F/Space conversation")
 for i in 120:
  await physics_frame
  if game.model.enemies.values().filter(func(enemy):return enemy.has("habaru_slot")).size()==10:break
 var formation=game.model.enemies.values().filter(func(enemy):return enemy.has("habaru_slot"))
 check(formation.size()==10,"Legacy Habaru keeps all ten native formation slots")
 check(game.model.waves.patrol_source!=Bank,"Legacy Habaru retains its existing specialized source owner")
