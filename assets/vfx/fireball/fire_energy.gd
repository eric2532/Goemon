class_name FireEnergy
extends Node3D
@export var charged=false
var age=0.0
var sparks: CPUParticles3D
func _ready():
	Geo.sphere(self,Vector3.ZERO,Vector3.ONE*.27,Geo.mat("fff2ad",0,2.2))
	for i in range(5 if charged else 3):
		var flame=Geo.spike(self,Vector3(0,-.10,0),Vector3(.05,.48,0),.13,Geo.mat("ff6b18" if i%2==0 else "ed3214",0,1.3))
		flame.name="Flame"+str(i)
	if charged:
		for i in range(2):
			var ring=Geo.torus(self,Vector3.ZERO,.28,.31,Geo.mat("ffd579",0,1.8));ring.rotation=Vector3(i*1.5,.8,0)
	sparks=CPUParticles3D.new();sparks.amount=28 if charged else 12;sparks.lifetime=.28;sparks.explosiveness=0
	sparks.mesh=PrismMesh.new();sparks.mesh.size=Vector3(.025,.10,.025)
	sparks.material_override=Geo.mat("ff9639",0,1.3);sparks.direction=Vector3.UP;sparks.spread=150
	sparks.initial_velocity_min=.4;sparks.initial_velocity_max=1.8;sparks.gravity=Vector3(0,1,0);add_child(sparks)
func _process(delta):
	age+=delta
	for child in get_children():
		if str(child.name).begins_with("Flame"):
			var i=float(str(child.name).trim_prefix("Flame"));var a=age*8+i*TAU/5
			child.position=Vector3(cos(a),.75+sin(a*1.3)*.3,sin(a))*.16
			child.rotation.z=sin(a)*.8
