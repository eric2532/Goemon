extends SceneTree
const FX=preload("res://scripts/recovered_goemon_charge_vfx.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1
 print("PASS: " if ok else "FAIL: ",label_)
func run():
 var world=Node3D.new();root.add_child(world)
 var data=FX.data();var effect=FX.create(world,.016,Vector3(0,.1,0))
 check(data.provenance.selector=="0x11" and data.provenance.texture.pic_id=="0x801f","Charge assets belong to native selector 11 and PIC 801F")
 check(data.clips.size()==3 and data.parts.size()==7,"Original three skeletons and seven source quads are recovered")
 check(effect.particle_roots.size()==3 and effect.particle_parts.all(func(p):return p.size()==7),"Charge renders the original three times seven particle meshes")
 effect.set_charge_time(.499)
 check(not effect.visible,"Charge effect stays hidden before the native half-second cue")
 effect.set_charge_time(1.0)
 check(effect.visible and absf(effect.particle_roots[0].basis.get_scale().x-.016*.15)<.000001,"Original root growth is 0.01 per 30 Hz tick")
 check(effect.particle_roots[0].position.is_equal_approx(Vector3(0,.9,0)),"Charge follows native 50-unit Goemon height with uniform source conversion")
 var matrices=true
 for variant in range(3):
  for i in range(7):
   var v=data.clips[variant].frames[15][i]
   var expected=Transform3D(Basis(Vector3(v[0],v[1],v[2]),Vector3(v[3],v[4],v[5]),Vector3(v[6],v[7],v[8])),Vector3(v[9],v[10],v[11]))
   matrices=matrices and effect.particle_parts[variant][i].transform.is_equal_approx(expected)
 check(matrices,"Every rendered quad uses its verified native half-frame matrix")
 effect.set_charge_time(2.0+1.001/30.0)
 var spins=true
 for variant in range(3):
  var angle=TAU*float([28,8,16][variant])/1024.0
  spins=spins and effect.particle_roots[variant].basis.is_equal_approx(Basis(Vector3.UP,angle).scaled(Vector3.ONE*.016*.46))
 check(spins,"Full-charge spin matches the original 28/8/16-unit rotation increments")
 var material=effect.particle_parts[0][0].mesh.surface_get_material(0) as ShaderMaterial
 check(material.get_shader_parameter("billboard")==true,"Original rotation flags keep the source quads facing the camera")
 check(material.get_shader_parameter("primitive_color")==Vector3(255,245,184)/255.0 and material.get_shader_parameter("environment_color")==Vector3(255,250,36)/255.0,"Original charge primitive and environment colors are preserved")
 var impact=FX.impact(world,Vector3(1,2,3),.016);impact.set_process(false)
 check(impact.global_position==Vector3(1,2,3) and impact.impact_mesh.scale.is_equal_approx(Vector3.ONE*.0032),"Coin impact keeps native 0.2 mesh scale at the supplied world origin")
 impact._process(.1)
 var impact_material=impact.impact_mesh.mesh.surface_get_material(0) as ShaderMaterial
 check(absf(impact_material.get_shader_parameter("opacity")-207.0/255.0)<.000001,"Original impact fades 16 alpha units per native tick")
 check(impact_material.get_shader_parameter("source_texture").resource_path.ends_with("coin_impact_1.png"),"Original coin impact advances its source image every two ticks")
 check(data.impact.frames.size()==10 and data.impact.lifetime_ticks==16,"All ten original impact frames and 16-tick fade are retained")
 world.queue_free();await process_frame
 print("GOEMON_CHARGE_VFX_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
