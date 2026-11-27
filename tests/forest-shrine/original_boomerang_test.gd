extends "res://tests/forest-shrine/dodge_counter_stats_test.gd"
const EVIDENCE="res://build/Other Files/Asset Toolkit/Original Boomerang/Implementation/"
const OriginalShot=preload("res://scripts/recovered_enemy_projectile.gd")
var covered=[]

func choose_skin(character:int,skin:int):
 if character==34:game.select_kaz_skin(skin)
 elif character==36:game.select_kaz_skin(preload("res://scripts/kaz_skins.gd").MAZE)
 elif Gear.Roster.is_shin(character):game.select_shin_skin(character,skin)
 elif Gear.Roster.has_variant_skins(character):game.select_crossgate_skin(character,skin)

func equip(item:String):
 var p=game.player
 check(game.save_equipment_loadouts({Gear.character_key(p.character_id):{"1":item}},{},{}),"Save/equip "+item)

func finish_shots():
 for i in 180:
  for shot in shots:
   if shot.pool_live:shot._physics_process(DT)

func picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.army_runtime.flush_presentation()
 await frames(2);RenderingServer.force_draw()
 check(root.get_texture().get_image().save_png(EVIDENCE+stem+".png")==OK,"Captured "+stem)

func throw_case(character:int,skin:int,custom:bool=false,capture_:bool=false):
 var p=game.player;var kit=p.active_ability;var model=p.model;var pool=Pool.service(game)
 var item="weapon:water-dragon-boomerang" if custom else "weapon:boomerang"
 var kind="water_dragon_boomerang" if custom else "crossgate_boomerang"
 var texture=OriginalShot.WATER_BOOMERANG_ATLAS if custom else OriginalShot.BOOMERANG_ATLAS
 pool.release_owner(p);equip(item);planted();chance(0,100)
 kit.primary_combo_hits=0;kit.primary_combo_left=0
 game.update_character_tuning(character,"critical_chance",0)
 game.update_character_tuning(character,"accuracy",100)
 var army=game.army_runtime;army.clear();game.model.enemies.clear();army.refresh_kits()
 var row=spawn(Vector3.FORWARD*12);var enemy=row.target;var health:float=enemy.hp
 var pattern:Dictionary=model.normal_attack_pattern();var rate:float=p.attack_speed_multiplier()
 if not custom:check(pattern.attack.audio_cues[0]==pattern.attack.audio_cues[1],"Original throw plays its native release cue")
 check(model.current_weapon()=="boomerang" and model.fighter.strike=="throw" and kit.ranged_projectile()==kind,"Matching throw controller: %d/%d %s"%[character,skin,item])
 check(model.motions.get("water_dragon",false)==custom,"Custom ice/wave art stays separate")
 check(model.motions.clips.values().all(func(clip):return clip.has("duration") and float(clip.duration)>0),"Every reused movement/guard pose has a valid clock")
 for direction in 8:
  var attack:Dictionary=model.body_clip(5,"5:%d"%direction)
  check(attack.source_action==7 and attack.has("release"),"Native throw/release in facing %d"%direction)
  p.facing=Vector3(sin(direction*TAU/8),0,cos(direction*TAU/8))
  model.show_shin_counter(p.global_position,attack,true)
  model.pose_shin_counter(attack,float(attack.duration)*.8)
  model.show_frame(5,"5:%d"%direction,mini(attack.frames.size()-1,floori(attack.frames.size()*.8)))
  check(model.stat_counter_shadow.texture==model.sprite.texture and model.stat_counter_shadow.region_rect==model.sprite.region_rect,"Counter uses the equipped normal frame in facing %d"%direction)
 model.stat_counter_shadow.hide();p.facing=Vector3.FORWARD
 kit.primary_tab_target=weakref(enemy);kit.start_attack()
 kit.tick((float(pattern.contacts[0])-.001)/rate)
 check(shots.is_empty(),"No projectile before the native release")
 kit.tick(.002/rate)
 check(shots.size()==1 and shots[0].kind==kind,"Exactly one equipped boomerang at release")
 if shots.size()!=1:return
 var shot=shots[0]
 check(shot.dagger_sprite.texture==texture and shot.dagger_sprite.hframes==(16 if custom else 8),"The projectile uses the matching cached original/custom atlas")
 check((shot.impact_sound!=null)==custom,"Only the custom throw carries its ice layer")
 if capture_:
  shot._physics_process(DT*4)
  await picture("%d-%d-%s-flight"%[character,skin,"water" if custom else "original"])
 finish_shots()
 check(not shot.pool_live and is_equal_approx(health-enemy.hp,Skills.basic_damage(pattern)*p.damage_multiplier()),"Both flight legs deliver one normal hit and retire")
 kit.cancel(true);planted();p.take_hit_from(2,Vector3.BACK,false,row.id)
 check(not kit.shin_counter.is_empty() and kit.shin_counter.projectile==kind,"Natural counter snapshots the equipped projectile")
 if not kit.shin_counter.is_empty():
  kit.tick_shin_counter(float(kit.shin_counter.contact)/rate+.001)
  check(shots.size()==1 and shots[0].kind==kind and shots[0].dagger_sprite.texture==texture,"Counter launches the same equipped artwork")
  finish_shots()
 kit.clear_shin_counter();pool.release_owner(p)

func run():
 create_timer(900).timeout.connect(func():printerr("ORIGINAL_BOOMERANG_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(EVIDENCE);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.settings.forest_pet_loadout=[];game.settings.gear_loadouts={};game.settings.skill_item_loadouts={}
 game.begin_arena();game.choose_rogue_character(37);await frames(2);game.equipment_hub.enter_map();await frames(3)
 for node in [game,game.player,game.army_runtime,game.camera_rig]:node.set_process(false);node.set_physics_process(false)
 game.clear_menu();game.playing=true;game.paused=false;paused=false;game.forest_ui.hide();game.music.stop()
 game.model.waves.crossgate_pet_test=true;game.model.waves.patrol_posts.clear()
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 if is_instance_valid(game.training_dummy):game.training_dummy.position=home+Vector3.DOWN*1000
 game.camera_rig.camera.global_position=home+Vector3(5,6,17);game.camera_rig.camera.look_at(home+Vector3(0,1,-5));game.camera_rig.camera.make_current()
 var p=game.player;var pool=Pool.service(game)
 pool.launched.connect(func(shot):shot.set_physics_process(false);shots.append(shot))
 check(Gear.ITEMS["weapon:boomerang"].icon.resource_path.ends_with("/defaults/boomerang.png"),"Default equipment icon is the original Lv1 wooden boomerang")
 check(Gear.ITEMS["weapon:water-dragon-boomerang"].icon.resource_path.ends_with("/900050/boomerang/item.png"),"Custom equipment keeps its original 水龍 icon")
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/crossgate/weapons/boomerang/provenance.json"))
 for character_key in Gear.catalog():
  var character=int(character_key);p.select_character(character)
  var first=true
  for skin_key in Gear.catalog()[character_key]:
   var skin=int(skin_key);choose_skin(character,skin)
   var expected=source.supported.any(func(row):return row[0]==character_key and row[1]==skin_key)
   check(Gear.can_equip(Gear.character_key(character),"weapon:boomerang",game.settings)==expected,"Compatibility matches recovered source: %d/%d"%[character,skin])
   if not expected:continue
   await throw_case(character,skin,false,first);first=false;covered.append([character,skin])
   await frames(1)
 check(covered.size()==source.supported.size() and covered.size()==237,"Every one of the 237 compatible skins was exercised")
 p.select_character(37);choose_skin(37,900050)
 await throw_case(37,900050,true,true)
 # Switching both ways must reuse the two prepared pools without stale water artwork.
 for item in ["weapon:boomerang","weapon:water-dragon-boomerang"]:equip(item)
 var created=pool.created;var misses=pool.misses;var nodes=get_node_count()
 for i in 12:
  equip("weapon:boomerang" if i%2==0 else "weapon:water-dragon-boomerang");shots.clear()
  var kind:String=p.active_ability.ranged_projectile()
  var shot=pool.launch(p,OriginalShot,kind,{"kind":kind,"position":p.auto_aim_origin(),"velocity":Vector3.FORWARD*72,"boomerang_reach":18.0,"damage":1.0,"attack_ticket":{}})
  check(shot.age==0 and shot.hit_targets.is_empty() and shot.dagger_sprite.texture==(OriginalShot.BOOMERANG_ATLAS if i%2==0 else OriginalShot.WATER_BOOMERANG_ATLAS),"Repeated original/custom switching clears each lease")
  shot.retire()
 check(pool.created==created and pool.misses==misses and get_node_count()==nodes,"Repeated switching reuses prepared nodes and leases")
 equip("weapon:boomerang");game.load_settings()
 check(Gear.equipped(game.settings.gear_loadouts,37)=="weapon:boomerang","Original choice survives save/reload")
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p,0);shots.clear()
 for i in 4:check(mirrors.reinforce(37,home+Vector3((i-1.5)*2,0,1)),"Native copy deployment")
 var target=spawn(Vector3.FORWARD*15).target
 for body in mirrors.bodies:
  check(body.model.current_weapon()=="boomerang" and body.model.atlases==p.model.atlases,"Native copies share equipped body atlases")
  check(body.perform(0,target.global_position),"Native copy begins the equipped throw")
  body.active_ability.tick(float(body.model.normal_attack_pattern().contacts[0])/body.attack_speed_multiplier()+.002)
 check(shots.size()==4 and shots.all(func(shot):return shot.kind=="crossgate_boomerang" and shot.dagger_sprite.texture==OriginalShot.BOOMERANG_ATLAS),"Simultaneous copies use original boomerangs")
 await picture("four-original-native-copies");mirrors.dispose()
 planted();p.set_auto_attack(false);p.set_physics_process(true)
 var center:Vector2=root.get_visible_rect().get_center()
 var motion=InputEventMouseMotion.new();motion.position=center;root.push_input(motion,true)
 var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
 click.position=center;click.global_position=center
 root.push_input(click,true);click.pressed=false;root.push_input(click,true)
 for i in 180:
  await physics_frame
  if not shots.is_empty():break
 check(shots.size()==1 and shots[0].kind=="crossgate_boomerang","Actual left click releases the original boomerang (shots %d, mode %s)"%[shots.size(),p.active_ability.mode])
 pool.release_owner(p);p.active_ability.cancel(true)
 var move=InputEventAction.new();move.action="move_left";move.pressed=true;Input.parse_input_event(move)
 await create_timer(.35).timeout
 check(p.model.current_clip.begins_with("1:"),"Original boomerang walks using the native movement pose")
 await picture("original-walk")
 var shift=InputEventKey.new();shift.physical_keycode=KEY_SHIFT;shift.pressed=true;shift.shift_pressed=true;Input.parse_input_event(shift)
 await create_timer(.35).timeout
 check(p.model.current_clip.begins_with("3:"),"Shift selects the native running pose")
 await picture("original-run")
 shift=InputEventKey.new();shift.physical_keycode=KEY_SHIFT;shift.pressed=false;Input.parse_input_event(shift)
 await create_timer(.25).timeout
 check(p.model.current_clip.begins_with("1:"),"Releasing Shift resumes the walking pose")
 move=InputEventAction.new();move.action="move_left";move.pressed=false;Input.parse_input_event(move);p.set_physics_process(false)
 game.show_equipment_hub();await frames(3)
 check("weapon:boomerang" in game.equipment_hub.available_items() and "weapon:water-dragon-boomerang" in game.equipment_hub.available_items(),"Equipment exposes distinct original and 水龍 items")
 await picture("original-and-water-equipment")
 var file=FileAccess.open(EVIDENCE+"runtime-coverage.json",FileAccess.WRITE);file.store_string(JSON.stringify(covered));file.close()
 print("ORIGINAL_BOOMERANG_RESULT skins=",covered.size()," checks=",checks," failures=",failures)
 game.queue_free();current_scene=null;await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
