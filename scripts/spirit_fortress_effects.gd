extends Node3D
## Spirit Fortress 0.1.0 techniques adapted to the playable Fire Siege field.
## Visuals only; the world's existing routes, structures and physics own gameplay.
const WATER=preload("res://assets/vfx/spirit_fortress/water.gdshader")
const BANNER=preload("res://assets/vfx/spirit_fortress/banner.gdshader")
var clock_time=0.0
var particles: Array[CPUParticles3D]=[]
var lights: Array[OmniLight3D]=[]
var float_roots: Array[Node3D]=[]
var float_positions: Array[Vector3]=[]
var banner_materials: Array[ShaderMaterial]=[]
var cloth_materials: Dictionary={}
var cloth_meshes: Dictionary={}
var water_material: ShaderMaterial
var pulse: MeshInstance3D
var environment: Environment
var original_fog: Dictionary={}
var quality=1
var neon_theme=false

func _ready():
 name="SpiritFortressEffects"
 var world=get_parent()
 for child in world.get_children():
  if child is WorldEnvironment:environment=child.environment
 if environment:
  for key in ["fog_mode","fog_density","fog_light_color","fog_light_energy","fog_sky_affect"]:
   original_fog[key]=environment.get(key)
 water_material=ShaderMaterial.new();water_material.shader=WATER
 water_material.set_shader_parameter("clock_time",0.0)
 var custom=world.get("custom_map")==true
 neon_theme=not custom
 if custom:
  for piece in world.piece_nodes.values():
   if piece.get_meta("piece_kind","")=="banner":_cloth(piece,Vector3(.8,3.3,0),Vector2(1.6,2.3),Color("48a595"))
 else:
  for flag in world.defense_banners:_cloth(flag,Vector3(.85,-1.25,0),Vector2(1.7,2.5),Color("454066"))
  _gardens(world.spawn_point)
  var positions: Array=world.spirit_lantern_positions.duplicate()
  positions.sort_custom(func(a,b):return a.distance_squared_to(world.spawn_point)<b.distance_squared_to(world.spawn_point))
  for i in range(mini(4,positions.size())):_light(positions[i]+Vector3.UP*3,Color("ffba79"),.8,8,false)
 _light(world.base_position+Vector3.UP*5,Color("73dedc"),1.25,12,true)
 _particles(world.spawn_point+Vector3(0,5,0),64,Color("edb8c7"),true)
 _particles(world.base_position+Vector3.UP*3,36,Color("84f5ec"),false)
 _runes(world.base_position)
 # Ground overlays, tiny trim and distant ornaments need no extra shadow pass.
 # Battlefield cloth stays outside this branch and retains its wind-driven shadow.
 for geometry in find_children("*","GeometryInstance3D",true,false):
  geometry.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 apply_quality(1)

func _cloth(parent: Node3D,position: Vector3,size: Vector2,color: Color):
 # Retain the existing pole and footprint; replace only rigid cloth/emblem boxes.
 for child in parent.get_children():
  if child is MeshInstance3D and child.mesh is BoxMesh:child.hide()
 var material: ShaderMaterial=cloth_materials.get(color)
 if material==null:
  material=ShaderMaterial.new();material.shader=BANNER
  material.set_shader_parameter("clock_time",0.0)
  material.set_shader_parameter("cloth_color",color.darkened(.25))
  material.set_shader_parameter("trim_color",Color("f4e5bf"))
  if neon_theme:
   material.set_shader_parameter("trim_color",Color("e966b0"))
   material.set_shader_parameter("neon_strength",.9)
  cloth_materials[color]=material;banner_materials.append(material)
 var plane: PlaneMesh=cloth_meshes.get(size)
 if plane==null:
  plane=PlaneMesh.new();plane.orientation=PlaneMesh.FACE_Z;plane.size=size
  plane.subdivide_width=8;plane.subdivide_depth=20
  cloth_meshes[size]=plane
 var cloth=Geo.mesh(parent,plane,position,material)
 cloth.name="SpiritCloth";cloth.extra_cull_margin=.4

func _light(position: Vector3,color: Color,energy: float,radius: float,shadows: bool):
 var light=OmniLight3D.new();light.position=position;light.light_color=color
 light.light_energy=energy;light.omni_range=radius
 light.distance_fade_enabled=true;light.distance_fade_begin=55;light.distance_fade_length=20
 light.set_meta("spirit_shadow",shadows);add_child(light);lights.append(light)

func _particles(position: Vector3,amount: int,color: Color,petals: bool):
 var ps=CPUParticles3D.new();ps.name="Petals" if petals else "SpiritMotes"
 ps.position=position;ps.amount=amount;ps.lifetime=8;ps.preprocess=4
 ps.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
 ps.emission_box_extents=Vector3(18,2,20) if petals else Vector3(3,1,3)
 ps.direction=Vector3(.65,-.2,.2) if petals else Vector3.UP;ps.spread=35
 ps.initial_velocity_min=.15;ps.initial_velocity_max=.65
 ps.gravity=Vector3(0,-.03,0) if petals else Vector3(0,.03,0)
 ps.scale_amount_min=.12 if petals else .08;ps.scale_amount_max=.24 if petals else .17
 var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.albedo_color=color;material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
 material.vertex_color_use_as_albedo=true
 material.billboard_keep_scale=true;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 material.cull_mode=BaseMaterial3D.CULL_DISABLED
 var gradient=Gradient.new();gradient.offsets=PackedFloat32Array([0,.65,1])
 gradient.colors=PackedColorArray([Color.WHITE,Color(1,1,1,.9),Color(1,1,1,0)])
 ps.color_ramp=gradient
 var texture=GradientTexture2D.new();texture.gradient=gradient;texture.width=32;texture.height=32
 texture.fill=GradientTexture2D.FILL_RADIAL;texture.fill_from=Vector2(.5,.5);texture.fill_to=Vector2(.5,0)
 material.albedo_texture=texture
 var quad=QuadMesh.new();quad.size=Vector2(1,.55) if petals else Vector2(.65,.65);quad.material=material
 ps.mesh=quad;add_child(ps);particles.append(ps)

func _gardens(spawn: Vector3):
 var pools=Node3D.new();pools.name="SpiritPools";add_child(pools)
 var stone=Geo.mat("526f70")
 for side in [-1,1]:
  var p=Vector3(side*40,0,spawn.z+12)
  var plane=PlaneMesh.new();plane.size=Vector2(8,16);plane.subdivide_width=24;plane.subdivide_depth=40
  Geo.mesh(pools,plane,p+Vector3.UP*.12,water_material)
  for x in [-4.2,4.2]:Geo.box(pools,p+Vector3(x,.16,0),Vector3(.3,.3,16.6),stone)
  for z in [-8.2,8.2]:Geo.box(pools,p+Vector3(0,.16,z),Vector3(8.6,.3,.3),stone)
  _particles(p+Vector3.UP*.6,8,Color("d4faef"),false)
  # Hover beyond the map boundary, clear of actors, work spots and the route.
  for i in range(3):
   var n=Node3D.new();n.name="FloatingStone";n.position=Vector3(side*(87+i*6),5+i*2,spawn.z-10+i*28)
   add_child(n);float_roots.append(n);float_positions.append(n.position)
   var rock=Geo.sphere(n,Vector3.ZERO,Vector3(2,3,2.5),Geo.mat("4b6070"));rock.mesh.radial_segments=9;rock.mesh.rings=4
   Geo.cylinder(n,Vector3(0,-1,0),.4,2.2,Geo.mat("48bbc8",.25,1.3),false,.15)

func _runes(base: Vector3):
 var root=Node3D.new();root.name="ShrineRunes";root.position=base;add_child(root)
 var material=Geo.mat("73e1dc",.3,1.3)
 for radius in [3.5,4.8]:Geo.torus(root,Vector3.UP*.2,radius-.04,radius+.04,material)
 for i in range(8):
  var a=TAU*i/8
  var rune=Geo.box(root,Vector3(cos(a)*4.15,.2,sin(a)*4.15),Vector3(.13,.03,.7),material);rune.rotation.y=-a
 pulse=Geo.torus(root,Vector3.UP*.24,.91,1,material)

func _process(delta: float):
 if quality==0:return
 clock_time+=delta
 water_material.set_shader_parameter("clock_time",clock_time)
 for material in banner_materials:material.set_shader_parameter("clock_time",clock_time)
 for i in range(float_roots.size()):
  float_roots[i].position.y=float_positions[i].y+sin(clock_time*.9+i*.7)*.5
 var phase=fmod(clock_time,3.0)/3.0
 pulse.scale=Vector3.ONE*(.7+phase*5.2)
 pulse.transparency=phase

func apply_quality(value: int):
 quality=value;visible=value>0;set_process(value>0)
 for ps in particles:ps.emitting=value>0
 for light in lights:
  light.visible=value>0;light.shadow_enabled=value==2 and light.get_meta("spirit_shadow",false)
 for material in banner_materials:material.set_shader_parameter("animate",value>0)
 water_material.set_shader_parameter("animate",value>0)
 if environment:
  if value==0:
   for key in original_fog:environment.set(key,original_fog[key])
  else:
   environment.fog_enabled=true;environment.fog_mode=Environment.FOG_MODE_DEPTH
   environment.fog_density=.24;environment.fog_depth_begin=80;environment.fog_depth_end=330
   environment.fog_depth_curve=1.3;environment.fog_sky_affect=0
   environment.fog_light_color=Color("9cb5bb");environment.fog_light_energy=.8
   environment.glow_intensity=.4;environment.glow_hdr_threshold=1.1
   if neon_theme:
    environment.fog_density=.18;environment.fog_depth_begin=100
    environment.fog_light_color=Color("556b90");environment.fog_light_energy=.65
    environment.glow_intensity=.5;environment.glow_hdr_threshold=1.3
