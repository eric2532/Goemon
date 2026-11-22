extends "res://tests/forest-shrine/ruby_remaining_effects_test.gd"
const HOLY_REVIEW="res://build/Other Files/Asset Toolkit/Ruby Holy Shield/"
var holy_contacts=0
var holy_triggered=false
func review_folder()->String:return HOLY_REVIEW
func check_ruby_furniture():
 await super.check_ruby_furniture()
 var props=game.world.find_child("ArchivedRubyProps",true,false)
 var ids=[16115,16124,16140,16204,16205]
 var source=Tour.Indoor.RoomArt.RubyProps.PLACEMENTS[Ruby.ROOM].filter(func(row):return row[1] in ids)
 var models=props.get_children().filter(func(node):return node.get_meta("blue_cg_serial",0) in ids)
 check(models.size()==13 and models.size()==source.size(),"All thirteen source dining/chair/cabinet/stool placements use solid scenery")
 var mesh_cache={}
 for node in models:
  var serial:int=node.get_meta("blue_cg_serial")
  check(node is MeshInstance3D,"New royal furniture has solid geometry")
  check(source.any(func(row):return row[0]==node.get_meta("source_cell") and row[1]==serial),"Royal furniture preserves its original map cell")
  var local_bounds:AABB=node.mesh.get_aabb()
  for child in node.get_children():
   if child is MeshInstance3D:local_bounds=local_bounds.merge(child.transform*child.mesh.get_aabb())
  var bounds:AABB=node.transform*local_bounds
  var span:Vector2i=Tour.Indoor.RoomArt.RubyProps.GRAPHICS[serial][1]
  check(bounds.size.x<=span.x*3.0+.01 and bounds.size.z<=span.y*3.0+.01,"Furniture fits its unchanged archived blocked footprint")
  if mesh_cache.has(serial):check(node.mesh==mesh_cache[serial],"Repeated royal furniture shares one mesh")
  mesh_cache[serial]=node.mesh
  if serial==16115:
   var arrays:Array=node.mesh.surface_get_arrays(0)
   var tile:Vector2=Tour.Indoor.RoomArt.PrayerArt.Scenery.TILES.court_linen
   var top_vertices=0
   for i in arrays[Mesh.ARRAY_VERTEX].size():
    if arrays[Mesh.ARRAY_TEX_UV2][i]!=tile:continue
    var vertex:Vector3=arrays[Mesh.ARRAY_VERTEX][i];var uv:Vector2=arrays[Mesh.ARRAY_TEX_UV][i]
    check((vertex.x<0)==(uv.x<.01) and (vertex.z<0)==(uv.y<.01),"Native linen follows the original long table axis")
    top_vertices+=1
   check(top_vertices>0,"The native tablecloth remains visible above its gilt rim")
   var chairs=node.get_children().filter(func(child):return child.name.begins_with("OriginalDiningChair"))
   check(chairs.size()==2 and chairs[0].mesh==chairs[1].mesh,"Each original dining set reuses two matching whole chair meshes")
 check(Tour.Indoor.RoomArt.PrayerArt.royal_chair().get_surface_count()==3,"Royal chairs reuse the existing complete chair geometry and isolated native palette")
 if DisplayServer.get_name()!="headless":
  var gallery=Node3D.new();gallery.position=Vector3(2000,0,2000)*game.model.falan_scale;gallery.scale=Vector3.ONE*game.model.falan_scale;game.world.add_child(gallery)
  for serial in ids:
   var model=models.filter(func(node):return node.get_meta("blue_cg_serial")==serial)[0].duplicate()
   gallery.add_child(model);model.position=Vector3.ZERO
   await shot("royal-"+str(serial),gallery.to_global(Vector3(4,4.7,7)),gallery.to_global(Vector3(0,1.8,0)),65)
   model.queue_free();await process_frame
  gallery.queue_free();await process_frame
func observe_ruby(boss_id:int):
 var events:Array=game.army_runtime.event_log.duplicate()
 await super.observe_ruby(boss_id)
 for event in events:
  if event.kind!="status" or event.source_id!=boss_id:continue
  if event.action_index==Ruby.WARD_ACTIVE and int(event.amount)==Ruby.HOLY_SHIELD and not holy_triggered:
   holy_triggered=true
   var runtime=game.army_runtime
   for magical in [false,true]:
    var accepted=false
    for attempt in 3:
     var old_hp:float=runtime.unit_state(runtime.handles[boss_id]).hp
     var result:Dictionary=runtime.apply_hit(runtime.handles[boss_id],{"amount":100.0,"magical":magical,"provoke":false})
     if not result.accepted:continue
     accepted=true
     check(old_hp-result.hp>=0 and old_hp-result.hp<=50,"Holy Shield keeps its existing physical/magic reduction")
     break
    check(accepted,"Holy Shield remains hittable after any earlier finite typed ward is consumed")
   runtime.flush_presentation()
   var presentation=game.crowd.army.presentation
   var flashes=presentation.effects.filter(func(e):return e.kind=="ruby-native-110098" and e.owner_id==boss_id)
   check(flashes.size()==2 and flashes.all(func(e):return e.half_height and not e.loop),"Two real native contacts create two original Holy Shield flashes")
   var spec:Dictionary=Ruby.spell_art.clips["110098"]
   var mesh:QuadMesh=presentation.batches["ruby-native-110098"].multimesh.mesh
   check(spec.reference_body_pixels==85 and mesh.size.is_equal_approx(Vector2(spec.width,spec.height)*Ruby.KAZ_HEIGHT*1.1/85),"Holy Shield preserves its original size relative to Ruby's measured source body")
   check(not presentation.batches.has("ruby-ward-2"),"The original Holy Shield flash replaces the persistent prototype shield")
   check(Ruby.spell_sounds.has("131") and Ruby.spell_sounds.has("132"),"Original Holy Shield impact sound choices are prepared once")
   holy_contacts+=flashes.size()
   if DisplayServer.get_name()!="headless":
    presentation.tick(.10)
    await spell_shot("holy-original-contact",boss_id)
func check_east_il_road():
 await super.check_east_il_road()
 await check_holy_pool()
 check(holy_triggered and holy_contacts==2,"Original Holy Shield was reviewed on both actual native hit channels")
 print("RUBY_HOLY_RESULT checks=",checks," contacts=",holy_contacts," failures=",errors)

func check_holy_pool():
 var presentation=game.crowd.army.presentation
 var count_:int=presentation.get_child_count()
 var mesh:Mesh=presentation.batches["ruby-native-110098"].multimesh.mesh
 var material=mesh.material
 var empty_us=0;var active_us=0
 for wave in 12:
  var started=Time.get_ticks_usec()
  presentation.tick(0);empty_us+=Time.get_ticks_usec()-started
  started=Time.get_ticks_usec()
  var events=[]
  for copy in 5:events.append({"kind":"status","unit_kind":20,"action_index":Ruby.WARD_BLOCK,"source_id":0,"position":game.player.position+Vector3((copy-2)*2,0,0),"amount":Ruby.HOLY_SHIELD,"source_tick":1})
  presentation.present(events,presentation.effect_snapshot);presentation.tick(.11)
  active_us+=Time.get_ticks_usec()-started
  check(presentation.effects.size()<=presentation.MAX_EFFECTS,"Simultaneous Holy Shield contacts remain bounded")
  await process_frame
  presentation.tick(.41)
 check(presentation.get_child_count()==count_ and presentation.batches["ruby-native-110098"].multimesh.mesh==mesh and mesh.material==material,"Repeated Holy Shield contacts reuse the prepared mesh/material and presentation nodes")
 check(not presentation.effects.any(func(e):return e.kind=="ruby-native-110098"),"Original Holy Shield contacts expire after repeated simultaneous use")
 print("RUBY_HOLY_POOL waves=12 copies=5 mean_empty_tick_us=",empty_us/12.0," mean_five_contacts_us=",active_us/12.0)
