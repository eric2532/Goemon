extends "res://scripts/recovered_goemon_gameplay_tests.gd"
## Actual physics travel plus distance/cadence checks for the Cross Gate roster.
const Roster=preload("res://scripts/rogue_roster.gd")
const Balance=preload("res://scripts/character_balance.gd")
const Gear=preload("res://scripts/forest/equipment.gd")
var OUT="res://build/Other Files/Asset Toolkit/Bau El Gen Sarah/Movement/" if "--four-cast" in OS.get_cmdline_user_args() else "res://build/Other Files/Asset Toolkit/Movement Feel/"
var baseline="--baseline" in OS.get_cmdline_user_args()
var visual="--visual" in OS.get_cmdline_user_args()
var driver
var rows=[]
var tick_us=[]
var home=Vector3(0,100.05,60)
var sprint_held=false
var slow_walk_held=false

func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)

func key(code:Key,pressed:bool):
 var event=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed
 Input.parse_input_event(event);Input.flush_buffered_events()
 if code==KEY_SHIFT:sprint_held=pressed
 elif code==KEY_CTRL:slow_walk_held=pressed
 # OS focus changes can release synthetic held keys during desktop captures.
 if visual and code in [KEY_A,KEY_D]:game.player.smoke_move.x=(1 if code==KEY_D else -1) if pressed else 0

func advance(dt:float):
 if visual:
  if sprint_held:Input.action_press("sprint")
  else:Input.action_release("sprint")
  if slow_walk_held:Input.action_press("walk_modifier")
  else:Input.action_release("walk_modifier")
 var start=Time.get_ticks_usec()
 game.player._physics_process(dt)
 tick_us.append(Time.get_ticks_usec()-start)
 var camera=game.camera_rig.camera
 camera.global_position=game.player.position+Vector3(0,3,11)
 camera.look_at(game.player.position+Vector3.UP*1.4)

func settle():
 key(KEY_D,false);key(KEY_SHIFT,false);key(KEY_CTRL,false)
 await process_frame
 var p=game.player;p.active_ability.cancel(true);p.set_auto_attack(false)
 p.position=home;p.velocity=Vector3.ZERO;p.facing=Vector3.RIGHT
 p.model.rotation=Vector3(0,-PI/2,0);p.model.phase=0;p.model.reset_jump_pose()
 p.impact_pause=0;p.dodge_time=0;p.jump_windup=0;p.combat_hold_left=0
 await driver.advance(15,advance)
 check(p.is_on_floor(),"Body settles onto the collision platform")

func capture(stem:String):
 if not visual or DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+("before-" if baseline else "after-")+stem+".png")==OK,"Captured "+stem)

func measure(label_:String,sprint:bool,shoes:bool=false):
 var p=game.player
 var owner=Gear.character_key(p.character_id)
 game.settings.gear_loadouts={owner:{"accessory:5":"accessory:21817"}} if shoes else {}
 Gear.apply(p)
 await settle()
 key(KEY_D,true);key(KEY_SHIFT,sprint);await process_frame
 await driver.advance(30,advance)
 var origin=p.position;var phase=p.model.phase;var events=p.model.locomotion.step_events
 for frame in 60:
  await driver.advance(1,advance)
  if frame%3==0:await capture(label_+"-%02d"%frame)
 var distance=p.position.distance_to(origin)
 var end_phase=p.model.phase;var moving_steps=p.model.locomotion.step_events-events
 var speed=Vector2(p.velocity.x,p.velocity.z).length()
 var desired=p.combat_tuning("sprint_speed" if sprint else "walk_speed")*(3.0 if shoes else 1.0)
 check(absf(speed-desired)<.02,"%s reaches its configured controller speed"%label_)
 check(p.model.current_clip.begins_with("3:" if sprint else "1:"),label_+" selects the matching gait")
 check(absf(distance-speed)<.05,label_+" travels its measured speed in one physics second")
 key(KEY_D,false);key(KEY_SHIFT,false);await process_frame
 var stop=p.position
 await driver.advance(12,advance)
 var stop_distance=p.position.distance_to(stop)
 check(Vector2(p.velocity.x,p.velocity.z).length()<.01,label_+" stops within 200 ms")
 var row={"label":label_,"speed":speed,"distance":distance,"phase_start":phase,"phase_end":end_phase,"steps_per_second":moving_steps,"stop_distance":stop_distance}
 rows.append(row);print("MOVEMENT_FEEL_SAMPLE ",JSON.stringify(row))

func verify_distance_clock(p):
 var model=p.model
 model.reset_jump_pose();model.clear_kagerou_dodge()
 for sprint in [false,true]:
  if sprint:Input.action_press("sprint")
  else:Input.action_release("sprint")
  var phases=[];var steps=[]
  for speed in ([1.0,4.0] if not sprint else [4.0,8.0]):
   model.phase=0;model.locomotion.step_events=0
   model.locomotion_velocity=Vector3.RIGHT*speed
   var dt=.5/speed
   for tick in 6:model.animate(dt,speed,true,0,0,false,0,false)
   phases.append(model.phase);steps.append(model.locomotion.step_events)
  check(is_equal_approx(phases[0],phases[1]) and steps[0]==steps[1],"%d equal ground distance has equal gait phase at different speeds (sprint=%s)"%[p.character_id,sprint])
  var phase=model.phase;var events=model.locomotion.step_events
  model.locomotion_velocity=Vector3.ZERO
  model.animate(.2,18,true,0,0,false,0,false)
  check(model.phase==phase and model.locomotion.step_events==events and model.current_clip.begins_with("0:"),"%d obstruction has no phantom steps"%p.character_id)
  model.locomotion_velocity=Vector3.RIGHT*8
  model.animate(.2,8,false,4,0,false,0,false)
  check(model.phase==phase and model.locomotion.step_events==events,"%d airborne travel has no ground stride"%p.character_id)
 Input.action_release("sprint")
 var phase=model.phase
 Input.action_press("sprint");model.animate(0,8,true,0,0,false,0,false)
 Input.action_release("sprint");p.facing=Vector3.LEFT;model.animate(0,8,true,0,0,false,0,false)
 check(model.phase==phase,"%d Shift/reversal retain stride phase"%p.character_id)
 # A larger body covers proportionally more ground with the same drawing.
 model.phase=0;model.locomotion_velocity=Vector3.RIGHT*4
 model.animate(.1,4,true,0,0,false,0,false);var normal=model.phase
 model.scale*=2;model.phase=0
 model.animate(.2,4,true,0,0,false,0,false)
 check(is_equal_approx(model.phase,normal),"%d stride respects model scale"%p.character_id)
 model.scale/=2

func verify_transitions():
 var p=game.player
 p.select_character(Roster.SHIN_ID);game.settings.gear_loadouts={};Gear.apply(p)
 await settle()
 key(KEY_D,true);key(KEY_SHIFT,true);await process_frame
 await driver.advance(30,advance)
 key(KEY_SHIFT,false);await process_frame;await driver.advance(30,advance)
 check(is_equal_approx(p.velocity.x,p.combat_tuning("walk_speed")) and p.model.current_clip.begins_with("1:"),"Releasing Shift while moving restores walking speed and pose")
 key(KEY_SHIFT,true);key(KEY_CTRL,true);await process_frame;await driver.advance(30,advance)
 check(is_equal_approx(p.velocity.x,2.2) and p.model.current_clip.begins_with("1:"),"Ctrl slow walk overrides Shift in actual player physics")
 key(KEY_SHIFT,false);key(KEY_CTRL,false);key(KEY_D,false);key(KEY_A,true)
 await process_frame;await driver.advance(20,advance)
 check(absf(p.velocity.x+p.combat_tuning("walk_speed"))<.01 and p.facing.x< -.99,"Direction reversal promptly reaches the opposite speed and facing")
 var wall=StaticBody3D.new();root.add_child(wall)
 var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(1,10,20)
 wall.add_child(shape);wall.position=p.position+Vector3.LEFT*2
 await driver.advance(60,advance)
 var phase=p.model.phase;var events=p.model.locomotion.step_events
 await driver.advance(20,advance)
 check(p.model.locomotion.actual_speed<.01 and p.model.current_clip.begins_with("0:") and p.model.phase==phase and p.model.locomotion.step_events==events,"An actual wall stops ground travel, animation and new footfalls")
 key(KEY_A,false);await process_frame;wall.queue_free()

func verify_movement_bonuses(p):
 var owner=Gear.character_key(p.character_id)
 game.settings.gear_loadouts={owner:{"accessory:5":"accessory:21817"}};Gear.apply(p)
 p.apply_food_buff("movement_speed");p.progression.level=99
 # Wind Walk is a prepared shared buff, including on borrowed loadouts.
 var instance=p.spell_loadout._instance("blademaster/wind-walk")
 instance.controller.wind_left=10
 var bonus=p.movement_multiplier()
 check(is_equal_approx(bonus,3*1.2*1.4*1.5),"%d shoes/food/level/Wind Walk stack for movement"%p.character_id)
 p.skullpion_poison_left=10
 check(is_equal_approx(p.movement_multiplier(),bonus*.55),"%d poison still slows movement alongside positive bonuses"%p.character_id)
 p.skullpion_poison_left=0
 p.ai_controlled=true
 check(is_equal_approx(p.movement_multiplier(),bonus),"%d native copies retain their existing movement budget"%p.character_id)
 p.ai_controlled=false
 instance.controller.wind_left=0;p.clear_food_buffs();p.progression.reset(false)
 game.settings.gear_loadouts={};Gear.apply(p)
 check(is_equal_approx(p.movement_multiplier(),1.0),"%d removing bonuses restores base movement"%p.character_id)

func verify_buffed_controls():
 var p=game.player;p.select_character(Roster.SHIN_ID)
 await settle()
 game.settings.gear_loadouts={Gear.character_key(p.character_id):{"accessory:5":"accessory:21817"}};Gear.apply(p)
 p.apply_food_buff("movement_speed");p.progression.level=99
 var wind=p.spell_loadout._instance("blademaster/wind-walk").controller;wind.wind_left=10
 key(KEY_D,true);await process_frame;await driver.advance(30,advance)
 var bonus=3*1.2*1.4*1.5
 check(absf(p.velocity.x-p.combat_tuning("walk_speed")*bonus)<.02 and p.model.current_clip.begins_with("1:"),"Stacked shoes, food, levels and Wind Walk boost actual walking")
 key(KEY_SHIFT,true);await process_frame;await driver.advance(30,advance)
 var expected=p.combat_tuning("sprint_speed")*3*1.2*1.4*1.5
 check(absf(p.velocity.x-expected)<.02 and p.model.current_clip.begins_with("3:"),"Holding Shift activates all stacked sprint bonuses in actual movement")
 key(KEY_SHIFT,false);await process_frame;await driver.advance(15,advance)
 check(absf(p.velocity.x-p.combat_tuning("walk_speed")*bonus)<.02,"Releasing Shift returns to buffed walking speed within 250 ms")
 key(KEY_SHIFT,true);key(KEY_CTRL,true);await process_frame;await driver.advance(30,advance)
 check(absf(p.velocity.x-2.2*bonus)<.02,"Ctrl retains its slow-walk ratio with movement bonuses")
 p.skullpion_poison_left=10
 key(KEY_CTRL,false);key(KEY_SHIFT,false);await process_frame;await driver.advance(30,advance)
 check(absf(p.velocity.x-p.combat_tuning("walk_speed")*bonus*.55)<.02,"Poison slows actual walking even with positive buffs equipped")
 p.skullpion_poison_left=0;wind.wind_left=.001;p.food_buffs.movement_speed=.001
 await driver.advance(2,advance)
 check(p.food_multiplier("movement_speed")==1 and p.spell_loadout.wind_controller()==null,"Timed food and Wind Walk bonuses expire through their existing clocks")
 p.progression.reset(false);game.settings.gear_loadouts={};Gear.apply(p)
 await driver.advance(30,advance)
 check(is_equal_approx(p.velocity.x,p.combat_tuning("walk_speed")),"Buff expiry and equipment removal leave walking unchanged")
 key(KEY_SHIFT,true);await process_frame;await driver.advance(30,advance)
 check(is_equal_approx(p.velocity.x,p.combat_tuning("sprint_speed")),"Sprint returns to its configured base after bonuses expire")
 key(KEY_D,false);key(KEY_SHIFT,false);await process_frame

func run():
 create_timer(300).timeout.connect(func():printerr("MOVEMENT_FEEL_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT)
 Input.use_accumulated_input=false
 root.size=Vector2i(960,600);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.explorer_helpers.set_process(false);game.model.waves.patrol_posts.clear()
 game.settings.forest_pet_loadout=[];game.settings.gear_loadouts={};game.character_tuning={}
 game.training_dummy.position=Vector3(0,-100,0);game.training_dummy.collision_layer=0
 for node in [game,game.player,game.camera_rig]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 game.player.smoke_mode=visual;game.player.soft_target=false;game.tuning.invincible=true
 game.player.progression.reset(false);game.player.set_scarf_equipped(false)
 game.camera_rig.yaw=0;root.gui_disable_input=true
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 var floor_=StaticBody3D.new();root.add_child(floor_)
 var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(400,1,400)
 floor_.add_child(shape);floor_.position=home-Vector3.UP*.55
 var mesh=MeshInstance3D.new();mesh.mesh=PlaneMesh.new();mesh.mesh.size=Vector2(400,400)
 var texture=Image.create(2,2,false,Image.FORMAT_RGB8)
 texture.fill(Color("809184"));texture.set_pixel(0,0,Color("596e61"));texture.set_pixel(1,1,Color("596e61"))
 var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.albedo_texture=ImageTexture.create_from_image(texture);material.uv1_scale=Vector3(200,200,1)
 material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;mesh.material_override=material
 root.add_child(mesh);mesh.position=home-Vector3.UP*.05
 await physics_frame
 var p=game.player
 for character in Roster.CROSSGATE:
  p.select_character(character);p.active_ability.cancel(true);p.set_auto_attack(false)
  if not baseline:verify_distance_clock(p)
  if not baseline:verify_movement_bonuses(p)
  var expected=[10.2,18.0]
  var accepted=Balance.sanitized({"walk_speed":expected[0],"sprint_speed":expected[1]},character)
  check(is_equal_approx(accepted.walk_speed,expected[0]) and is_equal_approx(accepted.sprint_speed,expected[1]),"%d balance controls/save validation accept the movement defaults"%character)
  for index in 2:
   var field="walk_speed" if index==0 else "sprint_speed"
   check(is_equal_approx(p.combat_tuning(field),expected[index]),"%d uses the tuned %s"%[character,field])
   var profile=Balance.key_for(character)
   game.character_tuning[profile]={field:23.0}
   check(p.combat_tuning(field)==23,"%d explicit speed override remains authoritative"%character)
   game.character_tuning.erase(profile)
 await frames(3)
 for character in ([Roster.BAU_ID,Roster.EL_ID,Roster.GEN_ID,Roster.SARAH_ID] if "--four-cast" in OS.get_cmdline_user_args() else [Roster.SHIN_ID,Roster.KAZI_ID,Roster.SHIN_SPECIAL_ID]):
  p.select_character(character)
  if character==Roster.SHIN_ID:game.select_shin_skin(character,900050)
  elif character==Roster.SHIN_SPECIAL_ID:game.select_shin_skin(character,118993)
  for sprint in [false,true]:await measure("%d-%s"%[character,"sprint" if sprint else "walk"],sprint)
  if character==Roster.SHIN_ID:
   await measure("37-speed-shoes-walk",false,true)
   await measure("37-speed-shoes",true,true)
 if not baseline:
  await verify_transitions()
  await verify_buffed_controls()
 # Warm repeated animation must retain the existing resources.
 p.model.locomotion_velocity=Vector3.RIGHT*8
 p.model.animate(.1,8,true,0,0,false,0,false);await frames(3)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for repeat in 600:p.model.animate(1.0/60,8,true,0,0,false,0,false)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated locomotion retains node/resource counts")
 tick_us.sort()
 var result={"checks":checks,"failures":failures,"renderer":DisplayServer.get_name(),"rows":rows,"player_tick_p95_us":tick_us[floori(tick_us.size()*.95)],"player_tick_max_us":tick_us.back()}
 FileAccess.open(OUT+("before" if baseline else "after")+("-desktop" if visual else "-headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 key(KEY_D,false);key(KEY_SHIFT,false);key(KEY_CTRL,false)
 var path=game.settings_path;game.queue_free();floor_.queue_free();mesh.queue_free();driver.queue_free()
 await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("MOVEMENT_FEEL_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
