extends SceneTree
## Rigid enemy GLBs use the same shared GPU pose format as ordinary soldiers.
const DIR="res://assets/characters/recovered_monsters/"
const SCALE=1.8
func _initialize():run.call_deferred()
func run():
 var names=OS.get_cmdline_user_args()
 if names.is_empty():names=PackedStringArray(preload("res://scripts/forest/forest_enemy_roles.gd").RECOVERED.values())
 for name_ in names:
  assert(FileAccess.file_exists(DIR+name_+"_motion.json"),"Unknown recovered asset")
  await bake(name_)
 print("RECOVERED_MONSTER_BAKE_COMPLETE");quit()
func bake(name_:String):
 var input_dir="res://assets/models/enemies/recovered_monsters/" if FileAccess.file_exists("res://assets/models/enemies/recovered_monsters/"+name_+".glb") else DIR
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(input_dir+name_+"_motion.json"))
 var scene=load(input_dir+name_+".glb").instantiate();root.add_child(scene)
 var player:AnimationPlayer=scene.find_child("AnimationPlayer",true,false)
 player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 var count:int=source.parts.size();var parts=[];parts.resize(count)
 var mesh=ArrayMesh.new();var part_bounds=[];part_bounds.resize(count)
 for instance:MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
  var part=String(instance.name).trim_prefix("Part_").to_int();parts[part]=instance
  for surface in instance.mesh.get_surface_count():
   var arrays=instance.mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var uv2=PackedVector2Array();uv2.resize(vertices.size());uv2.fill(Vector2(part,0));arrays[Mesh.ARRAY_TEX_UV2]=uv2
   for vertex in vertices:part_bounds[part]=AABB(vertex,Vector3.ZERO) if part_bounds[part]==null else part_bounds[part].expand(vertex)
   mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   mesh.surface_set_material(mesh.get_surface_count()-1,instance.get_active_material(surface))
 var poses:Array[Transform3D]=[];var rows={};var clips={};var bounds=AABB();var first=true
 var convert=Transform3D(Basis(Vector3.UP,PI).scaled(Vector3.ONE*SCALE),Vector3.ZERO)
 for clip in source.clips:
  var timeline=PackedInt32Array();timeline.resize(int(clip.ticks));player.play(clip.name)
  for frame in clip.frames:
   if not rows.has(frame.pose):
    # Float32 glTF key times can sit a few nanoseconds after the nominal tick.
    player.seek(float(frame.tick)/30+.00001,true)
    rows[frame.pose]=rows.size()
    for part in count:
     assert(parts[part]!=null,"Missing original rigid part")
     var matrix:Transform3D=convert*parts[part].global_transform;poses.append(matrix)
     var box:AABB=matrix*part_bounds[part];bounds=box if first else bounds.merge(box);first=false
   for tick in range(int(frame.tick),mini(int(clip.ticks),int(frame.tick)+maxi(1,int(frame.hold)))):timeline[tick]=rows[frame.pose]
  clips[clip.name]={"rows":timeline,"ticks":int(clip.ticks),"loop":clip.terminal=="loop"}
 var pixels=Image.create(count*3,rows.size(),false,Image.FORMAT_RGBAF)
 for row in rows.size():
  for part in count:
   var matrix:Transform3D=poses[row*count+part]
   for axis in 3:
    var column=matrix.basis[axis];pixels.set_pixel(part*3+axis,row,Color(column.x,column.y,column.z,matrix.origin[axis]))
 var data=Resource.new();data.resource_name=name_
 var semantic:Dictionary=source.semantics.duplicate();semantic.run=semantic.walk;semantic.attack=[semantic.attack];semantic.hurt=[semantic.hurt]
 data.set_meta("mesh",mesh);data.set_meta("poses",poses);data.set_meta("part_count",count);data.set_meta("pose_keys",rows)
 data.set_meta("pose_texture",ImageTexture.create_from_image(pixels));data.set_meta("clips",clips);data.set_meta("semantics",semantic)
 data.set_meta("bounds",bounds);data.set_meta("part_bounds",part_bounds);data.set_meta("scale",SCALE)
 data.set_meta("source_path",input_dir+name_+"_motion.json");data.set_meta("visual_path",input_dir+name_+".glb")
 data.set_meta("source_sha256",FileAccess.get_sha256(input_dir+name_+"_motion.json"));data.set_meta("visual_sha256",FileAccess.get_sha256(input_dir+name_+".glb"))
 assert(ResourceSaver.save(data,DIR+name_+"_runtime.res",ResourceSaver.FLAG_COMPRESS)==OK)
 print("MONSTER_BAKE ",name_," parts=",count," clips=",clips.size()," poses=",rows.size()," surfaces=",mesh.get_surface_count()," bounds=",bounds)
 scene.queue_free();await process_frame
