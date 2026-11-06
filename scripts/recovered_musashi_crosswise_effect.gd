extends Node3D
## Original actor0x54: one snapshotted contact sprite, accelerated growth, hold,
## then fade at30Hz. Prepared slots retain overlapping hits without cast setup.
var flashes:Array=[]
var clock=0.0
var cursor=0
var misses=0
func _ready():
 top_level=true;global_transform=Transform3D.IDENTITY
 var quad=QuadMesh.new();quad.size=Vector2.ONE
 for i in 4:
  var node=MeshInstance3D.new();node.mesh=quad
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var material=StandardMaterial3D.new()
  material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
  material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
  material.billboard_keep_scale=true
  material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
  material.albedo_texture=preload("res://assets/characters/recovered_musashi/techniques/crosswise.png")
  node.material_override=material;add_child(node);node.hide()
  flashes.append({"node":node,"phase":-1,"size":0,"speed":256,"light":128,"hold":5,"model_scale":1.0})
func clear():
 for f in flashes:f.phase=-1;f.node.hide()
 clock=0;cursor=0
func spawn(point:Vector3,model_scale:float):
 var f=flashes[cursor];cursor=(cursor+1)%flashes.size()
 if f.phase>=0:misses+=1
 f.phase=0;f.size=0;f.speed=256;f.light=128;f.hold=5;f.model_scale=model_scale
 f.node.global_position=point;f.node.scale=Vector3.ONE*.0001
 f.node.material_override.albedo_color=Color.WHITE;f.node.layers=1;f.node.show()
func advance(delta:float):
 if flashes.all(func(f):return f.phase<0):clock=0;return
 clock+=delta*30
 while clock+.000001>=1:
  clock-=1
  for f in flashes:
   if f.phase<0:continue
   if f.phase==0:
    f.speed+=512;f.size+=f.speed
    if f.size>=12288:f.phase=1
   elif f.phase==1:
    f.hold-=1
    if f.hold==0:f.phase=2
   else:
    f.size+=1024;f.light-=8
    if f.light<=0:f.phase=-1;f.node.hide();continue
   # The PS1 drew screen-space pixels. A camera-facing world quad preserves
   # occlusion and the recovered shape in Goemon's freely moving 3D camera.
   f.node.scale=Vector3.ONE*float(f.size)/4096.0*.48*f.model_scale
   f.node.material_override.albedo_color=Color(float(f.light)/128,float(f.light)/128,float(f.light)/128)
