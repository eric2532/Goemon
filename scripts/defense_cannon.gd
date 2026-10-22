class_name DefenseCannon
extends Node3D

const TARGET_INTERVAL=.25
const MAX_SHELLS=4
const MAX_BLASTS=2
const EFFECT_DISTANCE=140.0
static var shell_mesh: SphereMesh
static var blast_mesh: TorusMesh
static var shell_material: StandardMaterial3D
static var blast_material: StandardMaterial3D
static var ice_shell_mesh: ArrayMesh
static var ice_blast_mesh: ArrayMesh
static var ice_material: StandardMaterial3D
static var feedback_window=-1
static var feedback_counts={"number":0,"burst":0,"sound":0}
var game: Node
var director: Node
var lane=0
var level=1
var cooldown=0.3
var target_clock=0.0
var target: Ninja
var pivot: Node3D
var muzzle: MeshInstance3D
var badge: Label3D
var flash_left=0.0
var shells: Array=[]
var blasts: Array=[]
var shell_pool: Array[MeshInstance3D]=[]
var blast_pool: Array[MeshInstance3D]=[]
var acquire_scans=0
var shots_fired=0
var cannon_trim: Array[MeshInstance3D]=[]
var normal_muzzle_mesh: Mesh

func _ready():
	process_mode=Node.PROCESS_MODE_PAUSABLE
	# Spread acquisition work even when many prebuilt guns share one frame.
	target_clock=float(get_instance_id()%15)/60.0
	cooldown+=target_clock
	if shell_mesh==null:
		shell_mesh=SphereMesh.new();shell_mesh.radius=.35;shell_mesh.height=.7
		shell_mesh.radial_segments=8;shell_mesh.rings=4
		blast_mesh=TorusMesh.new();blast_mesh.inner_radius=.85;blast_mesh.outer_radius=1
		blast_mesh.rings=16;blast_mesh.ring_segments=4
		shell_material=Geo.mat("ffcf71",.3,2.4)
		blast_material=Geo.mat("ffbe60",0,1.2)
	_prepare_ice_meshes()
	var bronze=Geo.mat("cba75f",.65)
	var iron=Geo.mat("24323b",.65)
	Geo.cylinder(self,Vector3(0,.12,0),1.35,.24,iron)
	cannon_trim.append(Geo.cylinder(self,Vector3(0,.38,0),.82,.48,bronze))
	pivot=Node3D.new();pivot.position.y=.92;add_child(pivot)
	Geo.box(pivot,Vector3(0,-.22,.18),Vector3(1.5,.65,1.4),iron)
	var barrel=Geo.cylinder(pivot,Vector3(0,0,-.9),.4,2.65,bronze)
	cannon_trim.append(barrel)
	barrel.rotation.x=PI*.5
	var bore=Geo.cylinder(pivot,Vector3(0,0,-2.24),.32,.03,Geo.mat("111822"))
	bore.rotation.x=PI*.5
	for x in [-.85,.85]:
		var axle=Geo.cylinder(pivot,Vector3(x,-.08,.1),.5,.2,bronze);axle.rotation.z=PI*.5;cannon_trim.append(axle)
	muzzle=Geo.sphere(pivot,Vector3(0,0,-2.5),Vector3(.8,.8,1.4),Geo.mat("ffeaa0",0,3))
	normal_muzzle_mesh=muzzle.mesh
	muzzle.hide()
	badge=Label3D.new();badge.text="CANNON I";badge.position=Vector3(0,2.3,0)
	badge.font_size=28;badge.pixel_size=.018;badge.modulate=Color("ffe1a0")
	badge.billboard=BaseMaterial3D.BILLBOARD_ENABLED;badge.visibility_range_end=85;add_child(badge)
	refresh_upgrades()

func upgrade(new_level: int):
	level=clampi(new_level,1,3);cooldown=minf(cooldown,.2)
	pivot.scale=Vector3.ONE*(1.0+(level-1)*.09)
	refresh_upgrades()

func upgrade_level(id: String)->int:
	return maxi(0,int(director.call("upgrade_level",id))) if is_instance_valid(director) and director.has_method("upgrade_level") else 0

func cannon_branch()->String:
	var value=director.get("cannon_path") if is_instance_valid(director) else null
	return String(value) if value is String else ""

func fire_branch()->String:
	var value=director.get("fire_path") if is_instance_valid(director) else null
	return String(value) if value is String else ""

func ice_enabled()->bool:return upgrade_level("ice_shells")>0
func reload_factor()->float:return maxf(.4,1.0-.15*mini(3,upgrade_level("rapid_reload")))
func sight_factor()->float:return 1.0+.15*mini(2,upgrade_level("long_sights"))

func chilled(enemy)->bool:
	if not is_instance_valid(enemy):return false
	var traits=enemy.get("defense_traits")
	if traits==null:return false
	var remaining=traits.get("slow_left")
	return remaining!=null and float(remaining)>0.0

func shatter_damage(enemy,base_damage: float)->float:
	return base_damage*1.4 if upgrade_level("shatter")>0 and chilled(enemy) else base_damage

func attack_range()->float:return (105.0+(level-1)*12.0)*sight_factor()
func damage()->float:
	var path_factor=1.15 if cannon_branch()=="siege" else (1.4 if cannon_branch()=="piercing" else 1.0)
	return [110.0,165.0,240.0][level-1]*(1.0+.25*mini(3,upgrade_level("cannon_power")))*path_factor
func fire_interval()->float:return [1.8,1.45,1.15][level-1]*reload_factor()
func splash_radius()->float:
	return (6.0+level)*(1.5 if cannon_branch()=="siege" else (.5 if cannon_branch()=="piercing" else 1.0))

func refresh_upgrades():
	if not is_instance_valid(badge):return
	var icy=ice_enabled()
	var title="ICE CANNON" if icy else "CANNON"
	if cannon_branch()=="siege":title="ICE SIEGE" if icy else "SIEGE"
	elif cannon_branch()=="piercing":title="ICE LANCE" if icy else "PIERCING"
	badge.text="%s %s" % [title,["I","II","III"][level-1]]
	badge.modulate=Color("91e9ff") if icy else Color("ffe1a0")
	for piece in cannon_trim:piece.material_override=Geo.mat("83bfd8",.6,.15) if icy else Geo.mat("cba75f",.65)
	if is_instance_valid(muzzle):
		muzzle.mesh=ice_shell_mesh if icy else normal_muzzle_mesh
		muzzle.material_override=ice_material if icy else Geo.mat("ffeaa0",0,3)

static func _prepare_ice_meshes():
	if ice_shell_mesh!=null:return
	ice_material=Geo.mat("77dcff",.25,.8)
	var points=[Vector3(0,.7,0),Vector3(0,-.7,0),Vector3(.33,0,0),Vector3(0,0,.33),Vector3(-.33,0,0),Vector3(0,0,-.33)]
	var faces=[[0,2,3],[0,3,4],[0,4,5],[0,5,2],[1,3,2],[1,4,3],[1,5,4],[1,2,5]]
	var builder=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		for index in face:builder.add_vertex(points[index])
	builder.generate_normals();ice_shell_mesh=builder.commit()
	builder=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for crystal in range(8):
		var angle=float(crystal)*TAU/8
		var center=Vector3(cos(angle)*.78,0,sin(angle)*.78)
		for face in faces:
			for index in face:builder.add_vertex(center+points[index]*Vector3(.42,.6,.42))
	builder.generate_normals();ice_blast_mesh=builder.commit()

func valid_target(enemy)->bool:
	return is_instance_valid(enemy) and not enemy.dead and enemy.defense_lane>=0 and global_position.distance_squared_to(enemy.position)<=attack_range()*attack_range()

func acquire_target():
	acquire_scans+=1;target=null;var furthest=-INF
	var origin=global_position;var range_squared=attack_range()*attack_range()
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.defense_lane<0:continue
		if origin.distance_squared_to(enemy.position)>range_squared:continue
		# Protect the shrine first, including threats after the three lanes merge.
		if enemy.position.z>furthest:furthest=enemy.position.z;target=enemy

func tick(delta: float):
	if not director.active or not game.playing or game.paused or game.transitioning:return
	flash_left=maxf(0,flash_left-delta);muzzle.visible=flash_left>0
	tick_shells(delta);tick_blasts(delta)
	cooldown=maxf(0,cooldown-delta);target_clock-=delta
	# A missing/dead target must not bypass the scan timer: idle batteries
	# otherwise scan every living actor sixty times per second.
	if target_clock<=0:
		acquire_target();target_clock=TARGET_INTERVAL
	if valid_target(target):
		var aim=target.position+Vector3.UP*1.2
		# Elevation makes the artillery silhouette readable above its cover.
		pivot.look_at(aim+Vector3.UP*global_position.distance_to(aim)*.16,Vector3.UP)
		if cooldown<=0:fire_at(target);cooldown=fire_interval()

func fire_at(enemy: Ninja):
	if not valid_target(enemy) or shells.size()>=MAX_SHELLS:return
	var start=pivot.to_global(Vector3(0,0,-2.4))
	var travel=clampf(start.distance_to(enemy.position)/60.0,.3,1.8)
	var destination=enemy.position+Vector3.UP*1.05
	# Modest motion prediction; dodging or stunning a target can make it miss.
	destination+=Vector3(enemy.velocity.x,0,enemy.velocity.z).limit_length(13)*travel*.65
	var shell: MeshInstance3D=null
	if start.distance_squared_to(game.player.position)<EFFECT_DISTANCE*EFFECT_DISTANCE or destination.distance_squared_to(game.player.position)<EFFECT_DISTANCE*EFFECT_DISTANCE:
		shell=effect_node(true,ice_enabled());shell.global_position=start;shell.show()
	var deep=mini(2,upgrade_level("deep_freeze"))
	shells.append({"node":shell,"position":start,"from":start,"to":destination,"age":0.0,"duration":travel,"damage":damage(),"radius":splash_radius(),"ice":ice_enabled(),"piercing":cannon_branch()=="piercing","slow_factor":.6-.1*deep,"slow_duration":2.0+.5*deep})
	shots_fired+=1
	flash_left=.12;muzzle.show()
	if global_position.distance_squared_to(game.player.position)<85*85 and claim_feedback("sound",2):game.sound("heavy_swing",.35,true)

static func claim_feedback(kind: String,limit: int)->bool:
	# Shared across the entire battery: six or twenty-four simultaneous guns
	# retain the same bounded cosmetic budget. Combat damage is never skipped.
	var window=int(Engine.get_physics_frames()/12)
	if window!=feedback_window:
		feedback_window=window;feedback_counts={"number":0,"burst":0,"sound":0}
	if feedback_counts[kind]>=limit:return false
	feedback_counts[kind]+=1;return true

func effect_node(is_shell: bool,icy: bool=false)->MeshInstance3D:
	var pool=shell_pool if is_shell else blast_pool
	for effect in pool:
		if not effect.visible:
			_style_effect(effect,is_shell,icy)
			return effect
	var effect=MeshInstance3D.new()
	_style_effect(effect,is_shell,icy)
	effect.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(effect);effect.set_as_top_level(true)
	pool.append(effect)
	return effect

func _style_effect(effect: MeshInstance3D,is_shell: bool,icy: bool):
	effect.mesh=(ice_shell_mesh if is_shell else ice_blast_mesh) if icy else (shell_mesh if is_shell else blast_mesh)
	effect.material_override=ice_material if icy else (shell_material if is_shell else blast_material)
	effect.rotation=Vector3.ZERO;effect.scale=Vector3.ONE

func tick_shells(delta: float):
	for i in range(shells.size()-1,-1,-1):
		var shell: Dictionary=shells[i];shell.age+=delta
		var fraction=minf(1,shell.age/shell.duration)
		var next: Vector3=shell.from.lerp(shell.to,fraction)
		next.y+=sin(fraction*PI)*(4+shell.duration*7)
		var previous: Vector3=shell.position
		var hit=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(previous,next,1))
		if not hit.is_empty():next=hit.position
		shell.position=next
		if shell.node!=null:
			shell.node.global_position=next
			if shell.get("ice",false):shell.node.rotation=Vector3(shell.age*4,shell.age*3,.4)
		if fraction>=1 or not hit.is_empty():
			explode(next,shell.damage,shell.radius,shell)
			if shell.node!=null:shell.node.hide()
			shells.remove_at(i)

func explode(point: Vector3,hit_damage: float,radius: float,effects: Dictionary={}):
	var near_effect=point.distance_squared_to(game.player.position)<EFFECT_DISTANCE*EFFECT_DISTANCE
	var near_numbers=point.distance_squared_to(game.player.position)<60*60
	var radius_squared=radius*radius
	var space=get_world_3d().direct_space_state
	var icy=bool(effects.get("ice",ice_enabled()))
	var piercing=bool(effects.get("piercing",cannon_branch()=="piercing"))
	if near_effect and claim_feedback("burst",4):game.burst(point,Color("8ae6ff") if icy else Color("ffc477"),6,1.6)
	if near_effect and blasts.size()<MAX_BLASTS:
		var blast=effect_node(false,icy);blast.global_position=point;blast.scale=Vector3.ONE;blast.show()
		blasts.append({"node":blast,"age":0.0,"radius":radius})
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.defense_lane<0:continue
		var aim: Vector3=enemy.position+Vector3.UP
		var difference=aim-point
		if difference.length_squared()>radius_squared:continue
		# Walls shield both the hero and raiders; artillery does real splash
		# damage without confirming or multiplying the player's attack chain.
		var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.15,aim,1)
		if not space.intersect_ray(ray).is_empty():continue
		var direction=difference.normalized();direction.y=0
		var feedback=near_numbers and claim_feedback("number",6)
		var ticket={"tower":true,"tower_feedback":feedback,"armor_piercing":piercing}
		if icy:ticket["element"]="ice"
		enemy.take_hit(shatter_damage(enemy,hit_damage),direction,false,ticket)
		if icy and is_instance_valid(enemy) and not enemy.dead and enemy.has_method("apply_defense_slow"):
			var deep=mini(2,upgrade_level("deep_freeze"))
			enemy.call("apply_defense_slow",float(effects.get("slow_factor",.6-.1*deep)),float(effects.get("slow_duration",2.0+.5*deep)))

func tick_blasts(delta: float):
	for i in range(blasts.size()-1,-1,-1):
		var blast: Dictionary=blasts[i];blast.age+=delta
		blast.node.scale=Vector3.ONE*(1+blast.radius*blast.age/.4)
		if blast.age>=.4:blast.node.hide();blasts.remove_at(i)
