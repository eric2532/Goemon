extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Loot=preload("res://scripts/forest/exploration_loot.gd")
const OUT="res://build/Other Files/Food Magnet/"
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
 create_timer(120).timeout.connect(func():printerr("FOOD_MAGNET_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 loot=game.exploration_loot;loot.set_process(false)
 var p=game.player
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
 for i in 30:loot._process(1.0/60)
 check(not slot.active and p.food_buff_stacks.damage_mult==1,"Pulled food auto-collects exactly once")
 for i in 20:loot._process(1.0/60)
 check(p.food_buff_stacks.damage_mult==1,"A collected food cannot apply its effect again")
 for rate in [20,30,60]:
  slot=drop(3,7.0);origin=slot.pos
  for i in rate/10:loot._process(1.0/rate)
  check(slot.active and is_equal_approx(slot.pos.distance_to(origin),Loot.MAGNET_SPEED*.1),"Pull distance is consistent at %d updates per second"%rate)
 for kind in 3:
  p.hp=p.max_hp;slot=drop(kind,6);origin=slot.pos;loot._process(.05)
  check(slot.active and slot.pos!=origin,"Healing food %d pulls toward a full-health player"%kind)
  for i in 30:loot._process(1.0/60)
  check(not slot.active and p.hp==p.max_hp and loot.food_text.text.contains("HP full"),"Healing food %d is consumed once at full HP without overhealing"%kind)
 await capture("food-full-health.png")
 p.hp=1;slot=drop(0,6)
 for i in 30:loot._process(1.0/60)
 check(not slot.active and p.hp>1,"Healing food still restores missing health")
 loot.clear();p.position=home;p.hp=p.max_hp
 loot.spawn_chest(0,home+Vector3.RIGHT*3,"full-hp-check")
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
 for i in 30:loot._process(1.0/60)
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
 # Fill the existing pool with simultaneously moving food and inspect reuse.
 p.position=home;loot.clear();p.clear_food_buffs()
 for i in Loot.CAPACITY:loot.spawn_food(3,home+Vector3.RIGHT.rotated(Vector3.UP,TAU*i/Loot.CAPACITY)*7)
 loot._process(.05);await capture("food-ring-pulling.png")
 for i in 30:loot._process(1.0/60)
 loot.clear();await frames(2)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var times=[]
 for cycle in 12:
  p.clear_food_buffs()
  for i in Loot.CAPACITY:loot.spawn_food(3,home+Vector3.RIGHT.rotated(Vector3.UP,TAU*i/Loot.CAPACITY)*7)
  var started=Time.get_ticks_usec()
  for i in 20:loot._process(1.0/60)
  times.append(Time.get_ticks_usec()-started)
  check(p.food_buff_stacks.damage_mult==64 and loot.slots.all(func(row):return not row.active),"All 64 simultaneous foods collect through the same slots")
  loot.clear()
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated attraction retains the prepared nodes and resources")
 loot.spawn_food(3,home+Vector3.RIGHT*6);loot._process(.05);loot.clear()
 check(loot.slots.all(func(row):return not row.active) and loot.batches.all(func(batch):return batch.multimesh.visible_instance_count==0),"Area cleanup removes moving food and its batch entries")
 times.sort()
 print("FOOD_MAGNET_PERFORMANCE burst_20_steps_p95_us=%d max_us=%d"%[times[11],times.back()])
 var config=game.settings_path;game.queue_free();current_scene=null;paused=false;await frames(4)
 if FileAccess.file_exists(config):DirAccess.remove_absolute(ProjectSettings.globalize_path(config))
 print("FOOD_MAGNET_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
