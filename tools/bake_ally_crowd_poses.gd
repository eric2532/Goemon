extends SceneTree
## Offline only: preserve original geometry/materials and sample authored poses.
const OUT="res://assets/characters/ally_crowd/"
const KINDS=[11,5,7,8,10]
const FPS=60.0
var failures=0
func _initialize():run.call_deferred()
func run():
 var fixture=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(fixture);var game=await fixture.make_game("original")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 for kind in KINDS:
  var unit=game.explorer_helpers.pool.filter(func(u):return u.kit_id==kind)[0]
  var resource=bake(unit)
  var error=ResourceSaver.save(resource,OUT+str(kind)+".res",ResourceSaver.FLAG_COMPRESS)
  print("ARMY_POSE_BAKE kind=",kind," parts=",resource.get_meta("palette").size()," rows=",resource.get_meta("pose_texture").get_height()," surfaces=",resource.get_meta("mesh").get_surface_count()," error=",error)
  if error!=OK or resource.get_meta("mesh").get_surface_count()==0:failures+=1
 bake_visuals(game)
 await fixture.close();fixture.queue_free();await process_frame
 print("ARMY_POSE_BAKE_RESULT failures=",failures);quit(1 if failures else 0)
func bake(unit)->Resource:return preload("res://scripts/forest/crowd/army_pose_baker.gd").new().bake(unit)
func bake_visuals(game:Node):
 var shader=Shader.new();var code=FileAccess.get_file_as_string("res://assets/rogue/shaders/magic_ink_brush.gdshader")
 assert(code.contains("void vertex() { trail_alpha = COLOR.a; }") and code.contains("float flow = brush_clock * 2.0;"),"Original ink shader changed; update the crowd adapter")
 code=code.replace("varying float trail_alpha;","varying float trail_alpha;\nvarying float army_clock;\nvarying float army_fade;")
 code=code.replace("void vertex() { trail_alpha = COLOR.a; }","void vertex() { trail_alpha = COLOR.a; army_clock=INSTANCE_CUSTOM.x; army_fade=INSTANCE_CUSTOM.y; }")
 code=code.replace("float flow = brush_clock * 2.0;","float flow = army_clock * 2.0;").replace("(use_vertex_alpha ? trail_alpha : 1.0);","(use_vertex_alpha ? trail_alpha : 1.0) * army_fade;")
 shader.code=code;ResourceSaver.save(shader,"res://assets/materials/army_ink.gdshader")
 var fx=game.explorer_helpers.pool[0].active_ability.fx;var meshes={}
 for key in ["ranger-arrow","ranger-power-arrow","star"]:
  var color=preload("res://assets/rogue/scripts/class_actions.gd").RANGER_POWER_COLOR if key=="ranger-power-arrow" else (game.explorer_helpers.pool.filter(func(u):return u.kit_id==5)[0].active_ability.tint() if key=="star" else Color("d4be8a"))
  var node=fx.create_projectile(key,color)
  meshes[key]=merge_visual(node);node.free()
 var shield=fx.knight_shield_pulse(Vector3.ZERO,0,1,0);meshes.shield=merge_visual(shield);fx.clear()
 var ring=fx.ring(Vector3.ZERO,Color("63cfff"),1,.4);meshes.ring=merge_visual(ring);fx.clear()
 var smoke=fx._mesh(fx.sphere_geometry,Color("adbfc0"),.5);meshes.smoke=merge_visual(smoke);smoke.free()
 var spark=fx._mesh(fx._diamond(.7,.13),Color("fff2b5"),.9);meshes.spark=merge_visual(spark);spark.free()
 var bullet=load("res://assets/characters/thirstquencher/projectiles/bullet.glb").instantiate();root.add_child(bullet);bullet.scale=Vector3.ONE*5.4
 var player:AnimationPlayer=bullet.find_child("AnimationPlayer",true,false)
 for name_ in player.get_animation_list():
  if "Source__801b1208" in name_:player.play(name_);player.pause();break
 for frame in 16:
  player.seek(frame/30.0,true);meshes["bullet%d"%frame]=merge_visual(bullet,true)
 bullet.free()
 var resource=Resource.new();resource.set_meta("meshes",meshes)
 var error=ResourceSaver.save(resource,OUT+"visuals.res",ResourceSaver.FLAG_COMPRESS)
 if error!=OK:failures+=1
 print("ARMY_VISUAL_BAKE meshes=",meshes.size()," error=",error)
func merge_visual(source:Node3D,include_root:bool=false)->ArrayMesh:
 var groups={};collect_visual(source,Transform3D.IDENTITY,groups,include_root)
 var mesh=ArrayMesh.new()
 for material in groups:
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,groups[material])
  var copy:Material=material.duplicate()
  if copy is StandardMaterial3D:copy.vertex_color_use_as_albedo=true
  elif copy is ShaderMaterial:
   assert(copy.shader.resource_path=="res://assets/rogue/shaders/magic_ink_brush.gdshader","Unexported pooled visual shader")
   copy.shader=load("res://assets/materials/army_ink.gdshader")
   for uniform in material.shader.get_shader_uniform_list():copy.set_shader_parameter(uniform.name,material.get_shader_parameter(uniform.name))
  mesh.surface_set_material(mesh.get_surface_count()-1,copy)
 return mesh
func collect_visual(node:Node,parent:Transform3D,groups:Dictionary,transform_root:bool=true):
 var pose=parent*node.transform if node is Node3D and transform_root else parent
 if node is MeshInstance3D and node.visible and node.mesh!=null:
  for surface in node.mesh.get_surface_count():
   var material=node.get_active_material(surface)
   assert(material is StandardMaterial3D or material is ShaderMaterial,"Unexported pooled visual material")
   if not groups.has(material):
    var blank=[];blank.resize(Mesh.ARRAY_MAX);blank[Mesh.ARRAY_VERTEX]=PackedVector3Array();blank[Mesh.ARRAY_NORMAL]=PackedVector3Array();blank[Mesh.ARRAY_TEX_UV]=PackedVector2Array();blank[Mesh.ARRAY_INDEX]=PackedInt32Array();groups[material]=blank
   var a=node.mesh.surface_get_arrays(surface);var dest:Array=groups[material];var offset:int=dest[Mesh.ARRAY_VERTEX].size();var normal=pose.basis.inverse().transposed()
   for i in a[Mesh.ARRAY_VERTEX].size():
    dest[Mesh.ARRAY_VERTEX].append(pose*a[Mesh.ARRAY_VERTEX][i]);dest[Mesh.ARRAY_NORMAL].append((normal*a[Mesh.ARRAY_NORMAL][i]).normalized() if a[Mesh.ARRAY_NORMAL]!=null else Vector3.UP);dest[Mesh.ARRAY_TEX_UV].append(a[Mesh.ARRAY_TEX_UV][i] if a[Mesh.ARRAY_TEX_UV]!=null else Vector2.ZERO)
   var indices=a[Mesh.ARRAY_INDEX]
   if indices!=null:
    for index in indices:dest[Mesh.ARRAY_INDEX].append(offset+index)
   else:
    for index in a[Mesh.ARRAY_VERTEX].size():dest[Mesh.ARRAY_INDEX].append(offset+index)
 for child in node.get_children():collect_visual(child,pose,groups)
