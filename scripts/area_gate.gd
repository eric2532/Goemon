class_name AreaGate
extends Node3D
const INTERACTION_RADIUS=6.0
var game: Node
var destination=0
var forward_gate=true
var rim: MeshInstance3D
var title: Label3D
var unlocked=true
var clock=0.0
var energy: MeshInstance3D
var outer_ring: MeshInstance3D
var beacon: MeshInstance3D
func _ready():
	add_to_group("area_gates")
	for side in [-1,1]:
		Geo.box(self,Vector3(side*3.5,3.5,0),Vector3(1.0,7,1.5),Geo.mat("526f6b"),true)
		Geo.cylinder(self,Vector3(side*3.0,3.3,-.85),.16,6.6,Geo.mat("65ead8",0,1.3))
	Geo.box(self,Vector3(0,7.2,0),Vector3(8.3,.65,1.7),Geo.mat("43655e"),true)
	Geo.box(self,Vector3(0,6.7,-.9),Vector3(7.3,.18,.3),Geo.mat("e9c87b",.3,.6))
	rim=Geo.torus(self,Vector3(0,3.4,0),2.65,2.84,Geo.mat("8bfff1",0,3.8));rim.rotation.x=PI/2
	var material=ShaderMaterial.new();var shader=Shader.new()
	shader.code="""shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
void fragment(){
 vec2 p=UV*2.0-1.0;float r=length(p);float angle=atan(p.y,p.x);
 float spiral=pow(0.5+0.5*sin(angle*7.0-r*30.0+TIME*5.0),3.0);
 float pulse=0.5+0.5*sin(r*45.0-TIME*7.0);
 float rim=exp(-pow((r-0.86)*18.0,2.0));
 float core=exp(-r*r*5.0);
 vec3 color=mix(vec3(0.02,0.25,0.9),vec3(0.25,1.0,0.88),spiral);
 ALBEDO=color;EMISSION=color*(1.8+spiral*2.2)+vec3(0.6,1.0,1.0)*(core+rim)*2.0;
 ALPHA=(1.0-smoothstep(0.87,1.0,r))*(0.55+0.3*pulse)+rim*0.5;
}"""
	material.shader=shader
	var plane=QuadMesh.new();plane.size=Vector2(6.1,6.1)
	energy=Geo.mesh(self,plane,Vector3(0,3.4,0),material);energy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Geo.torus(self,Vector3(0,.1,0),3.4,3.6,Geo.mat("64efda",0,.7))
	outer_ring=Geo.torus(self,Vector3(0,3.4,.05),3.05,3.16,Geo.mat("57bfff",0,3.0));outer_ring.rotation.x=PI/2
	for i in range(12):
		var a=i*TAU/12;var crystal=Geo.sphere(self,Vector3(cos(a)*3.12,3.4+sin(a)*3.12,.05),Vector3(.16,.28,.16),Geo.mat("bdfff5",0,3.5));crystal.rotation.z=-a
	var beacon_shader=Shader.new();beacon_shader.code="""shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
void fragment(){
 float streak=pow(0.5+0.5*sin(UV.x*60.0+UV.y*24.0-TIME*6.0),6.0);
 ALBEDO=vec3(0.1,0.75,1.0);EMISSION=ALBEDO*(1.0+streak*2.0);
 ALPHA=(0.12+streak*0.22)*sin(UV.y*3.14159);
}"""
	var beacon_material=ShaderMaterial.new();beacon_material.shader=beacon_shader
	beacon=Geo.cylinder(self,Vector3(0,32,0),1.25,64,beacon_material);beacon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var particles=GPUParticles3D.new();particles.position=Vector3(0,3.4,0);particles.amount=100;particles.lifetime=1.5
	particles.visibility_aabb=AABB(Vector3(-5,-5,-3),Vector3(10,14,6))
	var process=ParticleProcessMaterial.new();process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis=Vector3.FORWARD;process.emission_ring_radius=3.1;process.emission_ring_inner_radius=2.8;process.emission_ring_height=.2
	process.direction=Vector3.UP;process.spread=100;process.initial_velocity_min=.5;process.initial_velocity_max=2.5;process.gravity=Vector3(0,1.2,0)
	process.scale_min=.035;process.scale_max=.12;particles.process_material=process
	var mote=SphereMesh.new();mote.radius=.5;mote.height=1;mote.radial_segments=8;mote.rings=4;mote.material=Geo.mat("95fff0",0,3.5)
	particles.draw_pass_1=mote;add_child(particles)
	var light=OmniLight3D.new();light.position=Vector3(0,3,1);light.omni_range=18;light.light_color=Color("69ffdc");light.light_energy=3.2;add_child(light)
	title=Label3D.new();title.font_size=42;title.pixel_size=.018;title.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	title.position=Vector3(0,9.0,0);title.outline_size=9;title.no_depth_test=true;add_child(title)
	refresh()
func refresh():
	unlocked=true
	title.text=("ENERGY PORTAL" if forward_gate else "RETURN PORTAL")+"\n"+game.AREA_NAMES[destination]+"\n[F] ENTER · ALWAYS OPEN"
	title.modulate=Color("acf8de")
func prompt()->String:return "F · Enter "+game.AREA_NAMES[destination]+" · Always open"
func _process(delta):
	clock+=delta
	rim.scale=Vector3.ONE*(1+sin(clock*2)*.035)
	energy.rotation.z=clock*.12
	outer_ring.rotation.y=sin(clock*.8)*.12
	beacon.scale.x=1+sin(clock*2)*.12;beacon.scale.z=beacon.scale.x
