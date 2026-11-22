extends "res://tests/forest-shrine/cave_progression_test.gd"
const Loot=preload("res://scripts/forest/exploration_loot.gd")
const LOOT_OUT="res://build/Other Files/Explore Loot/Movement Defense/"

func _initialize():
 create_timer(240).timeout.connect(func():printerr("EXPLORE_LOOT_TIMEOUT");quit(1))
 run.call_deferred()

func run():
 DirAccess.make_dir_recursive_absolute(LOOT_OUT)
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/goemon-explore-loot-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 var arena:Dictionary=game.active_forest_map()
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.forest_ui.start_wave_button.pressed.emit()
 game.set_physics_process(false);game.player.set_physics_process(false)
 game.camera_rig.set_process(false);game.player.set_auto_attack(false)
 game.settings.forest_level_up_cards=false;game.tuning.invincible=true
 var loot=game.exploration_loot;loot.set_process(false)
 check(active(loot)>0 and loot.slots.all(func(slot):return not slot.active or slot.chest),"Explore begins with scattered chests, without killing enemies")
 check(Loot.chest_kind(0)==1 and Loot.chest_kind(.04999)==1 and Loot.chest_kind(.05)==2 and Loot.chest_kind(.09999)==2 and Loot.chest_kind(.1)==0,"Black and white are equally rare 5% chest variants")
 var random=RandomNumberGenerator.new();random.seed=4815
 var counts=[0,0,0]
 for i in 100000:counts[Loot.chest_kind(random.randf())]+=1
 check(counts[0]>89000 and counts[0]<91000 and counts[1]>4500 and counts[1]<5500 and counts[2]>4500 and counts[2]<5500,"Seeded placement sample retains common and rare proportions")
 var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/crossgate/provenance.json"))
 for texture in Loot.CHESTS+Loot.FOODS:
  var image:Image=texture.get_image();var key=texture.resource_path.get_file().get_basename()
  var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data())
  check(hash.finish().hex_encode()==manifest[key].rgba_sha256,"Imported source pixels preserved: "+key)
 await visit(11003)
 game.paused=false;paused=false;loot.clear()
 var units:Array=game.model.enemies.values()
 for kind in Loot.FOODS.size():
  loot.clear();force_food(loot,kind)
  var row:Dictionary=units[kind];var gold:int=game.model.gold
  game.army_runtime.apply_hit(game.army_runtime.handles[row.id],{"amount":row.max_hp*2,"magical":true})
  check(active(loot)==1 and not loot.slots[0].chest and loot.slots[0].kind==kind,"Actual native cave death drops food directly: "+str(kind))
  check(game.model.gold>gold,"Ryo remains a separate death reward")
  game.army_runtime.damage_enemy(row.id,row.max_hp*2)
  check(active(loot)==1,"Repeated corpse damage cannot duplicate food")
  game.player.clear_food_buffs();game.player.hp=1
  game.player.position=loot.slots[0].pos+Vector3.UP*.15
  loot._process(.1)
  check(active(loot)==0 and loot.food_icon.texture==Loot.FOODS[kind],"Walking over food eats it without F: "+str(kind))
  check(game.model.team_progression.skill_food_stacks>0 if kind==Loot.OYAKODON else game.player.hp>1 if kind<3 or kind==4 else game.player.food_buffs[Loot.BUFFS[kind]]==600,"Food applies its heal, timed bonus or run growth")
 # Same bonus must reach the shared melee, Cross Gate and gun stat paths.
 for fighter in [1,game.player.RogueRoster.KAZI_ID,18]:
  game.player.clear_food_buffs();game.player.select_character(fighter);game.player.refresh_max_health()
  var damage:float=game.player.damage_multiplier();var speed:float=game.player.attack_speed_multiplier();var health:float=game.player.max_hp
  var movement:float=game.player.movement_multiplier();var flight:float=game.player.jump_style.flight_speed()
  game.player.hp=health
  check(loot.eat(3) and is_equal_approx(game.player.damage_multiplier(),damage*1.3),"Hot pot grants exactly 30% damage: "+str(fighter))
  check(loot.eat(5) and is_equal_approx(game.player.attack_speed_multiplier(),speed*1.2),"Noodles grant exactly 20% attack speed: "+str(fighter))
  check(loot.eat(4) and is_equal_approx(game.player.max_hp,health*1.3) and is_equal_approx(game.player.hp,health*1.3),"Stew grants exactly 30% maximum HP and the added health: "+str(fighter))
  loot.eat(3);loot.eat(3);loot.eat(5);loot.eat(4);loot.eat(4)
  check(is_equal_approx(game.player.damage_multiplier(),damage*1.9) and game.player.food_buff_stacks.damage_mult==3,"Three hot pots add 90% damage: "+str(fighter))
  check(is_equal_approx(game.player.attack_speed_multiplier(),speed*1.4) and game.player.food_buff_stacks.attack_speed==2,"Two noodle servings add 40% attack speed")
  check(is_equal_approx(game.player.max_hp,health*1.9) and is_equal_approx(game.player.hp,health*1.9),"Three stews add 90% max HP and each new serving grants its added health")
  loot.eat(6);loot.eat(6);loot.eat(7);loot.eat(7);loot.eat(7)
  check(is_equal_approx(game.player.movement_multiplier(),movement*1.4),"Two fruit salads add 40% movement speed: "+str(fighter))
  check(is_equal_approx(game.player.jump_style.flight_speed(),flight*1.4),"Food also scales prepared flight speed once")
  check(game.player.food_defense()==60 and game.player.food_buff_stacks.defense==3,"Three dumpling servings add 60 defense")
  if fighter==1:
   var previous:float=game.player.hp;game.player.invuln=0;game.tuning.invincible=false
   var wanted=20*100.0/(100+game.model.team_progression.stat_defense()+60)*game.tuning.enemy_damage
   game.player.take_hit(20,Vector3.RIGHT)
   check(is_equal_approx(previous-game.player.hp,wanted),"Actual damage uses base armor plus food defense exactly once")
   game.tuning.invincible=true;game.player.invuln=0;game.player.velocity=Vector3.ZERO
  game.player.tick_food_buffs(599)
  check(game.player.food_buffs.damage_mult==1 and is_equal_approx(game.player.damage_multiplier(),damage*1.9),"All stacks last the first 599 gameplay seconds")
  var before:float=game.player.hp;loot.eat(4)
  check(game.player.food_buffs.max_hp==600 and game.player.food_buff_stacks.max_hp==4 and is_equal_approx(game.player.hp,before+health*.3) and is_equal_approx(game.player.max_hp,health*2.2),"Another stew adds a stack and refreshes the shared timer")
  game.player.tick_food_buffs(1)
  check(is_equal_approx(game.player.damage_multiplier(),damage) and is_equal_approx(game.player.attack_speed_multiplier(),speed),"Damage and attack speed expire at 600 seconds")
  check(game.player.food_buff_stacks.damage_mult==0 and game.player.food_buff_stacks.attack_speed==0,"Expired bonuses clear their stack counts")
  check(is_equal_approx(game.player.movement_multiplier(),movement) and game.player.food_defense()==0,"Speed and defense stacks expire with their timers")
  game.player.tick_food_buffs(599)
  check(is_equal_approx(game.player.max_hp,health) and game.player.hp<=health and game.player.hp>0,"Max HP expiry clamps living HP safely")
 game.player.select_character(game.player.RogueRoster.KAZI_ID)
 game.player.clear_food_buffs();game.player.hp=game.player.max_hp
 var point:Vector3=game.player.position
 loot.clear();loot.spawn_food(0,point);loot._process(.2)
 check(active(loot)==0 and game.player.hp==game.player.max_hp,"Full HP still consumes healing food without overhealing")
 game.player.hp=game.player.max_hp-1;loot.spawn_food(0,point);loot._process(.2)
 check(active(loot)==0 and game.player.hp==game.player.max_hp,"Automatic healing caps at maximum HP")
 loot.spawn_food(3,point);loot._process(.2)
 game.paused=true;var left:float=game.player.food_buffs.damage_mult
 game.player._physics_process(30);loot._process(30)
 check(game.player.food_buffs.damage_mult==left and game.forest_ui.food_effects.visible,"Pause freezes the bonus timer and preserves the food icon state")
 loot.spawn_food(0,point);game.player.hp=1;loot._process(30)
 check(active(loot)==1 and loot.slots[0].left==Loot.FOOD_LIFETIME,"Pause freezes food expiry and pickup")
 game.paused=false;game.player.hp=0;loot._process(.2)
 check(active(loot)==1 and game.player.hp==0,"Food cannot revive a dead player")
 game.player.hp=1;game.transitioning=true;loot._process(.2)
 check(active(loot)==1,"Travel blocks automatic pickup")
 game.transitioning=false
 loot.clear();loot.spawn_food(0,point+Vector3(Loot.MAGNET_DISTANCE+.5,0,0));loot._process(.2)
 check(active(loot)==1,"Food outside the attraction radius stays put")
 loot.clear();loot.spawn_food(0,point+Vector3(2,0,0))
 var wall=StaticBody3D.new();wall.collision_layer=1
 var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(.3,8,8);wall.add_child(shape)
 game.add_child(wall);wall.position=point+Vector3(1,2,0)
 await physics_frame
 loot._process(.2);check(active(loot)==1,"A real physics wall blocks automatic pickup")
 wall.free();await physics_frame
 loot._process(.2);check(active(loot)==0,"Food collects once the obstruction is gone")
 # Area travel keeps food bonuses, and deterministic chest keys prevent re-entry farming.
 loot.eat(3)
 loot.eat(Loot.OYAKODON)
 var growth_stacks:int=game.model.team_progression.skill_food_stacks
 Tour.travel(game,Tour.Regions.layout("east_gate"),{"arrival":Vector2(3,240),"yaw":0.0,"velocity":Vector3.ZERO})
 game.set_physics_process(false);game.player.set_physics_process(false);game.model.team_progression.cards_enabled=false
 game.army_runtime.refresh_navigation(0)
 var placed=loot.slots.filter(func(slot):return slot.active)
 check(placed.size()==12 and placed.all(func(slot):return slot.chest),"World map scatters twelve optional chests on entry")
 check(game.player.food_buffs.damage_mult>0,"Food bonuses survive area travel")
 check(game.model.team_progression.skill_food_stacks==growth_stacks,"親子丼 growth survives actual area travel")
 for slot in placed:
  var cell:Vector2i=game.model.cell_of(slot.pos/game.model.falan_scale)
  var start:Vector2i=game.model.nearest_open(game.model.cell_of(game.player.position/game.model.falan_scale))
  check(not game.model.route(start,cell).is_empty(),"Scattered chest is reachable through the existing navigation grid")
 var chest:Dictionary=placed[0];var chest_key:String=chest.key
 game.player.position=chest.pos+Vector3.UP*.15;game.player.hp=1
 var f=InputEventKey.new();f.physical_keycode=KEY_F;f.pressed=true;game._input(f)
 check(loot.opened_chests.has(chest_key),"F opens a scattered chest and records that location")
 loot.clear();loot.prepare_world()
 check(loot.slots.all(func(slot):return not slot.active or slot.key!=chest_key),"Revisiting the same map cannot respawn an opened chest")
 var count:int=active(loot);loot.prepare_world()
 check(active(loot)==count,"Repeated preparation does not scatter duplicate chests")
 game.player.position=game.model.world_point(Vector2(3,240),.15)
 for i in game.model.waves.patrol_posts.size()+1:game.model.waves.tick(12,game.player.position)
 game.army_runtime.import_arrivals();loot.clear()
 var patrol:Dictionary=game.model.enemies.values()[0];force_food(loot,3)
 game.army_runtime.apply_hit(game.army_runtime.handles[patrol.id],{"amount":patrol.max_hp*2,"magical":true})
 check(active(loot)==1 and not loot.slots[0].chest and loot.slots[0].kind==3,"Outdoor native enemies drop food, never a chest")
 loot.clear();force_food(loot,-1)
 loot.enemy_died({"team":0,"position":game.player.position})
 check(active(loot)==0,"Enemies can also roll no food")
 point=game.model.world_point(Vector2(3,240))
 loot.clear();game.player.clear_food_buffs();game.player.hp=1
 for kind in 3:loot.spawn_chest(kind,point+Vector3((kind-1)*3,0,0))
 for kind in Loot.FOODS.size():loot.spawn_food(kind,point+Vector3((kind-3.5)*2,0,-4))
 game.player.position=point+Vector3(0,.15,3)
 game.model.update_vision(game.player.position);game.forest_ui.message_left=0;game.forest_ui.sync()
 game.camera_rig.camera.global_position=point+Vector3(8,8,15);game.camera_rig.camera.look_at(point+Vector3(0,1,-1))
 loot._process(.1);await capture_loot("scattered-chests-and-food")
 loot.clear();loot.spawn_food(3,game.player.position);loot._process(.2)
 loot.eat(3);loot.eat(4);loot.eat(5);loot.eat(5);loot.eat(5);loot.eat(6);loot.eat(6);loot.eat(6);loot.eat(6);loot.eat(7);loot.eat(7)
 check(loot.buff_counts.slice(0,5).map(func(label):return label.text)==["×2","","×3","×4","×2"],"Existing food icons retain their own stack counts")
 check(game.forest_ui.food_effects.get_parent()==game.forest_ui.hero_dock and game.forest_ui.food_effects.get_global_rect().position.y>game.forest_ui.health.get_global_rect().end.y,"Food icons sit below character health")
 check(game.forest_ui.food_effects.get_global_rect().position.y>=game.forest_ui.loadout_slots.get_global_rect().end.y,"Food icons stay below the integrated skill row")
 check(loot.buff_tiles[0].tooltip_text.contains("Damage +60%") and loot.buff_tiles[2].tooltip_text.contains("Attack speed +60%"),"Icon tooltips show the total bonus and remaining time")
 check(loot.buff_tiles[3].tooltip_text.contains("Movement speed +80%") and loot.buff_tiles[4].tooltip_text.contains("Defense +40\n"),"New tooltips distinguish speed percent from defense points")
 await capture_loot("food-buffs")
 root.size=Vector2i(960,600);await capture_loot("food-buffs-small")
 root.size=Vector2i(1280,800)
 var kit=game.player.active_ability
 game.player.clear_food_buffs();kit.cancel(true);kit.start_attack();kit.tick(.02)
 var ordinary_elapsed:float=kit.elapsed
 kit.cancel(true);loot.eat(5);kit.start_attack();kit.tick(.02)
 check(is_equal_approx(kit.elapsed,ordinary_elapsed*1.2),"Noodles advance the actual authored attack clock by exactly 20%")
 for frame in 10:
  kit.tick(1.0/60);game.player.model.animate(1.0/60,0,true,0,0,false,0,false)
  if DisplayServer.get_name()!="headless":await process_frame
 await capture_loot("food-attack");kit.cancel(true)
 await verify_movement_food(loot,point)
 loot.clear();loot.spawn_food(0,point+Vector3(20,0,0));loot.spawn_chest(0,point+Vector3(24,0,0))
 loot._process(121)
 check(active(loot)==1 and loot.slots.any(func(slot):return slot.active and slot.chest),"Dropped food expires; scattered chests stay until opened")
 var objects:int=Performance.get_monitor(Performance.OBJECT_COUNT)
 var nodes:int=game.get_child_count();var hud_nodes:int=game.forest_ui.get_child_count()
 var samples=[]
 for cycle in 20:
  var started=Time.get_ticks_usec();loot.clear();game.player.hp=1
  var filled=true
  for i in Loot.CAPACITY:filled=loot.spawn_food(i%Loot.FOODS.size(),point) and filled
  check(filled and active(loot)==64 and not loot.spawn_food(0,point),"Repeated food bursts use all slots and respect capacity")
  game.player.position=point+Vector3.UP*.15;loot._process(.2)
  check(game.player.hp>1 and active(loot)<64,"Simultaneous food drops auto-collect through the shared presentation")
  loot.clear();samples.append((Time.get_ticks_usec()-started)/1000.0)
 check(game.get_child_count()==nodes and game.forest_ui.get_child_count()==hud_nodes,"Repeated drops/pickups retain the same scene and HUD nodes")
 check(Performance.get_monitor(Performance.OBJECT_COUNT)<=objects+2,"Repeated food use retains no extra resources")
 loot.enemy_died({"team":1,"position":point});check(active(loot)==0,"Allied deaths do not drop food")
 game.preview_forest_map(arena,false);game.model.waves.crossgate_pet_test=true;game.start_wave();force_food(loot,0)
 loot.enemy_died({"team":0,"position":Vector3.ZERO})
 check(not loot.exploring() and active(loot)==0,"Arena scatters no chests and ordinary non-slime enemies do not drop food")
 game.army_runtime.refresh_navigation(0)
 for kind in Loot.FOODS.size():
  loot.clear();game.player.clear_food_buffs();game.player.hp=1;force_food(loot,kind)
  var slime:Dictionary=game.model.waves.spawn_enemy(20,game.player.position+Vector3(3,0,0),-1,kind)
  slime.slime_side=kind%4
  var returns:int=game.model.waves.slime_rebirth_pending
  game.army_runtime.import_arrivals()
  game.army_runtime.apply_hit(game.army_runtime.handles[slime.id],{"amount":slime.max_hp*2,"magical":true})
  check(active(loot)==1 and not loot.slots[0].chest and loot.slots[0].kind==kind,"Actual arena slime death drops food: "+str(kind))
  check(game.model.waves.slime_rebirth_pending==returns+1,"Food does not interfere with the slime's next-wave return")
  game.player.position=loot.slots[0].pos+Vector3.UP*.15
  loot._process(.1)
  check(active(loot)==0 and (game.model.team_progression.skill_food_stacks>0 if kind==Loot.OYAKODON else game.player.hp>1 if kind<3 or kind==4 else game.player.food_buffs[Loot.BUFFS[kind]]>0),"Arena food auto-collects and applies its effect: "+str(kind))
 loot.spawn_food(3,game.player.position);loot._process(.1)
 game.camera_rig.camera.global_position=game.player.position+Vector3(7,6,12);game.camera_rig.camera.look_at(game.player.position+Vector3.UP)
 await capture_loot("arena-food-buffs")
 loot.spawn_chest(0,Vector3.ZERO);game.show_title()
 check(active(loot)==0 and loot.opened_chests.is_empty() and game.player.food_buffs.values().all(func(value):return value==0) and game.player.food_buff_stacks.values().all(func(value):return value==0) and game.model.team_progression.skill_food_stacks==0,"Title clears drops, chest history, temporary bonuses and run growth")
 samples.sort()
 print("EXPLORE_LOOT_RESULT checks=",checks," failures=",errors," burst_pickup_p95_ms=",samples[18]," max_ms=",samples[19])
 await finish()

func active(loot)->int:
 return loot.slots.filter(func(slot):return slot.active).size()

func force_food(loot,kind:int):
 var random=RandomNumberGenerator.new();random.seed=77
 for i in 100000:
  var state=random.state;var drop=random.randf()<.2
  if not drop and kind<0:loot.rng.state=state;return
  if drop and random.randi_range(0,Loot.FOODS.size()-1)==kind:loot.rng.state=state;return
 check(false,"Could not prepare food drop roll")

func capture_loot(filename:String):
 if DisplayServer.get_name()=="headless":return
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(LOOT_OUT+filename+".png")==OK,"Rendered loot evidence: "+filename)

func verify_movement_food(loot,point:Vector3):
 var p=game.player
 p.clear_food_buffs();p.select_character(1);p.hp=p.max_hp
 p.set_auto_attack(false);p.cancel_charge(true);p.smoke_mode=true;p.smoke_move=Vector2.UP
 var speeds=[]
 for serving in 2:
  p.position=point+Vector3.UP*.15;p.velocity=Vector3.ZERO;p.invuln=1;p.set_physics_process(true)
  for i in 45:await physics_frame
  p.set_physics_process(false);speeds.append(Vector2(p.velocity.x,p.velocity.z).length())
  if serving==0:loot.eat(6);loot.eat(6)
 check(speeds[0]>.1 and is_equal_approx(speeds[1],speeds[0]*1.4),"Two salads increase actual walking speed by 40% on the same road")
 p.smoke_move=Vector2.ZERO;p.smoke_mode=false;p.velocity=Vector3.ZERO
 game.camera_rig.camera.global_position=p.position+Vector3(7,6,12);game.camera_rig.camera.look_at(p.position+Vector3.UP)
 await capture_loot("movement-food")
 p.clear_food_buffs();p.select_character(p.RogueRoster.KAZI_ID)
