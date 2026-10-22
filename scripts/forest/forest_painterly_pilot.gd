extends RefCounted
## Reversible scenery only. Never changes model data or physics shapes.
const GROUND=preload("res://scripts/forest/forest_painterly_ground.gdshader")
const SURFACE=preload("res://scripts/forest/forest_painterly_surface.gdshader")
const EnvironmentStyle=preload("res://scripts/forest/forest_painterly_environment.gd")
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
const Glade=preload("res://scripts/forest/forest_glade_structures.gd")
const TEXTURE=preload("res://assets/textures/forest_painterly/painterly_ground_v1.png")
var world
var enabled=false
var selected_ids:Array=[]
var scenery:Node3D
var environment_style
var shaders:Array=[]
var original_environment:Environment
var environment_node:WorldEnvironment
var sun:DirectionalLight3D
var sun_state:Array=[]
var materials:Dictionary={}
var applied_signature:Array=[]
var styled_structures:Dictionary={}
func _init(owner_world):world=owner_world;environment_style=EnvironmentStyle.new(world)
func set_enabled(value:bool):
 if value==enabled:return
 if value:
  enabled=true;apply()
 else:
  restore();enabled=false
func restore():
 world.restore_map_environment()
 environment_style.restore()
 for entry in styled_structures.values():restore_geometry(entry)
 for entry in shaders:
  var material=entry[0].get_ref()
  if is_instance_valid(material):material.shader=entry[1]
 shaders.clear()
 if is_instance_valid(scenery):scenery.get_parent().remove_child(scenery);scenery.queue_free()
 scenery=null;selected_ids.clear();materials.clear();applied_signature.clear();styled_structures.clear()
 if is_instance_valid(environment_node):environment_node.environment=original_environment
 if is_instance_valid(sun) and not sun_state.is_empty():
  sun.rotation=sun_state[0];sun.light_color=sun_state[1];sun.light_energy=sun_state[2]
 environment_node=null;sun=null;sun_state.clear();original_environment=null
func choose_ids()->Array:
 var gate=null;var tower=null
 for b in world.model.buildings.values():
  if b.kind=="gate" and (gate==null or b.id<gate.id):gate=b
 if gate==null:return []
 var gate_pos:Vector3=world.model.center(gate)
 var score=INF
 for b in world.model.buildings.values():
  if b.kind!="tower":continue
  var pos:Vector3=world.model.center(b)
  var distance=gate_pos.distance_squared_to(pos)+(100000.0 if pos.x>=gate_pos.x else 0.0)
  if distance<score:score=distance;tower=b
 return [gate.id,tower.id] if tower!=null else [gate.id]
func signature()->Array:
 var result=[world.map_features.get_instance_id(),world.forest_root.get_instance_id(),world.deposit_root.get_instance_id()]
 var all_ids=world.structure_nodes.keys();all_ids.sort()
 for id in all_ids:result.append(world.structure_nodes[id].get_instance_id())
 return result
func refresh():
 if not enabled:return
 var next_signature=signature()
 if next_signature==applied_signature:return
 # Map reloads replace the shared scenery roots. Ordinary building changes
 # only need their own bindings/details; keep the live environment and lights.
 if not is_instance_valid(scenery) or next_signature.slice(0,3)!=applied_signature.slice(0,3):
  restore();apply();return
 sync_structures(true)
 selected_ids=choose_ids();applied_signature=next_signature
func sync_structures(paint_new:bool):
 for id in styled_structures.keys():
  var entry:Dictionary=styled_structures[id]
  var root:Node3D=entry.root.get_ref()
  if is_instance_valid(root) and world.structure_nodes.get(id)==root:continue
  restore_geometry(entry)
  environment_style.restore_overrides(root)
  var detail:Node3D=entry.detail.get_ref() if entry.detail!=null else null
  if is_instance_valid(detail):scenery.remove_child(detail);detail.queue_free()
  styled_structures.erase(id)
 for id in world.structure_nodes:
  if styled_structures.has(id):continue
  var root:Node3D=world.structure_nodes[id]
  var detail:Node3D
  var hidden=[]
  var kind:String=world.model.buildings[id].kind
  if kind in ["tower","barracks"]:
   detail=Glade.build(kind,world.model,root.transform);scenery.add_child(detail);detail.transform=root.transform
   hide_geometry(root,hidden)
  elif kind=="gate":
   detail=Node3D.new();detail.name="GateDetails";scenery.add_child(detail);detail.transform=root.transform
   gate_details(detail)
  if paint_new:environment_style.style(root,"building")
  styled_structures[id]={"root":weakref(root),"detail":weakref(detail) if detail!=null else null,"hidden":hidden}
func hide_geometry(root:Node,hidden:Array):
 for node in root.get_children():
  if node.name in ["Health","TerrainFoundation"]:continue
  if node is GeometryInstance3D:hidden.append([weakref(node),node.visible]);node.hide()
  hide_geometry(node,hidden)
func restore_geometry(entry:Dictionary):
 for item in entry.get("hidden",[]):
  var node=item[0].get_ref()
  if is_instance_valid(node):node.visible=item[1]
func apply():
 var ids=choose_ids();applied_signature=signature()
 selected_ids=ids
 scenery=Node3D.new();scenery.name="PainterlyScenery";world.add_child(scenery)
 sync_structures(false)
 var ground_materials=[world.ground_material]
 var roads=world.map_features.get_node_or_null("RoadTiles")
 if roads!=null and world.model.terrain_source not in ["kai_highway","blood_gulch"]:ground_materials.append(roads.material_override)
 for material in ground_materials:
  shaders.append([weakref(material),material.shader]);material.shader=GROUND
  material.set_shader_parameter("painted_ground",TEXTURE)
 environment_style.apply()
 for node in world.get_children():
  if node is WorldEnvironment:
   environment_node=node;original_environment=node.environment
   var env:Environment=original_environment.duplicate();environment_node.environment=env
   env.ambient_light_color=Color("aebfce");env.ambient_light_energy=.58
   env.ssao_enabled=true;env.ssao_radius=2.0;env.ssao_intensity=1.3
   env.tonemap_exposure=1.05
  if node is DirectionalLight3D:
   sun=node;sun_state=[sun.rotation,sun.light_color,sun.light_energy]
   sun.rotation_degrees=Vector3(-38,-42,0);sun.light_color=Color("ffdaa0");sun.light_energy=1.35
 world.apply_map_environment()
func material(color:Color,axis:Vector3=Vector3.UP,kind:float=0)->ShaderMaterial:
 var key=str(color)+str(axis)+str(kind)
 if materials.has(key):return materials[key]
 var mat=ShaderMaterial.new();mat.shader=SURFACE;mat.set_shader_parameter("base_color",color);mat.set_shader_parameter("grain_axis",axis);mat.set_shader_parameter("surface_kind",kind);mat.set_shader_parameter("brush_texture",TEXTURE)
 materials[key]=mat;return mat
func stone(parent:Node3D,p:Vector3,size_:Vector3,shade:String):
 var mesh=BoxMesh.new();mesh.size=size_
 # Render-only footings; collision is still the original building geometry.
 var node=Geo.mesh(parent,mesh,p,material(Color(shade),Vector3.UP,1))
 return node
func lantern(parent:Node3D,p:Vector3):
 var iron=material(Color("3c453e"),Vector3.UP,1)
 Geo.box(parent,p+Vector3(0,.55,0),Vector3(.85,.13,.85),iron)
 Geo.box(parent,p-Vector3(0,.55,0),Vector3(.85,.15,.85),iron)
 var paper=Geo.mat("ffca77",0,.8)
 Geo.box(parent,p,Vector3(.56,.9,.56),paper)
 for x in [-.34,.34]:
  for z in [-.34,.34]:Geo.box(parent,p+Vector3(x,0,z),Vector3(.07,1.05,.07),iron)
 var light=OmniLight3D.new();light.position=p;light.light_color=Color("ffc16d");light.light_energy=1.3;light.omni_range=11;light.omni_attenuation=1.5;parent.add_child(light)
func gate_details(parent:Node3D):
 # Lanterns sit on the tall stone piers; no old wooden lintel crosses the opening.
 for side in [-1,1]:
  stone(parent,Vector3(side*Profile.GATE_PILLAR_X,.45,0),Vector3(Profile.GATE_PILLAR_WIDTH,.9,4.1),"727f75")
  lantern(parent,Vector3(side*Profile.GATE_PILLAR_X,7.0,2.2))
