extends "res://scripts/recovered_leaders_tests.gd"
## Isolated native slime demonstration. No production material, hit rule or save is changed.
const Slimes=preload("res://scripts/forest/crowd/slime_sprites.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Kits=preload("res://scripts/forest/crowd/army_kit_data.gd")
const OUT="res://build/Other Files/Asset Toolkit/Ice Status Preview/"
const FPS=24
const LENGTH=13.0
var runtime
var handles:Array[int]=[]
var batch:MultiMeshInstance3D
var shards:MultiMeshInstance3D
var ice_material:ShaderMaterial
var camera:Camera3D
var origin=Vector3(-60,0,90)
var clock_=0.0
var phase=-1
var status_label:Label
var detail_label:Label
var live=false
var stopped=false
var slow_samples:Array[float]=[]
var freeze_samples:Array[float]=[]
var recovery_samples:Array[float]=[]
var frozen_frames:Dictionary={}
var baseline_nodes=0
var baseline_resources=0
var native_samples:Array[float]=[]
var travel:Array[float]=[-1.0,-1.0]

func run():
 var args=OS.get_cmdline_user_args()
 live="--live" in args
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"frames"))
 await setup_stage()
 make_visuals();make_ui()
 check(Slimes.motions().variants[0].clips.any(func(c):return c.action==8 and c.direction==4 and c.frames==2 and c.duration_ms==1000),"Preview uses the original two-frame, one-second get-hit clip")
 check(batch.multimesh.mesh!=Slimes.make_mesh() and ice_material!=Slimes.make_mesh().material,"Preview owns its mesh/material; the shared slime resources are unchanged")
 check(not FileAccess.get_file_as_string("res://assets/materials/hound_sprite.gdshaderinc").contains("slime_ice"),"Production sprite shader has no ice-preview code")
 reset_cycle();draw_frame()
 await frames(3)
 baseline_nodes=get_node_count();baseline_resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 if DisplayServer.get_name()!="headless":DisplayServer.window_move_to_foreground()
 if live:
  print("SLIME_ICE_LIVE_READY Space pauses/resumes; R replays; Escape closes")
  return
 for cycle in 3:
  if cycle>0:reset_cycle()
  for frame in int(LENGTH*FPS):
   advance(1.0/FPS)
   if DisplayServer.get_name()!="headless" and not "--verify-only" in args:
    await process_frame;RenderingServer.force_draw();await RenderingServer.frame_post_draw
    if cycle==0:
     check(root.get_texture().get_image().save_png(OUT+"frames/%04d.png"%frame)==OK,"Captured preview frame %d"%frame) if frame==0 else save_frame(frame)
     if frame in [24,84,156,186,228,276]:root.get_texture().get_image().save_png(OUT+"stage-%03d.png"%frame)
 verify()
 var report={"checks":checks,"failures":failures,"cycles":3,"native_slime_count":handles.size(),"slow_speed_ratio":mean(slow_samples),"frozen_max_displacement":freeze_samples.max(),"recovered_speed_ratio":mean(recovery_samples),"get_hit_frames":frozen_frames.keys(),"node_delta":get_node_count()-baseline_nodes,"resource_delta":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))-baseline_resources,"production_changes":false,"native_step_mean_ms":mean(native_samples),"rendered":DisplayServer.get_name()!="headless"}
 FileAccess.open(OUT+"result-"+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("SLIME_ICE_PREVIEW_RESULT ",JSON.stringify(report))
 await finish()

func setup_stage():
 set_meta("forest_custom_layout",JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_wind_meadow.json")))
 game=load("res://scenes/forest_shrine.tscn").instantiate()
 game.settings_path="user://slime-ice-preview-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;await frames(3)
 game.process_mode=Node.PROCESS_MODE_DISABLED;paused=false;game.paused=false
 for node in game.find_children("*","",true,false):node.process_mode=Node.PROCESS_MODE_DISABLED
 stop_audio(game)
 for node in game.find_children("*","CanvasLayer",true,false):node.hide()
 game.player.hide()
 if is_instance_valid(game.training_dummy):game.training_dummy.hide()
 game.world.preview.hide();game.crowd.clear()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 runtime=game.army_runtime;runtime.finish_integration();runtime.clear()
 var heights=PackedFloat32Array();heights.resize(33*33)
 var covered=PackedByteArray();covered.resize(33*33);covered.fill(1)
 runtime.set_navigation(99001,{"width":33,"spacing":6.0,"origin":Vector3(-96,0,-96),"heights":heights,"covered":covered})
 var kit=Kits.from_model(game.model,1.0,game)
 kit.slime_approach_boost=false;runtime.configure_kits(kit);game.crowd.army.configure_profiles(kit)
 origin.y=game.model.surface_height(origin.x,origin.z)+0.08
 camera=game.camera_rig.camera
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=23
 camera.global_position=origin+Vector3(0,14,30);camera.look_at(origin+Vector3(0,2,-1))
 camera.make_current()

func make_visuals():
 var original:QuadMesh=Slimes.make_mesh()
 var mesh:QuadMesh=original.duplicate()
 ice_material=original.material.duplicate()
 var source=FileAccess.get_file_as_string("res://assets/materials/hound_sprite.gdshaderinc")
 var tint=" ALBEDO = ice_sprite_surface(original.rgb, vec2(pixel), ice_coat);"
 check(source.count(tint)==1,"Preview replaces exactly the shared frozen-tint fragment")
 var shader=Shader.new()
 shader.code="shader_type spatial;\nrender_mode unshaded, cull_disabled;\nuniform float preview_frost=0.0;\nuniform float preview_thaw=0.0;\n"+source.replace('#include "enemy_ice_sprite.gdshaderinc"','#include "res://assets/materials/enemy_ice_sprite.gdshaderinc"').replace("void fragment()",FileAccess.get_file_as_string("res://tests/forest-shrine/slime_ice_surface.gdshaderinc").replace("frost","preview_frost").replace("thaw","preview_thaw")+"\nvoid fragment()").replace(tint," ALBEDO = slime_ice(original.rgb, vec2(pixel));")
 ice_material.shader=shader;mesh.material=ice_material
 batch=MultiMeshInstance3D.new();batch.name="IsolatedSlimeIcePreview"
 batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D;batch.multimesh.use_custom_data=true;batch.multimesh.mesh=mesh;batch.multimesh.instance_count=1
 batch.custom_aabb=AABB(origin-Vector3(20,5,20),Vector3(40,25,40));batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root.add_child(batch)
 var control=MultiMeshInstance3D.new();control.name="OriginalSlimeControl"
 control.multimesh=MultiMesh.new();control.multimesh.transform_format=MultiMesh.TRANSFORM_3D;control.multimesh.use_custom_data=true;control.multimesh.mesh=original;control.multimesh.instance_count=1
 control.custom_aabb=batch.custom_aabb;control.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 batch.set_meta("control",control);root.add_child(control)
 shards=MultiMeshInstance3D.new();shards.name="ReusableThawFlakes"
 var crystal=PrismMesh.new();crystal.size=Vector3(.17,.26,.1)
 var paint=StandardMaterial3D.new();paint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;paint.albedo_color=Color("c6efff")
 crystal.material=paint
 shards.multimesh=MultiMesh.new();shards.multimesh.transform_format=MultiMesh.TRANSFORM_3D;shards.multimesh.mesh=crystal;shards.multimesh.instance_count=12
 shards.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(shards)

func make_ui():
 var layer=CanvasLayer.new();root.add_child(layer)
 var panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);panel.offset_bottom=130;layer.add_child(panel)
 var style=StyleBoxFlat.new();style.bg_color=Color(.035,.065,.075,.91);style.content_margin_left=25;style.content_margin_top=10;style.content_margin_bottom=12;panel.add_theme_stylebox_override("panel",style)
 var box=VBoxContainer.new();panel.add_child(box)
 var title=Label.new();title.text="SLIME · IN-GAME ICE PREVIEW";title.add_theme_font_size_override("font_size",27);box.add_child(title)
 status_label=Label.new();status_label.add_theme_font_size_override("font_size",23);box.add_child(status_label)
 detail_label=Label.new();detail_label.add_theme_font_size_override("font_size",18);box.add_child(detail_label)
 var footer=Label.new();footer.text="LEFT: original slime     RIGHT: ice preview   |   Preview only · Space: pause · R: replay · Esc: close";footer.position=Vector2(25,root.size.y-38);footer.add_theme_font_size_override("font_size",17);layer.add_child(footer)

func reset_cycle():
 if live:slow_samples.clear();freeze_samples.clear();recovery_samples.clear();native_samples.clear();frozen_frames.clear()
 runtime.clear();handles.clear();clock_=0;phase=-1;travel=[-1.0,-1.0]
 for i in 2:
  var h:int=runtime.spawn(i+1,0,Roles.SLIME,Vector3(-50 if i==0 else 50,0,2),700,Roles.SLIME_RADIUS)
  handles.append(h);check(h!=0,"Native preview slime spawns")
 set_phase(0)

func set_phase(next:int):
 if phase==next:return
 phase=next
 if phase==1:check(runtime.apply_hit(handles[1],{"element":"slow","slow_factor":.4,"status_seconds":3.0}).accepted,"Native 40% movement slow is accepted")
 if phase==2:check(runtime.apply_hit(handles[1],{"element":"ice","status_seconds":3.0}).accepted,"Native three-second freeze is accepted")
 status_label.text=["NORMAL · original movement","SLOWED · 40% movement speed","FROZEN · get-hit reaction, then held","THAWING · cracks, shedding ice, movement returns","RECOVERED · original movement restored"][phase]
 detail_label.text=["Both slimes use the same original green artwork and native movement.","A thin frost layer forms; the original green body stays visible.","The two original get-hit frames play once; the final pose stays frozen.","The coating breaks away and fades. No damage or skill changes.","This sequence loops for visual review; other enemies are unchanged."][phase]

func advance(delta:float):
 var next=0 if clock_<2 else 1 if clock_<5 else 2 if clock_<8 else 3 if clock_<10 else 4
 set_phase(next)
 var before:Dictionary=runtime.unit_state(handles[1])
 var goals=PackedVector3Array()
 for i in 2:
  var point:Vector3=runtime.unit_state(handles[i]).position
  if point.z< -5.5:travel[i]=1
  elif point.z>2:travel[i]=-1
  goals.append(Vector3(-50 if i==0 else 50,0,travel[i]*22))
 # Separate native lanes avoid mutual crowding; only their presentation is brought together.
 var started=Time.get_ticks_usec();runtime.step(delta,{"targets":{"ids":PackedInt64Array([1001,1002]),"kinds":PackedInt32Array([3,3]),"positions":goals,"hp":PackedFloat32Array([100000,100000])}})
 native_samples.append((Time.get_ticks_usec()-started)*.001)
 var a:Dictionary=runtime.unit_state(handles[0]);var b:Dictionary=runtime.unit_state(handles[1])
 if phase==1 and clock_>2.1 and clock_<4.8:slow_samples.append(Vector2(b.velocity.x,b.velocity.z).length()/maxf(.001,Vector2(a.velocity.x,a.velocity.z).length()))
 if phase==2 and clock_>5.1 and clock_<7.8:freeze_samples.append(b.position.distance_to(before.position))
 if phase==4 and clock_>10.2:recovery_samples.append(Vector2(b.velocity.x,b.velocity.z).length()/maxf(.001,Vector2(a.velocity.x,a.velocity.z).length()))
 clock_+=delta;draw_frame()

func draw_frame():
 var snapshot:Dictionary=runtime.render_snapshot()
 var control:MultiMeshInstance3D=batch.get_meta("control")
 for i in 2:
  var index:int=snapshot.handles.find(handles[i])
  var pose:Color=game.crowd.army.pose_sample(snapshot,index)
  pose.r=0;pose.g=fmod(pose.g,8)+80;pose.a=0
  if i==1 and phase==2:
   pose.g=83;pose.b=minf(maxf(0,clock_-5),.55);frozen_frames[0 if pose.b<.5 else 1]=true
  var mm:MultiMesh=batch.multimesh if i==1 else control.multimesh
  mm.set_instance_transform(0,Transform3D(Basis.IDENTITY,origin+snapshot.positions[index]+Vector3(45 if i==0 else -45,0,0)))
  mm.set_instance_custom_data(0,pose)
 var thawing=clampf((clock_-8)/2,0,1) if phase==3 else 0.0
 ice_material.set_shader_parameter("preview_frost",.42 if phase==1 else 1.0 if phase in [2,3] else 0.0)
 ice_material.set_shader_parameter("preview_thaw",thawing)
 var body:Vector3=origin+runtime.unit_state(handles[1]).position+Vector3(-45,0,0)
 for i in 12:
  var t=clampf(thawing*1.8-float(i%4)*.16,0,1)
  var side=-1.0 if i%2==0 else 1.0
  var point=body+camera.global_basis.x*(side*(1.3+t*1.0))+camera.global_basis.y*(1.2+float(i%5)*.6-t*t*2.4)
  var size_=sin(t*PI) if phase==3 else 0.0
  shards.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.FORWARD,i*.7+t*3).scaled(Vector3.ONE*size_),point))

func save_frame(frame:int):
 if root.get_texture().get_image().save_png(OUT+"frames/%04d.png"%frame)!=OK:check(false,"Save frame %d"%frame)

func verify():
 check(not slow_samples.is_empty() and absf(mean(slow_samples)-.4)<.02,"Slowed movement measures 40% of the untreated native slime")
 check(not freeze_samples.is_empty() and freeze_samples.max()<.00001,"Frozen native slime remains stationary")
 check(frozen_frames.has(0) and frozen_frames.has(1),"Both original get-hit frames are presented before holding")
 check(not recovery_samples.is_empty() and absf(mean(recovery_samples)-1)<.02,"Thawed movement returns to the untreated native speed")
 check(get_node_count()<=baseline_nodes,"Three repeated cycles add no nodes")
 check(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=baseline_resources,"Three repeated cycles add no resources")
 check(runtime.unit_state(handles[1]).hp==700,"Preview status application does not change slime HP")
 check(ice_material.get_shader_parameter("preview_frost")==0.0,"The coating is cleared after recovery")

func mean(values:Array[float])->float:
 var total=0.0
 for value in values:total+=value
 return total/maxi(1,values.size())

func _process(delta:float):
 if not live or handles.is_empty() or stopped:return
 advance(minf(delta,.05))
 if clock_>=LENGTH:reset_cycle()

func _input(event:InputEvent):
 if not live or not event is InputEventKey or not event.pressed or event.echo:return
 if event.keycode==KEY_SPACE:stopped=not stopped
 if event.keycode==KEY_R:reset_cycle();draw_frame()
 if event.keycode==KEY_ESCAPE:finish()

func finish():
 live=false;stop_audio(game)
 var path:String=game.settings_path
 current_scene=null;game.queue_free();await frames(3)
 if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 quit(1 if failures else 0)
