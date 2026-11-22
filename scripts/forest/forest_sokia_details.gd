extends RefCounted
## Source paint/contours on the existing palm trunk, frond curves and cliff owner.
const Data=preload("res://assets/maps/falan/sokia/details.gd")
const Atlas=preload("res://assets/maps/falan/sokia/details.png")
const SourceMesh=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Shapes=preload("res://scripts/forest/forest_coastal_buildings.gd")
static var palms={}
static var trunk:Array=[]
static func palm(serial:int)->Mesh:
 if palms.has(serial):return palms[serial]
 if trunk.is_empty():
  var original=load("res://assets/models/environments/palm.glb").instantiate()
  var node=original.find_child("Trunk",true,false)
  trunk=node.mesh.surface_get_arrays(0).duplicate(true)
  original.free()
 var profile:Array=Data.PALMS[serial]
 var skin=SourceMesh.new([Rect2(),Vector2.ZERO,Vector2.ONE,0],Atlas,.031)
 skin.tiles=Data.TILES
 palm_parts(skin,serial,profile,Vector3.ZERO,1.0)
 if not profile[5].is_empty():palm_parts(skin,serial,profile,Vector3(profile[5][1],0,.23),profile[5][0])
 if Data.FRUITS.has(serial):fruit_bunch(skin,serial)
 skin.surface.generate_normals()
 palms[serial]=skin.finish()
 return palms[serial]
static func palm_parts(skin,serial:int,profile:Array,offset:Vector3,scale_:float):
 var broad=serial in [11194,11195,11196]
 var traced=Data.PALM_FRONDS.has(serial)
 var blade=broad or traced
 var crown=crown_point(serial)
 var curves:Array=Data.PALM_FRONDS[serial] if traced else Data.FRONDS
 var width:float=profile[1]/6.84;var girth:float=profile[3]/.5
 skin.surface.set_uv2(Data.TILES["bark_"+str(serial)])
 skin.surface.set_normal(Vector3.UP)
 var vertices:PackedVector3Array=trunk[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=trunk[Mesh.ARRAY_INDEX]
 for i in (indices.size() if not indices.is_empty() else vertices.size()):
  var p:Vector3=vertices[indices[i] if not indices.is_empty() else i]
  var progress=p.y/6.0344
  p=Vector3(p.x*girth+(crown.x-.3*girth)*progress,progress*crown.y,p.z*girth+(crown.z-.2*girth)*progress)
  skin.surface.set_uv(Vector2(p.x*2+p.z,p.y*1.1));skin.surface.add_vertex(offset+p*scale_)
 skin.part=("dry_leaf_" if serial==11194 and scale_<1.0 else "leaf_")+str(serial);skin.feature=false
 for curve_index in curves.size()*(1 if traced or profile[4] else 2):
  var curve:Array=curves[curve_index%curves.size()]
  var secondary=curve_index>=curves.size()
  for section in 15:
   var t=section/15.0
   var a=source_frond_point(curve,t,crown) if traced else frond_point(curve,t,profile,broad)
   var b=source_frond_point(curve,(section+1)/15.0,crown) if traced else frond_point(curve,(section+1)/15.0,profile,broad)
   if secondary:
    a=crown+(a-crown).rotated(Vector3.UP,PI/9)*.76
    b=crown+(b-crown).rotated(Vector3.UP,PI/9)*.76
   var tangent=(b-a).normalized()
   var across=Vector3(-tangent.y,tangent.x,0).normalized() if traced else Vector3(-tangent.z,0,tangent.x).normalized()
   var next_across=across
   if traced:
    var before=source_frond_point(curve,maxf(0,t-.01),crown);var after=source_frond_point(curve,minf(1,t+.01),crown)
    across=Vector3(before.y-after.y,after.x-before.x,0).normalized()
    before=source_frond_point(curve,maxf(0,(section+1)/15.0-.01),crown);after=source_frond_point(curve,minf(1,(section+1)/15.0+.01),crown)
    next_across=Vector3(before.y-after.y,after.x-before.x,0).normalized()
   var original:Vector4=curve[mini(4,int(t*5))].lerp(curve[mini(5,int(t*5)+1)],fmod(t*5,1.0))
   var spread=original.w if traced else original.w*width*(.76 if secondary else 1.0)
   var core=maxf(.025,spread*(.90 if traced else (1.25 if broad else .48)))
   if blade:
    var next_t=(section+1)/15.0
    var next_index=mini(4,int(next_t*5))
    var next_width=curve[next_index].lerp(curve[next_index+1],next_t*5-next_index).w
    var next_spread:float=next_width if traced else next_width*width*(.76 if secondary else 1.0)
    var next_core=maxf(.025,next_spread*(.90 if traced else 1.25))
    var rib=(Vector3.BACK if traced else Vector3.UP)*spread*.12
    var next_rib=(Vector3.BACK if traced else Vector3.UP)*next_spread*.12
    skin.quad(offset+(a-across*core)*scale_,offset+(a+rib)*scale_,offset+(b+next_rib)*scale_,offset+(b-next_across*next_core)*scale_)
    skin.quad(offset+(a+rib)*scale_,offset+(a+across*core)*scale_,offset+(b+next_across*next_core)*scale_,offset+(b+next_rib)*scale_)
   else:skin.quad(offset+(a-across*core)*scale_,offset+(a+across*core)*scale_,offset+(b+across*core)*scale_,offset+(b-across*core)*scale_)
   for side in [-1,1]:
    var root=a+across*side*.018
    var tip=a+across*side*spread*(1.12 if traced else (1.50 if broad else 1.65))+tangent*minf(.18,spread*.5)-Vector3.UP*spread*.16
    var middle=root.lerp(tip,.60)+Vector3.UP*spread*.13
    var half=tangent*minf(.23*width,spread*.55)
    skin.quad(offset+(root-half)*scale_,offset+(middle-half*.5)*scale_,offset+tip*scale_,offset+(middle+half*.5)*scale_)
    skin.quad(offset+(root-half)*scale_,offset+(root+half)*scale_,offset+(middle+half*.5)*scale_,offset+(middle-half*.5)*scale_)
static func fruit_bunch(skin,serial:int):
 skin.surface.set_smooth_group(0)
 var crown=crown_point(serial)
 var bottom=crown.y
 for lobe:Vector4 in Data.FRUITS[serial]:bottom=minf(bottom,crown.y+(lobe.y-lobe.w)*.031)
 skin.part="bark_"+str(serial);skin.feature=false
 Shapes.kili_round(skin,Vector3(crown.x,bottom,crown.z+.17),[Vector2(.018,0),Vector2(.026,crown.y-bottom)])
 skin.part="fruit_"+str(serial);skin.feature=true
 for i in Data.FRUIT_SHAPES[serial].size():
  var shape:Array=Data.FRUIT_SHAPES[serial][i]
  for row in shape.size()-1:
   var lower:Vector3=shape[row];var upper:Vector3=shape[row+1]
   var a=crown+Vector3(lower.x*.031,lower.y*.031,.26+(i%2)*.035)
   var b=crown+Vector3(upper.x*.031,upper.y*.031,.26+(i%2)*.035)
   for side in 16:
    var angle=-side*TAU/16;var next=-(side+1)*TAU/16
    skin.quad(a+Vector3(cos(angle),0,sin(angle))*lower.z*.031,b+Vector3(cos(angle),0,sin(angle))*upper.z*.031,
     b+Vector3(cos(next),0,sin(next))*upper.z*.031,a+Vector3(cos(next),0,sin(next))*lower.z*.031)
static func crown_point(serial:int)->Vector3:
 if Data.PALM_CROWNS.has(serial):return Data.PALM_CROWNS[serial]
 return frond_point(Data.FRONDS[0],0.0,Data.PALMS[serial],serial in [11194,11195,11196])
static func source_frond_point(curve:Array,t:float,crown:Vector3)->Vector3:
 var index=mini(4,int(t*5));var p:Vector4=curve[index].lerp(curve[index+1],t*5-index)
 return crown+Vector3(p.x,p.y,p.z)
static func frond_point(curve:Array,t:float,profile:Array,broad:bool=false)->Vector3:
 var index=mini(4,int(t*5));var p:Vector4=curve[index].lerp(curve[index+1],t*5-index)
 var width:float=profile[1]/6.84
 var rise:float=(-p.y*.8+Vector2(p.x,p.z).length()*.18) if profile[4] else p.y
 if broad:
  var ray=Vector2(p.x-.3,p.z-.2)
  rise=p.y*.7+ray.length()*.22*sin(atan2(ray.y,ray.x)*2.0)
 return Vector3(p.x*width,profile[0]+rise*profile[2]/1.25,p.z*width)
static func build_palms(parent:Node3D,groups:Dictionary):
 for serial in groups:
  var chunks={}
  for pose:Transform3D in groups[serial]:
   var chunk=Vector2i(floori(pose.origin.x/48),floori(pose.origin.z/48))
   if not chunks.has(chunk):chunks[chunk]=[]
   chunks[chunk].append(pose)
  for chunk in chunks:
   var batch=MultiMeshInstance3D.new();batch.name="NativeSokiaPalm_%d_%d_%d"%[serial,chunk.x,chunk.y]
   batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D;batch.multimesh.mesh=palm(serial)
   batch.multimesh.instance_count=chunks[chunk].size()
   for i in chunks[chunk].size():batch.multimesh.set_instance_transform(i,chunks[chunk][i])
   batch.set_meta("source_graphic",serial);parent.add_child(batch)
