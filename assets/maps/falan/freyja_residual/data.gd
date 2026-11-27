extends RefCounted
## Original masks remain intact; seven measured owners select the checked source derivative.
const Full=preload("res://assets/maps/falan/freyja_residual/full/data.gd")
const SURFACES={"freyja":preload("res://assets/maps/falan/freyja_residual/freyja-surface.png"),"east_gate":preload("res://assets/maps/falan/freyja_residual/east_gate-surface.png")}
const EXCEPTIONS={"freyja":preload("res://assets/maps/falan/freyja_residual/freyja-exception.png"),"east_gate":preload("res://assets/maps/falan/freyja_residual/east_gate-exception.png")}
const BASES={"freyja":preload("res://assets/maps/falan/west_approach_surface.png"),"east_gate":preload("res://assets/maps/falan/east_region/east_gate-surface.png")}
static var prepared={}
static func image(area:String)->Image:
 return load("res://assets/maps/falan/freyja_residual/full/cpu-masks/"+area+".res")
static func surface(area:String)->Texture2D:
 if prepared.has(area):return prepared[area]
 # Preserve every RGBA byte, including transparent legacy channels, without GPU readback.
 var source=image(area)
 prepared[area]=ImageTexture.create_from_image(source)
 prepared[area].set_meta("source_cpu_image",source)
 return prepared[area]
