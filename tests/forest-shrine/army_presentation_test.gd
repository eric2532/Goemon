extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var r=load("res://scripts/forest/crowd/army_runtime.gd").new();r.configure(null);r.set_navigation(1,{"width":0})
 check(r.has_method("render_snapshot"),"Renderer consumes owned packed poses without per-unit scene nodes")
 if r.has_method("render_snapshot"):
  r.spawn(1,0,0,Vector3.ZERO,200,3.9);r.spawn(-1,1,7,Vector3(8,0,0),500,.4)
  var before=r.render_snapshot();r.step(.25,{"goal_handles":before.handles,"goal_positions":PackedVector3Array([Vector3(0,0,4),Vector3(8,0,4)]),"goal_speeds":PackedFloat32Array([4,4])})
  check(["render_actions","render_time","stun_left","flash_left","projectile_age"].all(func(key):return before.has(key)),"Packed render state carries visual recovery, hurt and projectile clocks")
  var moved=r.render_snapshot()
  check(before.positions[0]==Vector3.ZERO and moved.positions[0]!=before.positions[0],"Old render buffers remain immutable after units move")
  check(moved.pose_time.size()==2 and moved.pose_time[0]>.2,"Every NPC owns an independent active animation clock")
  var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {},false)
  r.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(model))
  r.apply_hit(before.handles[0],{"element":"ice","status_seconds":1.0});r.step(.1,{})
  var frozen=r.render_snapshot();r.step(.4,{})
  check(r.render_snapshot().pose_time[0]==frozen.pose_time[0],"A frozen body keeps the same GPU pose sample")
  check(r.render_snapshot().pose_time[1]>frozen.pose_time[1],"Other units continue their own animation while one is frozen")
 r.clear();r.free()
 var ready=true
 for file in ["scripts/forest/crowd/army_renderer.gd","scripts/forest/crowd/army_presentation.gd","assets/characters/ally_crowd/11.res","assets/characters/ally_crowd/5.res","assets/characters/ally_crowd/7.res","assets/characters/ally_crowd/8.res","assets/characters/ally_crowd/10.res"]:
  var exists=FileAccess.file_exists("res://"+file);check(exists,"Original crowd presentation exists: "+file);ready=ready and exists
 for kind in [11,5,7,8,10]:
  if not FileAccess.file_exists("res://assets/characters/ally_crowd/%d.res"%kind):continue
  var baked=load("res://assets/characters/ally_crowd/%d.res"%kind)
  check(baked.get_meta("mesh").get_surface_count()>0,"Kind %d retains drawable source mesh surfaces"%kind)
 if FileAccess.file_exists("res://assets/characters/ally_crowd/10.res"):await verify_source()
 if ready:await verify_presentation()
 print("ARMY_PRESENTATION_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
func verify_presentation():
 var renderer=load("res://scripts/forest/crowd/army_renderer.gd").new();root.add_child(renderer);renderer.configure(null)
 var effects=renderer.presentation
 var baseline:Dictionary=effects.counts()
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null);runtime.set_navigation(1,{"width":0})
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {},false)
 runtime.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(model))
 var kinds=[0,1,3,11,5,7,8,10]
 for i in kinds.size():runtime.spawn(i+1 if i<3 else -i,0 if i<3 else 1,kinds[i],Vector3(i*40,4*(i%3),0),500,.4)
 runtime.step(1.0/60,{})
 var s=runtime.render_snapshot();renderer.present(s,[])
 check(renderer.counts().units==8 and renderer.counts().health==5,"All eight NPC kinds render with five independent ally health bars")
 check(renderer.batches.size()==8,"Spatial partitions keep distinct remote units in independent culling batches")
 for key in renderer.batches:
  var node=renderer.batches[key];var index=kinds.find(key.x)
  var raw:PackedFloat32Array=node.multimesh.buffer
  check(Vector3(raw[3],raw[7],raw[11]).distance_to(s.positions[index])<.001,"Kind %d render root retains authoritative terrain elevation"%key.x)
  if RenderingServer.get_rendering_device()!=null:check(node.multimesh.get_instance_transform(0).origin.distance_to(s.positions[index])<.001,"GPU transform agrees with the packed submission for kind %d"%key.x)
  check(node.multimesh.mesh==renderer.meshes[key.x],"Kind %d uses the shared mesh/material resource"%key.x)
 # Two actors in one batch retain their own facing and pose clocks.
 runtime.clear();var a:int=runtime.spawn(-1,1,11,Vector3.ZERO,200,.4);runtime.step(.1,{})
 var b:int=runtime.spawn(-2,1,11,Vector3(4,0,0),200,.4);runtime.set_pose(a,Vector3.ZERO,0);runtime.set_pose(b,Vector3(4,0,0),PI/2)
 runtime.step(1.0/60,{});s=runtime.render_snapshot();renderer.present(s,[])
 var batch=renderer.batches[Vector3i(11,0,0)].multimesh
 var raw:PackedFloat32Array=batch.buffer
 check(batch.visible_instance_count==2 and absf(Vector3(raw[2],raw[6],raw[10]).dot(Vector3(raw[18],raw[22],raw[26])))<.001,"Batching preserves independent actor facing")
 check(raw[12]!=raw[28],"Shared animation texture retains independent per-unit phases")
 runtime.apply_hit(a,{"element":"ice","status_seconds":1.0});runtime.step(.1,{});s=runtime.render_snapshot();var frozen=renderer.pose_sample(s,0)
 runtime.step(.4,{});renderer.present(runtime.render_snapshot(),[])
 check(renderer.pose_sample(runtime.render_snapshot(),0)==frozen,"Frozen actor holds the same texture row and tint while neighbours move")
 var moving_freeze=load("res://scripts/forest/crowd/army_runtime.gd").new();moving_freeze.configure(null);moving_freeze.set_navigation(1,{"width":0})
 var runner:int=moving_freeze.spawn(-1,1,11,Vector3.ZERO,200,.4)
 moving_freeze.step(.2,{"goal_handles":PackedInt64Array([runner]),"goal_positions":PackedVector3Array([Vector3(0,0,8)]),"goal_speeds":PackedFloat32Array([4])})
 var walk=renderer.pose_sample(moving_freeze.render_snapshot(),0)
 moving_freeze.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(model));moving_freeze.apply_hit(runner,{"element":"ice","status_seconds":1});moving_freeze.step(.2,{})
 var held=renderer.pose_sample(moving_freeze.render_snapshot(),0)
 check(walk.r==held.r and walk.g==held.g and absf(fposmod(walk.b,2)-fposmod(held.b,2))<.000001,"Freezing a walking fighter retains its gait and motion blend instead of snapping idle")
 moving_freeze.clear();moving_freeze.free()
 var walking=load("res://scripts/forest/crowd/army_runtime.gd").new();walking.configure(null);walking.set_navigation(1,{"width":0});walking.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(model))
 var distant:int=walking.spawn(1,0,0,Vector3.ZERO,10000,3.9);walking.apply_hit(distant,{"element":"ice","status_seconds":100})
 walking.spawn(-1,1,11,Vector3(0,0,40),200,.4);walking.step(1,{})
 var walk_snapshot=walking.render_snapshot();var sample=renderer.pose_sample(walk_snapshot,1);var walk_clip:Dictionary=load("res://assets/characters/ally_crowd/11.res").get_meta("clips").walk
 check(absf(sample.g-(walk_clip.start+fposmod(1.0,walk_clip.duration)*60))<.02,"One second of full-speed walking plays one second of the original gait")
 walking.clear();walking.free()
 # At the full population the draw submitter must not allocate controllers.
 runtime.clear()
 for i in 2000:
  runtime.spawn(i+1,0,[0,1,3][i%3],Vector3((i%50)*4,0,(i/50)*4),200,3.9)
  runtime.spawn(-i-1,1,[11,5,7,8,10][i%5],Vector3((i%50)*4,0,200+(i/50)*4),500,.4)
 s=runtime.render_snapshot();renderer.present(s,[])
 check(renderer.counts().units==4000 and renderer.counts().health==2000,"Packed submission retains all 2000 enemies and 2000 independent allies")
 check(renderer.get_child_count()<800 and renderer.find_children("*","Skeleton3D",true,false).is_empty(),"Full crowd rendering does not construct per-NPC skeletons/controllers")
 # A moving bow's visible hand must remain its authoritative release point.
 for gap in [5,28]:
  var moving=load("res://scripts/forest/crowd/army_runtime.gd").new();moving.configure(null);moving.set_navigation(1,{"width":0});moving.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(model))
  var target:int=moving.spawn(1,0,0,Vector3.ZERO,10000,3.9);moving.apply_hit(target,{"element":"ice","status_seconds":100})
  var ranger:int=moving.spawn(-1,1,10,Vector3(0,0,gap),100,.4);var matched=false
  for frame in 60:
   moving.step(1.0/60,{})
   for e in moving.take_events():
    if e.kind!="bullet" or e.unit_kind!=10 or e.action_index==3:continue
    var state:Dictionary=moving.unit_state(ranger);var snapshot=moving.render_snapshot();var i=snapshot.handles.find(ranger)
    var key="primary%d"%e.action_index+("_walk" if state.velocity.dot(Vector3(sin(state.yaw),0,cos(state.yaw)))>=0 else "_back")
    var resource=load("res://assets/characters/ally_crowd/10.res");var clip:Dictionary=resource.get_meta("clips")[key]
    var t=state.action_time*60;var low=floori(t);var high=mini(low+1,clip.count-1)
    var hand:Vector3=resource.get_meta("muzzles")[key][low].lerp(resource.get_meta("muzzles")[key][high],t-low)
    var idle_key="primary%d"%e.action_index;var idle_hand:Vector3=resource.get_meta("muzzles")[idle_key][low].lerp(resource.get_meta("muzzles")[idle_key][high],t-low)
    var speed=Vector2(state.velocity.x,state.velocity.z).length();hand=idle_hand.lerp(hand,clampf(speed/float(load("res://assets/crowd/army_kit_profiles.tres").get_meta("profiles")[10].speed),0,1))
    var actual:Vector3=e.position-e.direction*.12-state.position
    check(actual.distance_to(Basis(Vector3.UP,state.yaw)*hand)<.01,"Moving Ranger release agrees with its visible hand within .01m at gap%d (%.6f)"%[gap,actual.distance_to(Basis(Vector3.UP,state.yaw)*hand)])
    matched=true;break
   if matched:break
  check(matched,"Moving Ranger fixture releases a real primary arrow at gap%d"%gap);moving.clear();moving.free()
 # Shield presentation must follow configured simulation geometry, including freeze.
 var shield=load("res://scripts/forest/crowd/army_runtime.gd").new();shield.configure(null);shield.set_navigation(1,{"width":0})
 var tuned:Dictionary=load("res://scripts/forest/crowd/army_kit_data.gd").from_model(model)
 for i in tuned.ally_kinds.size():tuned.ally_profiles[i*5+1]=0
 for i in tuned.soldier_kinds.size():tuned.soldier_profiles[i*6+1]=0
 tuned.knight[4]=.4;tuned.knight[5]=.3;tuned.knight[6]=.1;tuned.knight[7]=2;tuned.knight[8]=9;tuned.knight[11]=8
 shield.configure_kits(tuned);shield.spawn(1,0,1,Vector3(0,0,8),10000,3.9);var defender:int=shield.spawn(-1,1,7,Vector3.ZERO,500,.4)
 shield.step(.25,{});shield.apply_hit(defender,{"amount":40.0,"direction":Vector3.FORWARD});shield.step(.1,{})
 var visible_shield=shield.render_snapshot()
 check(visible_shield.shield_positions.size()==1 and visible_shield.shield_positions[0].distance_to(Vector3(0,4,5))<.001,"Shield visual uses configured height, start, distance and travel clock")
 shield.apply_hit(defender,{"element":"ice","status_seconds":1});shield.step(.2,{})
 check(shield.render_snapshot().shield_positions==visible_shield.shield_positions,"Frozen shield retains its authoritative position")
 shield.clear();shield.free()
 var wrapper=load("res://scripts/forest/forest_enemy_crowd.gd").new();root.add_child(wrapper)
 check(wrapper.has_method("configure_army"),"Existing enemy renderer accepts common army snapshots")
 if wrapper.has_method("configure_army"):
  wrapper.configure_army(null);wrapper.present_army(s,[])
  check(wrapper.army.counts().units==4000 and not wrapper.is_processing(),"Shared renderer delegates all independent bodies without a second legacy tick")
  wrapper.clear();check(wrapper.army.counts().units==0,"Existing renderer reset clears native batches")
 wrapper.queue_free();await process_frame
 var events=[]
 for i in 2000:
  events.append({"serial":i*2+1,"kind":"death","team":0,"target_id":i+1,"unit_kind":[0,1,3][i%3],"position":Vector3(i%30,0,i/30),"direction":Vector3.BACK})
  events.append({"serial":i*2+2,"kind":"damage","position":Vector3.ZERO,"amount":40.0})
 var nodes=effects.get_child_count()
 for repeat in 4:
  effects.clear();effects.present(events);effects.tick(.01)
  var count=effects.counts()
  check(count.effects<=384 and count.corpses<=128 and count.labels<=32 and effects.get_child_count()==nodes,"Mass death reuses fixed cosmetic pools (round %d)"%repeat)
  effects.present(events);check(effects.counts().corpses==count.corpses,"Repeated event delivery cannot duplicate death presentation")
  effects.tick(2);effects.clear();check(effects.counts()==baseline,"Mass death expiration and reset return all pool counts to baseline")
 effects.effect_capacity=0;effects.corpse_capacity=0;effects.label_capacity=0;effects.present(events)
 check(effects.counts().effects==0 and effects.counts().corpses==0 and runtime.render_snapshot().handles.size()==4000,"Zero cosmetic capacity leaves every authoritative fighter intact")
 renderer.clear();check(renderer.counts().units==0 and renderer.counts().health==0,"Reset hides every spatial and health instance")
 runtime.clear();runtime.free();renderer.queue_free();await process_frame
func decode(image:Image,part:int,row:int)->Transform3D:
 var x=image.get_pixel(part*6,row);var y=image.get_pixel(part*6+1,row);var z=image.get_pixel(part*6+2,row)
 return Transform3D(Basis(Vector3(x.r,x.g,x.b),Vector3(y.r,y.g,y.b),Vector3(z.r,z.g,z.b)),Vector3(x.a,y.a,z.a))
func verify_source():
 var f=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(f);var game=await f.make_game("original")
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(game);runtime.set_navigation(1,{"width":0});runtime.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model))
 var renderer=load("res://scripts/forest/crowd/army_renderer.gd").new();root.add_child(renderer);renderer.configure(null)
 var external={"targets":{"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([Vector3(0,0,50)]),"hp":PackedFloat32Array([500])}}
 for role in [0,1,3]:
  runtime.clear();var handle:int=runtime.spawn(1,0,role,Vector3.ZERO,500,3.9);runtime.step(.4,external);var actor=runtime.enemy_target(1)
  for mode in ["walking","frozen","hurt"]:
   if mode=="frozen":runtime.apply_hit(handle,{"element":"ice","status_seconds":.6});runtime.step(.2,external)
   if mode=="hurt":runtime.step(.8,external);runtime.apply_hit(handle,{"amount":1.0,"direction":Vector3.RIGHT});runtime.step(.1,external)
   runtime.sync_targets();var snapshot=runtime.render_snapshot();var row=floori(renderer.pose_sample(snapshot,0).r)
   var actual=preload("res://scripts/forest/forest_thirstquencher_visual.gd").frame_state(actor._combat_data())
   check(row==actual.row,"Soldier%d %s head/contact queries use the displayed animation frame"%[role,mode])
 runtime.clear();runtime.free();renderer.queue_free();await process_frame
 for kind in [11,5,7,8,10]:
  var baked=load("res://assets/characters/ally_crowd/%d.res"%kind)
  var unit=game.explorer_helpers.pool.filter(func(u):return u.kit_id==kind)[0];unit.global_position=Vector3.ZERO;unit.show()
  var c=unit.active_ability;var actor=unit.model.actor
  var image:Image=baked.get_meta("pose_texture").get_image();var profile:Dictionary=load("res://assets/crowd/army_kit_profiles.tres").get_meta("profiles")[kind]
  var paint_error=0.0;var material_image:Image=baked.get_meta("properties").get_image()
  for ref in baked.get_meta("vertex_refs"):
   if baked.get_meta("mesh").get_surface_count()<=ref.group:continue
   var source:MeshInstance3D=actor.model.get_node(ref.path);var mat:StandardMaterial3D=source.get_active_material(ref.surface)
   var a=baked.get_meta("mesh").surface_get_arrays(ref.group)
   var actual:Color=a[Mesh.ARRAY_COLOR][ref.offset];var row=int(a[Mesh.ARRAY_TEX_UV2][ref.offset].x)
   if material_image.get_width()>2:actual*=material_image.get_pixel(2,row)
   var expected=mat.albedo_color.srgb_to_linear();var original=source.mesh.surface_get_arrays(ref.surface)
   if mat.vertex_color_use_as_albedo and original[Mesh.ARRAY_COLOR]!=null:expected*=original[Mesh.ARRAY_COLOR][0].srgb_to_linear() if mat.vertex_color_is_srgb else original[Mesh.ARRAY_COLOR][0]
   paint_error=maxf(paint_error,Vector3(actual.r,actual.g,actual.b).distance_to(Vector3(expected.r,expected.g,expected.b)))
  check(paint_error<.0001,"Kind %d retains original material colors without byte quantization (%.6f)"%[kind,paint_error])
  var keys=["idle","walk","walk_back","hurt","death","primary0","primary1","primary2","primary3_walk","primary4_back","primary5"]
  if kind==5:keys.append_array(["shadow_cut","shot","shot_walk","shot_back"])
  if kind==7:keys.append_array(["guard","guard_walk","guard_back"])
  if kind==8:keys.append_array(["lance_leap","lance_landing","lance_sweep","jump","fall"])
  if kind==10:keys.append_array(["ranger_fan","ranger_fan_walk","ranger_fan_back"])
  for key in keys:
   var clip:Dictionary=baked.get_meta("clips")[key];var moving=1 if key=="walk" or key.ends_with("_walk") else (-1 if key=="walk_back" or key.ends_with("_back") else 0)
   c.active=true;c.reset_run();actor.seed=0;unit.facing=Vector3.BACK;unit.model.rotation.y=PI;c.aim=Vector3.BACK*10;c.player.pos=Vector3.ZERO
   if key.begins_with("primary"):
    var sample=int(key.substr(7,1));c.player.bladeSide=profile.primary[sample].get("swingSide",1);c.player.rangerShots=sample
    c.Actions.begin_attack(c,c.Actions.primary_config(c,sample%3),sample%3)
   if key=="lance_sweep":c.Actions.begin_attack(c,{"duration":.84,"contact":.22,"damage":111,"reach":7.2,"arc":PI/2,"style":"dragoon-sweep","sweep_hits":0},0,"flintlock")
   if clip.get("warmup",0)>0:
    var warm:Dictionary=c.player.duplicate(true);warm.graphicsQuality=0;warm.grounded=true;warm.vertical=0;warm.flip=-1;warm.landing=0;warm.motionSpeed=profile.speed;warm.localMotion=Vector3.BACK*moving*profile.speed
    if key.begins_with("guard"):warm.blocking=true;warm.guardTime=1
    for warm_frame in roundi(clip.warmup*60):actor.animate_pose(warm,1.0/60,(warm_frame+1)/60.0,1)
    actor.locomotion.phase=0
   var error=0.0;var marker_error=0.0
   for frame in int(clip.count):
    var t=frame/60.0;var state:Dictionary=c.player.duplicate(true)
    state.graphicsQuality=0;state.grounded=true;state.vertical=0;state.flip=-1;state.landing=0
    state.motionSpeed=absf(moving)*profile.speed;state.localMotion=Vector3.BACK*moving*profile.speed
    if state.attack is Dictionary:state.attack.time=minf(t,state.attack.duration);state.meleeVisualScale=state.attack.get("meleeVisualScale",1)
    if key.begins_with("guard"):state.blocking=true;state.guardTime=1
    if key.begins_with("ranger_fan") or key.begins_with("shot"):state.shot=maxf(.00001,.2-t)
    if key=="shadow_cut":state.rollDuration=.14;state.roll=maxf(0,.14-t);state.rollStyle="dash-cut";state.dashAttack={"style":"dash-cut","weaponScale":1.0,"effectScale":1.0} if t<.14 else null
    if key=="lance_leap":state.grounded=false;state.vertical=-38;state.travel={"kind":"lance-leap","phase":"aimed-drop","duration":.72,"time":t,"height":0.0}
    if key=="jump":state.grounded=false;state.vertical=20.0
    if key=="fall":state.grounded=false;state.vertical=-38.0
    if key=="lance_landing":
     if frame==0:
      var before=state.duplicate(true);before.grounded=false;before.vertical=-38;before.travel={"kind":"lance-leap","phase":"aimed-drop","duration":.72,"time":.72,"height":0.0};actor.animate_pose(before,0,0,0)
     state.landing=maxf(.00001,.8-t)
    actor.animate_pose(state,1.0/60 if frame>0 else 0.0,t,absf(moving))
    if frame%7!=0 and frame!=int(clip.count)-1:continue
    var row=int(clip.start)+frame
    for part in baked.get_meta("palette").size():
     var entry:Dictionary=baked.get_meta("palette")[part];var node:MeshInstance3D=actor.model.get_node(entry.path);var expected=node.global_transform
     if entry.bind>=0:
      var sk:Skeleton3D=node.get_node(node.skeleton);sk.force_update_all_bone_transforms();var bone=node.skin.get_bind_bone(entry.bind)
      if bone<0:bone=sk.find_bone(node.skin.get_bind_name(entry.bind))
      expected=sk.global_transform*sk.get_bone_global_pose(bone)*node.skin.get_bind_pose(entry.bind)
     if key=="death" or not node.is_visible_in_tree():expected=Transform3D(Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO),Vector3.ZERO)
     var actual=decode(image,part,row)
     for p in [Vector3.ZERO,Vector3(1,2,3),Vector3(-1,2,-3)]:error=maxf(error,(expected*p).distance_to(actual*p))
    marker_error=maxf(marker_error,unit.model.hand_position("R").distance_to(baked.get_meta("muzzles")[key][frame]))
    var tip=actor.joints.Weapon_Cutlass.node.global_transform*actor.WEAPON_AXES.get(actor.id,Vector3.UP)
    marker_error=maxf(marker_error,tip.distance_to(baked.get_meta("contacts")[key][frame]))
   check(error<.01,"Kind %d %s authored skin and rigid poses agree within .01m (%.6f)"%[kind,key,error])
   check(marker_error<.01,"Kind %d %s actual weapon contacts and hand muzzles agree within .01m (%.6f)"%[kind,key,marker_error])
 await f.close();f.queue_free();await process_frame
