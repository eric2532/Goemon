extends SceneTree
## Geometry ownership checks only; the user reviews appearance in-game.
const Court=preload("res://scripts/forest/forest_falan_courtyard.gd")
const Civic=preload("res://scripts/forest/forest_falan_civic_exterior.gd")
const OUT="res://build/Other Files/Asset Toolkit/Explore Visual Match/courtyard-physics-baseline.json"

func _initialize():
 create_timer(120).timeout.connect(func():printerr("EXPLORE_COURTYARD_TIMEOUT");quit(1))
 run.call_deferred()

func run():
 var scene=Node3D.new();root.add_child(scene)
 Court.build(scene)
 var report={"obstacles":[],"shapes":[]}
 for box in Court.obstacles():report.obstacles.append(str(box))
 for node in scene.find_children("*","CollisionShape3D",true,false):
  report.shapes.append([str(node.global_transform),str(node.shape.get_debug_mesh().get_aabb())])
 if "--baseline" in OS.get_cmdline_user_args():
  var file=FileAccess.open(OUT,FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close()
 else:
  var baseline=JSON.parse_string(FileAccess.get_file_as_string(OUT))
  assert(report==baseline,"Visual fort reuse preserves all courtyard obstacles and stair physics")
  var placements={}
  for rows in [Court.Data.WALLS,Court.Data.SQUARE_TOWERS,Court.Data.ROUND_TOWERS,Court.Data.GATE_BEAMS]:
   for row in rows:
    var serial:int=row[1]
    if not placements.has(serial):placements[serial]=[]
    placements[serial].append(Court.point(row[0]))
  var found={}
  var parts=load("res://scripts/forest/forest_falan_fort_parts.gd")
  for node in scene.find_children("*","MultiMeshInstance3D",true,false):
   var serial:int=node.get_meta("falan_fort_graphic",0)
   if serial==0:continue
   assert(node.multimesh.mesh==parts.prepare(serial),"Castle reuses the existing cached native fort mesh")
   found[serial]=found.get(serial,0)+node.multimesh.instance_count
  assert(found.size()==placements.size(),"Every native courtyard fort family is represented")
  for serial in placements:
   assert(found[serial]==placements[serial].size(),"No native fort placement is added or removed")
  # The headless dummy renderer returns zero MultiMesh transforms; source anchors
  # are passed directly by Court.build, while this check covers mesh/count/physics.
  var office=Node3D.new();root.add_child(office)
  Civic.build(office,Vector3.ZERO,Civic.SHELLS[Vector2i(-42,-23)])
  var panes=office.find_children("*","MeshInstance3D",true,false).filter(func(n):return n.get_meta("falan_source_feature","") in ["office_side_near","office_side_far"])
  assert(panes.size()==2,"The office retains both independently recovered upper side windows")
  var village=Node3D.new();root.add_child(village)
  var coastal=load("res://scripts/forest/forest_coastal_buildings.gd")
  var il=load("res://assets/maps/falan/il_restoration_data.gd")
  coastal.build(village,Vector3(84,0,36),10607,il,load("res://assets/maps/falan/il_buildings.png"),Vector3(1,14.0/15.925,15.0/21.0))
  var guild:Node3D=village.get_child(0)
  assert(guild.position==Vector3(84,0,36) and guild.get_meta("source_graphic")==10607,"Il guild retains its native origin and graphic")
  assert(guild.scale==Vector3.ONE,"The same native office graphic retains its calibrated proportions in Il")
  assert(guild.find_children("*","CollisionShape3D",true,false).is_empty(),"Il guild reuse adds only scenery")
  assert(guild.find_children("*","MeshInstance3D",true,false).any(func(n):return n.get_meta("office_source_body",false)),"Il reuses the solid source office instead of the flat-roof substitute")
 print("EXPLORE_COURTYARD_VISUAL_PASS obstacles=",report.obstacles.size()," shapes=",report.shapes.size())
 scene.queue_free();await process_frame;quit()
