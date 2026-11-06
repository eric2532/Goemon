extends SceneTree
var checks=0
var failures=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():run.call_deferred()
func run():
 var parent=Node3D.new();root.add_child(parent)
 var reference=SphereMesh.new();reference.radius=.5;reference.height=1;reference.radial_segments=16;reference.rings=8
 var red=Geo.mat("ff0000");var blue=Geo.mat("0000ff")
 var a=Geo.sphere(parent,Vector3.ONE,Vector3(2,3,4),red)
 var b=Geo.sphere(parent,Vector3.LEFT,Vector3.ONE*.1,blue)
 check(a.mesh==b.mesh,"Repeated sparks share the existing sphere geometry")
 check(a.position==Vector3.ONE and a.scale==Vector3(2,3,4) and b.scale==Vector3.ONE*.1,"Position and per-instance size stay independent")
 check(a.material_override==red and b.material_override==blue,"Per-instance materials retain their own color")
 var before=reference.surface_get_arrays(0);var after=a.mesh.surface_get_arrays(0)
 for i in Mesh.ARRAY_MAX:
  check(before[i]==after[i],"Sphere array %d is byte-identical to the previous geometry"%i)
 var custom=Geo.sphere(parent,Vector3.ZERO,Vector3.ONE,red);custom.mesh=custom.mesh.duplicate();custom.mesh.radial_segments=9;custom.mesh.rings=4
 check(a.mesh.radial_segments==16 and a.mesh.rings==8,"Owned scenery variants cannot change shared spark geometry")
 for i in 200:
  var n=Geo.sphere(parent,Vector3.ZERO,Vector3.ONE,red);check(n.mesh==a.mesh,"Repeated creation reuses the same mesh");n.free()
 parent.free();print("SHARED_SPHERE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
