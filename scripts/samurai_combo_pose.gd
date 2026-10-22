extends RefCounted
## Five katana paths on the original articulated Goemon body, with native clocks.
const Strike=preload("res://scripts/goemon_reference_strike.gd")
const Scabbard=preload("res://scripts/samurai_scabbard.gd")
const WRISTS=[
	[Vector3(.75,1.10,.15),Vector3(.30,1.04,-.84),Vector3(-.60,1.0,-.35)],
	[Vector3(-.55,1.12,-.12),Vector3(.26,1.08,-.87),Vector3(.80,1.05,-.25)],
	[Vector3(.70,1.62,.10),Vector3(.30,1.02,-.82),Vector3(-.50,.85,-.35)],
	[Vector3(.26,1.75,.10),Vector3(.28,1.10,-.80),Vector3(.25,.95,-.65)],
	[Vector3(-.60,1.10,-.10),Vector3(.30,1.03,-.82),Vector3(.75,1.05,-.20)]
]
const AXES=[
	[Vector3(1,.05,.10),Vector3(0,.03,-1),Vector3(-1,.03,.20)],
	[Vector3(-1,.08,.15),Vector3(0,.02,-1),Vector3(1,.03,.10)],
	[Vector3(.65,.70,.08),Vector3(.04,-.35,-1),Vector3(-.70,-.40,.20)],
	[Vector3(0,1,.20),Vector3(0,.15,-1),Vector3(0,-.65,-.75)],
	[Vector3(-1,.10,.10),Vector3(0,.06,-1),Vector3(1,.06,.10)]
]
static func sample(stage: int,time: float,duration: float,contact: float)->Dictionary:
	stage=posmod(stage,5)
	var keys=[]
	for i in 3:
		var p=Strike.key(1,["wind","contact","follow"][i])
		p.wrist=WRISTS[stage][i];p.aim=AXES[stage][i]
		if stage==1:
			p.hip.y=-p.hip.y;p.chest.y=-p.chest.y;p.head.y=-p.head.y
		if stage in [2,3]:
			p.chest.x*=1.15
		if stage==4:
			p.hip.y=[.35,-.15,-.45][i];p.chest.y=[.55,-.20,-.65][i]
		keys.append(p)
	var t=clampf(time/maxf(.01,duration),0,1)
	var hit=clampf(contact/maxf(.01,duration),.05,.8)
	var wind=hit*.52;var follow=hit+minf(.16,(1-hit)*.26)
	var ready=Strike.REST.duplicate();ready.wrist=Scabbard.READY;ready.aim=Scabbard.AXIS;ready.weight=1.0
	ready.offhand=Scabbard.READY+Scabbard.AXIS.normalized()*Scabbard.SUPPORT
	var extracted=ready.duplicate();extracted.wrist-=Scabbard.AXIS.normalized()*.80
	# Each cut starts seated, draws quickly, strikes, aligns and slides home.
	if t<wind*.55:return Strike.blend(ready,extracted,smoothstep(0,wind*.55,t))
	if t<wind:return Strike.blend(extracted,keys[0],smoothstep(wind*.55,wind,t))
	if t<hit:return Strike.blend(keys[0],keys[1],pow(inverse_lerp(wind,hit,t),2))
	if t<follow:return Strike.blend(keys[1],keys[2],1-pow(1-inverse_lerp(hit,follow,t),2))
	if t<.76:return Strike.blend(keys[2],extracted,smoothstep(follow,.76,t))
	return Strike.blend(extracted,ready,smoothstep(.76,.92,t))
