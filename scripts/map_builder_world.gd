extends "res://scripts/tower_defense_world.gd"
## Adapter from editable documents to the existing Fire Siege world interface.
const Document=preload("res://scripts/map_document.gd")
const Pieces=preload("res://scripts/map_pieces.gd")
var map_data: Dictionary={}
var custom_map=true
var editor_labels=false
var piece_nodes: Dictionary={}
func _ready():
 var doc=Document.new()
 if not doc.decode(JSON.stringify(map_data)).is_empty():doc.reset_blank()
 beta_mode=true;redesign_mode=true;descent_mode=false
 playable_bounds=Document.BOUNDS
 spawn_point=doc.point(doc.find_kind("spawn")[0])+Vector3.UP*.15
 base_position=doc.point(doc.find_kind("base")[0])
 dog_spawn_position=spawn_point+Vector3(5,0,0);hero_spawn_position=spawn_point+Vector3(-5,0,0)
 landmarks={"CUSTOM SHRINE":base_position}
 lanes=[[],doc.route(),[]];defense_stations=[]
 lighting()
 for child in get_children():
  if child is WorldEnvironment:
   child.environment.fog_enabled=not editor_labels;child.environment.fog_density=.00025
   if editor_labels:child.environment.background_mode=Environment.BG_COLOR;child.environment.background_color=Color("293f3b")
   child.environment.fog_light_color=Color("b4cac3");child.environment.ambient_light_energy=.43
   child.environment.tonemap_exposure=1.0
   child.environment.sky.sky_material.sky_top_color=Color("537b91")
   child.environment.sky.sky_material.sky_horizon_color=Color("f2dec0")
  if child is DirectionalLight3D:
   child.light_color=Color("ffe5b4");child.light_energy=1.05
   child.directional_shadow_max_distance=400 if editor_labels else 130
 _build_ground()
 if editor_labels:
  for mesh in get_node("TerrainChunks").get_children():mesh.material_override=Geo.mat("657b4e")
 var path: Array=lanes[1]
 for i in range(path.size()-1):
  _road(path[i],path[i+1],12,Geo.mat("978e72"),1)
  _road(path[i]+Vector3.UP*.015,path[i+1]+Vector3.UP*.015,10,Geo.mat("c0af83"),1)
 for entry in doc.data.pieces:
  var kind: String=entry.kind
  var n=Pieces.build(self,kind,true);n.position=doc.point(entry);n.rotation_degrees.y=entry.rotation
  n.set_meta("piece_uid",entry.uid);piece_nodes[entry.uid]=n
  n.set_meta("piece_kind",kind)
  if kind in ["tower","mine"] and not editor_labels:n.hide()
  if kind=="tower":
   cannon_sites.append({"position":n.position+Vector3.UP*.15,"lane":1,"label":"CUSTOM ARROW TOWER","build_position":n.position+Vector3(0,.15,3.5),"footprint":Vector2(1.4,1.4)})
  elif kind=="mine":mine_sites.append({"position":n.position,"footprint":Vector2(2.3,2.365)})
 if not editor_labels:_install_spirit_effects()
func _process(_delta):pass
