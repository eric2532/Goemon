extends RefCounted
## Private technical continuity between two presentations of the SAME original100.
## This is not an original warp. Regions/Tour remain the only transfer owners.
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const EDGE=1471.5 # Native source x490.5, between source491360 and490360.
const CENTER=1080.0
const HALF_SPAN=.65
static func crossing(area:String,before:Vector2,at:Vector2,host_ready:bool=false)->Dictionary:
 if not host_ready or area not in ["east_gate","south_gate"]:return {}
 var source:Transform2D=Regions.frame(area);var previous=source*before;var next=source*at
 var direction=-1. if area=="east_gate"else 1.
 if absf(next.y-CENTER)>HALF_SPAN+.0001 or (previous.x-EDGE)*direction>=0 or (next.x-EDGE)*direction<0:return {}
 var destination="south_gate"if area=="east_gate"else"east_gate";var target:Transform2D=Regions.frame(destination)
 return {"area":destination,"arrival":target.inverse()*next,"rotation":target.get_rotation()-source.get_rotation(),"source":100,"source_float":next/3.,"display_boundary_only":true}
