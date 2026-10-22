class_name RecoveredSasukeBody
extends RefCounted
## Original ROM rigid body; vertices remain in native coordinates. The parent
## owns every part's world pose and a single uniform normalization transform.
const ROOT := "res://assets/characters/recovered_sasuke/body/"
const HEAD_POINTER := "0x9004aa8"
const GOLD_SHADER := preload("res://assets/characters/recovered_sasuke/body/gold_kunai_linear.gdshader")
const TILE_SHADER := preload("res://assets/characters/recovered_sasuke/body/native_tile.gdshader")
static var _data: Dictionary = {}
static var _textures: Dictionary = {}

static func data() -> Dictionary:
 if _data.is_empty():
  var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "body.json"))
  if parsed is Dictionary:
   _data = parsed
 return _data

static func create_parts() -> Dictionary:
 var result: Dictionary = {}
 var source: Dictionary = data().get("parts", {})
 for pointer: String in source:
  var wrapper := Node3D.new()
  wrapper.name = "OriginalPart_" + pointer
  wrapper.set_meta("rom_display_list", pointer)
  var normal := _create_mesh(source[pointer])
  normal.name = "normal" if pointer == HEAD_POINTER else "mesh"
  wrapper.add_child(normal)
  result[pointer] = wrapper
 set_face(result, 0, 0.0)
 return result

static func set_face(parts: Dictionary, action_id: int, seconds: float) -> void:
 var head: Node3D = parts.get(HEAD_POINTER) as Node3D
 if not is_instance_valid(head):
  return
 var face: Dictionary = data().get("face", {})
 var action: Dictionary = face.get("actions", {}).get(str(action_id), {})
 if action.is_empty():
  return
 var frames: Array = action.get("frames", [])
 if frames.is_empty():
  return
 var frame := clampi(int(floor(seconds * 30.0 * float(action.get("rate", 1.0)))), 0, frames.size() - 1)
 var pair: Array = frames[frame]
 var key := String(pair[0]) + "/" + String(pair[1])
 if head.get_meta("native_face_pair", "") == key:
  return
 for mesh_node in head.get_children():
  if not mesh_node is MeshInstance3D:
   continue
  for surface in range(mesh_node.mesh.get_surface_count()):
   var material := mesh_node.mesh.surface_get_material(surface) as ShaderMaterial
   if material == null or not material.has_meta("native_face_channel"):
    continue
   var channel: int = material.get_meta("native_face_channel")
   var image: Dictionary = face.get("textures", {}).get(pair[channel], {})
   if not image.is_empty():
    material.set_shader_parameter("source_texture", _texture(image["file"]))
 head.set_meta("native_face_pair", key)

static func _texture(texture_file: String) -> Texture2D:
 if not _textures.has(texture_file):
  _textures[texture_file] = load(ROOT + texture_file) as Texture2D
 return _textures[texture_file]

static func _create_mesh(part: Dictionary) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 var mesh := ArrayMesh.new()
 var vertices: Array = part.get("vertices", [])
 for surface: Dictionary in part.get("surfaces", []):
  var positions := PackedVector3Array()
  var normals := PackedVector3Array()
  var uvs := PackedVector2Array()
  var colors := PackedColorArray()
  var size: Array = surface.get("texture_size", [32, 32])
  var scale_: Array = surface.get("uv_scale", [0.5, 0.5])
  var lit: bool = surface.get("lit", true)
  for face: Array in surface.get("faces", []):
   for index: int in face:
    var v: Dictionary = vertices[index]
    var p: Array = v["position"]
    var n: Array = v["normal"]
    var st: Array = v["uv_raw"]
    var rgba: Array = v["rgba"]
    positions.append(Vector3(p[0], p[1], p[2]))
    normals.append(Vector3(n[0], n[1], n[2]).normalized())
    uvs.append(Vector2(float(st[0]) * float(scale_[0]) / 32.0 / float(size[0]), float(st[1]) * float(scale_[1]) / 32.0 / float(size[1])))
    colors.append(Color(1.0, 1.0, 1.0, float(rgba[3]) / 255.0) if lit else Color(float(rgba[0]) / 255.0, float(rgba[1]) / 255.0, float(rgba[2]) / 255.0, float(rgba[3]) / 255.0))
  var arrays: Array = []
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX] = positions
  arrays[Mesh.ARRAY_NORMAL] = normals
  arrays[Mesh.ARRAY_TEX_UV] = uvs
  arrays[Mesh.ARRAY_COLOR] = colors
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
  var material := ShaderMaterial.new()
  material.shader = TILE_SHADER
  var texture_file: String = surface.get("texture_file", "")
  material.set_shader_parameter("use_texture", not texture_file.is_empty())
  if not texture_file.is_empty():material.set_shader_parameter("source_texture", _texture(texture_file))
  material.set_shader_parameter("source_size", Vector2(size[0], size[1]))
  var tile: Dictionary = surface.get("tile", {})
  material.set_shader_parameter("tile_modes", Vector2(tile.get("s_mode", 2), tile.get("t_mode", 2)))
  var mask_s: int = tile.get("s_mask", 0)
  var mask_t: int = tile.get("t_mask", 0)
  material.set_shader_parameter("mask_period", Vector2(1 << mask_s if mask_s > 0 else 0, 1 << mask_t if mask_t > 0 else 0))
  var shift_s: int = tile.get("s_shift", 0)
  var shift_t: int = tile.get("t_shift", 0)
  material.set_shader_parameter("tile_shift", Vector2(pow(2.0, -shift_s if shift_s < 11 else 16 - shift_s), pow(2.0, -shift_t if shift_t < 11 else 16 - shift_t)))
  var origin: Array = tile.get("origin", [0, 0])
  material.set_shader_parameter("tile_origin", Vector2(origin[0], origin[1]))
  var texture_pointer: String = surface.get("texture_pointer", "")
  if texture_pointer == "0xb000000" or texture_pointer == "0xc000000":
   material.set_meta("native_face_channel", 0 if texture_pointer == "0xb000000" else 1)
  material.set_meta("rom_primitive_color", surface.get("primitive_color", []))
  material.set_meta("rom_ambient_color", surface.get("ambient_color", []))
  material.set_meta("rom_combine_words", surface.get("combine_words", []))
  if surface.get("texture_coordinate_mode", "") == "n64_generated_linear":
   material.shader = GOLD_SHADER
   material.set_shader_parameter("source_texture_scale", Vector2(scale_[0], scale_[1]))
   material.set_shader_parameter("source_texture_size", Vector2(size[0], size[1]))
  mesh.surface_set_material(mesh.get_surface_count() - 1, material)
 node.mesh = mesh
 return node

static func create_projectile(kind: String, source_scale: float) -> Node3D:
 var root := Node3D.new()
 var projectile: Dictionary = data().get("projectiles", {}).get("ice" if kind in ["ice", "hail", "charged_ice"] else "bomb", {})
 for pointer: String in projectile.get("parts", {}):
  var node := _create_mesh(data().parts[pointer])
  var v: Array = projectile.parts[pointer]
  node.transform = Transform3D(Basis(Vector3(v[0],v[1],v[2]),Vector3(v[3],v[4],v[5]),Vector3(v[6],v[7],v[8])).scaled(Vector3.ONE * source_scale),Vector3(v[9],v[10],v[11]) * source_scale)
  root.add_child(node)
 return root
