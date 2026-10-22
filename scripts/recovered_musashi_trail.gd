extends MeshInstance3D
## Retail actor4/5: pose-header endpoints, two samples/source tick, sixteen-pair
## world-space ring and additive Gouraud quads. Tables are extracted from ROM.
static var sources:Dictionary={}
var samples:Array=[]
var trail_material:ShaderMaterial
var action=""
var weapon="fusion"
var delay_ticks=0
var record_ticks=0
var length_divisor=116
var brightness=244
var source_clock=0.0
var seeded=false
var fading=false
var trail_index=0
var fading_trails:Array=[]
var fusion_flag=false # Native save flag0x81; full equipment does not imply it.
func _ready():
 top_level=true;global_transform=Transform3D.IDENTITY
 cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 trail_material=ShaderMaterial.new();trail_material.shader=preload('res://scripts/recovered_musashi_effect.gdshader');material_override=trail_material
static func data()->Dictionary:
 if sources.is_empty():sources=JSON.parse_string(FileAccess.get_file_as_string('res://assets/characters/recovered_musashi/effects/sword_sources.json'))
 return sources
func clear():
 for trail in fading_trails:trail.free()
 fading_trails.clear();_clear_current()
func _clear_current():
 samples.clear();mesh=null;action="";source_clock=0;seeded=false;fading=false
func begin_action(key:String):
 if not data().clips.has(key):return
 var spec=data().clips[key]
 var descriptor=data().weapons[spec.weapon].descriptors[int(spec.effect_descriptor)]
 var next_index=int(descriptor.trail_index)
 for old in fading_trails.duplicate():
  if old.trail_index==next_index:fading_trails.erase(old);old.free()
 if not samples.is_empty() and trail_index!=next_index:
  var old=get_script().new();add_child(old)
  old.action=action;old.weapon=weapon;old.trail_index=trail_index;old.samples=samples.duplicate(true)
  old.brightness=brightness;old.seeded=true;old.fading=true;old.mesh=mesh;old.fusion_flag=fusion_flag
  fading_trails.append(old)
 _clear_current();action=key;weapon=spec.weapon;trail_index=next_index
 delay_ticks=int(descriptor.delay_ticks);record_ticks=int(descriptor.record_ticks);length_divisor=int(descriptor.length_divisor);brightness=244
static func pose_segment(key:String,time:float,transform:Transform3D)->PackedVector3Array:
 if not data().clips.has(key):return PackedVector3Array()
 var frames=data().clips[key].frames;var selected=frames[0]
 for frame in frames:
  if int(frame.tick)>floori(time*30+.00001):break
  selected=frame
 var pair=PackedVector3Array()
 for point in selected.endpoints_source:pair.append(transform*(Vector3(point[0],-point[1],-point[2])*.01))
 return pair
func advance_model(delta:float,model,combat):
 for old in fading_trails.duplicate():
  old.advance_model(delta,model,combat)
  if old.action.is_empty():fading_trails.erase(old);old.free()
 if action.is_empty():return
 source_clock+=delta*30
 while source_clock+.000001>=1:
  source_clock-=1
  var key=combat.action_key if combat.is_attacking() else action
  var sample_time=maxf(0,combat.elapsed-source_clock/30.0)
  var pair=pose_segment(key,sample_time,model.rig_visual.global_transform)
  source_tick(pair,model.rig_visual.global_basis.get_scale().x*.01,combat.is_attacking())
func source_tick(pair:PackedVector3Array,source_unit:float,owner_active:bool=true):
 if action.is_empty():return
 if not owner_active:fading=true
 if not seeded and fading:_clear_current();return
 if not seeded:
  delay_ticks-=1
  if delay_ticks<=0 and pair.size()==2:samples.append({'outer':pair[0],'inner':pair[1]});seeded=true
  return
 if not fading:
  record_ticks-=1
  if record_ticks<=0:fading=true
  elif pair.size()==2:
   var old=samples.back();var inner=(old.inner+pair[1])*.5
   var outer=(old.outer+pair[0])*.5
   outer=inner+(outer-inner).normalized()*(4096.0/length_divisor)*source_unit
   samples.append({'outer':outer,'inner':inner});samples.append({'outer':pair[0],'inner':pair[1]})
   while samples.size()>16:samples.pop_front()
 if fading:
  brightness-=16
  if brightness<16:_clear_current();return
  while samples.size()>2 and samples.size()-1>brightness>>4:samples.pop_front()
 _draw()
func vertex_colors(age:int)->Array[Color]:
 var intensity=maxi(0,brightness-age*16)
 var newest:Vector3
 if weapon=='lumina':newest=Vector3(intensity,maxi(0,(brightness>>1)-age*16),maxi(0,(brightness>>1)-age*16))
 elif fusion_flag:newest=Vector3(intensity,intensity,int(intensity*.625))
 else:newest=Vector3(maxi(0,(brightness>>1)-age*16),maxi(0,(brightness>>1)-age*16),intensity)
 var older=(newest-Vector3.ONE*16).max(Vector3.ZERO)
 return [Color(newest.x/255,newest.y/255,newest.z/255),Color(older.x/255,older.y/255,older.z/255)]
func _draw():
 if samples.size()<2:mesh=null;return
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for age in samples.size()-1:
  var newest=samples[samples.size()-1-age];var older=samples[samples.size()-2-age]
  var points=[newest.outer,newest.inner,older.outer,older.inner];var colors=vertex_colors(age)
  for index in [0,1,2,1,3,2]:
   surface.set_color(colors[0 if index<2 else 1]);surface.add_vertex(points[index])
 mesh=surface.commit()
