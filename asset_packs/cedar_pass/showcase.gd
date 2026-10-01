extends Node3D
var camera: Camera3D
var focus := Vector3(40, 0, -25)
var angle := 0.3
var elevation := 0.8
var distance := 115.0
var asset_roots := {}
func _ready():
 var data = JSON.parse_string(FileAccess.get_file_as_string("res://manifest.json"))
 var shared = preload("res://shared_matte.tres")
 for i in data.size():
  var entry = data[i]
  var packed = load("res://exports/" + entry.id + ".glb") as PackedScene
  assert(packed != null, entry.id)
  var asset = packed.instantiate()
  add_child(asset)
  asset.position = Vector3((i % 6) * 18, 0, -(i / 6) * 25)
  asset_roots[entry.id] = asset
  for node in asset.find_children("*", "MeshInstance3D", true, false):
   node.material_override = shared
   if entry.category != "tree": node.create_trimesh_collision()
  var label := Label3D.new()
  label.text = entry.id + "\n" + str(entry.triangles) + " tris"
  label.font_size = 32
  label.pixel_size = 0.012
  label.position = asset.position + Vector3(0, 1.0, 6)
  label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
  add_child(label)
 var ground := MeshInstance3D.new()
 var mesh := BoxMesh.new()
 mesh.size = Vector3(125, 0.3, 115)
 ground.mesh = mesh
 ground.position = Vector3(45, -0.2, -33)
 var ground_mat := StandardMaterial3D.new()
 ground_mat.albedo_color = Color("c4c3a3")
 ground.material_override = ground_mat
 add_child(ground)
 ground.create_trimesh_collision()
 var marker := MeshInstance3D.new()
 var capsule := CapsuleMesh.new()
 capsule.height = 1.8
 capsule.radius = 0.3
 marker.mesh = capsule
 marker.position = Vector3(-5, 0.9, 4)
 add_child(marker)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-55,-30,0)
 sun.light_energy = 0.8
 sun.shadow_enabled = true
 add_child(sun)
 var env := WorldEnvironment.new()
 var e := Environment.new()
 e.background_mode = Environment.BG_COLOR
 e.background_color = Color("8eb9c2")
 e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 e.ambient_light_color = Color("cddce8")
 e.ambient_light_energy = 0.3
 env.environment = e
 add_child(env)
 camera = Camera3D.new()
 add_child(camera)
 camera.far = 500
 camera.current = true
 var canvas := CanvasLayer.new()
 add_child(canvas)
 var help := Label.new()
 help.text = "CEDAR PASS  |  22 original environment assets  |  metres, scale 1\nDrag left mouse: orbit   Wheel: zoom   WASD: pan   1: shop   2: tea house   3: overview\nCream capsule beside shop = 1.8 m. Static collision demo; interiors have open doorways."
 help.position = Vector2(24,20)
 canvas.add_child(help)
 _camera_update()
func _camera_update():
 camera.position = focus + Vector3(sin(angle)*cos(elevation),sin(elevation),cos(angle)*cos(elevation))*distance
 camera.look_at(focus)
func _process(delta):
 var move := Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
 focus += move * delta * distance * 0.4
 _camera_update()
func _unhandled_input(event):
 if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
  angle -= event.relative.x * .005
  elevation = clamp(elevation + event.relative.y * .005, .12, 1.45)
 if event is InputEventMouseButton and event.pressed:
  if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = max(8, distance*.9)
  if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = min(220, distance*1.1)
 if event is InputEventKey and event.pressed:
  if event.keycode == KEY_1: focus = Vector3(0,2,0); distance=17
  if event.keycode == KEY_2: focus = Vector3(36,2,0); distance=17
  if event.keycode == KEY_3: focus = Vector3(40,0,-25); distance=115
