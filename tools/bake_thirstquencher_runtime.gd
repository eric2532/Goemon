extends SceneTree
## Bake STEP source poses once. Runtime crowds use shared GPU palettes, with
## no per-enemy AnimationPlayer, Skeleton3D, or repeated terrain fitting.
const DIR="res://assets/characters/thirstquencher/"
const SCALE=5.4
var texture_cache={}
func _initialize():run.call_deferred()
func blank_arrays()->Array:
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array();arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array()
 arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array();arrays[Mesh.ARRAY_TEX_UV2]=PackedVector2Array()
 arrays[Mesh.ARRAY_COLOR]=PackedColorArray();arrays[Mesh.ARRAY_INDEX]=PackedInt32Array()
 return arrays
func private_texture(source:Texture2D)->Texture2D:
 if source==null:return null
 var id=source.get_instance_id()
 if not texture_cache.has(id):
  var pixels=source.get_image()
  if pixels.is_compressed():pixels.decompress()
  pixels.generate_mipmaps();texture_cache[id]=ImageTexture.create_from_image(pixels)
 return texture_cache[id]
func run():
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIR+"manifest.json"))
 for variant in manifest.variants:await bake(variant)
 print("THIRSTQUENCHER_BAKE_COMPLETE");quit()
func bake(variant:Dictionary):
 var scene=load(variant.glb).instantiate();root.add_child(scene)
 var skeleton:Skeleton3D=scene.find_child("Skeleton3D",true,false)
 var player:AnimationPlayer=scene.find_child("AnimationPlayer",true,false)
 player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 var grouped={};var originals={};var part_bounds=[]
 part_bounds.resize(11)
 for mesh in scene.find_children("*","MeshInstance3D",true,false):
  var part=String(mesh.name).substr(5,2).to_int()
  assert(mesh.global_transform.is_equal_approx(Transform3D.IDENTITY),"Unexpected source mesh transform")
  for slot in mesh.mesh.get_surface_count():
   var original=mesh.get_active_material(slot) as StandardMaterial3D
   assert(original!=null)
   var key=original.get_instance_id()
   if not grouped.has(key):
    grouped[key]=blank_arrays();var copy=original.duplicate()
    copy.albedo_texture=private_texture(original.albedo_texture);copy.emission_texture=private_texture(original.emission_texture)
    originals[key]=copy
   var dst:Array=grouped[key];var src:Array=mesh.mesh.surface_get_arrays(slot)
   var offset:int=dst[Mesh.ARRAY_VERTEX].size()
   var vertices:PackedVector3Array=src[Mesh.ARRAY_VERTEX];var normals=src[Mesh.ARRAY_NORMAL]
   var weights:PackedFloat32Array=src[Mesh.ARRAY_WEIGHTS];var bones:PackedInt32Array=src[Mesh.ARRAY_BONES]
   var stride=weights.size()/vertices.size()
   for index in vertices.size():
    var binding=bones[index*stride]
    assert(is_equal_approx(weights[index*stride],1.0),"Source part must remain rigid")
    var bind_name=String(mesh.skin.get_bind_name(binding))
    var bone=skeleton.find_bone(bind_name) if not bind_name.is_empty() else mesh.skin.get_bind_bone(binding)
    assert(skeleton.get_bone_name(bone)=="Part_%02d"%part)
    var inverse_bind:Transform3D=mesh.skin.get_bind_pose(binding)
    var vertex=inverse_bind*vertices[index]
    dst[Mesh.ARRAY_VERTEX].append(vertex)
    dst[Mesh.ARRAY_NORMAL].append((inverse_bind.basis.inverse().transposed()*normals[index]).normalized())
    dst[Mesh.ARRAY_TEX_UV].append(src[Mesh.ARRAY_TEX_UV][index] if src[Mesh.ARRAY_TEX_UV]!=null else Vector2.ZERO)
    dst[Mesh.ARRAY_TEX_UV2].append(Vector2(part,0))
    dst[Mesh.ARRAY_COLOR].append(src[Mesh.ARRAY_COLOR][index] if src[Mesh.ARRAY_COLOR]!=null else Color.WHITE)
    part_bounds[part]=AABB(vertex,Vector3.ZERO) if part_bounds[part]==null else part_bounds[part].expand(vertex)
   var indices=src[Mesh.ARRAY_INDEX]
   if indices!=null and not indices.is_empty():
    for index in indices:dst[Mesh.ARRAY_INDEX].append(offset+index)
   else:
    for index in vertices.size():dst[Mesh.ARRAY_INDEX].append(offset+index)
 var merged=ArrayMesh.new()
 for key in grouped:
  merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,grouped[key]);merged.surface_set_material(merged.get_surface_count()-1,originals[key])
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(variant.motion_sources))
 var rows={};var poses:Array[Transform3D]=[];var clips={};var bounds=AABB();var first=true
 var convert=Transform3D(Basis(Vector3.UP,PI).scaled(Vector3.ONE*SCALE),Vector3.ZERO)
 for clip in source.clips:
  var timeline=PackedInt32Array();timeline.resize(int(clip.ticks))
  player.play(clip.name)
  for frame in clip.frames:
   if not rows.has(frame.pose):
    player.seek(float(frame.tick)/30.0,true);skeleton.force_update_all_bone_transforms()
    rows[frame.pose]=rows.size()
    for part in 11:
     var matrix=convert*skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("Part_%02d"%part))
     poses.append(matrix)
     var box:AABB=matrix*part_bounds[part];bounds=box if first else bounds.merge(box);first=false
   for tick in range(int(frame.tick),mini(int(clip.ticks),int(frame.tick)+int(frame.hold_ticks))):timeline[tick]=rows[frame.pose]
  clips[clip.name]={"rows":timeline,"ticks":int(clip.ticks),"loop":clip.terminal=="loop"}
 var image=Image.create(33,rows.size(),false,Image.FORMAT_RGBAF)
 for row in rows.size():
  for part in 11:
   var matrix:Transform3D=poses[row*11+part]
   for axis in 3:
    var column=matrix.basis[axis];image.set_pixel(part*3+axis,row,Color(column.x,column.y,column.z,matrix.origin[axis]))
 var data=Resource.new();data.resource_name=variant.name
 data.set_meta("schema",1);data.set_meta("variant_id",int(variant.id));data.set_meta("part_count",11)
 data.set_meta("mesh",merged);data.set_meta("poses",poses);data.set_meta("pose_texture",ImageTexture.create_from_image(image))
 data.set_meta("clips",clips);data.set_meta("semantics",variant.semantics);data.set_meta("bounds",bounds)
 data.set_meta("part_bounds",part_bounds);data.set_meta("source_sha256",manifest_sha());data.set_meta("scale",SCALE)
 var output=DIR+"soldier_%d_runtime.res"%int(variant.id)
 assert(ResourceSaver.save(data,output,ResourceSaver.FLAG_COMPRESS)==OK)
 print("SOLDIER_BAKE variant=",variant.id," parts=11 clips=",clips.size()," poses=",rows.size()," surfaces=",merged.get_surface_count()," bounds=",bounds)
 scene.queue_free();await process_frame
func manifest_sha()->String:
 return FileAccess.get_sha256(DIR+"manifest.json")
