extends RefCounted
## Module 0x73 source gestures, markers and five-copy sky sequence; shared by both owners.
const ROLE=18
const PLAYER=30
const SCALE=preload("res://scripts/forest/forest_enemy_roles.gd").DARK_LUMINA_3_SCALE
const SWORD_CROSS_ANGLE=0.0
const SOUND_RANGE=65.0*SCALE
const MOVE_SPEED=1.6
const EFFECT_SCALE={"water":3.0,"water_fall":3.0,"fire":2.0,"blast":2.0,"sword_wave":3.0,"sword_cross":3.0}
const FALL_SPREAD=[97.2,64.8]
const FALL_HEIGHT=40.5
const WATER_BURST_LIFE=1.65
const WIND_AREA=12.0*SCALE
const WIND_VISUAL_SCALE=.22
const WIND_POOL=256
const WIND_FAN=4
const NAMES=["Sword","Wind","Water","Fire","Earth","Sky"]
const COLORS=[Color(.5,0,.75),Color(0,.75,0),Color(0,0,1),Color(1,.125,0),Color(.5,.25,0),Color(.125,.25,1)]
const DIR="res://assets/characters/recovered_monsters/"
const SOUND_DIR=DIR+"audio/dark_lumina_3/"
const FX_DIR=DIR+"dark_lumina_3_effects/"
const SHOT_SPEED=[20.0*SCALE,30.0*SCALE,11.0*SCALE,13.0*SCALE,0.0,24.0*SCALE]
const SHOT_LIFE=[2.0,1.2,4.5,3.75,0.0,2.0]
const SHOT_RADIUS=[2.1*SCALE,2.0*SCALE,3.0*SCALE,1.4*SCALE,28.0*SCALE,1.1*SCALE]
const DAMAGE=[15.0,2.25,3.5,1.0,7.5,8.0]
static var moves=[]
static var meshes={}
static var sounds={}
static var resource:Resource
static var shots={}
static var loops={}
static var blast_radius=1.0
const SOUND_NAMES=["cast","sword_wave","sword_cross","sword_swing","wind_start","wind_loop","water_burst","fire_fall","fire_loop","earth_impact","earth_rumble","sky_copy","sky_launch","core_charge","core_hit","core_burst","core_loop","defeat","ending","hit","hit_strong","impact"]
const SOUND_GAIN={"wind_start":.55,"wind_loop":1.0,"fire_fall":.22,"sky_copy":.55,"sky_launch":.55,"sword_wave":.75,"sword_cross":.7,"earth_impact":.9,"impact":.6}
static func slot_labels()->Dictionary:
 var result={}
 for cue in SOUND_NAMES:result["finale_"+cue]="Dark Lumina 3 · "+cue.replace("_"," ").capitalize()
 return result
static func stream_for(slot:String)->AudioStream:
 var cue=slot.trim_prefix("finale_") if slot.begins_with("finale_") else {"swing":"sword_swing","heavy_swing":"sword_swing","hurt":"hit_strong","death":"defeat"}.get(slot,"")
 if cue not in SOUND_NAMES:return null
 if cue=="wind_loop":cue="wind_sustain"
 return preload("res://scripts/character_audio_bank.gd").sample(SOUND_DIR+cue+("_column1" if cue in ["hit","hit_strong"] else "")+".wav")

static func prepare():
 if not moves.is_empty():return
 resource=preload("res://scripts/forest/forest_thirstquencher_visual.gd").data(ROLE)
 # Segment: source stream suffix, duration, starting source tick, loop.
 var segments=[
  [["801eeea0",60,0,false],["801ef270",40,0,false],["801ef270",16,39,false],["801ef3b8",32,0,false],["801ef6d0",32,0,false],["801ef7d8",24,0,false]],
  [["801ef088",60,0,false],["801ef088",256,59,false]],
  [["801eeb70",40,0,false],["801eeb70",20,39,false],["801ef4c0",32,0,false],["801afc60",96,0,true],["801ef5c8",32,0,false]],
  [["801eeb70",40,0,false],["801eeb70",20,39,false],["801ef4c0",32,0,false],["801afc60",96,0,true],["801ef5c8",32,0,false]],
  [["801eecb8",40,0,false],["801eecb8",64,40,false],["801eecb8",20,40,false]],
  [["801ef8a0",19,0,false],["801ef928",32,0,false],["801ef928",9,0,false],["801ef928",31,0,false],["801ef928",48,0,false],["801ef928",48,0,false],["801ef928",64,0,false],["801ef928",7,0,false]]]
 for index in 6:
  var frames=[]
  for segment in segments[index]:
   var clip="Source__"+segment[0];var source:Dictionary=resource.get_meta("clips")[clip]
   for i in segment[1]:
    var tick=posmod(i+segment[2],source.ticks) if segment[3] else mini(i+segment[2],source.ticks-1)
    frames.append({"clip":clip,"tick":tick,"row":source.rows[tick],"event":0,"speed":0.0,"hidden":false,"cue":0})
  moves.append(frames)
 moves[0][36].cue=32; moves[0][156].cue=33
 moves[2][20].cue=32; moves[3][20].cue=32; moves[4][30].cue=33; moves[4][40].cue=34
 for t in [88,127,139]:moves[0][t].event=1
 for t in range(68,92):moves[0][t].speed=14.0*SCALE
 for t in range(156,176):moves[0][t].speed=-7.0*SCALE
 for t in range(60,316,12):moves[1][t].event=2
 for t in range(60,188,24):moves[2][t].event=3
 for t in range(60,188,4):moves[3][t].event=4
 moves[4][40].event=5
 for t in range(60,85,6):moves[5][t].event=6
 for t in range(139,188,12):moves[5][t].event=7
 for t in range(19,51):moves[5][t].hidden=true
 for t in range(91,251):moves[5][t].hidden=true
 moves[5][251].cue=35
 for cue in SOUND_NAMES:sounds[cue]=stream_for("finale_"+cue)
 for cue in ["wind_loop","fire_loop","core_loop"]:
  var stream:AudioStreamWAV=sounds[cue].duplicate();stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_begin=0;stream.loop_end=roundi(stream.get_length()*stream.mix_rate);loops[cue]=stream
  if cue=="wind_loop":stream.loop_begin=56 # Source ADPCM frame 1 at the recovered pitch.
 var effects=load("res://assets/models/enemies/recovered_monsters/dark_lumina_3_effects.glb").instantiate()
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIR+"dark_lumina_3_effects_motion.json"))
 for group in source.groups:
  if group.name=="arena":continue
  var node:MeshInstance3D=effects.find_child(source.parts[group.nodes[0]-1].name,true,false)
  meshes[group.name]=morph_mesh(node.mesh,group.name) if group.name in ["wind","wind_outer","core","core_open"] else node.mesh
 effects.free()
 var sprites:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FX_DIR+"sources.json")).sprites
 for key in sprites:
  var mesh=QuadMesh.new();mesh.size=Vector2(sprites[key].width,sprites[key].height)*.018*SCALE*float(sprites[key].get("display_scale",1))*float(EFFECT_SCALE.get(key,1))
  if key=="fire":mesh.size.x*=1.5
  if key in ["fire","water"]:mesh.center_offset=Vector3(0,mesh.size.y*.5,0)
  var material=ShaderMaterial.new();material.shader=preload("res://assets/characters/recovered_skullpion/effects/volley.gdshader")
  material.set_shader_parameter("atlas",load(FX_DIR+key+".png"));material.set_shader_parameter("frames",float(sprites[key].frames));material.set_shader_parameter("playback_fps",30.0/float(sprites[key].get("hold_ticks",1)));material.set_shader_parameter("billboard",key!="sword_cross");material.set_shader_parameter("instanced",true);mesh.material=material;meshes[key]=mesh
  material.set_shader_parameter("frame_loop",key=="fire");material.set_shader_parameter("instance_alpha",true);material.set_shader_parameter("opacity_scale",1.0)
  # The recovered crescent's convex +Y rim leads along projectile +Z.
  if key=="sword_cross":meshes[key]=transform_mesh(mesh,Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3.ZERO))
 for key in source.groups:
  if key.name not in ["arena","wind","wind_outer","core","core_open"]:meshes[key.name]=transform_mesh(meshes[key.name],Transform3D(Basis(Vector3.UP,PI).scaled(Vector3.ONE*.018*SCALE*float(EFFECT_SCALE.get(key.name,1))),Vector3.ZERO))
 # Source tpages 186/41/59 use additive ABR 1, which GLB cannot encode.
 for key in ["sword_wave","core_rays"]:
  for surface in meshes[key].get_surface_count():
   var material:BaseMaterial3D=meshes[key].surface_get_material(surface).duplicate()
   material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
   meshes[key].surface_set_material(surface,material)
 # Actor 801AC47C scales the aura 3/4/3 and rotates its 16-entry CLUT by four.
 meshes.cast_aura=transform_mesh(meshes.cast_aura,Transform3D(Basis.from_scale(Vector3(3,4,3)),Vector3.ZERO))
 for surface in meshes.cast_aura.get_surface_count():
  var material=ShaderMaterial.new();material.shader=preload("res://assets/characters/recovered_skullpion/effects/volley.gdshader")
  material.set_shader_parameter("atlas",load(FX_DIR+"cast_aura_cycle.png"));material.set_shader_parameter("frames",4.0);material.set_shader_parameter("instanced",true);material.set_shader_parameter("opacity_scale",1.0)
  meshes.cast_aura.surface_set_material(surface,material)
 for surface in meshes.burst.get_surface_count():
  var material=ShaderMaterial.new();material.shader=preload("res://assets/characters/recovered_monsters/dark_lumina_2_effects/energy_mesh.gdshader")
  meshes.burst.surface_set_material(surface,material)
 meshes.water_secondary=meshes.water.duplicate();meshes.water_secondary.material=meshes.water.material.duplicate()
 meshes.water_secondary.material.set_shader_parameter("playback_fps",30.0)
 # Earth landing 801A12C0 calls shared actor 0x352, the same recovered DL2 wave.
 var dark=preload("res://scripts/forest/dark_lumina_kit.gd");dark.prepare()
 meshes.blast=dark.meshes.stomp_wave;blast_radius=1056.0
 meshes.wind_gust=meshes.wind_outer.duplicate()
 for surface in meshes.wind_gust.get_surface_count():
  var material=meshes.wind_gust.surface_get_material(surface).duplicate();material.set_shader_parameter("pose_start_tick",70.0);meshes.wind_gust.surface_set_material(surface,material)
 # Actor 801AE138 adds transparency at runtime; the source mesh alone is opaque.
 for surface in meshes.ending.get_surface_count():
  var material:BaseMaterial3D=meshes.ending.surface_get_material(surface).duplicate()
  material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  meshes.ending.surface_set_material(surface,material)
 var copy_resource=load(DIR+"dark_lumina_3_sky_copy_runtime.res")
 var copy_mesh:ArrayMesh=preload("res://scripts/forest/forest_thirstquencher_visual.gd").make_mesh(-1,false,copy_resource)
 for surface in copy_mesh.get_surface_count():
  var material=copy_mesh.surface_get_material(surface)
  material.set_shader_parameter("effect_pose_start",0);material.set_shader_parameter("effect_pose_count",2);material.set_shader_parameter("role_size",SCALE)
  copy_mesh.surface_set_material(surface,material)
 meshes.sky_copy=copy_mesh
 var copy_bounds:AABB=copy_resource.get_meta("bounds");copy_mesh.custom_aabb=AABB(copy_bounds.position*SCALE,copy_bounds.size*SCALE)
 shots={0:meshes.sword_wave,1:meshes.wind_gust,2:meshes.water_fall,3:meshes.fire,4:meshes.blast,5:meshes.sky_copy}

static func transform_mesh(source:Mesh,matrix:Transform3D,result:ArrayMesh=null)->ArrayMesh:
 if result==null:result=ArrayMesh.new()
 for surface in source.get_surface_count():
  var arrays=source.surface_get_arrays(surface)
  var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL]!=null else PackedVector3Array()
  for i in points.size():
   points[i]=matrix*points[i]
   if not normals.is_empty():normals[i]=(matrix.basis*normals[i]).normalized()
  arrays[Mesh.ARRAY_VERTEX]=points
  if not normals.is_empty():arrays[Mesh.ARRAY_NORMAL]=normals
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  result.surface_set_material(result.get_surface_count()-1,source.surface_get_material(surface))
 return result
static func shot_mesh(kind:int)->Mesh:return shots[kind]

static func frame(move:int,tick:int)->Dictionary:return moves[move][clampi(tick,0,moves[move].size()-1)]
static func native()->Dictionary:
 prepare()
 var meta=PackedInt32Array();var frames=PackedFloat32Array()
 for move in moves:
  meta.append_array(PackedInt32Array([frames.size()/5,move.size()]))
  for f in move:frames.append_array(PackedFloat32Array([f.row,f.event,f.speed,1 if f.hidden else 0,f.cue]))
 var shots=PackedFloat64Array()
 for i in 6:shots.append_array(PackedFloat64Array([SHOT_SPEED[i],SHOT_LIFE[i],SHOT_RADIUS[i],DAMAGE[i]]))
 return {"finale_meta":meta,"finale_frames":frames,"finale_shots":shots,"finale_scale":SCALE,"finale_ranges":PackedFloat64Array([FALL_SPREAD[0],FALL_SPREAD[1],FALL_HEIGHT,WATER_BURST_LIFE])}

static func morph_mesh(source:ArrayMesh,group:String)->ArrayMesh:
 var result=ArrayMesh.new()
 var count=316 if group in ["wind","wind_outer"] else 40 if group=="core" else 32
 for surface in source.get_surface_count():
  var arrays=source.surface_get_arrays(surface);var shapes=source.surface_get_blend_shape_arrays(surface)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var uv2=PackedVector2Array();uv2.resize(vertices.size())
  var image=Image.create(vertices.size(),count,false,Image.FORMAT_RGBAF)
  for tick in count:
   var start=0;var end=1;var weight=0.0
   if group in ["wind","wind_outer"]:
    if tick<22:weight=0
    elif tick<26:weight=(tick-22)/4.0
    elif tick<47:weight=1
    elif tick<50:start=2;end=3;weight=(tick-47)/3.0
    elif tick<60:start=2;end=3;weight=1
    elif tick<70:start=4;end=5;weight=(tick-60)/10.0
    else:
     var phase=(tick-70)%18;start=6+floori(phase/3.0)*2;end=start+1;weight=(phase%3)/3.0
   elif group=="core":start=mini(floori(tick/8.0),4)*2;end=start+1;weight=(tick%8)/8.0
   else:weight=tick/31.0
   for vertex in vertices.size():
    # Godot imports normalized GLB shape keys as absolute authored positions.
    var point:Vector3=shapes[start][Mesh.ARRAY_VERTEX][vertex].lerp(shapes[end][Mesh.ARRAY_VERTEX][vertex],weight)
    point=Basis(Vector3.UP,PI)*(point*.018*SCALE)
    image.set_pixel(vertex,tick,Color(point.x,point.y,point.z,1));uv2[vertex]=Vector2(vertex,0)
  arrays[Mesh.ARRAY_TEX_UV2]=uv2
  var material=ShaderMaterial.new();material.shader=preload("res://assets/characters/recovered_monsters/dark_lumina_3_effects/morph.gdshader")
  if group=="wind":
   var shader=Shader.new();shader.code=material.shader.code.replace("blend_add","blend_mix");material.shader=shader
  material.set_shader_parameter("pose_texture",ImageTexture.create_from_image(image));material.set_shader_parameter("pose_count",count)
  var original:BaseMaterial3D=source.surface_get_material(surface)
  material.set_shader_parameter("tint",original.albedo_color)
  if original.albedo_texture!=null:material.set_shader_parameter("paint_texture",original.albedo_texture);material.set_shader_parameter("textured",true)
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);result.surface_set_material(result.get_surface_count()-1,material)
 result.custom_aabb=AABB(Vector3(-20,-20,-20)*SCALE,Vector3.ONE*40*SCALE)
 return result
