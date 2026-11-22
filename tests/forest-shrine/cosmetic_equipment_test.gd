extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Gear=preload("res://scripts/forest/equipment.gd")
const Catalog=preload("res://scripts/forest/cosmetic_catalog.gd")
const OUT="res://build/Other Files/Asset Toolkit/Sponsor Cosmetics/Gameplay/"
const CHOICES=["cosmetic:119802","cosmetic:119010","cosmetic:115809","cosmetic:115801"]

func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+message)

func picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 if stem.begins_with("controls-"):
  game.camera_rig.camera.position=game.player.position+Vector3(0,4,8)
  game.camera_rig.camera.look_at(game.player.position+Vector3.UP*1.6)
  print("COSMETIC_CONTROL_POSE ",stem," ",game.player.model.current_clip)
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Capture "+stem)

func render_sample(visual:Node)->Dictionary:
 await frames(30)
 var durations=[];var draws=[];var previous=Time.get_ticks_usec()
 for i in 180:
  await process_frame
  var now=Time.get_ticks_usec();durations.append(float(now-previous)/1000.0);previous=now
  draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
 durations.sort();draws.sort()
 return {"median_ms":durations[90],"p95_ms":durations[171],"draw_calls":draws[90],"layers":visual.cosmetic_layers.selected.size()}

func control(action:String,pressed:bool):
 var event=InputEventAction.new();event.action=action;event.pressed=pressed;Input.parse_input_event(event)

func controls_review():
 var player=game.player;var start=player.position
 player.set_physics_process(true)
 control("move_left",true);await create_timer(.6).timeout
 check(player.position.distance_to(start)>.2,"Normal movement input moves the equipped character")
 await picture("controls-walk")
 control("sprint",true);await create_timer(.7).timeout
 await picture("controls-sprint")
 control("sprint",false);await create_timer(.4).timeout
 check(not Input.is_action_pressed("sprint"),"Sprint release returns through the normal input state")
 control("move_left",false)
 control("jump",true);await create_timer(.15).timeout;control("jump",false)
 await picture("controls-jump")
 await create_timer(1).timeout
 control("light_attack",true);await create_timer(.1).timeout;control("light_attack",false)
 await picture("controls-attack")
 if DisplayServer.get_name()!="headless":
  for i in 12:
   await create_timer(.07).timeout
   await picture("controls-attack-%02d"%i)
 check(player.model.cosmetic_layers.selected==CHOICES and player.model.cosmetic_layers.nodes.all(func(node):return node.visible),"Cosmetics remain equipped through movement, sprint, jump and attack input")
 player.set_physics_process(false)

func select_review_skin(entry:Dictionary):
 var character=int(str(entry.key).get_slice(":",0));var skin=int(str(entry.key).get_slice(":",1)) if ":" in str(entry.key) else 0
 game.settings.cosmetic_loadouts[Gear.character_key(character)]={"qi_color":"","slots":{"1":CHOICES[0],"2":CHOICES[1],"3":CHOICES[2]}}
 var setting:String=Gear.Roster.skin_setting(character)
 if not setting.is_empty():game.settings[setting]=skin
 game.player.select_character(character)
 if character==34:game.player.model.set_kaz_skin(skin)
 elif Gear.Roster.is_shin(character):game.player.model.set_shin_skin(skin)
 elif Gear.Roster.has_variant_skins(character):game.player.model.set_variant_skin(skin)
 Gear.apply(game.player)

func record_alignment_motion(stem:String,seconds:float):
 if DisplayServer.get_name()=="headless":await create_timer(seconds).timeout;return
 var images=[];var times=[]
 for i in 12:
  game.camera_rig.camera.position=game.player.position+Vector3(0,4,8)
  game.camera_rig.camera.look_at(game.player.position+Vector3.UP*1.6)
  await RenderingServer.frame_post_draw
  times.append(Time.get_ticks_msec())
  images.append(root.get_texture().get_image().get_region(Rect2i(320,80,640,640)))
  await create_timer(seconds/12).timeout
 for i in images.size():check(images[i].save_png(OUT+"alignment/"+stem+"-%02d.png"%i)==OK,"Alignment motion capture")
 var timing=FileAccess.open(OUT+"alignment/"+stem+".json",FileAccess.WRITE)
 timing.store_string(JSON.stringify(times));timing.close()

func record_reactions(character:int,visual:Node):
 var combat=game.player.active_ability
 visual.set_process(false)
 for action in [8,10]:
  for direction in 8:
   var angle=(direction-1)*TAU/8.0
   game.player.facing=Vector3(sin(angle),0,-cos(angle))
   check(visual.direction()==direction,"Reaction capture uses the requested camera facing")
   var pose="%d:%d"%[action,direction];var clip:Dictionary=visual.motions.clips[pose]
   if action==8:combat.hit()
   else:combat.die()
   check(combat.mode==("hurt" if action==8 else "dead"),"Existing combat owner enters the reaction")
   var images=[]
   for index in clip.frames.size():
    combat.elapsed=(index+.25)*float(clip.duration)/clip.frames.size()
    visual.animate(0,0,true,0,0,false,0,false);visual._process(0)
    check(visual.current_clip==pose and visual.current_frame==index,"Full reaction playback follows the existing combat clock")
    check(visual.cosmetic_layers.nodes.slice(0,visual.cosmetic_layers.selected.size()).all(func(node):return node.visible),"Equipped layers follow every hurt/death frame")
    if DisplayServer.get_name()!="headless":
     await RenderingServer.frame_post_draw
     images.append(root.get_texture().get_image().get_region(Rect2i(320,80,640,640)))
   if action==10:
    var region:Rect2=visual.sprite.region_rect;var head=Catalog.head(visual.sprite.texture,region)
    visual._process(float(clip.duration)+1)
    check(visual.sprite.region_rect==region and Catalog.head(visual.sprite.texture,region)==head,"Corpse hold keeps the final prepared attachment")
   for index in images.size():check(images[index].save_png(OUT+"all-animations/%d-%d-%d-%02d.png"%[character,action,direction,index])==OK,"Full reaction frame capture")
   var metadata=FileAccess.open(OUT+"all-animations/%d-%d-%d.json"%[character,action,direction],FileAccess.WRITE)
   metadata.store_string(JSON.stringify({"duration":clip.duration,"frames":clip.frames.size()}));metadata.close()
   combat.cancel(true)
 visual.set_process(true)

func alignment_review():
 var complete="--all-animations" in OS.get_cmdline_user_args()
 var review_folder="all-animations" if complete else "alignment"
 DirAccess.make_dir_recursive_absolute(OUT+review_folder)
 for sample in [
  {"key":"38:118993","pose":"8:6","frame":0,"head":Vector2(-4,-59),"tolerance":2},
  {"key":"38:118993","pose":"10:0","frame":2,"head":Vector2(-14,-62),"tolerance":2},
  {"key":"38:118993","pose":"5:5","frame":3,"head":Vector2(5,-47),"tolerance":2},
  {"key":"39:119308","pose":"5:0","frame":3,"head":Vector2(-38,-65),"weapon":"staff","tolerance":2},
  {"key":"39:119308","pose":"5:2","frame":1,"head":Vector2(37,-65),"weapon":"staff","tolerance":2},
  {"key":"39:119308","pose":"5:2","frame":2,"head":Vector2(42,-54),"weapon":"staff","tolerance":2},
  {"key":"35:108921","pose":"5:3","frame":4,"head":Vector2(61,-58),"stance":1},
  {"key":"44:100731","pose":"5:4","frame":2,"head":Vector2(-1,-76)},
  {"key":"46:100798","pose":"5:6","frame":3,"head":Vector2(-8,-45)},
  {"key":"39:106058","pose":"5:7","frame":2,"head":Vector2(-67,-35),"weapon":"staff"},
  {"key":"35","pose":"8:1","frame":1,"head":Vector2(0,-44),"tolerance":2},
  {"key":"35:108921","pose":"8:5","frame":1,"head":Vector2(-12,-54),"tolerance":2},
  {"key":"39:106477","pose":"10:7","frame":12,"head":Vector2(-56,-20),"tolerance":2},
  {"key":"38:118993","pose":"10:7","frame":5,"head":Vector2(-74,-12),"tolerance":2},
  {"key":"42:120387","pose":"8:3","frame":1,"head":Vector2(-36,-47),"tolerance":2},
  {"key":"48:120386","pose":"10:5","frame":5,"head":Vector2(-7,16),"tolerance":2},
  {"key":"50:105300","pose":"8:3","frame":1,"head":Vector2(-38,-53),"tolerance":2}]:
  select_review_skin(sample)
  var visual=game.player.model
  if sample.has("stance"):visual.select_stance(sample.stance)
  if sample.has("weapon"):
   var code:String=sample.key
   visual.apply_gear_weapon(sample.weapon,Gear.catalog()[code.get_slice(":",0)][code.get_slice(":",1)][sample.weapon])
  var action=int(sample.pose.get_slice(":",0))
  visual.show_frame(action,sample.pose,sample.frame);visual._process(.016)
  var f:Array=visual.body_clip(action,sample.pose).frames[sample.frame]
  var head=Catalog.head(visual.sprite.texture,visual.sprite.region_rect)+Vector2(f[5],f[6])
  check(head.distance_to(sample.head)<sample.get("tolerance",12),"Reviewed head landmark on "+sample.key)
  await picture("alignment/repaired-"+sample.key.replace(":","-")+"-"+sample.pose.replace(":","-")+"-"+str(sample.frame))
 var entries:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/portraits/crossgate/model-head-provenance.json"))
 var pictured={};var origin=game.player.position;var skin_frames=0;var resource_poses=0
 for entry in entries:
  var character=int(str(entry.key).get_slice(":",0))
  if not Gear.Roster.CROSSGATE.has(character):continue
  select_review_skin(entry)
  var visual=game.player.model
  for action in range(21) if complete else [1,3,5,6,7]:
   for direction in 8:
    var pose="%d:%d"%[action,direction]
    if not visual.motions.clips.has(pose):continue
    var clip:Dictionary=visual.body_clip(action,pose)
    for index in range(clip.frames.size()) if complete else [0,clip.frames.size()/2,clip.frames.size()-1]:
     visual.show_frame(action,pose,int(index));visual.cosmetic_layers.update(.016,visual.sprite,pose,true)
     check(Catalog.bound_tables.get(visual.sprite.texture.resource_path,{}).has(Vector2i(visual.sprite.region_rect.position)),"Actual selected skin motion has a prepared head: "+str(entry.key)+" "+pose)
     skin_frames+=1
  if not pictured.has(character):
   pictured[character]=true
   for id in Catalog.items():
    visual.cosmetic_layers.configure(visual.body,[id])
    var definition:Dictionary=Catalog.items()[id]
    for action in range(21) if complete else [1,3,5,6,7]:
     for direction in 8:
      var pose="%d:%d"%[action,direction]
      if not visual.motions.clips.has(pose):continue
      var clip:Dictionary=visual.body_clip(action,pose)
      visual.show_frame(action,pose,clip.frames.size()/2)
      visual.cosmetic_layers.update(.033,visual.sprite,pose,true)
      var facing=0 if definition.fixed_facing else direction
      var authored=definition.clips.has("%d:%d"%[action,facing]) or definition.clips.has("0:%d"%facing)
      var node:Sprite3D=visual.cosmetic_layers.nodes[0]
      check(node.visible==authored and (not authored or node.texture!=null),"Actual moving/attacking costume resource on character %d: %s"%[character,id])
      resource_poses+=1
    if Catalog.items().keys().find(id)%50==0:await process_frame
   Gear.apply(game.player)
   game.player.position=origin;game.player.velocity=Vector3.ZERO
   if complete:
    await record_reactions(character,visual)
    print("COSMETIC_ALL_ANIMATIONS_CHARACTER ",character," 400 resources / every available action / full hurt and death clips")
    continue
   game.player.set_physics_process(true)
   var start=game.player.position
   control("move_left",true);await create_timer(.1).timeout
   await record_alignment_motion(str(character)+"-walk",.4)
   control("sprint",true);await create_timer(.1).timeout
   await record_alignment_motion(str(character)+"-sprint",.4)
   control("sprint",false);control("move_left",false);await create_timer(.15).timeout
   check(game.player.position.distance_to(start)>.2,"Normal walk/sprint controls with cosmetics on character "+str(character))
   control("jump",true);await create_timer(.025).timeout;control("jump",false)
   await record_alignment_motion(str(character)+"-jump",.7)
   await create_timer(.6).timeout
   control("light_attack",true);await create_timer(.025).timeout;control("light_attack",false)
   var attack:Dictionary=visual.normal_attack_pattern()
   await record_alignment_motion(str(character)+"-attack",float(attack.duration)+.15)
   game.player.set_physics_process(false)
   print("COSMETIC_ALIGNMENT_CHARACTER ",character," 400 resources / eight facings / available movement and attack poses")
  if entries.find(entry)%20==0:await process_frame
 var report_name="headless-result.json" if DisplayServer.get_name()=="headless" else "result.json"
 var report=FileAccess.open(OUT+review_folder+"/"+report_name,FileAccess.WRITE)
 report.store_string(JSON.stringify({"characters":pictured.size(),"skin_frames":skin_frames,"resource_poses":resource_poses,"checks":checks,"failures":failures}));report.close()
 print("COSMETIC_ALL_ANIMATIONS_RESULT" if complete else "COSMETIC_ALIGNMENT_RESULT"," checks=%d failures=%d skins=%d resource_poses=%d"%[checks,failures,entries.size(),resource_poses])

func run():
 cfg="user://goemon-cosmetic-equipment-%d.cfg"%OS.get_process_id()
 create_timer(900).timeout.connect(func():printerr("COSMETIC_TEST_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 game.settings.gear_loadouts={};game.settings.cosmetic_loadouts={};game.settings.forest_pet_loadout=[];game.save_settings()
 game.begin_arena();game.choose_rogue_character(34);await frames()
 var hub=game.equipment_hub;hub.show_page("cosmetics")
 check(Catalog.items().size()==401 and hub.collection.size()==407,"Recovered resources and the crossed Water Dragon weapons are offered alongside Qi choices")
 check(hub.inventory.size()>=407 and hub.allowed_icons.size()==7,"Large cosmetic catalog reuses the scrolling grid without hundreds of weapon controls")
 var owner=Gear.character_key(34);var before=FileAccess.get_sha256(cfg)
 var invalid={owner:{"qi_color":"","slots":{"1":CHOICES[0],"2":CHOICES[0],"3":"cosmetic:missing","6":CHOICES[1]}}}
 check(Gear.sanitized_cosmetics(invalid)[owner].slots=={"1":CHOICES[0]},"Save validation rejects unknown resources, duplicate items and invalid slots")
 for i in CHOICES.size():
  hub.select_category_slot("cosmetics",str(i+1));hub.selected_item=CHOICES[i];hub.equip_selected()
 check(hub.cosmetic_draft[owner].slots.size()==4 and FileAccess.get_sha256(cfg)!=before and game.settings.cosmetic_loadouts==hub.cosmetic_draft,"Equipping recovered items saves immediately")
 game.back_from_equipment();await frames();game.choose_rogue_character(34);await frames();hub=game.equipment_hub;hub.show_page("cosmetics")
 check(Gear.cosmetic_slots(hub.cosmetic_draft,owner).size()==4,"Back retains equipped recovered cosmetics")
 for i in CHOICES.size():
  hub.select_category_slot("cosmetics",str(i+1));hub.selected_item=CHOICES[i];hub.equip_selected()
 hub.select_category_slot("cosmetics","5");hub.set_cosmetic_color("qi-chrome")
 await picture("cosmetics-menu")
 hub.enter_map();await frames(4)
 game.set_physics_process(false);game.player.set_physics_process(false);game.army_runtime.set_physics_process(false)
 game.player.position=Vector3(-120,0,125);game.player.velocity=Vector3.ZERO
 game.player.position.y=game.world.surface_height_at(game.player.position)+.1
 game.player.model._process(.1)
 check(game.player.model.cosmetic_layers.selected==CHOICES,"Saved equipment reaches the actual character renderer")
 check(game.player.model.cosmetic_layers.nodes.all(func(node):return node.visible and node.texture!=null),"Every equipped layer has actual artwork")
 game.load_settings();Gear.apply(game.player)
 check(Gear.cosmetic_slots(game.settings.cosmetic_loadouts,owner).values().has("qi-chrome") and game.player.model.cosmetic_layers.selected==CHOICES,"Recovered items and Qi color survive disk reload together")
 game.camera_rig.set_process(false);game.camera_rig.camera.position=game.player.position+Vector3(0,4,8)
 game.camera_rig.camera.look_at(game.player.position+Vector3.UP*1.6)
 game.player.facing=Vector3.BACK;game.player.model.show_pose(0,0,true);game.player.model._process(.016)
 await picture("equipped-kaz")
 if "--alignment" in OS.get_cmdline_user_args() or "--all-animations" in OS.get_cmdline_user_args():
  await alignment_review()
  game.queue_free();current_scene=null;paused=false;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
  quit(1 if failures else 0);return
 if "--controls" in OS.get_cmdline_user_args():
  await controls_review()
  game.queue_free();current_scene=null;paused=false;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
  print("COSMETIC_CONTROLS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0);return
 var visual=game.player.model
 visual.show_frame(5,"5:1",1)
 var rear_head=Catalog.head(visual.sprite.texture,visual.sprite.region_rect)
 check(rear_head.distance_to(Vector2(105,91))<7,"Baked rear attack attachment follows the reviewed head rather than the black coat")
 visual.cosmetic_layers.configure(visual.body,CHOICES+["cosmetic:119817"])
 visual.cosmetic_layers.update(.016,visual.sprite,"0:5",true)
 check(visual.cosmetic_layers.nodes.size()==5 and visual.cosmetic_layers.nodes.all(func(node):return node.visible),"All five cosmetic slots can carry recovered artwork together")
 Gear.apply(game.player)
 var live_nodes=visual.cosmetic_layers.nodes.size()
 for id in Catalog.items():
  visual.cosmetic_layers.configure(visual.body,[id])
  var definition:Dictionary=Catalog.items()[id]
  for direction in 8:
   visual.show_frame(0,"0:%d"%direction,0)
   visual.cosmetic_layers.update(.031,visual.sprite,"0:%d"%direction,true)
   var expected=definition.clips.has("0:%d"%(0 if definition.fixed_facing else direction))
   check(visual.cosmetic_layers.nodes[0].visible==expected,"Authored facing visibility for "+id)
   if expected:
    check(visual.cosmetic_layers.nodes[0].region_rect.size.x>0 and visual.cosmetic_layers.nodes[0].texture!=null,"Renderable resource "+id)
  visual.cosmetic_layers.update(.1,visual.sprite,"10:5",true)
  var node:Sprite3D=visual.cosmetic_layers.nodes[0]
  var fall_facing=0 if definition.fixed_facing else 5
  var fall:Dictionary=definition.clips.get("10:%d"%fall_facing,definition.clips["0:%d"%fall_facing])
  var fall_frame:Array=fall.frames[posmod(floori(visual.cosmetic_layers.elapsed/maxf(.001,float(fall.duration))*fall.frames.size()),fall.frames.size())]
  check(node.visible and node.region_rect==Rect2(fall_frame[1],fall_frame[2],fall_frame[3],fall_frame[4]),"Fall uses the prepared authored/fallback artwork: "+id)
 check(visual.cosmetic_layers.nodes.size()==live_nodes,"All 400 choices reuse the existing layer nodes")
 Gear.apply(game.player)
 var nodes_before=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
 var resources_before=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for repeat in 1200:
  visual.show_frame(3,"3:%d"%(repeat%8),repeat%visual.body_clip(3,"3:%d"%(repeat%8)).frames.size())
  visual.cosmetic_layers.update(1.0/60,visual.sprite,visual.current_clip,true)
 check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==nodes_before and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources_before,"Repeated playback creates no nodes or resources")
 var entries:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/portraits/crossgate/model-head-provenance.json"))
 var pictured={}
 for entry in entries:
  var character=int(str(entry.key).get_slice(":",0));var skin=int(str(entry.key).get_slice(":",1)) if ":" in str(entry.key) else 0
  var model_root="res://"+str(entry.manifest).get_base_dir()+"/"
  var data:Dictionary=visual.profile(model_root)
  for stance in [data]+data.get("weapons",[]):
   for clip in stance.clips.values():
    for frame in clip.frames:
     var texture_path=model_root+("atlas-%d.png"%int(frame[0]) if int(frame[0])<int(data.pages) else "cast-%d.png"%(int(frame[0])-int(data.pages)))
     check(Catalog.frame_anchors(texture_path).has(Vector2i(frame[1],frame[2])),"Prepared attachment exists for actual frame "+str(entry.key))
  if not Gear.Roster.CROSSGATE.has(character):continue
  game.settings.cosmetic_loadouts[Gear.character_key(character)]={"qi_color":"","slots":{"1":CHOICES[0],"2":CHOICES[1],"3":CHOICES[2]}}
  game.player.select_character(character)
  if character==34:game.player.model.set_kaz_skin(skin)
  elif Gear.Roster.is_shin(character):game.player.model.set_shin_skin(skin)
  elif Gear.Roster.has_variant_skins(character):game.player.model.set_variant_skin(skin)
  Gear.apply(game.player);game.player.model.show_pose(0,0,true);game.player.model._process(.016)
  check(game.player.model.cosmetic_layers.nodes.slice(0,3).all(func(node):return node.visible),"Equip follows selected Cross Gate skin "+str(entry.key))
  if not pictured.has(character) or str(entry.key)=="38:118993":
   pictured[character]=true
   await picture("equipped-"+str(entry.key).replace(":","-"))
  if entries.find(entry)%20==0:await process_frame
 game.player.select_character(34);game.player.model.set_kaz_skin(102488);Gear.apply(game.player)
 var copies=preload("res://scripts/warcraft_mirrors.gd").new(game.player,0)
 for i in 5:
  check(copies.reinforce(34,game.player.position+Vector3.RIGHT*i),"Native copy remains under the existing army owner")
  copies.bodies.back().model._process(.016)
  check(copies.bodies.back().model.cosmetic_layers.selected==game.player.model.cosmetic_layers.selected,"Native copy inherits equipped cosmetics")
 var retired=copies.bodies.duplicate()
 copies.dispose();await frames()
 check(retired.all(func(body):return not is_instance_valid(body)),"Native retirement frees the cosmetic child layers with their existing owner")
 if DisplayServer.get_name()!="headless":
  var model=game.player.model
  model.cosmetic_layers.configure(model.body,[])
  var without=await render_sample(model)
  model.cosmetic_layers.configure(model.body,CHOICES)
  var with_items=await render_sample(model)
  var report=FileAccess.open(OUT+"focused-render-profile.json",FileAccess.WRITE)
  report.store_string(JSON.stringify({"scope":"Frozen-world desktop rendering after catalog warmup; not a full-army or long-session benchmark","without":without,"with":with_items},"  "));report.close()
 game.show_equipment_hub(true);await frames();hub=game.equipment_hub;hub.show_page("cosmetics")
 hub.select_category_slot("cosmetics","1");hub.unequip();hub.enter_map();await frames()
 check(not game.player.model.cosmetic_layers.selected.has(CHOICES[0]),"Unequip removes the actual visible item")
 game.queue_free();current_scene=null;paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("COSMETIC_EQUIPMENT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
