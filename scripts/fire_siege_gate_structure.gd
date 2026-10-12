extends Node3D
## Static Japanese barrier. The director alone owns payment and gate health.
var game: Node
var director: Node
var kind: String="gate"
var _generation: int
var completed=false
var walls_built=false
var walls: Node3D
var panel: StaticBody3D
var panel_mesh: MeshInstance3D
var prompt: Label3D
var progress=0.0
var selected=false
var affordable=false
var occupancy_shape=BoxShape3D.new()
func _ready():
 _generation=director.generation;name="ShrineDefenseGate"
 walls=Node3D.new();walls.name="JapaneseSideWalls";add_child(walls)
 panel=StaticBody3D.new();panel.name="EnemyOnlyDoor";panel.collision_layer=0;panel.collision_mask=0;add_child(panel)
 var shape=CollisionShape3D.new();occupancy_shape.size=Vector3(12,4,.6);shape.shape=occupancy_shape;shape.position.y=2;panel.add_child(shape)
 var ink=Geo.mat("408f9e",.15,.12).duplicate();ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;ink.albedo_color.a=.30
 ink.cull_mode=BaseMaterial3D.CULL_DISABLED;ink.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
 panel_mesh=Geo.box(panel,Vector3(0,2,0),Vector3(12,4,.12),ink)
 panel_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;panel_mesh.hide()
 # Foundation has no terrain collider; an unpurchased gate never blocks the route.
 for x in [-6.4,6.4]:Geo.box(self,Vector3(x,.07,0),Vector3(.7,.14,1),Geo.mat("64767b"))
 prompt=Label3D.new();prompt.position=Vector3(0,5.1,0);prompt.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 prompt.font_size=28;prompt.pixel_size=.008;prompt.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(prompt)
 _label()
func _solid(point: Vector3,size_: Vector3,color: String) -> void:
 var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;walls.add_child(body)
 var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size_;collision.shape=box;collision.position=point;body.add_child(collision)
 Geo.box(walls,point,size_,Geo.mat(color))
func _build_walls() -> void:
 for solid in _wall_solids():_solid(solid.point,solid.size,solid.color)
 for side in [-1,1]:
  # Static board seams and a stepped eave give the wall a timber rhythm.
  for i in range(7):Geo.box(walls,Vector3(side*(7+i*1.9),2.3,-.28),Vector3(.08,2.55,.07),Geo.mat("292e36"))
  Geo.box(walls,Vector3(side*13,3.8,0),Vector3(14.6,.25,1.3),Geo.mat("252c43"))
  Geo.box(walls,Vector3(side*13,4,0),Vector3(13.8,.18,.85),Geo.mat("36334e"))
  Geo.box(walls,Vector3(side*6.25,3.3,-.52),Vector3(.10,1.0,.06),Geo.mat("66e3df",0,.7))
 Geo.box(walls,Vector3(0,4.3,0),Vector3(12.4,.22,.75),Geo.mat("88363f"))
 walls_built=true
 if is_instance_valid(game.pursuit):game.pursuit.configure()
func _wall_solids() -> Array:
 var solids=[]
 for side in [-1,1]:
  solids.append({"point":Vector3(side*13,.5,0),"size":Vector3(14,1,.8),"color":"48515b"})
  solids.append({"point":Vector3(side*13,2.3,0),"size":Vector3(14,2.6,.48),"color":"624335"})
  solids.append({"point":Vector3(side*6.25,2,0),"size":Vector3(.5,4,1),"color":"802f34"})
  solids.append({"point":Vector3(side*19.7,2,0),"size":Vector3(.6,4,.8),"color":"802f34"})
 solids.append({"point":Vector3(0,4.05,0),"size":Vector3(13.4,.32,1.5),"color":"262b44"})
 return solids
func can_complete_build() -> bool:
 if _generation!=director.generation:return false
 var query=PhysicsShapeQueryParameters3D.new();query.shape=occupancy_shape
 query.transform=global_transform.translated_local(Vector3.UP*2);query.collision_mask=4
 for hit in get_world_3d().direct_space_state.intersect_shape(query,300):
  if hit.collider is Ninja and not hit.collider.dead:return false
 # Rebuilding replaces only the friendly-transparent panel. First purchase
 # also creates solid terrain, so every new collider must be safe for actors.
 if not walls_built:
  query.collision_mask=0xFFFFFFFF
  for solid in _wall_solids():
   var shape=BoxShape3D.new();shape.size=solid.size;query.shape=shape
   query.transform=global_transform.translated_local(solid.point)
   for hit in get_world_3d().direct_space_state.intersect_shape(query,300):
    if hit.collider is PhysicsBody3D and not hit.collider is StaticBody3D:return false
 return true
func complete_build() -> void:
 if completed or not can_complete_build():return
 if not walls_built:_build_walls()
 completed=true;panel.collision_layer=16;panel_mesh.show();_label()
func break_gate() -> void:
 if not completed:return
 completed=false;panel.collision_layer=0;panel_mesh.hide();progress=0;_label()
 if game.has_method("_native_feedback"):game._native_feedback().fx.ring(global_position,Color("ff5268"),6,.4)
func set_build_progress(value: float,_working: bool) -> void:
 progress=value;_label()
func set_proximity(value: bool,can_afford: bool) -> void:
 selected=value;affordable=can_afford;_label()
func tick(_delta: float,_powered_delta: float=0.0) -> void:_label()
func retire_wave_effects() -> void:progress=0;selected=false;_label()
func _label() -> void:
 if not is_instance_valid(prompt):return
 prompt.visible=completed or selected
 if completed:prompt.text="SHRINE GATE  %d / 5000 HP" % director.gate_hp;prompt.modulate=Color("9ceae5")
 else:
  prompt.modulate=Color("ffd487") if affordable else Color("e9ad9e")
  prompt.text=("REBUILD" if walls_built else "BUILD WALL + GATE")+" · 10 GOLD · %d%%" % roundi(progress*100)
  if progress>=1 and not can_complete_build():prompt.text="BUILD AREA OCCUPIED · CLEAR THE DOOR AND WALLS"
func _exit_tree():
 if walls_built and is_instance_valid(game) and is_instance_valid(game.pursuit) and game.is_inside_tree():game.pursuit.configure()
