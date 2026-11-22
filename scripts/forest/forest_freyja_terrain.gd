@static_unload
extends "res://scripts/forest/forest_wind_meadow_terrain.gd"
## The Freyja cache is transcribed onto the meadow's existing 3 m terrain grid.
const ID="freyja_west_gate"
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const MASK=preload("res://assets/maps/freyja_west_gate/layout_mask.png")
const SURFACES={
 "freyja":[preload("res://assets/maps/falan/west_approach_surface.png"),Vector2(-480,-204)],
 "city":[preload("res://assets/maps/falan/city_surface.png"),Vector2(-402,-438)],
 "castle":[preload("res://assets/maps/falan/castle_surface.png"),Vector2(-168,-114)],
 "east_gate":[preload("res://assets/maps/falan/east_approach_surface.png"),Vector2(-480,-204)],
 "south_gate":[preload("res://assets/maps/falan/south_approach_surface.png"),Vector2(-480,-204)]
}
const WATER_HEIGHT=2.0
const BANK_HEIGHT=6.0
const CITY_POND=Rect2(-357,27,18,15)
const CITY_POND_WATER=5.38
const BRIDGE=Rect2(-6,63,18,87)
const BRIDGES={"freyja":BRIDGE,"east_gate":Rect2(-6,63,18,90),"south_gate":Rect2(-9,45,24,108)}
const IL_BRIDGE_SOURCE=Rect2(1660.5,694.5,18,9)
const EastRoad=preload("res://scripts/forest/forest_east_road.gd")
const Sokia=preload("res://scripts/forest/forest_sokia_scenery.gd")
static var fields:Dictionary={}
var variant="freyja"

func uses_baked_geometry()->bool:return false
func uses_baked_apron()->bool:return not Sokia.owns(variant) and variant not in ["city","il_village","kili","venoa"] and variant not in Regions.TOMATO_LAND and not BRIDGES.has(variant) and not Regions.Data.RIDGES.has(variant)
func mesh_heights()->PackedFloat32Array:return terrain_field().get_meta("bed")
func mask_texture()->Texture2D:
 if variant=="east_gate":return EastRoad.mask()
 if Sokia.owns(variant):return Sokia.MASKS[variant]
 if Regions.Sites.VILLAGES.has(variant):return Regions.Sites.VILLAGES[variant][3]
 if Regions.Data.REGIONS.has(variant):return Regions.joined_mask(variant,Regions.Data.REGIONS[variant][2],-(Regions.Data.REGIONS[variant][2].get_size()-Vector2.ONE)*1.5)
 return SURFACES[variant][0]
func mask_origin()->Vector2:
 if variant=="east_gate":return EastRoad.ORIGIN
 if Regions.Sites.VILLAGES.has(variant):return Regions.Sites.VILLAGES[variant][2]
 return -(mask_texture().get_size()-Vector2.ONE)*1.5 if Regions.Data.REGIONS.has(variant) else SURFACES[variant][1]
func mask_bounds()->Rect2:return Rect2(mask_origin()-Vector2.ONE*1.5,mask_texture().get_size()*3.0)
func bridge_bounds()->Rect2:return BRIDGES.get(variant,Rect2())
func il_bridge_bounds()->Rect2:
 return Regions.frame(variant).inverse()*IL_BRIDGE_SOURCE if variant in ["east_gate","east_coast"] else Rect2()

func water_walkable()->bool:return variant not in Regions.TOMATO_LAND

func submerged(p:Vector3)->bool:
 if variant in Regions.TOMATO_LAND:
  # The low ground below the raised trail uses the existing safe return.
  return p.y<WATER_HEIGHT and not contains(p.x,p.z)
 var at=Vector2(p.x,p.z)
 var level=CITY_POND_WATER if variant=="city" and CITY_POND.has_point(at) else WATER_HEIGHT
 return p.y<level-.15 and (variant in ["castle","il_village"] or mask_bounds().has_point(at)) and not contains(p.x,p.z)

func terrain_field()->Resource:
 if variant=="east_gate":return EastRoad.field()
 if fields.has(variant):return fields[variant]
 var source=super.terrain_field()
 var mask=mask_texture().get_image()
 var count:int=source.get_meta("width")
 var step:float=source.get_meta("spacing")
 var origin=mask_origin()
 var start=Vector2i((origin+Vector2.ONE*480.0)/step)
 var bridge=bridge_bounds()
 var joined=Regions.GATE_FRAMES.has(variant)
 var outlying=Regions.Data.REGIONS.has(variant)
 var archive_frame=Regions.frame(variant) if joined or outlying or variant=="kili" else Transform2D.IDENTITY
 var land:PackedFloat32Array=source.get_meta("heights")
 var bed=land.duplicate()
 var coverage:PackedByteArray=source.get_meta("covered")
 var crossings:PackedByteArray=source.get_meta("bridges")
 if Sokia.owns(variant):crossings=crossings.duplicate();crossings.fill(0)
 var mountain=variant in Regions.TOMATO_LAND
 if variant in ["city","castle","il_village"] or mountain or Sokia.owns(variant):
  land=land.duplicate()
  coverage=coverage.duplicate()
  land.fill(0.0)
  bed.fill(0.0)
  coverage.fill(0)
 for z in mask.get_height():
  for x in mask.get_width():
   var paint=mask.get_pixel(x,z)
   var i=(start.y+z)*count+start.x+x
   var point=origin+Vector2(x,z)*step
   var bank=BANK_HEIGHT*clampf((point.y-21.0)/minf(24.0,bridge.position.y-21.0),0.0,1.0) if bridge.has_area() else BANK_HEIGHT
   if joined:
    bank=BANK_HEIGHT
    if point.y>244:
     var hills=3.0*sin(point.x*.023+point.y*.016)+2.0*cos(point.y*.027-point.x*.011)
     bank+=hills*smoothstep(244.0,326.0,point.y)
    if variant=="east_gate":bank=lerpf(bank,BANK_HEIGHT,smoothstep(105.0,140.0,-point.x))
    bank=lerpf(bank,Regions.land_height(archive_frame*point),smoothstep(370.0,405.0,point.y))
   elif outlying or variant=="kili":
    bank=Regions.land_height(archive_frame*point)
   elif mountain:
    bank=15.0+sin(point.x*.018+point.y*.012)*4.5+cos(point.y*.027)*2.0
   bank=Regions.village_bank(variant,point,bank)
   if variant in ["ghana","ghana_north_road"] and paint.b>.98:
    # Lift the original cliff tiles and keep the paths at their usual grade.
    bank+=14.0+3.0*sin(point.x*.21+point.y*.11)
   bed[i]=lerpf(land[i],bank*(1.0-paint.r),paint.a)
   if variant=="freyja" and point.y<=63.0:
    # The outer shore should meet the city view without exposing the old meadow rim.
    bed[i]=lerpf(bed[i],minf(bed[i],bank),smoothstep(138.0,240.0,absf(point.x)))
   if variant=="city" and CITY_POND.has_point(point) and paint.r>.5:
    bed[i]=CITY_POND_WATER-.50
    land[i]=bed[i]
    coverage[i]=0
   elif bridge.has_area() and bridge.grow(.01).has_point(point):
    land[i]=BANK_HEIGHT
    crossings[i]=1
   else:
    land[i]=bed[i]
    if paint.r>.5 and bed[i]<WATER_HEIGHT:coverage[i]=0
    elif (variant in ["city","castle","il_village"] or mountain or Sokia.owns(variant)) and paint.a>.5:coverage[i]=1
   if variant in ["east_gate","east_coast"] and IL_BRIDGE_SOURCE.has_point(archive_frame*point):
    bed[i]=0.0
    crossings[i]=1
 if variant=="city":
  var fortifications=load("res://scripts/forest/forest_falan_fortifications.gd")
  for deck:Rect2 in fortifications.BRIDGES:
   var cut:Rect2=fortifications.expand_bridge(deck,0,3)
   # Keep the original route heights. The bridge meshes replace the cut-out terrain collision.
   for z in range(ceili((cut.position.y+480)/step),floori((cut.end.y+480)/step)+1):
    for x in range(ceili((cut.position.x+480)/step),floori((cut.end.x+480)/step)+1):
     var i=z*count+x
     bed[i]=0.0
     if deck.grow(.01).has_point(Vector2(x,z)*step-Vector2.ONE*480):crossings[i]=1
 var freyja_field=Resource.new()
 freyja_field.set_meta("width",count)
 freyja_field.set_meta("spacing",step)
 freyja_field.set_meta("heights",land)
 freyja_field.set_meta("covered",coverage)
 freyja_field.set_meta("bridges",crossings)
 freyja_field.set_meta("bed",bed)
 fields[variant]=freyja_field
 return freyja_field

func coordinate(x:float,z:float)->Vector2:
 return (Vector2(x,z)-EastRoad.ORIGIN)/EastRoad.STEP if variant=="east_gate" else super.coordinate(x,z)

func mesh()->ArrayMesh:
 return EastRoad.mesh() if variant=="east_gate" else super.mesh()

func _building_ground_info(cells:Array)->Dictionary:
 var bridge=bridge_bounds()
 for cell:Vector2i in cells:
  if bridge.has_area() and bridge.intersects(Rect2(Vector2(cell)*6.0-Vector2.ONE*3.0,Vector2.ONE*6.0)):
   return {"error":"Keep the stone bridge clear","minimum":0.0,"maximum":0.0}
 return super._building_ground_info(cells)

func _sample_cliff_cell(cell:Vector2i)->bool:
 var bridge=bridge_bounds()
 if bridge.has_area() and bridge.grow(.01).has_point(Vector2(cell)*6.0) and cell.x in [0,1]:return false
 return super._sample_cliff_cell(cell)
