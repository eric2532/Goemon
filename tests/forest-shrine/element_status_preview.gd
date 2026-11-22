extends "res://tests/forest-shrine/slime_ice_preview.gd"
const ELEMENT_OUT="res://build/Other Files/Asset Toolkit/Enemy Element Status/Fire and Lightning/"
var fire_batch:MultiMeshInstance3D
var arc_batch:MultiMeshInstance3D

func run():
 var args=OS.get_cmdline_user_args();live="--live" in args
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ELEMENT_OUT+"frames"))
 await setup_stage();make_visuals();make_ui();reset_cycle();draw_frame();await frames(3)
 baseline_nodes=get_node_count();baseline_resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 if DisplayServer.get_name()!="headless":DisplayServer.window_move_to_foreground()
 if live:print("ELEMENT_STATUS_LIVE_READY Space pauses; R replays; Escape closes");return
 for cycle in 3:
  if cycle>0:reset_cycle()
  for frame in int(LENGTH*FPS):
   advance(1.0/FPS)
   if DisplayServer.get_name()!="headless" and cycle==0:
    await process_frame;RenderingServer.force_draw();await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(ELEMENT_OUT+"frames/%04d.png"%frame)==OK,"Capture elemental frame") if frame==0 else save_element_frame(frame)
 verify()
 FileAccess.open(ELEMENT_OUT+"result-"+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"damage_enabled":false,"stun_enabled":false,"trigger_enabled":false,"cycles":3,"node_delta":get_node_count()-baseline_nodes,"resource_delta":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))-baseline_resources},"  "))
 print("ELEMENT_STATUS_PREVIEW_RESULT checks=",checks," failures=",failures)
 await finish()

func make_visuals():
 super.make_visuals();shards.hide()
 var shader=Shader.new()
 var code:String=ice_material.shader.code
 code=code.replace("uniform float preview_frost=0.0;","uniform float preview_frost=0.0;\nuniform float preview_fire=0.0;\nuniform float preview_lightning=0.0;\nuniform float preview_clock=0.0;")
 code=code.replace("void fragment()", "vec3 element_surface(vec3 paint, vec2 uv) {\n float embers = smoothstep(0.90, 0.99, sin(uv.x * 29.0 + sin(uv.y * 19.0 - preview_clock * 3.0)) * cos(uv.y * 23.0));\n paint = mix(paint, vec3(1.0, 0.32, 0.035), preview_fire * (0.04 + embers * 0.18));\n return mix(paint, vec3(0.65, 0.88, 1.0), preview_lightning * 0.12);\n}\nvoid fragment()")
 code=code.replace("ALBEDO = slime_ice(original.rgb, vec2(pixel));","ALBEDO = element_surface(original.rgb, UV);")
 shader.code=code;ice_material.shader=shader
 fire_batch=effect_batch(null,Vector2(1.5,1.5),8,2,"PaintedFlamesPreview")
 fire_batch.multimesh.mesh.material.shader=preload("res://tests/forest-shrine/burning_flame_preview.gdshader")
 arc_batch=effect_batch(preload("res://assets/characters/warcraft/mountain-king/effects/9fbc4488b385-Lightning2b.png"),Vector2(.75,2.4),1,1,"ReusedLightningArcs")
 var arc_shader=Shader.new();arc_shader.code=arc_batch.multimesh.mesh.material.shader.code.replace("blend_mix","blend_add")
 arc_batch.multimesh.mesh.material.shader=arc_shader

func effect_batch(texture:Texture2D,size_:Vector2,columns:int,rows:int,label_:String)->MultiMeshInstance3D:
 var mesh=QuadMesh.new();mesh.size=size_
 var material=ShaderMaterial.new();material.shader=preload("res://assets/characters/crossgate/hit_feedback/critical.gdshader")
 material.set_shader_parameter("atlas",texture);material.set_shader_parameter("frame_count",float(columns));material.set_shader_parameter("frame_rows",float(rows));mesh.material=material
 var node=MultiMeshInstance3D.new();node.name=label_;node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.use_custom_data=true;node.multimesh.mesh=mesh;node.multimesh.instance_count=6
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.custom_aabb=AABB(origin-Vector3(20,5,20),Vector3(40,25,40));root.add_child(node);return node

func make_ui():
 super.make_ui()
 status_label.get_parent().get_child(0).text="SLIME · FIRE / LIGHTNING VISUAL PREVIEW"
 for layer in root.get_children():
  if not layer is CanvasLayer:continue
  for label in layer.get_children():
   if label is Label and label.text.begins_with("LEFT:"):label.text="LEFT: original     RIGHT: visual preview   |   HP unchanged · damage, stun and triggers undecided"

func set_phase(next:int):
 if phase==next:return
 phase=next
 status_label.text=["NORMAL · original slime","FIRE · small flames and warm ember patches","EMBERS FADING · flames die down","LIGHTNING · blue-white arcs around the body","RECOVERING · electrical traces fade"][phase]
 detail_label.text="Visual proposal only. No burn damage, lightning damage, stun or equipment trigger is enabled."

func draw_frame():
 if not is_instance_valid(fire_batch) or handles.is_empty():return
 var snapshot:Dictionary=runtime.render_snapshot();var control:MultiMeshInstance3D=batch.get_meta("control")
 for i in 2:
  var index:int=snapshot.handles.find(handles[i]);var pose:Color=game.crowd.army.pose_sample(snapshot,index)
  pose.r=0;pose.g=fmod(pose.g,8)+80;pose.a=0
  var mm:MultiMesh=batch.multimesh if i==1 else control.multimesh
  mm.set_instance_transform(0,Transform3D(Basis.IDENTITY,origin+snapshot.positions[index]+Vector3(45 if i==0 else -45,0,0)));mm.set_instance_custom_data(0,pose)
 var fire=1.0 if phase==1 else 1.0-clampf((clock_-5)/3,0,1) if phase==2 else 0.0
 var electric=1.0 if phase==3 else 1.0-clampf((clock_-10)/1.5,0,1) if phase==4 else 0.0
 ice_material.set_shader_parameter("preview_fire",fire);ice_material.set_shader_parameter("preview_lightning",electric);ice_material.set_shader_parameter("preview_clock",clock_)
 fire_batch.multimesh.mesh.material.set_shader_parameter("burn_clock",clock_)
 var foot:Vector3=origin+runtime.unit_state(handles[1]).position+Vector3(-45,0,0)
 var basis=camera.global_basis.orthonormalized()
 var reduced=.35 if game.settings.get("reduced_flashes",false) else 1.0
 for i in 6:
  var t=fposmod(clock_*.8+i*.37,1.0)
  var side=-1.0 if i%2==0 else 1.0
  var point=foot+basis.x*(side*(1.05+sin(i*2.1)*.35))+basis.y*(.8+t*3.8)+basis.z*.07
  var scale_=Vector3.ONE*(.65+sin(t*PI)*.6)
  fire_batch.multimesh.set_instance_transform(i,Transform3D(basis.scaled(scale_),point))
  fire_batch.multimesh.set_instance_custom_data(i,Color(t,fire*sin(t*PI)*.85,0,0))
  point=foot+basis.x*(side*(.8+.35*sin(i*1.7+clock_)))+basis.y*(1.1+(i%3)*1.2)+basis.z*.09
  var arc_basis=basis*Basis(Vector3.FORWARD,side*(.35+.2*sin(clock_*2+i)))
  arc_batch.multimesh.set_instance_transform(i,Transform3D(arc_basis,point))
  var flicker=.35+.65*float(posmod(floori(clock_*6)+i*3,5)<3)
  arc_batch.multimesh.set_instance_custom_data(i,Color(0,electric*flicker*reduced,0,0))
 fire_batch.visible=fire>0;arc_batch.visible=electric>0

func verify():
 var snapshot:Dictionary=runtime.render_snapshot()
 check(snapshot.hp==PackedFloat64Array([700,700]),"Fire/lightning preview never deals damage")
 check(snapshot.status==PackedInt32Array([0,0]) and snapshot.ice_visual==PackedFloat32Array([0,0]),"Fire/lightning preview never adds stun, slow or freeze")
 check(get_node_count()<=baseline_nodes and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=baseline_resources,"Repeated elemental visuals reuse their prepared meshes, materials and slots")
 check(not fire_batch.visible and not arc_batch.visible,"Flames and electrical arcs clear at recovery")

func save_element_frame(frame:int):
 if root.get_texture().get_image().save_png(ELEMENT_OUT+"frames/%04d.png"%frame)!=OK:check(false,"Capture elemental frame")
