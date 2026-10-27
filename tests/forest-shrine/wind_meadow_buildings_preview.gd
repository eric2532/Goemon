extends "res://tests/forest-shrine/wind_meadow_preview.gd"
## Assemble the existing Twin Ramparts perimeter without editing its map document.
const OFFSET=Vector3(-6,0,-38)
var building_nodes:Dictionary={}
var walls:Array=[]
var layout:Dictionary
var gate:Node3D
var samples_:Array=[]
var pieces:Array=[]
var statue:Node3D
var cast:Array=[]

func height_at(_x:float,_z:float)->float:return 0.0

func ground():
 super.ground()
 var extension=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(1000,1000);extension.mesh=plane;extension.position.y=-.02
 var mat=ShaderMaterial.new();mat.shader=GROUND;extension.material_override=mat;stage.add_child(extension)

func place_asset(asset:String,transforms:Array,wind:bool=false):
 if asset!="terraced_mountain":
  transforms=transforms.filter(func(t):
   var p=t.origin
   if absf(p.x)<54 and p.z>-74 and p.z<8:return false
   if absf(p.x)<39 and p.z>14 and p.z<32:return false
   return true)
 if not transforms.is_empty():super.place_asset(asset,transforms,wind)

func piece(asset:String,p:Vector3,rotation_:float=0)->Node3D:
 var node=load(DIR+"buildings/"+asset+".glb").instantiate()
 stage.add_child(node);node.position=p;node.rotation.y=rotation_
 pieces.append(node)
 if not building_nodes.has(asset):building_nodes[asset]=node
 return node

func landscape():
 super.landscape()
 layout=JSON.parse_string(FileAccess.get_file_as_string("res://tests/forest-shrine/reference/maps/forest_twin_ramparts.json"))
 var wall_cells:Dictionary={}
 for b in layout.buildings:
  if b.kind=="wall":
   for i in int(b.span):
    var cell=Vector2i(int(b.x),int(b.z))+(Vector2i.DOWN if int(b.rotation)%2 else Vector2i.RIGHT)*i
    assert(not wall_cells.has(cell));wall_cells[cell]=true
    var node=piece("wall_section",Vector3(cell.x*6,0,cell.y*6)+OFFSET,int(b.rotation)*PI*.5);walls.append(node)
  elif b.kind=="tower":
   piece("watchtower",Vector3(int(b.x)*6+3,0,int(b.z)*6+3)+OFFSET,int(b.rotation)*PI*.5)
  elif b.kind=="gate":
   gate=piece("gate_frame",Vector3(int(b.x)*6+3,0,int(b.z)*6)+OFFSET,int(b.rotation)*PI*.5)
 # The new barracks and modular samples are display objects, not saved-map changes.
 piece("barracks",Vector3(25,0,-44))
 samples_.append(piece("wall_section",Vector3(-30,0,25)))
 samples_.append(piece("wall_corner",Vector3(-18,0,25)))
 samples_.append(piece("stone_block",Vector3(-5,0,25)));samples_.append(piece("stone_block",Vector3(-5,6,25)))
 samples_.append(piece("wall_cap",Vector3(-5,12,25)))
 statue=load("res://assets/models/forest/goemon_stone_statue.scn").instantiate()
 stage.add_child(statue);statue.position=OFFSET+Vector3(0,2.8,0);statue.rotation.y=PI
 for entry in [{"name":"Goemon","script":"recovered_goemon_model","x":-10.0},{"name":"Ed","script":"recovered_ed_model","x":-4.0},{"name":"Ben","script":"recovered_ben_model","x":4.0}]:
  var visual=load("res://scripts/"+entry.script+".gd").new()
  visual.name=entry.name;stage.add_child(visual);visual.position=Vector3(entry.x,0,18);visual.rotation.y=PI
  visual.animate(0.0,0.0,true,0.0,0.0,false,1,false);visual.sync_skeleton();visual.set_process(false);cast.append(visual)
 # Reuse the meadow meshes around the cast, keeping the worn path and feet clear.
 var grass:Array=[];var flowers:Array=[]
 for i in 650:
  var x=random.randf_range(-18,14);var z=random.randf_range(10,28)
  if absf(x-(-4+sin(z*.055)*5))<2:continue
  var clear=true
  for actor in cast:
   if Vector2(x-actor.position.x,z-actor.position.z).length()<(1.7 if actor.name=="Ben" else .9):clear=false;break
  if clear:grass.append(pose(x,z,random.randf_range(.8,1.1)))
  if clear and x<-12 and random.randf()<.18:flowers.append(pose(x,z))
 super.place_asset("grass_short",grass,true)
 super.place_asset("flowers_blue",flowers,true)
 super.place_asset("broadleaf_tree",[pose(-24,12,1.1),pose(20,11,1.2)],true)
 super.place_asset("leafy_shrub",[pose(-17,10),pose(14,14)],true)
 for node in samples_:node.hide()
 focus=Vector3(-3,3.5,18);distance_=27;orbit=Vector2(.12,.16);view()

func validate_scene()->bool:
 assert(building_nodes.size()==7 and walls.size()>40 and instances>500 and batches<110)
 for key in building_nodes:
  var meshes=building_nodes[key].find_children("*","MeshInstance3D",true,false)
  assert(meshes.size()<=3 and meshes.size()>=1)
  for mesh in meshes:assert(mesh.mesh.get_surface_count()==1,"Each group shares one painted atlas")
 var tower=building_nodes.watchtower
 assert(is_equal_approx(tower.find_child("DeckCenter",true,false).position.y,20))
 assert(is_equal_approx(tower.find_child("RearLookout",true,false).position.y,25))
 assert(is_equal_approx(building_nodes.barracks.find_child("DeckCenter",true,false).position.y,6))
 assert(is_equal_approx(building_nodes.wall_section.find_child("WallTop",true,false).position.y,16))
 assert(is_equal_approx(gate.find_child("OpeningTop",true,false).position.y,11))
 var corner=building_nodes.wall_corner
 assert(is_equal_approx(corner.find_child("JoinRight",true,false).position.x-corner.find_child("JoinLeft",true,false).position.x,6))
 var dimensions={"wall_section":Vector3(6,16,6),"wall_corner":Vector3(6,16,6),"stone_block":Vector3(6,6,6),"wall_cap":Vector3(6,.7,6)}
 for asset in dimensions:
  var node=building_nodes[asset];var mesh=node.find_child("Architecture",true,false)
  var bounds=(node.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
  assert(bounds.size.distance_to(dimensions[asset])<.01,"Module dimensions must match the grid: %s %s"%[asset,bounds.size])
 assert(walls[0].find_child("Architecture",true,false).mesh==walls[1].find_child("Architecture",true,false).mesh,"Repeated walls share mesh resources")
 assert(cast.size()==3 and cast[0].name=="Goemon" and cast[1].name=="Ed" and cast[2].name=="Ben")
 for actor in cast:assert(actor.scale.is_equal_approx(Vector3.ONE) and actor.position.y==0,"Reuse the gameplay model scale and ground origin")
 assert(cast[1].character_id==14 and cast[2].character_id==15)
 assert(is_equal_approx(cast[2].rig_visual.scale.y,preload("res://scripts/character_proportions.gd").BEN_MODEL_SCALE))
 var original=gate.find_child("GateDoor",true,false).position
 gate.find_child("GateDoor",true,false).position.y+=11
 assert(is_equal_approx(gate.find_child("GateDoor",true,false).position.y-original.y,11))
 gate.find_child("GateDoor",true,false).position=original
 var report=FileAccess.open(output_folder()+"geometry-validation.json",FileAccess.WRITE)
 report.store_string(JSON.stringify({"assets":building_nodes.keys(),"original_wall_cells":walls.size(),"shared_wall_mesh":true,"wall_height":16,"gate_opening_height":11,"tower_deck_height":20,"tower_lookout_height":25,"barracks_deck_height":6,"gameplay_integrated":false},"  "));report.close()
 print("WIND_MEADOW_BUILDINGS_IMPORT_PASS: 7 assets, %d original wall cells, unchanged deck and gate dimensions"%walls.size())
 return true

func output_folder()->String:return OUT+"Buildings/"

func prepare_capture(shot:Dictionary):
 var isolated=shot.get("isolate","")
 for node in pieces:node.visible=isolated=="" or (samples_.has(node) if isolated=="samples" else node==building_nodes[isolated])
 for node in samples_:node.visible=shot.name.begins_with("wall-kit")
 statue.visible=isolated==""
 for actor in cast:actor.visible=shot.name.begins_with("cast-")
 gate.find_child("GateDoor",true,false).position.y=11.0 if shot.name=="gate-open" else 0.0

func capture_views()->Array:
 return [{"name":"cast-meadow","orbit":Vector2(.12,.16),"distance":27.0,"focus":Vector3(-3,3.5,18)},
 {"name":"cast-castle","orbit":Vector2(.12,.27),"distance":45.0,"focus":Vector3(-3,7,4)},
 {"name":"existing-fort-meadow","orbit":Vector2(.24,.6),"distance":139.0,"focus":Vector3(0,4,-28)},
 {"name":"wall-kit","orbit":Vector2(.3,.3),"distance":55.0,"focus":Vector3(-16,7,25)},
 {"name":"wall-kit-back","orbit":Vector2(3.5,.35),"distance":48.0,"focus":Vector3(-16,7,25),"isolate":"samples"},
 {"name":"gate-front","orbit":Vector2(.2,.1),"distance":43.0,"focus":Vector3(-3,10,4)},
 {"name":"gate-open","orbit":Vector2(.2,.1),"distance":43.0,"focus":Vector3(-3,10,4)},
 {"name":"tower-front","orbit":Vector2(3.55,.25),"distance":44.0,"focus":Vector3(-27,15,-11),"isolate":"watchtower"},
 {"name":"tower-back","orbit":Vector2(.42,.45),"distance":44.0,"focus":Vector3(-27,15,-11),"isolate":"watchtower"},
 {"name":"barracks-front","orbit":Vector2(.4,.44),"distance":36.0,"focus":Vector3(25,3,-44),"isolate":"barracks"},
 {"name":"barracks-back","orbit":Vector2(3.55,.55),"distance":30.0,"focus":Vector3(25,3,-44),"isolate":"barracks"}]
