@static_unload
extends RefCounted
## Prepared indexed pixels and one camera-facing mesh shared by the native batches.
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const ROOT="res://assets/characters/crossgate/hounds/"
const Dimensions=preload("res://scripts/forest/crowd/pet_dimensions.gd")
const SUMMON_SOUND=preload("res://assets/audio/crossgate/hounds/cgbtl03.wav")
const RECALL_SOUND=preload("res://assets/audio/crossgate/hounds/cgbtl04.wav")
const SUMMON_PIXEL_SIZE=Roles.HOUND_PIXEL_SIZE*Roles.HOUND_SCALE
const SUMMON_CENTER=Vector2(.5,140)*SUMMON_PIXEL_SIZE
const SUMMON_LIFE=51.0/60.0
const SOUNDS={
 101:preload("res://assets/audio/crossgate/hounds/cgply00a.wav"),
 131:preload("res://assets/audio/crossgate/kazi/cgply10a.wav"),
 132:preload("res://assets/audio/crossgate/kazi/cgply10b.wav"),
 176:preload("res://assets/audio/crossgate/hounds/cgmon03a.wav"),
 264:preload("res://assets/audio/crossgate/kazi/cgefc13.wav"),
 267:preload("res://assets/audio/crossgate/hounds/cgefc16.wav"),
 288:preload("res://assets/audio/crossgate/hounds/cgefc37a.wav"),
 289:preload("res://assets/audio/crossgate/hounds/cgefc37b.wav"),
 290:preload("res://assets/audio/crossgate/hounds/cgefc37c.wav"),
}
static var manifest:Dictionary={}
static var meshes:Dictionary={}
static func apply_world_scale(node:MultiMeshInstance3D,model:RefCounted)->void:
 var mesh=node.multimesh.mesh
 if not mesh is QuadMesh or not mesh.material is ShaderMaterial:return
 if mesh.material.shader not in [preload("res://assets/materials/hound_crowd.gdshader"),preload("res://assets/materials/hound_afterimage.gdshader")]:return
 # Per-batch sizing keeps shared sprite materials and the survival arena unchanged.
 node.set_instance_shader_parameter("use_world_pet_sizes",Dimensions.exploring(model))
static func motions()->Dictionary:
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motions.json"))
 return manifest
static func timelines()->PackedFloat32Array:return PackedFloat32Array(motions().timelines)
static func summon_mesh()->QuadMesh:
 var material=ShaderMaterial.new()
 material.shader=preload("res://assets/characters/recovered_skullpion/effects/volley.gdshader")
 material.set_shader_parameter("atlas",preload("res://assets/characters/crossgate/hounds/summon.png"))
 material.set_shader_parameter("frames",7.0)
 material.set_shader_parameter("playback_fps",20.0)
 material.set_shader_parameter("instanced",true)
 material.set_shader_parameter("instance_alpha",true)
 material.set_shader_parameter("opacity_scale",1.0)
 var mesh=QuadMesh.new()
 mesh.size=Vector2(223,302)*SUMMON_PIXEL_SIZE
 mesh.material=material
 return mesh

static func make_mesh(root:String=ROOT,data:Dictionary={},size:float=Roles.HOUND_SCALE,pixel_size:float=Roles.HOUND_PIXEL_SIZE)->QuadMesh:
 if meshes.has(root):return meshes[root]
 if data.is_empty():data=motions()
 var images:Array[Image]=[]
 if data.has("skin_pages"):images.append(Image.create(2048,2048,false,Image.FORMAT_R8))
 else:
  for page in int(data.pages):
   var image:Image=load(data.atlas_paths[page] if data.has("atlas_paths") else root+"atlas-%d.png"%page).get_image()
   image.convert(Image.FORMAT_R8);images.append(image)
 var pixels=Texture2DArray.new()
 var error=pixels.create_from_images(images)
 assert(error==OK,"Cannot create the Cross Gate sprite atlas")
 var bytes=FileAccess.get_file_as_bytes(root+"frames.bin")
 var width=int(data.table_width)
 var lookup=ImageTexture.create_from_image(Image.create_from_data(width,bytes.size()/(width*16),false,Image.FORMAT_RGBAF,bytes))
 var material=ShaderMaterial.new()
 material.shader=preload("res://assets/materials/hound_crowd.gdshader")
 material.set_shader_parameter("enemy_size",size)
 material.set_shader_parameter("pet_scales",Dimensions.scales(root,data))
 material.set_shader_parameter("companion_pet_sizes",root.trim_suffix("/").get_file()=="guard_pets")
 material.set_shader_parameter("pixel_size",pixel_size)
 material.set_shader_parameter("clip_rows",int(data.clip_count))
 var actions:Array=data.get("actions",[0,3,5,8,10,1])
 material.set_shader_parameter("actions_per_skin",actions.size())
 material.set_shader_parameter("guard_clip",maxi(0,actions.find(9)))
 var guards:Dictionary=data.get("snow_guards",{})
 if guards.size()==2:
  var skins=PackedInt32Array()
  var holds=PackedInt32Array()
  for id in guards:
   skins.append(int(id))
   holds.append_array(PackedInt32Array(guards[id]))
  material.set_shader_parameter("snow_guard_skins",skins)
  material.set_shader_parameter("snow_guard_frames",holds)
  material.set_shader_parameter("has_snow_guards",true)
 material.set_shader_parameter("pixels",pixels);material.set_shader_parameter("frames",lookup)
 material.set_shader_parameter("palette",load(root+"palette.png"))
 var mesh=QuadMesh.new();mesh.material=material;meshes[root]=mesh
 if data.has("skin_pages"):mesh.set_meta("source_table",bytes)
 return mesh

static func prepare_pages(root:String,data:Dictionary,pages:Array)->void:
 var mesh:QuadMesh=meshes[root]
 pages.sort()
 if mesh.has_meta("prepared_pages") and mesh.get_meta("prepared_pages")==pages:return
 var images:Array[Image]=[Image.create(2048,2048,false,Image.FORMAT_R8)]
 var mapping=PackedInt32Array();mapping.resize(data.pages)
 for page in pages:
  var image:Image=load(data.atlas_paths[page]).get_image();image.convert(Image.FORMAT_R8)
  mapping[page]=images.size();images.append(image)
 var pixels=Texture2DArray.new()
 assert(pixels.create_from_images(images)==OK,"Cannot prepare the selected pet atlas pages")
 var source:PackedByteArray=mesh.get_meta("source_table")
 var table=source.duplicate()
 for frame in int(data.frame_count):
  var offset=(int(data.clip_count)+frame*2+1)*16+8
  table.encode_float(offset,float(mapping[int(source.decode_float(offset))]))
 var width=int(data.table_width)
 var lookup=ImageTexture.create_from_image(Image.create_from_data(width,table.size()/(width*16),false,Image.FORMAT_RGBAF,table))
 mesh.material.set_shader_parameter("pixels",pixels);mesh.material.set_shader_parameter("frames",lookup)
 mesh.set_meta("prepared_pages",pages.duplicate())
