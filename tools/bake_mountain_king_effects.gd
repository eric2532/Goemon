extends SceneTree
const ROOT="res://assets/characters/warcraft/mountain-king/effects/"
const INPUT="res://build/Other Files/Asset Toolkit/Mountain King/"
var materials={}
func _initialize():
 for key in ["bolt","clap","avatar","stun","bash","slow","body"]:
  var data=JSON.parse_string(FileAccess.get_file_as_string(INPUT+key+"-frames.json"))
  var resource=Resource.new();var clips={}
  for clip in data.clips:
   var frames:Array[ArrayMesh]=[]
   for frame in data.clips[clip].frames:
    var mesh=ArrayMesh.new()
    for s in frame:
     var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
     var vertices=PackedVector3Array();var uv=PackedVector2Array();var indices=PackedInt32Array();var colors=PackedColorArray()
     for i in range(0,s.vertices.size(),3):vertices.append(Vector3(s.vertices[i],s.vertices[i+2],-s.vertices[i+1]))
     for i in range(0,s.uv.size(),2):uv.append(Vector2(s.uv[i],s.uv[i+1]))
     for i in range(0,s.indices.size(),3):indices.append_array(PackedInt32Array([s.indices[i],s.indices[i+2],s.indices[i+1]]))
     if s.has("colors"):
      for i in range(0,s.colors.size(),4):colors.append(Color(s.colors[i],s.colors[i+1],s.colors[i+2],s.colors[i+3]))
     else:colors.resize(vertices.size());colors.fill(Color(s.color[0],s.color[1],s.color[2],s.color[3]))
     if int(s.mode) in [3,4]:
      for i in colors.size():
       var brightness=maxf(colors[i].r,maxf(colors[i].g,colors[i].b))
       colors[i]=Color(brightness,brightness,brightness,colors[i].a)
     arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices;arrays[Mesh.ARRAY_COLOR]=colors
     mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
     var id=s.texture+str(s.mode)
     if not materials.has(id):
      var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
      mat.vertex_color_use_as_albedo=true;mat.albedo_texture=load(ROOT+s.texture);mat.disable_fog=true
      mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
      if int(s.mode) in [3,4]:
       mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
      # The hammer's opaque team layer must match the already-blue spell energy.
      if int(s.mode) in [3,4] or s.texture.ends_with("-TeamColor00.png"):
       mat.albedo_texture=preload("res://scripts/warcraft_effects.gd").energy_texture(mat.albedo_texture);mat.albedo_color=Color("278dff")
      elif int(s.mode)==5:mat.blend_mode=BaseMaterial3D.BLEND_MODE_MUL
      materials[id]=mat
     mesh.surface_set_material(mesh.get_surface_count()-1,materials[id])
    frames.append(mesh)
   clips[clip]={"duration":data.clips[clip].duration,"frames":frames}
  resource.set_meta("clips",clips)
  resource.set_meta("source_sha256",FileAccess.get_sha256(INPUT+key+"-frames.json"))
  assert(ResourceSaver.save(resource,ROOT+key+".res",ResourceSaver.FLAG_COMPRESS)==OK)
  print("MOUNTAIN_EFFECT_BAKED ",key)
 quit()
