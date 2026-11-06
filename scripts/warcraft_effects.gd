extends Node3D
## Original textures and emitter settings, prepared once and restarted by skills.
const ROOT="res://assets/characters/warcraft/effects/"
static var source:Dictionary={}
static var energy_textures:Dictionary={}
var character=31
var emitters:Dictionary={}
var glow:Sprite3D
var flash_left=0.0
var windy=false
static func data()->Dictionary:
 if source.is_empty():source=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"sources.json"))
 return source
static func energy_color(id:int)->Color:return Color("ff2028") if id==31 else Color("278dff") if id==33 else Color("b05bff")
static func energy_tint(id:int,color:Color)->Color:
 var tint=energy_color(id)*color.v
 tint.a=color.a
 return tint
static func energy_texture(texture:Texture2D)->Texture2D:
 if not energy_textures.has(texture):
  var image:Image=texture.get_image().duplicate()
  if image.is_compressed():
   var error=image.decompress();assert(error==OK)
  image.convert(Image.FORMAT_RGBA8)
  # Keep native brightness/alpha while removing the baked-in hue, once per texture.
  for y in image.get_height():
   for x in image.get_width():
    var pixel=image.get_pixel(x,y)
    image.set_pixel(x,y,Color(pixel.v,pixel.v,pixel.v,pixel.a))
  if image.has_mipmaps():image.generate_mipmaps()
  energy_textures[texture]=ImageTexture.create_from_image(image)
 return energy_textures[texture]
func _ready():
 var scale_=preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT/float(load("res://scripts/warcraft_model.gd").data(character).standing_height)
 for key in (["spin","slam"] if character==31 else ["immolation"]):
  var d:Dictionary=data().emitters[key]
  var p=CPUParticles3D.new();p.name=key.capitalize();p.emitting=false;p.amount=ceili(float(d.EmissionRate)*float(d.LifeSpan));p.lifetime=d.LifeSpan;p.local_coords=true
  p.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;p.emission_box_extents=Vector3(d.Width,0,d.Length)*scale_*.5
  p.direction=Vector3.UP;p.spread=d.Latitude;p.gravity=Vector3.DOWN*float(d.Gravity)*scale_
  p.initial_velocity_min=float(d.Speed)*scale_*(1.0-d.Variation);p.initial_velocity_max=float(d.Speed)*scale_*(1.0+d.Variation)
  var ramp=Gradient.new();ramp.offsets=PackedFloat32Array([0,d.Time,1]);var colors=PackedColorArray()
  for i in 3:colors.append(energy_tint(character,Color(d.SegmentColor[i][0],d.SegmentColor[i][1],d.SegmentColor[i][2],float(d.Alpha[i])/255.0)))
  ramp.colors=colors;p.color_ramp=ramp
  p.scale_amount_min=float(d.ParticleScaling[0])*scale_;p.scale_amount_max=p.scale_amount_min
  var curve=Curve.new();curve.max_value=4;curve.add_point(Vector2(0,1));curve.add_point(Vector2(d.Time,float(d.ParticleScaling[1])/d.ParticleScaling[0]));curve.add_point(Vector2(1,float(d.ParticleScaling[2])/d.ParticleScaling[0]));p.scale_amount_curve=curve
  var quad=QuadMesh.new();quad.size=Vector2.ONE*2
  var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
  mat.vertex_color_use_as_albedo=true;mat.albedo_texture=energy_texture(load(ROOT+d.texture));mat.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES
  mat.particles_anim_h_frames=d.Columns;mat.particles_anim_v_frames=d.Rows;mat.particles_anim_loop=false
  p.anim_speed_min=1.0/float(d.LifeSpan);p.anim_speed_max=p.anim_speed_min;quad.material=mat;p.mesh=quad
  p.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;p.position=Vector3(0,1.0,0);add_child(p);emitters[key]=p
 glow=Sprite3D.new();glow.texture=energy_texture(load(ROOT+"Green_Glow2.png"));glow.billboard=BaseMaterial3D.BILLBOARD_ENABLED;glow.pixel_size=5.0/glow.texture.get_width();glow.position.y=1.2;glow.modulate=energy_tint(character,Color(1,1,1,.25));glow.hide();add_child(glow)
 var glow_material=StandardMaterial3D.new();glow_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 glow_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glow_material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
 glow_material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;glow_material.vertex_color_use_as_albedo=true;glow_material.albedo_texture=glow.texture
 glow.material_override=glow_material
func wind(enabled:bool):windy=enabled;glow.visible=windy or flash_left>0
func mirror():flash_left=.5;glow.show()
func immolation(enabled:bool):
 if emitters.has("immolation"):emitters.immolation.emitting=enabled
func spin(enabled:bool):
 if emitters.has("spin"):emitters.spin.emitting=enabled
func slam():
 if emitters.has("slam"):emitters.slam.one_shot=true;emitters.slam.explosiveness=1;emitters.slam.restart();emitters.slam.emitting=true
func _process(delta:float):
 if flash_left>0:
  flash_left=maxf(0,flash_left-delta)
  if flash_left<=0:glow.visible=windy
