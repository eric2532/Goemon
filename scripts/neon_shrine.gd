extends RefCounted
## Standard Fire Siege art direction. Duplicate world materials, never shared hero art.
const ROAD=preload("res://assets/vfx/spirit_fortress/neon_road.gdshader")
const PALETTE={
 "788883":"454c65","939c91":"63667f","62726f":"343c56",
 "253f43":"25273f","443b30":"33263c","c4a166":"91747f",
 "d6b25c":"70426e","5c6960":"333d56","873f32":"a34155",
 "243d3f":"22283e","b5975c":"d867aa","ae4732":"a94b62",
 "702f27":"482b45","49392d":"322a3c","263e3d":"22283e",
 "aaa37e":"353d55","8a9272":"383e56","e9d5a5":"91b9ce",
 "534236":"343044","3b6250":"334351","294c40":"273344",
 "c996a0":"c37fbc","657f7b":"253248","718e85":"37354f",
 "cccebb":"77768d"
}
static func apply(world: Node3D):
 for child in world.get_children():
  if child is WorldEnvironment:
   var e=child.environment
   e.ambient_light_color=Color("a9b4da");e.ambient_light_energy=.55
   e.tonemap_exposure=1.04;e.adjustment_saturation=1.08;e.ssao_intensity=1.25
   e.fog_light_color=Color("536483");e.fog_density=.0007
   e.sky.sky_material.sky_top_color=Color("101629")
   e.sky.sky_material.sky_horizon_color=Color("655274")
   e.sky.sky_material.ground_bottom_color=Color("182339")
   e.sky.sky_material.ground_horizon_color=Color("655274")
  elif child is DirectionalLight3D:
   child.light_color=Color("c3c9ff");child.light_energy=.72
 var mapped: Dictionary={}
 var road=ShaderMaterial.new();road.shader=ROAD
 for geometry in world.find_children("*","GeometryInstance3D",true,false):
  if geometry is MeshInstance3D and geometry.get_parent().name=="TerrainChunks":
   geometry.material_override.set_shader_parameter("night_theme",true);continue
  var material=geometry.material_override
  if material is StandardMaterial3D:geometry.material_override=_material(material,mapped,road)
  elif geometry is MeshInstance3D:
   for slot in range(geometry.mesh.get_surface_count()):
    var active=geometry.get_active_material(slot)
    if active is StandardMaterial3D:geometry.set_surface_override_material(slot,_material(active,mapped,road))
 _details(world)

static func _material(old: StandardMaterial3D,mapped: Dictionary,road: ShaderMaterial)->Material:
 if mapped.has(old):return mapped[old]
 if old.albedo_texture and "sand.png" in old.albedo_texture.resource_path:
  mapped[old]=road;return road
 var material=old.duplicate() as StandardMaterial3D
 var hex=old.albedo_color.to_html(false)
 if PALETTE.has(hex):material.albedo_color=Color(PALETTE[hex])
 elif old.albedo_texture:material.albedo_color=Color("9c9bb4")
 if old.emission_enabled:
  # Keep the warm lantern / shrine identity against the blue environment.
  material.emission_energy_multiplier=maxf(old.emission_energy_multiplier,1.2)
 mapped[old]=material;return material

static func _details(world: Node3D):
 var root=Node3D.new();root.name="NeonShrineDetails";world.add_child(root)
 var cyan: Array[Transform3D]=[];var pink: Array[Transform3D]=[];var amber: Array[Transform3D]=[]
 # Broken lane rails and circuitry remain flush and outside the attack path.
 for z in range(108,290,14):
  for side in [-1,1]:
   cyan.append(_box(Vector3(side*9.65,.15,z),Vector3(.13,.06,7)))
   pink.append(_box(Vector3(side*10.2,.15,z+2),Vector3(.09,.06,2)))
 for gate_z in [96.0,230.0]:
  if gate_z==96:
   pink.append(_box(Vector3(0,9.35,96.85),Vector3(28.5,.09,.09)))
   cyan.append(_box(Vector3(0,9.13,96.87),Vector3(26.5,.06,.09)))
   for side in [-1,1]:cyan.append(_box(Vector3(side*12.48,4.9,96.59),Vector3(.07,7.1,.07)))
  else:
   # Match the front faces of the existing high gatehouse and its watchtowers.
   pink.append(_box(Vector3(0,13.70,227.82),Vector3(22.25,.09,.09)))
   cyan.append(_box(Vector3(0,12.86,228.90),Vector3(63.8,.06,.09)))
   for x in [-30.85,-25.15,25.15,30.85]:
    cyan.append(_box(Vector3(x,9.4,228.96),Vector3(.07,5.4,.07)))
 # Circuit seams along the existing fortification, behind the combat sightline.
 for side in [-1,1]:
  cyan.append(_box(Vector3(side*43,3.0,228.93),Vector3(66,.10,.055)))
  pink.append(_box(Vector3(side*43,5.6,228.9),Vector3(66,.07,.055)))
  for x in [23.0,47.0,71.0]:
   cyan.append(_box(Vector3(side*x,4.2,228.92),Vector3(.08,2.4,.055)))
 # Shoji-like illuminated window lattices on the existing shrine footprint.
 for level in range(3):
  var width=24-level*5.5;var depth=14-level*2.8;var y=1+level*6.0
  var z=331-depth*.5+.24
  pink.append(_box(Vector3(0,y+4.48,z),Vector3(width+3,.09,.10)))
  for side in [-1,1]:
   for panel in range(3):
    var x=side*(3.2+panel*2.1)
    if absf(x)>width*.5-1.2:continue
    for dx in [-.68,0,.68]:cyan.append(_box(Vector3(x+dx,y+2.2,z),Vector3(.055,3.1,.055)))
    for dy in [-1.5,-.5,.5,1.5]:cyan.append(_box(Vector3(x,y+2.2+dy,z),Vector3(1.4,.055,.055)))
   amber.append(_box(Vector3(side*2,y+2.2,z),Vector3(.08,3.3,.055)))
 # Emissive seal at the gate, shaped as an invented geometric crest.
 for seal in [[96.75,7.9],[322.0,3.2]]:
  for stroke in [[0,0,.08,1.35],[0,.1,.9,.08],[-.3,.55,.07,.32],[.3,.55,.07,.32],[0,-.58,.75,.08]]:
   amber.append(_box(Vector3(stroke[0],seal[1]+stroke[1],seal[0]),Vector3(stroke[2],stroke[3],.065)))
 _batch(root,"CyanCircuits",cyan,Geo.mat("45dce8",.2,2.0))
 _batch(root,"MagentaEaves",pink,Geo.mat("e856ad",.15,1.8))
 _batch(root,"WarmSeals",amber,Geo.mat("ffc58b",.1,1.3))

static func _box(point: Vector3,size: Vector3)->Transform3D:
 return Transform3D(Basis.from_scale(size),point)

static func _batch(root: Node3D,label: String,transforms: Array[Transform3D],material: Material):
 var cube=BoxMesh.new();cube.size=Vector3.ONE
 var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=cube
 multi.instance_count=transforms.size()
 for i in range(transforms.size()):multi.set_instance_transform(i,transforms[i])
 var mesh=MultiMeshInstance3D.new();mesh.name=label;mesh.multimesh=multi;mesh.material_override=material
 mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(mesh)
