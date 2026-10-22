extends Node3D
## Native blade atlas and two 64-particle glow paths, bound to animated markers.
const SHADER=preload("res://scripts/master_chief_energy_sword.gdshader")
const ATLAS=preload("res://assets/characters/master_chief/energy_sword_texture.png")
const GLOW=preload("res://assets/characters/master_chief/energy_sword_glow.png")
const METRES=3.048
const PARTICLES_PER_BLADE=64
# Original marker order is unsorted in JMS. These are its two forward paths.
const PATHS=[[2,3,0,4,1],[2,1,3,0,4]]
var model:Node3D
var camera:Camera3D
var glow:MultiMeshInstance3D
var anchors:Array=[]
var clock=0.0
var blade_surfaces=0
func configure(weapon:Node3D,view_camera:Camera3D,layer:int):
	model=weapon;camera=view_camera
	var material=ShaderMaterial.new();material.shader=SHADER;material.set_shader_parameter("native_atlas",ATLAS)
	_apply_blades(model,material)
	for blade in 2:
		var path:Array=[]
		for index in PATHS[blade]:path.append(model.find_child("SwordGlow%d_%d"%[blade+1,index],true,false))
		anchors.append(path)
	glow=MultiMeshInstance3D.new();glow.name="NativeSwordGlows";glow.layers=layer
	glow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh=MultiMesh.new();mesh.transform_format=MultiMesh.TRANSFORM_3D;mesh.use_colors=true
	var quad=QuadMesh.new();quad.size=Vector2.ONE;mesh.mesh=quad;mesh.instance_count=2*PARTICLES_PER_BLADE
	glow.multimesh=mesh
	var glow_material=ShaderMaterial.new();glow_material.shader=SHADER
	glow_material.set_shader_parameter("native_atlas",GLOW);glow_material.set_shader_parameter("sprite_glow",true)
	glow.material_override=glow_material;add_child(glow)
func _apply_blades(node:Node,material:ShaderMaterial):
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var source=node.mesh.surface_get_material(surface)
			if source!=null and source.resource_name.begins_with("es blade"):
				node.set_surface_override_material(surface,material);blade_surfaces+=1
	for child in node.get_children():_apply_blades(child,material)
func _process(delta:float):
	if not is_instance_valid(glow) or not is_instance_valid(model):return
	glow.visible=model.is_visible_in_tree()
	if not glow.visible:return
	clock+=delta
	for blade in 2:
		var path:Array=anchors[blade]
		if path.any(func(anchor):return not is_instance_valid(anchor)):continue
		var points:Array[Vector3]=[];var distances:Array[float]=[0.0]
		for anchor in path:points.append(anchor.global_position)
		for i in range(1,points.size()):distances.append(distances[-1]+points[i-1].distance_to(points[i]))
		var length=maxf(.001,distances[-1])
		for index in PARTICLES_PER_BLADE:
			var direction=1.0 if index%2==0 else -1.0
			var distance=fposmod(float(index)/PARTICLES_PER_BLADE*length+clock*.05*METRES*direction,length)
			var segment=0
			while segment<points.size()-2 and distance>distances[segment+1]:segment+=1
			var amount=(distance-distances[segment])/maxf(.001,distances[segment+1]-distances[segment])
			var position=_curve(points[maxi(0,segment-1)],points[segment],points[segment+1],points[mini(points.size()-1,segment+2)],amount)
			var tangent=(points[segment+1]-points[segment]).normalized()
			var cross=tangent.cross(Vector3.UP).normalized()
			if cross.is_zero_approx():cross=Vector3.RIGHT
			position+=cross.rotated(tangent,clock+index*2.399963)*(.01*METRES)
			var mix_=float((index*37)%PARTICLES_PER_BLADE)/PARTICLES_PER_BLADE
			var size_=lerpf(.05,.11,mix_)*METRES
			var basis=camera.global_basis.orthonormalized().scaled(Vector3(size_,size_,1))
			glow.multimesh.set_instance_transform(blade*PARTICLES_PER_BLADE+index,glow.global_transform.affine_inverse()*Transform3D(basis,position))
			glow.multimesh.set_instance_color(blade*PARTICLES_PER_BLADE+index,Color(0,.356863,.356863).lerp(Color(0,.0862745,.109804),mix_))
func _curve(a:Vector3,b:Vector3,c:Vector3,d:Vector3,t:float)->Vector3:
	return .5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
