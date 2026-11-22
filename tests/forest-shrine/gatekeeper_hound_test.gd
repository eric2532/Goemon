extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Pets=preload("res://scripts/forest/pet_catalog.gd")
const Hound=preload("res://scripts/forest/crowd/hound_sprites.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Balance=preload("res://scripts/forest/core_balance.gd")
const Kit=preload("res://scripts/forest/crowd/army_kit_data.gd")
const Dimensions=preload("res://scripts/forest/crowd/pet_dimensions.gd")
const ROLE=Roles.GATEKEEPER_HOUND
const OUT="res://build/Other Files/Asset Toolkit/Cross Gate Hounds/Guard Hounds/"
const SUMMON_OUT="res://build/Other Files/Asset Toolkit/Cross Gate Hounds/Summon/"
const HUD_OUT="res://build/Other Files/Hound HUD/"

func run():
 var model=load("res://scripts/forest/forest_model.gd").new()
 model.reset(42,{"enemy_health_mult":1.0,"enemy_speed_mult":1.0,"enemy_size_mult":3.0},{},false)
 var stats=Roles.stats(ROLE)
 check(stats.hp==3000 and stats.damage==60 and stats.speed==4.5 and is_equal_approx(Roles.height(ROLE,3),Roles.height(ROLE)) and is_equal_approx(Roles.footprint_radius(ROLE,3),Roles.footprint_radius(ROLE)) and is_equal_approx(stats.range,3.2*Roles.HOUND_SCALE),"Hostile hounds use 3000 HP, 60 damage, 4.5 m/s, and a fixed body despite 3× shared size")
 check(ROLE not in Roles.WAVE_TYPES and ROLE not in Balance.TYPES and Balance.default_wave(0).reduce(func(a,b):return a+b,0)==361,"Hounds are isolated to testing and ordinary wave totals stay unchanged")
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new()
 runtime.configure(null);runtime.configure_kits(Kit.from_model(model))
 verify_dimensions(model,runtime)
 var variants:Array=Pets.motions().variants
 var invalid:int=runtime.spawn(1,0,ROLE,Vector3.ZERO,stats.hp,Roles.footprint_radius(ROLE,3))
 check(not runtime.native.set_hound_skin(invalid,-1) and not runtime.native.set_hound_skin(invalid,Pets.COUNT),"Native arrival rejects out-of-range color slots")
 var counts=[3,3,4,4,3,4,3,3,3,4,6,3,4,4,3,3,4,3,4,4,1]
 for skin in variants.size():
  for direction in (range(8) if skin>=19 else [4]):
   runtime.clear();runtime.set_navigation(skin*8+direction+1,{"width":0})
   var id:int=skin+10001
   var enemy:int=runtime.spawn(id,0,ROLE,Vector3.ZERO,stats.hp,Roles.footprint_radius(ROLE,3))
   check(runtime.native.set_hound_skin(enemy,skin),"Native arrival sets appearance #%d"%variants[skin].id)
   var target={"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([Vector3(0,0,-1.89)]),"hp":PackedFloat32Array([1000])}
   target.hound_camera_yaw=(direction-1)*TAU/8
   runtime.native.set_targets(target)
   var cues=[];var damage=[];var finished=false
   for i in 120:
    runtime.step([.011,.031,.017,.026][i%4],{})
    for event in runtime.take_events():
     if event.source_id!=id:continue
     if event.kind=="attack_started" and skin in [19,20] and cues.is_empty():
      var snapshot:Dictionary=runtime.render_snapshot()
      check(snapshot.action_indices[snapshot.handles.find(enemy)]==direction+1,"Attack pose locks to source direction %d"%direction)
      target.hound_camera_yaw+=PI
      runtime.native.set_targets(target)
     if event.kind=="status":cues.append([event.action_index-500,snappedf(event.source_tick,.0001)])
     if event.kind=="external_damage" and event.target_id==0:damage.append(event.amount)
     if event.kind=="done":finished=true
    if finished:break
   var expected:Array=variants[skin].attack_directions[direction].map(func(c):return [int(c.id),snappedf(c.atMs*.03,.0001)])
   var contacts=variants[skin].attack_directions[direction].filter(func(c):return int(c.flag)>=10000).size() if skin>=21 else 6 if skin==20 and direction in [3,7] else counts[skin]
   if not (finished and cues==expected and damage.size()==contacts):print("TRACE ",skin," finished=",finished," cues=",cues," expected=",expected," damage=",damage)
   check(finished and cues==expected and damage.size()==contacts and damage.all(func(amount):return amount==60),"#%d direction %d plays all original cues and lands %d separate 60-damage contacts"%[variants[skin].id,direction,contacts])
   runtime.apply_hit(enemy,{"amount":3000.0})
   check(runtime.take_events().any(func(e):return e.kind=="death" and e.action_index==skin) and not runtime.valid(enemy),"Retirement of #%d preserves its color for the fall animation"%variants[skin].id)
 runtime.clear();runtime.set_navigation(50,{"width":0})
 var runner:int=runtime.spawn(10001,0,ROLE,Vector3.ZERO,stats.hp,Roles.footprint_radius(ROLE,3))
 runtime.spawn(-1,1,12,Vector3(0,0,-40),1000,.4)
 for i in 60:runtime.step(1.0/60,{})
 var running:Dictionary=runtime.unit_state(runner)
 check(absf(running.position.z+4.5)<.25 and running.pose_row==0,"Fast pursuit advances at the configured speed and keeps the spawn color")
 verify_mantis_pack(runtime,stats)
 verify_guard(runtime,stats)
 verify_combat_recall(runtime,stats)
 verify_orders(runtime,stats)
 verify_pet_ranks(runtime,model)
 runtime.clear();runtime.free();model=null
 if DisplayServer.get_name()!="headless":await verify_desktop()
 print("GATEKEEPER_HOUND_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)

func verify_dimensions(model,runtime):
 var mesh=Pets.make_mesh()
 var factors:PackedFloat32Array=mesh.material.get_shader_parameter("pet_scales")
 check(mesh.material.get_shader_parameter("companion_pet_sizes")==true,"Companion proportions apply in both the arena and Explore")
 for area in ["","city"]:
  model.falan_area=area
  var data=Kit.from_model(model)
  for skin in Pets.COUNT:
   var box=Dimensions.companion_body(skin)
   check(is_equal_approx(factors[skin],data.pet_geometry[Dimensions.offset(ROLE,skin)+6]),"Rendered companion scale matches native geometry: %d"%skin)
   check(Dimensions.bounds(data.pet_geometry,ROLE,skin).is_equal_approx(box),"Native companion hurtbox matches the fitted body in "+area)
   var actor=load("res://scripts/forest/crowd/army_enemy_target.gd").new()
   actor.handle=runtime.spawn(90000+skin,0,ROLE,Vector3.ZERO,3000,2.0)
   runtime.native.set_hound_skin(actor.handle,skin)
   actor.runtime=runtime;actor.variant=ROLE;actor.body_override=box;root.add_child(actor)
   check(actor.get_child(0).shape.size.is_equal_approx(box.size),"Player physics query uses the same companion dimensions")
   for axis in [Vector3.UP,Vector3.RIGHT,Vector3.BACK]:
    var edge=box.get_center()+axis*box.size*.5
    var along=Vector3.RIGHT if axis==Vector3.UP else Vector3.UP
    check(actor.combat_segment_hit(edge-axis*.02-along*10,edge-axis*.02+along*10,0),"Hit inside companion boundary connects")
    check(not actor.combat_segment_hit(edge+axis*.02-along*10,edge+axis*.02+along*10,0),"Hit outside companion boundary misses")
   runtime.despawn(actor.handle);actor.free()
 model.falan_area=""
 check(Dimensions.companion_body(19).size.x>Dimensions.companion_body(0).size.x and Dimensions.companion_body(20).size.x>Dimensions.companion_body(0).size.x,"Large flame and three-headed hounds have wider body fits")

func verify_mantis_pack(runtime,stats):
 runtime.clear();runtime.set_navigation(505,{"width":0})
 var player={"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([Vector3.ZERO]),"hp":PackedFloat32Array([1000])}
 runtime.native.set_targets(player)
 var skins=[29,31,32,33,36];var landed={}
 for i in skins.size():
  var point=Vector3((i-2)*3,0,0)
  var pet:int=runtime.spawn(-100-i,1,ROLE,point,stats.hp,Roles.footprint_radius(ROLE))
  runtime.native.set_pet_skin(pet,skins[i]);runtime.native.set_guard(pet,point,18.0)
  runtime.spawn(100+i,0,12,point+Vector3.FORWARD*2,10000,.7)
 for i in 300:
  runtime.step(1.0/60,{})
  for event in runtime.take_events():
   if event.kind=="damage" and event.source_id in [-100,-101,-102,-103,-104]:landed[event.source_id]=true
 check(landed.size()==5,"All five simultaneous effect/archive mantises land real native contacts")

func verify_pet_ranks(runtime,model):
 runtime.clear();runtime.set_navigation(303,{"width":0})
 var origin=Vector3.ZERO
 var dog:int=runtime.spawn(-102,1,ROLE,origin,150,Roles.footprint_radius(ROLE))
 runtime.native.set_guard(dog,origin,18.0)
 var foe:int=runtime.spawn(42,0,12,Vector3(0,0,-13),1000,.7)
 var player={"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([origin]),"hp":PackedFloat32Array([1000])}
 runtime.native.set_targets(player)
 for i in 30:runtime.step(1.0/60,{})
 var base_speed:float=runtime.unit_state(dog).velocity.length()
 runtime.apply_hit(dog,{"amount":40.0})
 model.team_progression.ranks.merge({"pet_health":1,"pet_damage":1,"pet_speed":1},true)
 var kits=preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(model)
 runtime.configure_kits(kits);runtime.configure_kits(kits)
 var upgraded:Dictionary=runtime.unit_state(dog)
 check(upgraded.max_hp==195 and upgraded.hp==155,"An existing wounded hound gains maximum HP once and retains its damage")
 for i in 20:runtime.step(1.0/60,{})
 check(base_speed>0 and is_equal_approx(runtime.unit_state(dog).velocity.length(),base_speed*1.2),"Pet speed increases native pursuit by 20 percent")
 var upgraded_bite=false
 for i in 240:
  runtime.step(1.0/60,{})
  for event in runtime.take_events():
   if event.kind=="damage" and event.target_id==42 and is_equal_approx(event.amount,65):upgraded_bite=true
  if upgraded_bite:break
 check(upgraded_bite and runtime.valid(foe),"Pet damage increases a real native bite from 50 to 65")


func verify_guard(runtime,stats:Dictionary):
 runtime.clear();runtime.set_navigation(300,{"width":0})
 var radius=Roles.footprint_radius(ROLE)
 var dog:int=runtime.spawn(-102,1,ROLE,Vector3(5,0,0),stats.hp,radius)
 runtime.native.set_hound_skin(dog,20);runtime.native.set_guard(dog,Vector3(5,0,0),18.0)
 var foe:int=runtime.spawn(42,0,12,Vector3(26,0,0),30,.7)
 var player={"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([Vector3.ZERO]),"hp":PackedFloat32Array([1000]),"targetable":PackedByteArray([0])}
 runtime.native.set_targets(player)
 for i in 60:runtime.step(1.0/60,{})
 var first:Vector3=runtime.unit_state(dog).position
 check(runtime.valid(foe) and first.distance_to(Vector3(5,0,0))<.1,"Guard stands in place and ignores an enemy beyond its own search radius")
 for round_ in 2:
  runtime.despawn(foe)
  var start:Vector3=runtime.unit_state(dog).position
  foe=runtime.spawn(42+round_,0,12,start+Vector3.FORWARD*2,30,.7)
  for i in 420:runtime.step(1.0/60,{})
  var resting:Vector3=runtime.unit_state(dog).position
  check(not runtime.valid(foe) and resting.distance_to(start)>1.0 and resting.length()<14,"Guard defeats a nearby threat and finds a fresh spot near the player")
 var moved=Vector3.ZERO
 player.hound_player_speed=8.0
 for i in 180:
  moved.x+=8.0/60
  player.positions[0]=moved;runtime.native.set_targets(player)
  runtime.step(1.0/60,{})
 var following:Vector3=runtime.unit_state(dog).position
 check(following.distance_to(moved)<15 and following.distance_to(first)>8,"The hound follows an untargetable player running faster than its combat speed")
 player.hound_player_speed=0.0;runtime.native.set_targets(player)
 for i in 180:runtime.step(1.0/60,{})
 var settled:Vector3=runtime.unit_state(dog).position
 for i in 60:runtime.step(1.0/60,{})
 check(settled.distance_to(runtime.unit_state(dog).position)<.2,"The hound holds its spot once the player stops")
 runtime.native.rest_allies()
 check(runtime.unit_state(dog).pose_row==20 and runtime.unit_state(dog).team==1,"The guard keeps its original appearance between waves")

func verify_combat_recall(runtime,stats:Dictionary):
 runtime.clear();runtime.set_navigation(301,{"width":0})
 var body=Dimensions.companion_body(0)
 var radius=Vector2(body.size.x,body.size.z).length()*.5
 var dogs:Array[int]=[]
 for i in 6:
  var point=Vector3(cos(TAU*i/6),0,sin(TAU*i/6))*6
  var dog:int=runtime.spawn(-120-i,1,ROLE,point,stats.hp,radius)
  runtime.native.set_guard(dog,point,18.0);dogs.append(dog)
 var enemy:int=runtime.spawn(48,0,12,Vector3(0,0,-1),10000,.7)
 var player={"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([Vector3.ZERO]),"hp":PackedFloat32Array([1000])}
 runtime.native.set_targets(player)
 for i in 180:runtime.step(1.0/60,{})
 var destination=Vector3(45,0,0)
 player.positions[0]=destination;player.hound_player_speed=18.0;runtime.native.set_targets(player)
 for i in 45:runtime.step(1.0/60,{})
 check(runtime.unit_state(enemy).hp<10000 and dogs.all(func(d):return runtime.unit_state(d).target_id==48),"All six guards keep fighting the same enemy when the player sprints out of range")
 runtime.take_events()
 runtime.apply_hit(enemy,{"amount":10000.0})
 player.hound_player_speed=0.0;runtime.native.set_targets(player)
 var previous=dogs.map(func(d):return runtime.unit_state(d).position)
 var max_step=0.0;var blink=false
 for i in 360:
  runtime.step(1.0/60,{})
  for j in dogs.size():
   var point:Vector3=runtime.unit_state(dogs[j]).position
   max_step=maxf(max_step,point.distance_to(previous[j]));previous[j]=point
  for event in runtime.take_events():
   if event.kind=="status" and event.action_index==499:blink=true
  if previous.all(func(point):return point.distance_to(destination)<17) and dogs.all(func(d):return runtime.unit_state(d).velocity.length()<.1):break
 var separated=true
 # Each pet can stop 0.55 m short of its reserved position.
 for i in previous.size():
  for j in i:
   if previous[i].distance_to(previous[j])<maxf(radius*2+.3-1.1,2.0):separated=false
 var arrived=previous.all(func(point):return point.distance_to(destination)<17)
 if blink or max_step>=.75 or not separated or not arrived:
  print("PET_RETURN_TRACE blink=",blink," max_step=",max_step," separated=",separated," posts=",previous)
 check(not blink and max_step<.75 and separated and arrived,"Six guards run back in bounded steps to separate spots after their target dies")

func verify_orders(runtime,stats:Dictionary):
 runtime.clear();runtime.set_navigation(302,{"width":0})
 var dogs:Array[int]=[]
 for i in 6:
  var point=Vector3(4,0,(i-2.5)*4.4)
  var dog:int=runtime.spawn(-140-i,1,ROLE,point,stats.hp,Roles.footprint_radius(ROLE))
  runtime.native.set_guard(dog,point,18.0);dogs.append(dog)
 var first:int=runtime.spawn(60,0,12,Vector3(42,0,-5),60,.7)
 var player={"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([Vector3.ZERO]),"hp":PackedFloat32Array([1000]),"hound_order":1}
 runtime.native.set_targets(player)
 for i in 30:runtime.step(1.0/60,{})
 check(dogs.filter(func(d):var row=runtime.unit_state(d);return row.target_id==60 and row.position.x>9).size()==4,"Four hounds sprint from a stationary player toward an enemy beyond the old order radius")
 for i in range(1,3):runtime.spawn(60+i,0,12,Vector3(46,0,(i-1)*8),3000,.7)
 for i in 90:runtime.step(1.0/60,{})
 var targets={}
 for dog in dogs:targets[runtime.unit_state(dog).target_id]=true
 check(targets.size()>=2 and not targets.has(0),"Hunt splits the pack across distant targets")
 for i in 390:runtime.step(1.0/60,{})
 check(not runtime.valid(first) and dogs.all(func(d):return runtime.unit_state(d).target_id in [61,62]),"Hounds kill their first distant target and move on to the next enemies")
 runtime.take_events()
 player.hound_order=2;runtime.native.set_targets(player)
 var step_max=0.0
 for i in 360:
  var before=dogs.map(func(d):return runtime.unit_state(d).position)
  runtime.step(1.0/60,{})
  for j in dogs.size():step_max=maxf(step_max,before[j].distance_to(runtime.unit_state(dogs[j]).position))
 check(step_max>.5 and step_max<.65 and dogs.all(func(d):var row=runtime.unit_state(d);return row.target_id==0 and row.position.length()<18),"Return ends combat and sprints back on foot before defending")
 var separation=INF
 for i in dogs.size():
  for j in i:separation=minf(separation,runtime.unit_state(dogs[i]).position.distance_to(runtime.unit_state(dogs[j]).position))
 check(separation>Roles.footprint_radius(ROLE)*1.5 and dogs.all(func(d):return runtime.unit_state(d).velocity.length()<2.5),"Returning hounds ease down into separate spots")
 runtime.spawn(64,0,12,Vector3(-3,0,0),3000,.7)
 for i in 30:runtime.step(1.0/60,{})
 check(dogs.any(func(d):return runtime.unit_state(d).target_id==64),"Returned pets automatically defend against a nearby foe without G")
 player.hound_order_serial=1;runtime.native.set_targets(player);runtime.step(1.0/60,{})
 check(dogs.all(func(d):return runtime.unit_state(d).target_id==0),"Repeated recall interrupts resumed defense")

func verify_desktop():
 var document=load("res://scripts/forest/forest_map_document.gd").new()
 if "--large" in OS.get_cmdline_user_args():document.load_wind_meadow_large()
 else:document.load_wind_meadow()
 await setup_fixture(document.data)
 game.settings.forest_pet_loadout=Pets.sanitized([Pets.key(0),Pets.key(2),Pets.key(17),Pets.key(18),Pets.key(20)])
 game.army_runtime.set_process(false)
 var runtime=game.army_runtime
 var ui=game.forest_ui
 ui.sync()
 check(not ui.hound_dock.visible and ui.loadout_slots.position.y==26,"The player HUD reserves no extra room before summoning")
 var renderer=game.crowd.army
 var fx=renderer.presentation
 var summon_batch:MultiMesh=fx.batches.hound_summon.multimesh
 var summon_material:ShaderMaterial=summon_batch.mesh.material
 var atlas:Texture2D=summon_material.get_shader_parameter("atlas")
 var summon_image=Image.new()
 summon_image.load_png_from_buffer(FileAccess.get_file_as_bytes(Hound.ROOT+"summon.png"))
 check(atlas.get_image().get_data()==summon_image.get_data(),"The imported effect retains all seven frames' original RGBA bytes")
 var pcm=HashingContext.new()
 pcm.start(HashingContext.HASH_SHA256)
 pcm.update(Hound.SUMMON_SOUND.data)
 check(Hound.SUMMON_SOUND.mix_rate==22050 and pcm.finish().hex_encode()=="66f1650bd0fcddb53dd8478128da80bf0f3451e5809e9d41e1d898fcd35d4206","The game uses the original uncompressed summon PCM")
 game.model.balance.enemy_size_mult=3.0
 runtime.refresh_kits()
 runtime.integration_tick(1.0/60)
 var home=Vector3(-150,0,127)
 home.y=game.model.surface_height(home.x,home.z)
 game.player.position=home
 var key=InputEventKey.new();key.physical_keycode=KEY_P;key.pressed=true
 game._input(key)
 ui.sync()
 check(not ui.hound_dock.visible,"Queued hounds have no portrait until they arrive")
 var first_tick=true
 for i in 24:
  if runtime.pending_hounds.is_empty():break
  runtime.integration_tick(1.0/60)
  runtime.flush_presentation()
  if first_tick:
   check(fx.voices.filter(func(voice):return voice.playing and voice.stream==Hound.SUMMON_SOUND).size()==1,"The first successful arrivals play the original summon sound on one pooled voice")
   first_tick=false
 var queued=runtime.render_snapshot()
 var seen={}
 for i in queued.kinds.size():
  if queued.kinds[i]==ROLE and queued.teams[i]==1:seen[queued.pose_rows[i]]=true
 check(runtime.pending_hounds.is_empty() and seen.size()==5,"P summons only the five selected native pets")
 ui.sync()
 check(ui.hound_dock.visible and ui.hound_heads.all(func(head):return head.visible and head.modulate.a==1.0),"Five selected pets get fully opaque heads on arrival")
 check(ui.hound_dock.get_global_rect().position.y>=ui.health.get_global_rect().end.y and ui.hound_dock.get_global_rect().position.y>=ui.loadout_slots.get_global_rect().end.y,"The heads fit below player HP and the integrated loadout")
 var hound_shader:ShaderMaterial=renderer.meshes[ROLE].material
 var soldier_shader:ShaderMaterial=renderer.meshes[0].surface_get_material(0)
 check(is_equal_approx(hound_shader.get_shader_parameter("enemy_size"),Roles.HOUND_SCALE) and is_equal_approx(soldier_shader.get_shader_parameter("enemy_size"),3.0),"Hounds use their own scale while ordinary enemies honor the saved 3×")
 check(Dimensions.bounds(runtime.pet_geometry,ROLE,0).is_equal_approx(Dimensions.companion_body(0)),"Live hound contacts use the fitted companion dimensions despite shared enemy size")
 var exact=true
 for page in int(Pets.motions().pages):
  var image=Image.new();image.load_png_from_buffer(FileAccess.get_file_as_bytes(Pets.motions().atlas_paths[page]));image.convert(Image.FORMAT_R8)
  exact=exact and hound_shader.get_shader_parameter("pixels").get_layer_data(page).get_data()==image.get_data()
 check(exact,"All GPU index layers match the recovered source atlas bytes")
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=home+Vector3(-4,20,32);camera.look_at(home+Vector3.UP)
 game.crowd.present_army(queued,[])
 fx.tick(.12)
 var summons:Array=fx.effects.filter(func(row):return row.kind=="hound_summon")
 check(summons.size()==5 and summon_batch.visible_instance_count==5,"Each arrival plays at its spawn point in one shared effect batch")
 var sample=Vector3(Hound.SUMMON_CENTER.x,Hound.SUMMON_CENTER.y,.07)
 check(summons.size()==5 and summon_batch.get_instance_transform(0).origin.is_equal_approx(summons[0].position+camera.global_basis.orthonormalized()*sample),"The original frame anchor stays at the arrival point")
 await capture_hounds("Goemon summon effect",SUMMON_OUT)
 game._input(key)
 runtime.integration_tick(1.0/60);runtime.flush_presentation()
 check(fx.effects.filter(func(row):return row.kind=="hound_summon").size()==5,"Pressing P with a full pack does not replay the effect")
 fx.tick(Hound.SUMMON_LIFE)
 check(summon_batch.visible_instance_count==0 and not fx.effects.any(func(row):return row.kind=="hound_summon"),"The summon effects expire and release their shared slots")
 fx.suspend_audio()
 var tracked:int=runtime.handles[runtime.HOUND_ID-20]
 var other:int=runtime.handles[runtime.HOUND_ID-2]
 runtime.apply_hit(tracked,{"amount":1500.0})
 runtime.apply_hit(other,{"amount":2250.0})
 runtime.integration_tick(1.0/60);ui.sync()
 check(is_equal_approx(ui.hound_heads[4].modulate.a,.5) and is_equal_approx(ui.hound_heads[1].modulate.a,.25) and ui.hound_heads[0].modulate.a==1.0,"Independent native damage maps linearly to portrait opacity")
 await capture_hounds("Guard hound health",HUD_OUT)
 game.player.select_character(18);ui.sync()
 check(ui.hound_dock.is_visible_in_tree() and ui.hound_dock.get_parent()==ui.master_chief_hud.health,"The same heads follow the visor health bar on a fighter switch")
 check(not ui.master_chief_hud.health.get_global_rect().intersects(ui.wave_countdown.get_global_rect()) and not ui.hound_dock.get_global_rect().intersects(ui.hint.get_global_rect()),"Visor health and heads stay clear of the countdown and toast")
 await capture_hounds("Guard hound health visor",HUD_OUT)
 game.player.select_character(1)
 for i in 24:runtime.integration_tick(1.0/60)
 var lethal:Dictionary=runtime.apply_hit(tracked,{"amount":1500.0})
 ui.sync()
 check(lethal.dead and not ui.hound_heads[4].visible and ui.hound_heads[1].visible,"Death clears only the fallen hound's fixed slot")
 game._input(key)
 for i in 8:
  runtime.integration_tick(1.0/60);runtime.flush_presentation()
  if runtime.pending_hounds.is_empty():break
 check(fx.effects.filter(func(row):return row.kind=="hound_summon").size()==1 and fx.voices.any(func(voice):return voice.playing and voice.stream==Hound.SUMMON_SOUND),"A single resummoned hound reuses the original effect and audio")
 ui.sync()
 check(ui.hound_heads[4].visible and ui.hound_heads[4].modulate.a==1.0 and is_equal_approx(ui.hound_heads[1].modulate.a,.25),"Resummoning restores only that hound's portrait to full opacity")
 fx.tick(Hound.SUMMON_LIFE)
 check(renderer.submitted>=5 and renderer.batches.keys().filter(func(key):return key.x==ROLE).size()<=2,"Five selected friendly appearances use the existing spatial batches")
 var other_allies=0
 for i in queued.kinds.size():
  if queued.teams[i]==1 and queued.kinds[i]!=ROLE and renderer.meshes.has(queued.kinds[i]) and (not (queued.status[i]&64) or queued.kinds[i]==8):other_allies+=1
 check(renderer.counts().health==other_allies,"The army health overlay excludes all hounds")
 await capture_hounds("Goemon guard pack")
 var samples=[]
 var mixed=false
 runtime.native.set_targets(runtime.external_targets())
 for i in 720:
  var started=Time.get_ticks_usec()
  runtime.step(1.0/60,{})
  samples.append((Time.get_ticks_usec()-started)/1000.0)
  if i%12!=0:continue
  var current:Dictionary=runtime.render_snapshot()
  var idle=0;var walking=0
  for index in current.kinds.size():
   if current.kinds[index]!=ROLE:continue
   var motion:Vector3=current.pose_velocities[index]
   var speed=Vector2(motion.x,motion.z).length()
   if speed<=.1:idle+=1
   elif speed<2:walking+=1
  if idle>0 and walking>0:
   mixed=true
   game.crowd.present_army(current,[])
   await capture_hounds("Goemon guard patrol")
   break
 check(mixed,"The live guard pack mixes idle and original walking motion while the player stands still")
 samples.sort()
 print("HOUND_PACK_STEP samples=",samples.size()," p95_ms=",samples[floori((samples.size()-1)*.95)]," max_ms=",samples[-1])
 runtime.clear();game.model.enemies.clear()
 ui.sync()
 check(not ui.hound_dock.visible and ui.loadout_slots.position.y==26,"Clearing the army restores the original HUD layout")
 game.player.select_character(34)
 var midpoint=home+Vector3(0,0,3)
 game.player.position=midpoint+Vector3.LEFT*1.8
 game.player.facing=Vector3(1,0,1).normalized()
 camera.global_position=midpoint+Vector3(0,1.65,12);camera.look_at(midpoint+Vector3.UP*1.65)
 var kazi=game.player.model
 kazi.show_pose(0,0,true)
 var point=midpoint+Vector3.RIGHT*1.8
 var dog:int=runtime.spawn(-102,1,ROLE,point,3000,Roles.footprint_radius(ROLE))
 runtime.set_pose(dog,point,-3*PI/4)
 game.crowd.present_army(runtime.render_snapshot(),[])
 var table:Image=hound_shader.get_shader_parameter("frames").get_image()
 var first_frame=int(table.get_pixel(4,0).r)
 var placement_index=int(Pets.motions().clip_count)+first_frame*2+1
 var source_top:float=table.get_pixel(placement_index%table.get_width(),placement_index/table.get_width()).g
 var hound_height:float=(10-source_top)*hound_shader.get_shader_parameter("pixel_size")*hound_shader.get_shader_parameter("enemy_size")
 var kazi_height:float=(kazi.sprite.offset.y+kazi.sprite.region_rect.size.y*.5)*kazi.sprite.pixel_size*kazi.scale.y
 check(kazi.direction()==4 and absf(hound_height-kazi_height*1.4)<.01,"The actual front-diagonal hound stands 40% taller than Kazi within 1 cm")
 await capture_hounds("Kazi and hound height")
 runtime.clear();fx.clear()
 game.player.hide()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=22
 camera.global_position=midpoint+Vector3(0,7,24);camera.look_at(midpoint+Vector3.UP*1.5)
 var lineup=[0,21,31,32,36]
 for i in lineup.size():
  var place=midpoint+Vector3((i-2)*4.2,0,0)
  var pet:int=runtime.spawn(-200-i,1,ROLE,place,3000,Roles.footprint_radius(ROLE))
  runtime.native.set_hound_skin(pet,lineup[i]);runtime.set_pose(pet,place,-3*PI/4)
  if i>0:
   var row=lineup[i]*48+4
   check(is_equal_approx(table.get_pixel(row%table.get_width(),row/table.get_width()).a,Roles.HOUND_PIXEL_SIZE/(2.0 if lineup[i]==36 else 1.0)),"Mantis #%d matches hound pixel density after source-resolution correction"%Pets.motions().variants[lineup[i]].id)
 game.crowd.present_army(runtime.render_snapshot(),[])
 await capture_hounds("Hound and enlarged mantises","res://build/Other Files/Asset Toolkit/Cross Gate Mantises/")
 game.queue_free();await process_frame

func capture_hounds(label_:String,directory:String=OUT):
 await process_frame;RenderingServer.force_draw();await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute(directory)
 check(root.get_texture().get_image().save_png(directory+label_+(" large" if "--large" in OS.get_cmdline_user_args() else "")+".png")==OK,"Captured "+label_)
