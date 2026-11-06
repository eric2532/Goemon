extends SceneTree
const Immediate=preload("res://tests/forest-shrine/reference/recovered_leader_trail_immediate.gd")
class DeferredTrail extends "res://scripts/recovered_leader_trail.gd":
 var draws=0
 func flush_mesh():
  var building=redraw_queued and samples.size()>=2
  super.flush_mesh()
  if building:draws+=1
class Owner extends Node3D:
 var game={"settings":{"reduced_flashes":false}}
 func melee_reach_setting()->float:return 1.0
var checks=0
var failures=0
var output="res://build/Other Files/Asset Toolkit/24 Hero Smoothness/Coalesced Trails/"
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func viewport()->SubViewport:
 var view=SubViewport.new();view.size=Vector2i(320,240);view.own_world_3d=true
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var camera=Camera3D.new();view.add_child(camera);camera.position=Vector3(5,4,10);camera.look_at(Vector3(0,1,0));camera.current=true
 return view
func compare(before,after):
 check(before.samples==after.samples and before.sample_clock==after.sample_clock and before.brush_clock==after.brush_clock,"Every physics sample and shader clock is retained")
 check((before.mesh==null)==(after.mesh==null),"Expiry and mesh admission match")
 if before.mesh!=null and after.mesh!=null:
  var a=before.mesh.surface_get_arrays(0);var b=after.mesh.surface_get_arrays(0)
  for field in Mesh.ARRAY_MAX:check(a[field]==b[field],"Rendered mesh attribute %d is byte-identical"%field)
 if before.additive or before.original:check(before.trail_material.albedo_color==after.trail_material.albedo_color,"Original glow intensity is unchanged")
 else:
  for key in ["ink_tint","brush_clock","energy"]:check(before.trail_material.get_shader_parameter(key)==after.trail_material.get_shader_parameter(key),"Crescent shader parameter is unchanged: "+key)
func run():
 DirAccess.make_dir_recursive_absolute(output)
 var rows=[]
 for mode in ["crescent","original","additive"]:
  var left=viewport();var right=viewport()
  var owner_before=Owner.new();left.add_child(owner_before)
  var owner_after=Owner.new();right.add_child(owner_after)
  var before=Immediate.new();var after=DeferredTrail.new()
  for node in [before,after]:
   node.original=mode=="original";node.additive=mode=="additive"
   node.light_color=Color("f078f0");node.heavy_color=Color("fff0b0");node.opacity=.65
   node.sample_interval=1.0/30 if mode=="original" else 1.0/60 if mode=="additive" else 0.0
  owner_before.add_child(before);owner_after.add_child(after)
  var serial=0;var immediate_draws=0;var before_us=0;var after_us=0
  var mesh_id=after.prepared_mesh.get_instance_id();var material_id=after.trail_material.get_instance_id()
  for frame in 64:
   owner_before.game.settings.reduced_flashes=frame%9==0;owner_after.game.settings.reduced_flashes=frame%9==0
   var updates=[]
   for step in (64 if frame==40 else [1,2,4,8][frame%4]):
    serial+=1;var time=serial/60.0
    var segment=PackedVector3Array([Vector3(sin(time),.5,cos(time)),Vector3(sin(time*6)*4,1.8+sin(time*4),cos(time*6)*4)])
    updates.append([segment,frame%13!=12,serial%11<5])
   for deferred in ([false,true] if frame%2==0 else [true,false]):
    var node=after if deferred else before;var started=Time.get_ticks_usec()
    for update in updates:
     node.advance(1.0/60,update[0],update[1],update[2])
     if not deferred and node.mesh!=null:immediate_draws+=1
    if deferred:RenderingServer.frame_pre_draw.emit()
    if deferred:after_us+=Time.get_ticks_usec()-started
    else:before_us+=Time.get_ticks_usec()-started
   compare(before,after)
   if frame in [4,20,40,63] and DisplayServer.get_name()!="headless":
    for warm in 15:await process_frame
    await RenderingServer.frame_post_draw
    var a=left.get_texture().get_image();var b=right.get_texture().get_image()
    a.convert(Image.FORMAT_RGBA8);b.convert(Image.FORMAT_RGBA8)
    a.save_png(output+mode+"-%d-immediate.png"%frame);b.save_png(output+mode+"-%d-coalesced.png"%frame)
    check(a.get_data()==b.get_data(),"Same-frame desktop pixels match: "+mode+str(frame))
    var background=a.get_pixel(0,0);var drawn=false
    for y in a.get_height():
     for x in a.get_width():
      if a.get_pixel(x,y)!=background:drawn=true;break
     if drawn:break
    check(drawn,"The pixel comparison includes the visible ribbon")
   if frame%17==16:
    before.clear();after.clear();RenderingServer.frame_pre_draw.emit();compare(before,after)
  check(after.draws<=64 and immediate_draws>after.draws*2,"Many physics updates produce at most one surface per rendered frame")
  check(mesh_id==after.prepared_mesh.get_instance_id() and material_id==after.trail_material.get_instance_id(),"Prepared mesh/material ownership is unchanged")
  if DisplayServer.get_name()!="headless":
   for node in [before,after]:
    node.clear()
    node.advance(0,PackedVector3Array([Vector3.ZERO,Vector3.UP*3]),true,true)
    node.advance(.04,PackedVector3Array([Vector3.RIGHT*2,Vector3.UP*3+Vector3.RIGHT*2]),true,true)
   check(after.redraw_queued,"The new mesh waits for the real engine render boundary")
   await RenderingServer.frame_post_draw
   check(not after.redraw_queued,"The engine flushes pending geometry before rendering")
   compare(before,after)
   var first=left.get_texture().get_image();var second=right.get_texture().get_image()
   first.convert(Image.FORMAT_RGBA8);second.convert(Image.FORMAT_RGBA8)
   first.save_png(output+mode+"-first-frame-immediate.png");second.save_png(output+mode+"-first-frame-coalesced.png")
   check(first.get_data()==second.get_data(),"The first actual rendered frame is pixel-identical")
  for node in [before,after]:
   node.clear();node.lifetime=.5;node.opacity=.2
   node.advance(0,PackedVector3Array([Vector3.ZERO,Vector3.UP]),true,true)
   node.advance(.02,PackedVector3Array([Vector3.RIGHT,Vector3.UP+Vector3.RIGHT]),true,true)
   node.lifetime=4;node.opacity=.9;node.heavy_color=Color.BLUE
  RenderingServer.frame_pre_draw.emit();compare(before,after)
  before.clear();after.clear()
  for node in [before,after]:
   node.advance(0,PackedVector3Array([Vector3.ZERO,Vector3.UP]),true,false)
   node.advance(.02,PackedVector3Array([Vector3.RIGHT,Vector3.UP+Vector3.RIGHT]),true,false)
   node.clear()
  RenderingServer.frame_pre_draw.emit();compare(before,after)
  rows.append({"mode":mode,"immediate_surfaces":immediate_draws,"coalesced_surfaces":after.draws,"immediate_us":before_us,"coalesced_us":after_us})
  left.free();right.free()
 var connections=RenderingServer.frame_pre_draw.get_connections().size()
 var pending=DeferredTrail.new();root.add_child(pending)
 pending.advance(0,PackedVector3Array([Vector3.ZERO,Vector3.UP]),true,false)
 pending.advance(.02,PackedVector3Array([Vector3.RIGHT,Vector3.UP+Vector3.RIGHT]),true,false)
 pending.free();check(RenderingServer.frame_pre_draw.get_connections().size()==connections,"Freeing a queued effect clears its render callback")
 RenderingServer.frame_pre_draw.emit()
 FileAccess.open(output+"cost-"+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print("TRAIL_RENDER_COALESCING_RESULT checks=",checks," failures=",failures," costs=",rows);quit(1 if failures else 0)
