extends MeshInstance3D
## Retail actor4/5: pose-header endpoints, two samples/source tick, sixteen-pair
## world-space ring and additive Gouraud quads. Tables are extracted from ROM.
static var sources:Dictionary={}
var samples:Array=[]
var trail_material:ShaderMaterial
var prepared_mesh=ArrayMesh.new()
var original_mesh=ArrayMesh.new()
var original_trail:MeshInstance3D
var actor:Node
var action=""
var weapon="fusion"
var delay_ticks=0
var record_ticks=0
var length_divisor=116
var brightness=244
var source_clock=0.0
var brush_clock=0.0
var seeded=false
var fading=false
var trail_index=0
var fading_trails:Array=[]
var fusion_flag=false # Native save flag0x81; full equipment does not imply it.
func _ready():
 top_level=true;global_transform=Transform3D.IDENTITY
 cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 trail_material=preload("res://assets/rogue/scripts/ink_brush_style.gd").material(Color("8888ff"));material_override=trail_material
 trail_material.set_shader_parameter("strong_energy",true)
 original_trail=MeshInstance3D.new();original_trail.name="MusashiOriginalBladeTrail"
 original_trail.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var original_material=ShaderMaterial.new();original_material.shader=preload("res://scripts/recovered_musashi_effect.gdshader")
 original_trail.material_override=original_material;add_child(original_trail)
 var parent=get_parent()
 while parent!=null:
  if parent.has_method("melee_reach_setting"):actor=parent;break
  parent=parent.get_parent()
static func data()->Dictionary:
 if sources.is_empty():sources=JSON.parse_string(FileAccess.get_file_as_string('res://assets/characters/recovered_musashi/effects/sword_sources.json'))
 return sources
func clear():
 for trail in fading_trails:trail.free()
 fading_trails.clear();_clear_current()
func _clear_current():
 samples.clear();prepared_mesh.clear_surfaces();original_mesh.clear_surfaces();mesh=null;original_trail.mesh=null;action="";source_clock=0;brush_clock=0;seeded=false;fading=false
func begin_action(key:String):
 if not data().clips.has(key):return
 layers=1
 var spec=data().clips[key]
 var descriptor=data().weapons[spec.weapon].descriptors[int(spec.effect_descriptor)]
 var next_index=int(descriptor.trail_index)
 for old in fading_trails.duplicate():
  if old.trail_index==next_index:fading_trails.erase(old);old.free()
 if not samples.is_empty() and trail_index!=next_index:
  var old=get_script().new();add_child(old)
  old.action=action;old.weapon=weapon;old.trail_index=trail_index;old.samples=samples.duplicate(true)
  old.brightness=brightness;old.seeded=true;old.fading=true;old.fusion_flag=fusion_flag;old._draw()
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
 brush_clock+=delta
 for old in fading_trails.duplicate():
  old.advance_model(delta,model,combat)
  if old.action.is_empty():fading_trails.erase(old);old.free()
 if action.is_empty():return
 source_clock+=delta*30
 while source_clock+.000001>=1:
  source_clock-=1
  var key=combat.action_key if combat.is_attacking() else action
  if action=="desperado_fusion":
   if key=="desperado_dual":key=action
   else:fading=true
  var sample_time=maxf(0,combat.elapsed-source_clock/30.0)
  var pair=pose_segment(key,sample_time,model.rig_visual.global_transform)
  var effect_scale=preload("res://scripts/weapon_proportions.gd").RECOVERED_SKILL_SCALE if key in ["rotation","rotation_end","counter"] else 1.0
  effect_scale*=combat.skill_factor("size")
  if pair.size()==2:pair[0]=pair[1]+(pair[0]-pair[1])*effect_scale
  source_tick(pair,model.rig_visual.global_basis.get_scale().x*.01*effect_scale,combat.is_attacking(),combat.hero.global_position,combat.blade_reach(combat.hero.attack_heavy)*combat.skill_factor("size"))
static func wave_segment(pair:PackedVector3Array,origin:Vector3,reach:float)->PackedVector3Array:
 if pair.size()!=2:return pair
 var segment=preload("res://scripts/recovered_leader_trail.gd").extend_to_reach(PackedVector3Array([pair[1],pair[0]]),origin,reach)
 return PackedVector3Array([segment[1],segment[0]])
func sample(outer:Vector3,inner:Vector3,origin:Vector3,reach:float)->Dictionary:
 return {"outer":outer,"inner":inner,"wave_outer":wave_segment(PackedVector3Array([outer,inner]),origin,reach)[0]}
func source_tick(pair:PackedVector3Array,source_unit:float,owner_active:bool=true,origin:Vector3=Vector3.ZERO,reach:float=0.0):
 if action.is_empty():return
 if not owner_active:fading=true
 if not seeded and fading:_clear_current();return
 if not seeded:
  delay_ticks-=1
  if delay_ticks<=0 and pair.size()==2:samples.append(sample(pair[0],pair[1],origin,reach));seeded=true
  return
 if not fading:
  record_ticks-=1
  if record_ticks<=0:fading=true
  elif pair.size()==2:
   var old=samples.back();var inner=(old.inner+pair[1])*.5
   var outer=(old.outer+pair[0])*.5
   outer=inner+(outer-inner).normalized()*(4096.0/length_divisor)*source_unit
   samples.append(sample(outer,inner,origin,reach));samples.append(sample(pair[0],pair[1],origin,reach))
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
 prepared_mesh.clear_surfaces();original_mesh.clear_surfaces()
 if samples.size()<2:mesh=null;original_trail.mesh=null;return
 var palette=[]
 for age in samples.size():palette.append(vertex_colors(age))
 var original_vertices=PackedVector3Array();var original_colors=PackedColorArray()
 for age in samples.size()-1:
  var newest=samples[samples.size()-1-age];var older=samples[samples.size()-2-age]
  var points=[newest.outer,newest.inner,older.outer,older.inner];var colors=palette[age]
  for index in [0,1,2,1,3,2]:
   original_colors.append(colors[0 if index<2 else 1]);original_vertices.append(points[index])
 var original_arrays=[];original_arrays.resize(Mesh.ARRAY_MAX)
 original_arrays[Mesh.ARRAY_VERTEX]=original_vertices;original_arrays[Mesh.ARRAY_COLOR]=original_colors
 original_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,original_arrays);original_trail.mesh=original_mesh
 original_trail.layers=layers
 original_trail.material_override.set_shader_parameter("energy",.42 if is_instance_valid(actor) and actor.game.settings.get("reduced_flashes",false) else 1.0)
 var poses=[]
 for age in samples.size():
  var sample=samples[samples.size()-1-age];poses.append([sample.inner,sample.wave_outer])
 var arrays=preload("res://assets/rogue/scripts/magic_sword_brush.gd").surface_arrays(poses)
 var colors=PackedColorArray()
 for uv in arrays[Mesh.ARRAY_TEX_UV]:colors.append(palette[floori(uv.x*(samples.size()-1))][0])
 arrays[Mesh.ARRAY_COLOR]=colors
 prepared_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh=prepared_mesh
 trail_material.set_shader_parameter("ink_tint",palette[0][0])
 trail_material.set_shader_parameter("fade",float(brightness)/244.0)
 trail_material.set_shader_parameter("brush_clock",brush_clock)
 trail_material.set_shader_parameter("energy",.42 if is_instance_valid(actor) and actor.game.settings.get("reduced_flashes",false) else 1.0)
