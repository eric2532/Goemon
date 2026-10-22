extends RefCounted
## A fitted, curved sleeve around the actual enlarged katana, in its source frame.
const Strike=preload("res://scripts/goemon_reference_strike.gd")
const READY=Vector3(-.22,1.12,-.25)
const AXIS=Vector3(0,-.04,1)
const SUPPORT=.22
var node: Node3D
var weapon: Node3D
var source_axis: Vector3
var weapon_scale: Vector3
var blade_extent=0.0

func configure(actor):
	weapon=actor.joints.Weapon_Cutlass.node
	source_axis=actor.WEAPON_AXES.samurai.normalized()
	weapon_scale=actor.joints.Weapon_Cutlass.scale
	node=Node3D.new();node.name="SamuraiRedScabbard";actor.model.add_child(node)
	var frame=Basis(Quaternion(Vector3.UP,source_axis))
	var points: Array[Vector3]=[]
	collect_vertices(weapon,Transform3D.IDENTITY,frame.inverse(),points)
	var length=0.0
	for p in points:length=maxf(length,p.y)
	blade_extent=length+.03
	var rings: Array[Vector3]=[]
	var radii: Array[Vector2]=[]
	var radius=Vector2(.052,.034)
	# Fit the whole insertion sweep, including a curved blade moving through
	# every part of the curved sleeve, with clearance at the elliptical corners.
	for p in points:
		if p.y<.23:continue
		radius=radius.max(Vector2(maxf(absf(p.x),absf(p.x+.045))+.022,absf(p.z-.005)+.020))
	var margin=1.0
	for p in points:
		if p.y<.23:continue
		var corner=Vector2(maxf(absf(p.x),absf(p.x+.045))/radius.x,absf(p.z-.005)/radius.y)
		margin=maxf(margin,corner.length()*1.05)
	radius*=margin
	for i in 17:
		var u=i/16.0
		rings.append(Vector3(-.045*sin(PI*u),lerpf(.23,length+.028,u),.005))
		radii.append(radius)
	var shell=MeshInstance3D.new();shell.name="Shell";shell.mesh=sleeve(frame,rings,radii)
	var red=StandardMaterial3D.new();red.albedo_color=Color("b82032");red.roughness=.48
	red.cull_mode=BaseMaterial3D.CULL_DISABLED;shell.material_override=red;node.add_child(shell)
	var lip=MeshInstance3D.new();lip.name="DarkMouth";lip.mesh=sleeve(frame,[rings[0],rings[0]+Vector3.UP*.045],[radii[0]*1.12,radii[0]*1.12])
	var dark=StandardMaterial3D.new();dark.albedo_color=Color("241922");dark.roughness=.7
	dark.cull_mode=BaseMaterial3D.CULL_DISABLED;lip.material_override=dark;node.add_child(lip)

func collect_vertices(root_: Node,transform_: Transform3D,frame: Basis,points: Array[Vector3]):
	if root_ is MeshInstance3D and root_.mesh!=null:
		for surface in root_.mesh.get_surface_count():
			for vertex in root_.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:points.append(frame*(transform_*vertex))
	for child in root_.get_children():
		if child is Node3D:collect_vertices(child,transform_*child.transform,frame,points)

func sleeve(frame: Basis,centers: Array,radii: Array)->ArrayMesh:
	var vertices=PackedVector3Array();var indices=PackedInt32Array()
	for i in centers.size():
		for j in 12:
			var theta=TAU*j/12.0
			vertices.append(frame*(centers[i]+Vector3(cos(theta)*radii[i].x,0,sin(theta)*radii[i].y)))
	for i in centers.size()-1:
		for j in 12:
			var a=i*12+j;var b=i*12+(j+1)%12;var c=a+12;var d=b+12
			indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
	# Closed rounded end; the near end remains open for the blade to slide in.
	var last=vertices.size();vertices.append(frame*centers[-1])
	for j in 12:indices.append_array(PackedInt32Array([last,last-12+j,last-12+(j+1)%12]))
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var builder=SurfaceTool.new();builder.create_from(mesh,0);builder.generate_normals();return builder.commit()

func apply(actor,rig,state: Dictionary):
	if not is_instance_valid(node):configure(actor)
	var sk: Skeleton3D=rig.skeleton
	var hip=rig.pose("Pelvis")*rig.rest.Pelvis.affine_inverse()
	var base=hip*READY
	# Hold the closed tip behind the actor, independently of the fifth cut's
	# model turn or the upper body's wind-up. The sheath never fans sideways.
	var world_aim=(actor.global_basis*Vector3(0,-.04,-1)).normalized()
	var aim=(sk.global_basis.inverse()*world_aim).normalized()
	var attack=state.get("attack")
	var primary=attack is Dictionary and attack.get("primary",false)
	var withdrawal=0.0
	if primary:
		var t=clampf(float(attack.time)/maxf(.001,float(attack.duration)),0,1)
		var draw_end=clampf(float(attack.contact)/maxf(.001,float(attack.duration)),.05,.8)*.35
		withdrawal=smoothstep(0,draw_end,t) if t<=draw_end else (1-smoothstep(.76,.92,t) if t>=.76 else 1.0)
		var hit=clampf(float(attack.contact)/maxf(.001,float(attack.duration)),.05,.8)
		var follow_end=hit+minf(.16,(1-hit)*.26)
		var turn_weight=withdrawal if t<=draw_end or t>=.76 else (1-smoothstep(draw_end,hit*.52,t) if t<hit*.52 else smoothstep(follow_end,.76,t))
		if turn_weight>.00001:
			# Turn the shoulders to give the two short arms enough fore/aft
			# separation to draw the complete blade without turning its sheath.
			var shoulders=rig.pose("Arm_R").origin-rig.pose("Arm_L").origin;shoulders.y=0
			var forward=-aim;forward.y=0
			var turn=shoulders.normalized().signed_angle_to(forward.normalized(),Vector3.UP)*turn_weight
			rig.rotate_chain("Chest",Basis(Vector3.UP,turn))
			rig.rotate_chain("Neck",Basis(Vector3.UP,-turn))
	var scale_=weapon_scale*sk.global_basis.get_scale()*float(state.get("meleeVisualScale",1.0))
	var basis=Basis(Quaternion(source_axis,world_aim)).scaled(scale_)
	# All IK targets are skeleton-local. Avatar growth is applied once by the
	# skeleton transform, while the sword's own visual scale belongs here.
	var length=blade_extent*(weapon_scale*source_axis).length()*float(state.get("meleeVisualScale",1.0))
	var hands=not (float(state.get("shot",0))>0 or float(state.get("drinkGesture",0))>0)
	var origin=base
	if primary:
		var t=clampf(float(attack.time)/maxf(.001,float(attack.duration)),0,1)
		var hit=clampf(float(attack.contact)/maxf(.001,float(attack.duration)),.05,.8)
		var draw_end=hit*.35
		var wind_end=hit*.52
		var follow_end=hit+minf(.16,(1-hit)*.26)
		if t<=draw_end or t>=.76:
			# Split the full blade's withdrawal between both arms. The sheath
			# follows the real IK wrist, so neither limb clamping nor the fifth
			# cut's body turn can make the blade enter beside its housing.
			var target=reachable_grip(rig,base-aim*length*.5*withdrawal,aim*(length*withdrawal+SUPPORT))
			Strike.arm(sk,"R",target,1.0)
			var grip=rig.pose("Hand_R").origin
			origin=grip+aim*length*withdrawal
			weapon.global_transform=Transform3D(basis,sk.global_transform*grip)
		else:
			origin=base+aim*length*.5
			# Rotate only after the full blade clears the mouth. Before returning,
			# align the sword completely, then slide it home along the fitted axis.
			var blend_=1-smoothstep(draw_end,wind_end,t) if t<wind_end else smoothstep(follow_end,.76,t)
			if blend_>0:
				var extracted=reachable_grip(rig,base-aim*length*.5,aim*(length+SUPPORT))
				var target=(sk.global_transform.affine_inverse()*weapon.global_position).lerp(extracted,blend_)
				Strike.arm(sk,"R",target,1.0)
				var grip=rig.pose("Hand_R").origin
				var rotation=weapon.global_basis.orthonormalized().slerp(basis.orthonormalized(),blend_)
				weapon.global_transform=Transform3D(rotation.scaled(scale_),sk.global_transform*grip)
				origin=origin.lerp(grip+aim*length,blend_)
	else:
		if hands:
			Strike.arm(sk,"R",base,1.0)
			origin=rig.pose("Hand_R").origin
		weapon.global_transform=Transform3D(basis,sk.global_transform*origin)
	node.global_transform=Transform3D(basis,sk.global_transform*origin)
	if hands:
		var support=origin+aim*SUPPORT
		Strike.arm(sk,"L",support,1.0)
		# The sheath is carried by this wrist, including any reach constraint
		# while the sword is free and the torso twists through its strike.
		node.global_position=sk.global_transform*rig.pose("Hand_L").origin-sk.global_basis*aim*SUPPORT

func reachable_grip(rig,target: Vector3,support_offset: Vector3)->Vector3:
	# Fit the real hilt and sheath grip to both original arm lengths.
	for repeat in 16:
		for side in ["R","L"]:
			var shoulder=rig.pose("Arm_"+side).origin
			var reach=shoulder.distance_to(rig.pose("Forearm_"+side).origin)+rig.pose("Forearm_"+side).origin.distance_to(rig.pose("Hand_"+side).origin)
			var offset=support_offset if side=="L" else Vector3.ZERO
			var ray=target+offset-shoulder
			if ray.length()>reach*.94:target=shoulder+ray.normalized()*reach*.94-offset
	return target
