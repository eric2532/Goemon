extends SceneTree
const FOLDER="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/painterly-whole-ground-20261017"
var world
var camera:Camera3D
var checks=0
var failures=0
func _initialize():
 create_timer(80).timeout.connect(func():printerr("FAIL: Whole-map ground timeout");quit(1))
 run.call_deferred()
func check(ok:bool,note:String):
 checks+=1;print("PASS: " if ok else "FAIL: ",note)
 if not ok:failures+=1
func render_at(point:Vector3)->Image:
 camera.position=point+Vector3.UP*32;camera.look_at(point,Vector3.FORWARD)
 for i in 4:await process_frame
 RenderingServer.force_draw()
 return root.get_texture().get_image()
func delta_image(a:Image,b:Image)->float:
 var sum=0.0;var samples=0
 for y in range(80,a.get_height()-80,12):
  for x in range(80,a.get_width()-80,12):
   var ca=a.get_pixel(x,y);var cb=b.get_pixel(x,y)
   sum+=absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b);samples+=3
 return sum/maxi(1,samples)
func run():
 var model=load("res://scripts/forest/forest_model.gd").new()
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_ramparts();model.reset(42,{},doc.data)
 world=load("res://scripts/forest/forest_world.gd").new();world.model=model;root.add_child(world)
 await process_frame
 var original=world.ground_material.shader
 var scouting=[model.explored.duplicate(true),model.visible_cells.duplicate(true)]
 if DisplayServer.get_name()!="headless":
  camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=20;root.add_child(camera);camera.current=true
  # Isolate the actual ground material so trees cannot mask a far-field comparison.
  world.forest_root.hide();world.deposit_root.hide();world.map_features.hide()
  for node in world.structure_nodes.values():node.hide()
  for node in world.worker_nodes.values():node.hide()
  var fog_image=world.fog_texture.get_image()
  var white=Image.create(80,80,false,Image.FORMAT_RGBA8);white.fill(Color.WHITE);world.fog_texture.update(white)
  world.ground_material.set_shader_parameter("show_grid",false)
  for point in [Vector3(85,0,-80),Vector3(-110,0,100),Vector3(90,0,200)]:
   world.set_painterly_preview(false);var before=await render_at(point)
   world.set_painterly_preview(true);world.painterly_pilot.scenery.hide();var after=await render_at(point)
   var difference=delta_image(before,after)
   check(difference>.035,"Painted ground reaches far terrain at %s (mean color change %.4f)"%[point,difference])
  world.fog_texture.update(fog_image)
  world.forest_root.show();world.deposit_root.show();world.map_features.show()
  for node in world.structure_nodes.values():node.show()
  for node in world.worker_nodes.values():node.show()
  world.painterly_pilot.scenery.show()
  camera.size=300;camera.position=Vector3(0,230,225);camera.look_at(Vector3(0,0,85))
  for i in 4:await process_frame
  RenderingServer.force_draw();root.get_texture().get_image().save_png(FOLDER+"/whole-map-painterly.png")
  world.set_painterly_preview(false)
  for i in 4:await process_frame
  RenderingServer.force_draw();root.get_texture().get_image().save_png(FOLDER+"/whole-map-original.png")
 # Ground art must not depend on authored buildings being present.
 for id in model.buildings.keys():
  if model.buildings[id].kind in ["gate","tower"]:model.buildings.erase(id)
 model.revision+=1;world.sync(0);world.set_painterly_preview(true)
 check(world.painterly_pilot.selected_ids.is_empty(),"Maps without a gate or tower need no structure dressing")
 check(world.ground_material.shader!=original,"Whole-map painted ground also works without a gate or tower")
 var painted=world.ground_material.shader
 world.reload_map()
 check(world.ground_material.shader==painted,"Map reload retains global ground treatment")
 world.set_painterly_preview(false)
 check(world.ground_material.shader==original,"Original ground still restores exactly")
 check(model.explored==scouting[0] and model.visible_cells==scouting[1],"Scouting and actor visibility cells remain unchanged")
 world.queue_free();await process_frame
 print("PAINTERLY_WHOLE_GROUND_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
