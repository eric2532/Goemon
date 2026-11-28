extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Loot=preload("res://scripts/forest/exploration_loot.gd")
const OUT="res://build/Other Files/Asset Toolkit/Melon Bread/"
var home:Vector3
var loot:Node3D

func capture(filename:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync()
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+filename)==OK,"Captured "+filename)

func drop(kind:int,distance:float)->Dictionary:
 loot.clear();game.player.position=home;game.player.clear_food_buffs()
 check(loot.spawn_food(kind,home+Vector3.RIGHT*distance),"Prepared a reusable ground-food slot")
 return loot.slots[0]

func run():
 create_timer(120,true,false,true).timeout.connect(func():printerr("FOOD_MAGNET_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 cfg="/tmp/crossgate-food-glide-%d.cfg"%OS.get_process_id()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 loot=game.exploration_loot;loot.set_process(false)
 var p=game.player
 p.select_character(37);p.refresh_max_health()
 for node in [game,p,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 home=Vector3(-120,0,125);home.y=game.model.world_height(home.x,home.z)+.05
 game.model.update_vision(home);game.tuning.invincible=true
 p.position=home;p.velocity=Vector3.ZERO;p.hp=p.max_hp
 game.camera_rig.camera.global_position=home+Vector3(10,10,16)
 game.camera_rig.camera.look_at(home+Vector3(2,0,0))
 check(is_equal_approx(Loot.MAGNET_DISTANCE,float(game.EnemyRoles.MONSTERS[game.EnemyRoles.SLIME].range)),"Food starts pulling at one ordinary slime's 7.5m reach")
 var slot=drop(3,Loot.MAGNET_DISTANCE+.1);var origin:Vector3=slot.pos
 loot._process(.05)
 check(slot.active and slot.pos==origin,"Food outside attraction range stays where it dropped")
 p.position+=Vector3.RIGHT*.3
 loot._process(.05)
 check(slot.active and slot.pos.distance_to(p.position)<origin.distance_to(p.position),"Getting closer begins visible motion before collection")
 check(is_equal_approx(slot.pos.distance_to(origin),Loot.MAGNET_SPEED*.05),"Food moves smoothly at the prepared pull speed")
 check(p.food_buff_stacks.damage_mult==0,"A pulled food applies no bonus before reaching collection distance")
 if DisplayServer.get_name()!="headless":
  var transform:Transform3D=loot.batches[6].multimesh.get_instance_transform(0)
  check(transform.origin.is_equal_approx(slot.pos+Vector3.UP*loot.batches[6].multimesh.mesh.size.y*.5),"The existing batch displays the moving food position")
 await capture("food-pulling.png")
 for i in 90:loot._process(1.0/60)
 check(not slot.active and p.food_buff_stacks.damage_mult==1,"Pulled food auto-collects exactly once")
 for i in 90:loot._process(1.0/60)
 check(p.food_buff_stacks.damage_mult==1,"A collected food cannot apply its effect again")
 for rate in [20,30,60]:
  slot=drop(3,7.0);origin=slot.pos
  for i in rate/10:loot._process(1.0/rate)
  check(slot.active and is_equal_approx(slot.pos.distance_to(origin),Loot.MAGNET_SPEED*.1),"Pull distance is consistent at %d updates per second"%rate)
 for kind in 3:
  p.hp=p.max_hp;slot=drop(kind,6);origin=slot.pos;loot._process(.05)
  check(slot.active and slot.pos!=origin,"Healing food %d pulls toward a full-health player"%kind)
  for i in 90:loot._process(1.0/60)
  check(not slot.active and p.hp==p.max_hp and loot.food_text.text.contains("HP full"),"Healing food %d is consumed once at full HP without overhealing"%kind)
 await capture("food-full-health.png")
 p.hp=1;slot=drop(0,6)
 for i in 90:loot._process(1.0/60)
 check(not slot.active and p.hp>1,"Healing food still restores missing health")
 loot.clear();p.position=home;p.hp=p.max_hp
 loot.spawn_chest(0,home+Vector3.RIGHT*3,"full-hp-check",true);loot.slots[0].reward="weapon";loot.sword_bag=["weapon:SW016"];loot.slots[0].bonus=""
 check(loot.open_nearest() and not loot.slots[0].active and loot.opened_chests.has("full-hp-check") and p.hp==p.max_hp and not game.settings.chest_swords.is_empty(),"Opening a sword chest at full HP saves its sword without eating food")
 for field in ["paused","ordinary_pause","transitioning","settings_open","rogue_roster_open"]:
  slot=drop(3,6);origin=slot.pos
  game.set(field,true);loot._process(.2);game.set(field,false)
  check(slot.active and slot.pos==origin and slot.left==Loot.FOOD_LIFETIME,"%s freezes attraction and food expiry"%field)
 slot=drop(3,6);origin=slot.pos;p.hp=0;loot._process(.2);p.hp=p.max_hp
 check(slot.active and slot.pos==origin,"Food cannot move toward or revive a dead player")
 slot=drop(3,6);slot.pos+=Vector3.UP*12;origin=slot.pos;loot._process(.2)
 check(slot.active and slot.pos==origin,"Food on another distant height level is outside the 3D range")
 slot=drop(3,7);loot._process(.05);origin=slot.pos
 var wall=StaticBody3D.new();wall.collision_layer=1
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(.4,5,8);shape.shape=box
 wall.add_child(shape);game.add_child(wall);wall.position=home+Vector3(3,2,0)
 await physics_frame;await physics_frame
 loot._process(.2)
 check(slot.active and slot.pos==origin,"A wall appearing mid-pull stops food without collecting through it")
 wall.queue_free();await physics_frame;await physics_frame
 for i in 90:loot._process(1.0/60)
 check(not slot.active and p.food_buff_stacks.damage_mult==1,"Removing the obstruction allows the same food to collect")
 slot=drop(3,6);slot.left=.01;loot._process(.02)
 check(not slot.active and p.food_buff_stacks.damage_mult==0,"Expiry retires food before it can move or grant a bonus")
 loot.clear();p.position=home
 check(loot.spawn_chest(0,home+Vector3.RIGHT*6),"Prepared an existing chest inside attraction range")
 origin=loot.slots[0].pos;loot._process(.5)
 check(loot.slots[0].active and loot.slots[0].pos==origin,"Chests stay on the ground and retain their F interaction")
 # Walk into range using the ordinary character controller, without a pickup key.
 for kind in [6,Loot.OYAKODON]:
  var stacks:int=game.model.team_progression.skill_food_stacks
  slot=drop(kind,7);p.position=home-Vector3.RIGHT*3;p.smoke_mode=true;p.smoke_move=Vector2.RIGHT
  p.velocity=Vector3.ZERO;var began=false
  for i in 90:
   p._physics_process(1.0/60);loot._process(1.0/60)
   began=began or slot.pos.distance_to(home+Vector3.RIGHT*7)>.01
   if not slot.active:break
   await physics_frame
  p.smoke_move=Vector2.ZERO;p.velocity=Vector3.ZERO
  var applied=game.model.team_progression.skill_food_stacks==stacks+1 if kind==Loot.OYAKODON else p.food_buff_stacks.movement_speed==1
  check(began and not slot.active and applied,"Actual walking pulls and eats %s without F"%Loot.FOOD_NAMES[kind])
  await capture("oyakodon-collected.png" if kind==Loot.OYAKODON else "food-collected.png")
 # A grabbed serving visibly orbits, follows its eater, and applies only at the end.
 slot=drop(Loot.MELON_BREAD,1.4)
 game.model.waves.swarm_active=false
 loot._process(.01)
 check(slot.active and slot.flying and not game.model.waves.swarm_active,"Touch starts a flight without applying the food effect")
 var ground:Vector3=slot.pos
 loot._process(Loot.CONSUME_TIME*.3)
 check(slot.active and slot.pos.y>ground.y+.5 and absf(slot.pos.z-p.position.z)>.2,"Food rises and curls around the character before eating")
 await capture("food-orbit-early.png")
 origin=slot.pos;p.position+=Vector3.RIGHT
 loot._process(0)
 check(slot.pos.is_equal_approx(origin+Vector3.RIGHT),"Airborne food follows a moving eater")
 var age:float=slot.flight;origin=slot.pos
 game.paused=true;loot._process(1);game.paused=false
 check(slot.flight==age and slot.pos==origin,"Pause freezes an in-progress consumption")
 loot._process(Loot.CONSUME_TIME*.3);await capture("food-orbit-late.png")
 check(slot.active and not game.model.waves.swarm_active,"The invitation still waits for the food to reach the eater")
 loot._process(Loot.CONSUME_TIME)
 check(not slot.active and game.model.waves.swarm_active,"Consuming the melon bread starts native map pursuit")
 var clock:float=game.model.waves.spawn_clock
 loot._process(1)
 check(game.model.waves.spawn_clock==clock,"A completed serving cannot retrigger its effect")
 game.model.waves.swarm_active=false
 slot=drop(3,1);loot._process(.01);loot._process(.2);loot.clear();loot._process(1)
 check(p.food_buff_stacks.damage_mult==0,"Travel cleanup cancels airborne servings without stale bonuses")
 var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/crossgate/provenance.json"))
 for texture in Loot.FOODS:
  var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(texture.get_image().get_data())
  check(hash.finish().hex_encode()==manifest[texture.resource_path.get_file().get_basename()].rgba_sha256,"Active food pixels match the preserved original: "+texture.resource_path.get_file())
 loot.drop_bag.clear();loot.explore_drop_bag.clear()
 for cycle in 3:
  var arena_counts={};var explore_counts={}
  for i in Loot.FOODS.size()*5:
   var arena_kind=loot.draw_food_drop(false);arena_counts[arena_kind]=arena_counts.get(arena_kind,0)+1
   var explore_kind=loot.draw_food_drop(true);explore_counts[explore_kind]=explore_counts.get(explore_kind,0)+1
  check(arena_counts.get(-1,0)==52 and range(Loot.FOODS.size()).all(func(kind):return arena_counts.get(kind,0)==1),"Arena keeps one of every food per 65 deaths")
  check(explore_counts.get(-1,0)==45 and explore_counts.get(Loot.MELON_BREAD,0)==8 and range(Loot.FOODS.size()).all(func(kind):return kind==Loot.MELON_BREAD or explore_counts.get(kind,0)==1),"Explore replaces seven misses with melon bread and preserves the other food odds")
 if DisplayServer.get_name()!="headless":
  # Retain a short real-renderer sequence for judging the food's complete motion.
  DirAccess.make_dir_recursive_absolute(OUT+"Glide Frames/")
  slot=drop(Loot.MELON_BREAD,3)
  for frame in 55:
   loot._process(1.0/60)
   await process_frame;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUT+"Glide Frames/%03d.png"%frame)
 # The three original jellies use existing stat clocks and independent five-minute timers.
 for fighter in [37,p.RogueRoster.KAZI_ID,38]:
  p.select_character(fighter);p.refresh_max_health();p.hp=p.max_hp;p.clear_food_buffs()
  var damage:float=p.damage_multiplier();var magic:float=p.magic_damage_multiplier();var speed:float=p.base_attack_speed_multiplier()
  var spell:float=p.magic_spell_damage(120);var magic_stat:float=p.base_magic_damage()
  loot.eat(Loot.BLUE_JELLY)
  check(is_equal_approx(p.magic_damage_multiplier(),magic*1.5) and is_equal_approx(p.damage_multiplier(),damage) and is_equal_approx(p.base_attack_speed_multiplier(),speed),"Blue jelly boosts only the existing magic-damage stat by 50%%: %d"%fighter)
  check(is_equal_approx(p.magic_spell_damage(120)-spell,magic_stat*.5),"Blue magic damage reaches spell damage once without changing the spell's base")
  loot.eat(Loot.RED_JELLY);loot.eat(Loot.GREEN_JELLY)
  check(is_equal_approx(p.damage_multiplier(),damage*1.5) and is_equal_approx(p.base_attack_speed_multiplier(),speed*1.5),"Red damage and green attack speed each add exactly 50%")
  check(["jelly_damage","jelly_magic","jelly_speed"].all(func(key):return p.food_buffs[key]==300),"All three jelly timers start at five gameplay minutes")
  p.tick_food_buffs(299)
  check(p.food_buffs.jelly_magic==1 and is_equal_approx(p.damage_multiplier(),damage*1.5),"Jelly bonuses remain through the first 299 seconds")
  loot.eat(Loot.GREEN_JELLY)
  check(p.food_buffs.jelly_speed==300 and p.food_buff_stacks.jelly_speed==2 and is_equal_approx(p.base_attack_speed_multiplier(),speed*2),"Repeated jelly stacks additively and refresh only their own timer")
  p.tick_food_buffs(1)
  check(is_equal_approx(p.damage_multiplier(),damage) and is_equal_approx(p.magic_damage_multiplier(),magic) and p.food_buffs.jelly_speed==299,"Red and blue expire independently while refreshed green remains")
  p.tick_food_buffs(299)
  check(is_equal_approx(p.base_attack_speed_multiplier(),speed) and p.food_buff_stacks.jelly_speed==0,"Green expires at five minutes and clears its stacks")
  loot.eat(3);loot.eat(Loot.RED_JELLY);loot.eat(5);loot.eat(Loot.GREEN_JELLY)
  check(is_equal_approx(p.damage_multiplier(),damage*1.8) and is_equal_approx(p.base_attack_speed_multiplier(),speed*1.7),"Jelly percentages add to existing hot-pot and noodle food bonuses")
  p.tick_food_buffs(300)
  check(is_equal_approx(p.damage_multiplier(),damage*1.3) and is_equal_approx(p.base_attack_speed_multiplier(),speed*1.2),"Five-minute jelly expiry preserves ten-minute meals")
 p.select_character(37);p.refresh_max_health();p.hp=p.max_hp
 for kind in [Loot.RED_JELLY,Loot.BLUE_JELLY,Loot.GREEN_JELLY]:
  slot=drop(kind,1);loot._process(.01)
  check(slot.active and p.food_buff_stacks[Loot.BUFFS[kind]]==0,"Jelly pickup waits for its visible glide before applying")
  loot._process(Loot.CONSUME_TIME)
  check(not slot.active and p.food_buff_stacks[Loot.BUFFS[kind]]==1 and p.food_buffs[Loot.BUFFS[kind]]==300,"Jelly pickup consumes exactly once with the requested five-minute buff")
  var tile=loot.buff_tiles[Loot.BUFF_FOODS.find(kind)]
  check(tile.visible and tile.tooltip_text.contains("+50%") and tile.tooltip_text.contains("5:00"),"The original jelly icon reports its exact bonus and remaining time")
 loot.eat(Loot.RED_JELLY);loot.eat(Loot.BLUE_JELLY)
 await capture("three-jelly-buffs.png")
 # Fill the existing pool with simultaneously moving food and inspect reuse.
 p.position=home;loot.clear();p.clear_food_buffs()
 for i in Loot.CAPACITY:loot.spawn_food(3,home+Vector3.RIGHT.rotated(Vector3.UP,TAU*i/Loot.CAPACITY)*7)
 loot._process(.05);await capture("food-ring-pulling.png")
 for i in 90:loot._process(1.0/60)
 loot.clear();await frames(2)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var times=[]
 for cycle in 12:
  p.clear_food_buffs()
  for i in Loot.CAPACITY:loot.spawn_food(3,home+Vector3.RIGHT.rotated(Vector3.UP,TAU*i/Loot.CAPACITY)*7)
  var started=Time.get_ticks_usec()
  for i in 90:loot._process(1.0/60)
  times.append(Time.get_ticks_usec()-started)
  check(p.food_buff_stacks.damage_mult==64 and loot.slots.all(func(row):return not row.active),"All 64 simultaneous foods collect through the same slots")
  loot.clear()
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated attraction retains the prepared nodes and resources")
 loot.spawn_food(3,home+Vector3.RIGHT*6);loot._process(.05);loot.clear()
 check(loot.slots.all(func(row):return not row.active) and loot.batches.all(func(batch):return batch.multimesh.visible_instance_count==0),"Area cleanup removes moving food and its batch entries")
 times.sort()
 print("FOOD_MAGNET_PERFORMANCE burst_90_steps_p95_us=%d max_us=%d"%[times[11],times.back()])
 var config=game.settings_path;game.queue_free();current_scene=null;paused=false;await frames(4)
 if FileAccess.file_exists(config):DirAccess.remove_absolute(ProjectSettings.globalize_path(config))
 print("FOOD_MAGNET_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
