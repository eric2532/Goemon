extends "res://tests/forest-shrine/painterly_pilot_test.gd"
## Catch unbatched scenery, changed collision, duplicate decoration and lost restore state.
const OUTPUT="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Glade Structures 2026-10-21"
func visible_geometry(node:Node)->Array:
 var result=[]
 for child in node.get_children():
  if child.name=="Health":continue
  if child is GeometryInstance3D and child.is_visible_in_tree():result.append(child)
  result.append_array(visible_geometry(child))
 return result
func details(id:int)->Node3D:
 for node in world.painterly_pilot.scenery.get_children():
  if node.transform==world.structure_nodes[id].transform:return node
 return null
func run():
 var model=load("res://scripts/forest/forest_model.gd").new()
 model.reset(42,{}, {"trees":[],"deposits":[],"roads":[],"buildings":[
  {"kind":"tower","x":-4,"z":0,"rotation":0},
  {"kind":"barracks","x":0,"z":0,"rotation":0},
  {"kind":"barracks","x":0,"z":-5,"rotation":1}]})
 model.workers.clear()
 world=load("res://scripts/forest/forest_world.gd").new();world.model=model;root.add_child(world);await process_frame
 var before=collisions(world);var state=model.buildings.duplicate(true)
 var old_visibility={}
 for node in visible_geometry(world):old_visibility[node]=node.visible
 world.set_painterly_preview(true);await process_frame
 for b in model.buildings.values():
  if b.kind not in ["tower","barracks"]:continue
  var art=details(b.id)
  check(art!=null,"Every tower and bunker receives the scenery treatment")
  var rendered=visible_geometry(world.structure_nodes[b.id])
  if art!=null:rendered.append_array(visible_geometry(art))
  check(rendered.size()>0 and rendered.size()<=4,"Stonework and local planting stay within four geometry submissions per building")
  if art!=null:
   check(collisions(art).is_empty(),"Decorative stone and planting add no physics shapes")
   check(art.find_children("*","Light3D",true,false).is_empty(),"Building decoration introduces no local lights")
 check(collisions(world)==before and model.buildings==state,"Deck collision, building health and authored positions are preserved")
 var count=world.painterly_pilot.scenery.get_child_count()
 for i in 3:model.revision+=1;world.sync(0)
 check(world.painterly_pilot.scenery.get_child_count()==count,"Routine sync never duplicates the decorative area")
 var added=model._make_building("barracks",Vector2i(5,0),2);model.revision+=1;world.sync(0)
 check(details(added.id)!=null,"A newly constructed bunker receives its scenery immediately")
 model._remove_building(added.id);model.revision+=1;world.sync(0)
 check(world.painterly_pilot.scenery.get_child_count()==count,"Demolition removes the bunker and its surrounding decoration")
 if DisplayServer.get_name()!="headless":
  root.size=Vector2i(1440,900)
  var camera=Camera3D.new();root.add_child(camera);camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=64
  camera.position=Vector3(44,44,63);camera.look_at(Vector3(-7,7,1))
  for i in 8:await process_frame
  await RenderingServer.frame_post_draw
  DirAccess.make_dir_recursive_absolute(OUTPUT)
  var label_="after"
  for arg in OS.get_cmdline_user_args():
   if arg.begins_with("--capture="):label_=arg.trim_prefix("--capture=")
  root.get_texture().get_image().save_png(OUTPUT+"/"+label_+".png")
 world.set_painterly_preview(false);await process_frame
 check(collisions(world)==before,"Turning the style off retains original collision identities")
 check(old_visibility.keys().all(func(node):return node.visible==old_visibility[node]),"Turning the style off restores every original visible mesh")
 world.set_painterly_preview(true);world.reload_map();await process_frame
 check(world.painterly_pilot.scenery.get_child_count()==count,"Map reload restores exactly one decoration group per building")
 world.queue_free();await process_frame
 print("GLADE_STRUCTURES_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
