extends "res://tests/forest-shrine/ruby_spells_recovery_test.gd"
const REMAINING_REVIEW="res://build/Other Files/Asset Toolkit/Ruby Remaining Effects/"
var contacts={}
var triggered={}
func review_folder()->String:return REMAINING_REVIEW
func shot(label_:String,eye:Vector3,target:Vector3,fov:float,_refresh:bool=false):
 if DisplayServer.get_name()=="headless":return
 var before=paused;paused=true
 game.ui.hide();game.set_process(false)
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=eye;camera.look_at(target);camera.fov=fov;camera.reset_physics_interpolation()
 if game.crowd.army.presentation!=null:game.crowd.army.presentation.draw_effects()
 for frame in 3:await process_frame
 RenderingServer.force_draw()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(review_folder()+"after"))
 check(root.get_texture().get_image().save_png(review_folder()+"after/"+label_+".png")==OK,"Captured "+label_)
 game.set_process(true);game.ui.show();paused=before
func check_ruby_furniture():
 await super.check_ruby_furniture()
 var props=game.world.find_child("ArchivedRubyProps",true,false)
 var replacements=Tour.Indoor.RoomArt.RubyProps.PLACEMENTS[Ruby.ROOM].filter(func(row):return row[1] in [16464,16499,16130,16131,16132])
 var solid=props.get_children().filter(func(node):return node.get_meta("blue_cg_serial",0) in [16464,16499,16130,16131,16132])
 check(solid.size()==replacements.size(),"Every source column and framed picture has a solid replacement")
 var meshes={}
 for node in solid:
  check(node is MeshInstance3D,"Columns and picture frames have real depth")
  var serial:int=node.get_meta("blue_cg_serial")
  var bounds:AABB=node.mesh.get_aabb()
  check(bounds.size.x<=3 and bounds.size.z<=3 and bounds.end.y<=8.51,"Solid details fit the original cell and ceiling")
  if serial in [16464,16499]:
   var arrays:Array=node.mesh.surface_get_arrays(0)
   var top_x=[]
   for i in arrays[Mesh.ARRAY_VERTEX].size():
    if arrays[Mesh.ARRAY_VERTEX][i].y>8.49 and arrays[Mesh.ARRAY_NORMAL][i].y>.9:top_x.append(arrays[Mesh.ARRAY_VERTEX][i].x)
   check(not top_x.is_empty() and is_equal_approx(top_x.min(),bounds.position.x) and is_equal_approx(top_x.max(),bounds.end.x),"Solid native columns have complete caps with no black sprite tops or open rim")
  check(replacements.any(func(row):return row[0]==node.get_meta("source_cell") and row[1]==serial),"Source detail stays at its archived cell")
  if meshes.has(serial):check(node.mesh==meshes[serial],"Repeated palace details reuse a prepared mesh")
  meshes[serial]=node.mesh
 if DisplayServer.get_name()!="headless":
  var study=Node3D.new();study.position=Vector3(2000,0,2000)*game.model.falan_scale;study.scale=Vector3.ONE*game.model.falan_scale;game.world.add_child(study)
  for serial in [16464,16499,16130,16131,16132]:
   var source=solid.filter(func(n):return n.get_meta("blue_cg_serial")==serial)[0]
   var mesh=MeshInstance3D.new();mesh.mesh=source.mesh;mesh.material_override=source.material_override;study.add_child(mesh)
   var height=8.5 if serial in [16464,16499] else 3.8
   await shot("solid-"+str(serial),study.to_global(Vector3(4,height*.6,8)),study.to_global(Vector3(0,height*.5,0)),60)
   mesh.queue_free();await process_frame
  study.queue_free();await process_frame
  var column=solid.filter(func(n):return n.get_meta("blue_cg_serial")==16464)[0]
  await shot("columns-original-hall",column.to_global(Vector3(5,5,0)),column.to_global(Vector3(0,4,0)),74)
  var picture=solid.filter(func(n):return n.get_meta("blue_cg_serial")==16130)[0]
  await shot("picture-original-wall",picture.to_global(Vector3(0,2,4)),picture.to_global(Vector3(0,2,0)),65)

func observe_ruby(boss_id:int):
 var events:Array=game.army_runtime.event_log.duplicate()
 await super.observe_ruby(boss_id)
 var presentation=game.crowd.army.presentation
 for event in events:
  if event.kind!="status" or event.source_id!=boss_id:continue
  var action:int=event.action_index
  var spell=int(event.get("amount",0))
  if action==Ruby.WARD_ACTIVE and str(spell) in Ruby.spell_art.ward_contacts and not triggered.has(spell):
   triggered[spell]=true
   var result:Dictionary=game.army_runtime.apply_hit(game.army_runtime.handles[boss_id],{"amount":10.0,"magical":(spell-Ruby.PHYSICAL_ABSORB)%2==1,"provoke":false})
   check(not result.accepted,"The native typed ward actually blocks the review contact")
   game.army_runtime.flush_presentation()
   var ref:String=Ruby.spell_art.ward_contacts[str(spell)]
   check(presentation.effects.any(func(e):return e.kind=="ruby-native-"+ref and e.owner_id==boss_id and e.get("half_height",false)),"A native contact immediately plays its matching original ward sheet")
   check(not presentation.batches.has("ruby-ward-0") and not presentation.batches.has("ruby-ward-1"),"Source contact effects replace the persistent prototype ward rectangles")
   if DisplayServer.get_name()!="headless":
    presentation.tick(.12)
    await spell_shot("contact-"+str(spell),boss_id)
  if action==Ruby.WARD_BLOCK and str(spell) in Ruby.spell_art.ward_contacts:contacts[spell]=true
func check_confused_movement():
 game.army_runtime.flush_presentation()
 var presentation=game.crowd.army.presentation
 check(presentation.effects.any(func(e):return e.kind=="ruby-native-110163" and e.get("hero",false) and e.loop),"Player Confusion uses the original animated cube for its timed state")
 check(not presentation.batches.has("ruby-confusion"),"The original cube replaces the prototype Confusion ring")
 if DisplayServer.get_name()!="headless":
  var point:Vector3=game.player.position/game.model.falan_scale
  await shot("confusion-native-cube",game.model.world_point(Vector2(point.x-5,point.z+6),5),game.model.world_point(Vector2(point.x,point.z),2.4),62)
 await super.check_confused_movement()

func check_east_il_road():
 await super.check_east_il_road()
 await check_contact_pool()
 check(contacts.size()==6,"All six original typed contact effects were observed")
 print("RUBY_REMAINING_RESULT contacts=",contacts.size()," checks=",checks," failures=",errors)

func check_contact_pool():
 var presentation=game.crowd.army.presentation
 presentation.prepare_ruby()
 var nodes:int=presentation.get_child_count()
 var materials={}
 for ref in Ruby.spell_art.ward_contacts.values():materials[ref]=presentation.batches["ruby-native-"+ref].multimesh.mesh.material
 var cost_us=0
 var baseline_us=0
 for burst in 12:
  var started=Time.get_ticks_usec()
  presentation.tick(0)
  baseline_us+=Time.get_ticks_usec()-started
  started=Time.get_ticks_usec()
  var events=[]
  for copy in 5:
   for spell in Ruby.spell_art.ward_contacts:
    events.append({"kind":"status","unit_kind":20,"action_index":Ruby.WARD_BLOCK,"source_id":0,"position":game.player.position+Vector3((copy-2)*2,0,0),"amount":int(spell),"source_tick":0})
  presentation.present(events,presentation.effect_snapshot)
  presentation.tick(.12)
  cost_us+=Time.get_ticks_usec()-started
  check(presentation.effects.size()<=presentation.MAX_EFFECTS,"Simultaneous source contacts stay in the existing bounded pool")
  await process_frame
  presentation.tick(1)
 check(presentation.get_child_count()==nodes,"Repeated simultaneous source contacts do not create presentation nodes")
 for ref in materials:check(presentation.batches["ruby-native-"+ref].multimesh.mesh.material==materials[ref],"Simultaneous contacts reuse the prepared material")
 check(not presentation.effects.any(func(e):return e.kind.trim_prefix("ruby-native-") in materials),"Repeated source contact effects expire cleanly")
 print("RUBY_CONTACT_POOL samples=12 copies=5 effects_per_wave=30 mean_empty_tick_us=",baseline_us/12.0," mean_submit_tick_us=",cost_us/12.0)
