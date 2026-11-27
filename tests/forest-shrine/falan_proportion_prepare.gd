extends SceneTree
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const Architecture=preload("res://scripts/forest/forest_falan_architecture.gd")
const Special=preload("res://scripts/forest/forest_falan_special_exteriors.gd")
const Workshop=preload("res://scripts/forest/forest_falan_workshop.gd")
const Magic=preload("res://scripts/forest/forest_falan_magic_shop.gd")
const Civic=preload("res://scripts/forest/forest_falan_civic_exterior.gd")
const OUT="res://build/Other Files/Asset Toolkit/Falan Proportions/"
var rows=["extends RefCounted","## Prepared from native pixel bounds by falan_proportion_prepare.gd; do not edit fitted values.","static var FITS={"]
var heights={};var bases={};var report={}
var original_fits={}

func _initialize():
 create_timer(180).timeout.connect(func():printerr("FALAN_PROPORTION_PREPARE_TIMEOUT");quit(1))
 original_fits=Fit.Data.FITS.duplicate(true)
 Fit.enabled=false
 run.call_deferred()

func measure(key:String,points:Array[Vector3],basis:Basis):
 var pose=Fit.measure(points,key,basis)
 var world=Transform3D(basis,Vector3.ZERO)
 var before=Fit.projected_bounds(points,world);var after=Fit.projected_bounds(points,world*pose)
 var target:Rect2=Fit.References.RECTS[key]
 assert(after.position.distance_to(target.position)<.02 and after.size.distance_to(target.size)<.02,"Source bounds must match in actual geometry: "+key)
 var top=0.0
 for p in points:top=maxf(top,(pose*p).y)
 heights[key]=top;bases[key]=basis
 var scale_=pose.basis.get_scale()
 rows.append(' "%s":Transform3D(Basis.IDENTITY.scaled(Vector3(%.12f,%.12f,%.12f)),Vector3(%.12f,%.12f,%.12f)),'%[key,scale_.x,scale_.y,scale_.z,pose.origin.x,pose.origin.y,pose.origin.z])
 report[key]={"target":str(target),"before":str(before),"after":str(after),"scale":[scale_.x,scale_.y,scale_.z],"offset":[pose.origin.x,pose.origin.y,pose.origin.z],"world_height":top}
 print("MEASURED ",key," scale=",scale_," height=",top)

func run():
 for serial in Architecture.Data.GRAPHICS:measure("house_%d"%serial,Fit.mesh_points(Architecture.prepare(serial)),Basis(Vector3.UP,PI*.5))
 for anchor in Special.SPECS:
  var row:Array=Special.SPECS[anchor];measure("special_%d"%row[0],Fit.mesh_points(Special.prepare(row)),Basis(Vector3.UP,row[7]))
 measure("special_10301",Fit.mesh_points(Workshop.prepare()),Basis.IDENTITY)
 measure("special_10075",Fit.mesh_points(Magic.prepare()),Basis.IDENTITY)
 var holder=Node3D.new();root.add_child(holder)
 for anchor in Civic.SHELLS:
  var spec:Array=Civic.SHELLS[anchor]
  Civic.build(holder,Vector3.ZERO,spec)
  var node:Node3D=holder.get_children()[-1]
  measure("civic_%d"%spec[0],Fit.node_points(node),node.basis)
  node.queue_free();await process_frame
 rows.append("}");rows.append("const HEIGHTS={")
 for key in heights:rows.append(' "%s":%.12f,'%[key,heights[key]])
 rows.append("}");rows.append("const BASES={")
 for key in bases:
  var vectors=[]
  for axis in [bases[key].x,bases[key].y,bases[key].z]:vectors.append("Vector3(%.12f,%.12f,%.12f)"%[axis.x,axis.y,axis.z])
  rows.append(' "%s":Basis(%s),'%[key,",".join(vectors)])
 rows.append("}")
 if "--check" in OS.get_cmdline_user_args():
  for key in report:
   check_fit(key,report[key])
 else:
  var data=FileAccess.open("res://assets/maps/falan/city_proportion_fit.gd",FileAccess.WRITE);data.store_string("\n".join(rows)+"\n");data.close()
 var file:FileAccess
 file=FileAccess.open(OUT+"measurement.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("FALAN_PROPORTIONS_PREPARED count=",report.size())
 holder.queue_free();await process_frame
 quit()

func check_fit(key:String,row:Dictionary):
 var actual:Transform3D=original_fits[key];var scale_=actual.basis.get_scale()
 assert(scale_.distance_to(Vector3(row.scale[0],row.scale[1],row.scale[2]))<.0001,"Stale source proportion scale: "+key)
 assert(actual.origin.distance_to(Vector3(row.offset[0],row.offset[1],row.offset[2]))<.0001,"Stale source proportion origin: "+key)
 assert(absf(Fit.Data.HEIGHTS[key]-row.world_height)<.0001,"Stale source collision height: "+key)
