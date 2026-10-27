extends RefCounted
## Authored valley dimensions. Bake with tools/build_wind_meadow_map.gd.
const CLEARINGS=[Vector3(0,18,-186),Vector3(186,10,0),Vector3(0,6,186),Vector3(-186,12,0)]
const LANDMARK=Vector2i(-9,-9)
static var route_cache:Dictionary={}
static func clearings(scale_:float=1.0)->Array:
 var result=[]
 for p in CLEARINGS:result.append(p*Vector3(scale_,1,scale_))
 return result
static func routes(scale_:float=1.0)->Array:
 if route_cache.has(scale_):return route_cache[scale_]
 var result=[
  [Vector2(-72,-66),Vector2(0,-84),Vector2(78,-66),Vector2(84,66),Vector2(0,84),Vector2(-78,66),Vector2(-72,-66)],
  [Vector2(-150,0),Vector2(-114,-114),Vector2(0,-150),Vector2(114,-114),Vector2(150,0),Vector2(114,114),Vector2(0,150),Vector2(-114,114),Vector2(-150,0)],
  [Vector2(3,42),Vector2(3,84),Vector2(CLEARINGS[2].x,CLEARINGS[2].z)],
  [Vector2(0,-84),Vector2(CLEARINGS[0].x,CLEARINGS[0].z)],
  [Vector2(84,6),Vector2(CLEARINGS[1].x,CLEARINGS[1].z)],
  [Vector2(-78,0),Vector2(CLEARINGS[3].x,CLEARINGS[3].z)]]
 for route in result:
  for i in route.size():route[i]*=scale_
 if scale_>=2.0:
  var gates=[Vector2(-3,-48),Vector2(48,-3),Vector2(3,48),Vector2(-48,3)]
  for i in 4:
   var camp:Vector3=CLEARINGS[i]*Vector3(scale_,1,scale_)
   result[i+2]=[gates[i],gates[i].normalized()*168,Vector2(camp.x,camp.z)]
 else:result[2][0]=Vector2(3,42)
 route_cache[scale_]=result
 return result
static func road_distance(p:Vector2,scale_:float=1.0)->float:
 var result=INF
 for route in routes(scale_):
  for i in range(1,route.size()):
   var a:Vector2=route[i-1];var b:Vector2=route[i]
   result=minf(result,p.distance_to(a+(b-a)*clampf((p-a).dot(b-a)/(b-a).length_squared(),0,1)))
 return result
static func surface(x:float,z:float,scale_:float=1.0)->float:
 var world=Vector2(x,z);x/=scale_;z/=scale_
 var p=Vector2(x,z);var angle=atan2(z,x);var r=p.length()
 var h=maxf(18*smoothstep(75,162,-z),maxf(10*smoothstep(75,162,x),maxf(12*smoothstep(75,162,-x),6*smoothstep(84,162,z))))
 # Four broken interior shoulders divide combat lawns; both road rings stay wide.
 var shoulder=0.0
 for center in [Vector2(-105,-90),Vector2(105,-87),Vector2(-105,90),Vector2(105,90)]:
  shoulder=maxf(shoulder,28*(1-smoothstep(18,34,p.distance_to(center))))
 h+=shoulder*smoothstep(19,30,road_distance(p))
 var rim=204+9*sin(angle*3+.6)+6*sin(angle*7-1.2)+3*sin(angle*11)
 h+=smoothstep(rim-10,rim+9,r)*(42+10*sin(angle*5)+6*sin(angle*9+.4))
 # Keep the barracks foundations level where their clearings meet the cliff rim.
 for camp in CLEARINGS:
  h=lerpf(camp.y,h,smoothstep(18,30,p.distance_to(Vector2(camp.x,camp.z))))
 if scale_>=2.0:
  for camp in clearings(scale_):
   # Full-size forts and their exits need level foundations, not stretched models.
   h=lerpf(camp.y,h,smoothstep(70,100,world.distance_to(Vector2(camp.x,camp.z))))
 return h
