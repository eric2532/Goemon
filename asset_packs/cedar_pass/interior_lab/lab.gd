# Run in the Goemon repository project, not the asset-only standalone project.
# Uses unmodified repository Hero, HeroModel, tuning and ActionCamera base.
extends Node3D
const PACK="res://asset_packs/cedar_pass/"
var playing=true
var paused=false
var transitioning=false
var boss_active=false
var tuning=PrototypeTuning.DEFAULTS.duplicate()
var world: Node3D
var player: Hero
var camera_rig: ActionCamera
var checkpoint=Vector3(0,.5,7)
var enemies=[]
var rooms={}
var metadata={}
var current_room=""
var ui_label: Label
var selected_id="machiya_open"
var test_mode=false
class LabGround extends Node3D:
 var playable_bounds=Rect2(-300,-300,600,600)
func _ready():
 setup_inputs()
 world=LabGround.new();add_child(world)
 var ground=MeshInstance3D.new();var gm=BoxMesh.new();gm.size=Vector3(190,.3,70);ground.mesh=gm;ground.position=Vector3(55,-.15,0)
 var material=StandardMaterial3D.new();material.albedo_color=Color("9ba48c");material.roughness=1;ground.material_override=material;add_child(ground);ground.create_trimesh_collision()
 metadata=JSON.parse_string(FileAccess.get_file_as_string(PACK+"interiors.json"))
 var shared=load(PACK+"shared_matte.tres")
 var index=0
 for id in metadata:
  var data=metadata[id];var doc=GLTFDocument.new();var state=GLTFState.new()
  assert(doc.append_from_file(PACK+"exports/"+id+".glb",state)==OK,id)
  var node=doc.generate_scene(state);node.name=id;add_child(node);node.position=Vector3(index*23,0,0);index+=1
  var meshes={}
  for m in node.find_children("*","MeshInstance3D",true,false):m.material_override=shared;meshes[String(m.name).trim_prefix("CP_")]=m
  var bodies={}
  for c in data.colliders:
   var body=StaticBody3D.new();body.name="Collision_"+c.name;body.collision_layer=1|8;body.collision_mask=2;node.add_child(body)
   var shape_node=CollisionShape3D.new();body.add_child(shape_node)
   if c.type=="box":
    var shape=BoxShape3D.new();shape.size=cv(c.size_blender).abs();shape_node.shape=shape;body.position=cv(c.position_blender)
   else:
    var shape=ConvexPolygonShape3D.new();var points=PackedVector3Array()
    for v in c.vertices_blender:points.append(cv(v))
    shape.points=points;shape_node.shape=shape
   if not bodies.has(c.group):bodies[c.group]=[]
   bodies[c.group].append(body)
  for pos in data.lights_blender:
   var lamp=OmniLight3D.new();lamp.position=cv(pos);lamp.light_color=Color("ffdba5");lamp.light_energy=.3;lamp.omni_range=5;lamp.shadow_enabled=false;node.add_child(lamp)
  rooms[id]={"root":node,"meshes":meshes,"bodies":bodies,"data":data}
  var label=Label3D.new();label.text=id;label.position=Vector3(0,.1,data.body_depth/2+4.7);label.rotation_degrees.x=-90;label.font_size=42;label.pixel_size=.016;node.add_child(label)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-30,0);light.light_energy=.55;light.shadow_enabled=true;add_child(light)
 var environment=WorldEnvironment.new();var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color("819fac");e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("d1dce5");e.ambient_light_energy=.28;environment.environment=e;add_child(environment)
 player=Hero.new();player.game=self;player.position=checkpoint;add_child(player)
 camera_rig=load(PACK+"interior_lab/camera_adapter.gd").new();camera_rig.game=self;camera_rig.player=player;add_child(camera_rig);camera_rig.reset_follow()
 player.set_process_unhandled_input(false) # This lab exercises traversal; combat is inactive.
 var canvas=CanvasLayer.new();add_child(canvas);var panel=ColorRect.new();panel.position=Vector2(12,10);panel.size=Vector2(1576,94);panel.color=Color(.035,.055,.075,.88);panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(panel);ui_label=Label.new();ui_label.position=Vector2(22,18);canvas.add_child(ui_label)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func cv(v):return Vector3(v[0],v[2],-v[1])
func setup_inputs():
 var keys={"move_forward":KEY_W,"move_back":KEY_S,"move_left":KEY_A,"move_right":KEY_D,"sprint":KEY_SHIFT,"walk_modifier":KEY_CTRL,"jump":KEY_SPACE,"character_toggle":KEY_Q,"sky_strike":KEY_T,"light_attack":KEY_J,"heavy_attack":KEY_K,"assist":KEY_TAB,"dodge":KEY_C,"weapon_pipe":KEY_1,"weapon_coin":KEY_2,"weapon_chain":KEY_3,"scarf_toggle":KEY_4,"surge":KEY_R,"equip":KEY_E}
 for action in keys:
  if not InputMap.has_action(action):InputMap.add_action(action)
  var event=InputEventKey.new();event.physical_keycode=keys[action];InputMap.action_add_event(action,event)
func _process(_delta):
 if not is_instance_valid(player):return
 update_cutaway()
 if ui_label:ui_label.text="CEDAR PASS • ENTERABLE INTERIORS\nActual Goemon player: WASD • Ctrl walk • Shift run • right mouse look • wheel zoom • F5–F10 visit buildings\n"+("Inside: "+current_room+" • roof / near walls cut away; physical collision retained" if current_room!="" else "Outside • approach an entry ramp and walk in")
func update_cutaway():
 current_room=""
 for id in rooms:
  var r=rooms[id];var p=player.global_position-r.root.global_position;var d=r.data
  # Reveal before passing the lintel; mild hysteresis avoids boundary flicker.
  var margin=1.6 if camera_rig.interior_active and selected_id==id else 1.25
  var inside=absf(p.x)<d.body_width/2-.10 and absf(p.z)<d.body_depth/2+margin
  if inside:current_room=id;selected_id=id
  var hide_groups=[]
  if inside:
   hide_groups=["Roof"]
   if cos(camera_rig.yaw)>=-.15:hide_groups.append("Wall_Front")
   if cos(camera_rig.yaw)<.15:hide_groups.append("Wall_Back")
   if sin(camera_rig.yaw)>.15:hide_groups.append("Wall_Right")
   if sin(camera_rig.yaw)<-.15:hide_groups.append("Wall_Left")
   if id=="inn" and p.y<2.2:hide_groups.append_array(["UpperFloor","UpperFurniture"])
  for group in r.meshes:r.meshes[group].visible=not group in hide_groups
  for group in r.bodies:
   for b in r.bodies[group]:b.collision_layer=1 if group in hide_groups else 1|8
 camera_rig.interior_active=current_room!=""
func _unhandled_input(event):
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
 if event is InputEventKey and event.pressed and event.keycode>=KEY_F5 and event.keycode<=KEY_F10:
  var ids=rooms.keys();var idx=event.keycode-KEY_F5
  if idx<ids.size():visit(ids[idx])
func visit(id):
 var r=rooms[id];player.global_position=r.root.global_position+Vector3(0,.4,r.data.body_depth/2+3);player.velocity=Vector3.ZERO;camera_rig.yaw=0;camera_rig.pitch=.4;camera_rig.reset_follow()
# Traversal-only services expected by the unmodified player; combat/audio are not simulated.
func burst(_a,_b,_c,_d=1.0):pass
func sound(_a,_b=1.0):pass
func wind(_a,_b):pass
func toast(_s):pass
