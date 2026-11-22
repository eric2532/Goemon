extends RefCounted
## One prepared field and mesh owns both sides of the canal bridge.
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const MASK=preload("res://assets/maps/falan/east_road_surface.png")
const ORIGIN=Vector2(-675,-204)
const STEP=3.0
const CITY_BRIDGE=Rect2(-6,63,18,90)
const CANAL=Rect2(1660.5,694.5,18,9)
static var prepared:Resource
static var ground_mesh:ArrayMesh

static func mask()->Texture2D:return Regions.joined_mask("east_gate",MASK,ORIGIN)

static func field()->Resource:
 if prepared!=null:return prepared
 var image=mask().get_image()
 var count=maxi(image.get_width(),image.get_height())
 var heights=PackedFloat32Array();heights.resize(count*count)
 var bed=heights.duplicate()
 var covered=PackedByteArray();covered.resize(heights.size())
 var bridges=covered.duplicate()
 var frame=Regions.frame("east_gate")
 for z in image.get_height():
  for x in image.get_width():
   var tile=image.get_pixel(x,z)
   if tile.a<.5:continue
   var i=z*count+x
   var at=ORIGIN+Vector2(x,z)*STEP
   var source=frame*at
   var bank=6.0
   if at.y>244:
    bank+=(3*sin(at.x*.023+at.y*.016)+2*cos(at.y*.027-at.x*.011))*smoothstep(244,326,at.y)
   bank=lerpf(bank,6.0,smoothstep(105,140,-at.x))
   bank=lerpf(bank,Regions.land_height(source),smoothstep(370,405,at.y))
   bank=Regions.village_bank("east_gate",at,bank)
   heights[i]=bank*(1-tile.r);bed[i]=heights[i]
   covered[i]=int(tile.r<.5)
   if CITY_BRIDGE.has_point(at) or CANAL.has_point(source):
    heights[i]=6.0;bed[i]=0.0;covered[i]=1;bridges[i]=1
 prepared=Resource.new()
 for row in [["width",count],["spacing",STEP],["heights",heights],["bed",bed],["covered",covered],["bridges",bridges]]:prepared.set_meta(row[0],row[1])
 return prepared

static func mesh()->ArrayMesh:
 if ground_mesh!=null:return ground_mesh
 var data=field()
 var count:int=data.get_meta("width")
 var bed:PackedFloat32Array=data.get_meta("bed")
 var columns=MASK.get_width()
 var rows=MASK.get_height()
 var vertices=PackedVector3Array();vertices.resize(count*count)
 var normals=vertices.duplicate()
 var indices=PackedInt32Array();indices.resize((columns-1)*(rows-1)*6)
 for z in count:
  for x in count:
   var i=z*count+x
   vertices[i]=Vector3(ORIGIN.x+x*STEP,bed[i],ORIGIN.y+z*STEP)
   var dx=bed[z*count+mini(x+1,count-1)]-bed[z*count+maxi(x-1,0)]
   var dz=bed[mini(z+1,count-1)*count+x]-bed[maxi(z-1,0)*count+x]
   normals[i]=Vector3(-dx,STEP*2,-dz).normalized()
   if x>=columns-1 or z>=rows-1:continue
   var slot=(z*(columns-1)+x)*6
   indices[slot]=i;indices[slot+1]=i+1;indices[slot+2]=i+count
   indices[slot+3]=i+1;indices[slot+4]=i+count+1;indices[slot+5]=i+count
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
 ground_mesh=ArrayMesh.new();ground_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return ground_mesh
