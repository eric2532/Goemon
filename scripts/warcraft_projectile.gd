extends "res://scripts/character_projectile.gd"
## Demon bolts reuse shared leases, native rock motion, purple fire and local swept contacts.
const Effects=preload("res://scripts/warcraft_effects.gd")
const HIT_RADIUS=.9
const LIFETIME=4.0
const SPLASH_RADII=[1.0,3.0,5.0]
const IMPACT_TIME=2.0/3.0
static var source:Dictionary={}
static var particle_meshes:Array[QuadMesh]=[]
static var rock_mesh:ArrayMesh
static var rock_spin:Animation
var velocity=Vector3.ZERO
var damage=64.0
var age=0.0
var resolved=false
var impact_age=0.0
var visual:Sprite3D
var rock:MeshInstance3D
var rock_facing=Quaternion.IDENTITY
var core_flames:CPUParticles3D
var particles:Array[CPUParticles3D]=[]

func _ready():
	add_to_group("projectiles")
	visual=Sprite3D.new();visual.texture=preload("res://assets/characters/warcraft/demon-hunter/bolt.png")
	visual.texture=Effects.energy_texture(visual.texture)
	visual.modulate=Effects.energy_color(32)
	visual.pixel_size=.36
	visual.billboard=BaseMaterial3D.BILLBOARD_ENABLED;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	material.disable_fog=true # Warcraft's native glow is Unfogged; fog fills its additive quad.
	material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;material.vertex_color_use_as_albedo=true;material.albedo_texture=visual.texture
	visual.material_override=material
	add_child(visual)
	if source.is_empty():source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/warcraft/demon-hunter/missile/source.json"))
	if rock_mesh==null:
		var d:Dictionary=source.rock;var g:Dictionary=d.geoset;var pivot:Array=d.bone.PivotPoint
		var vertices=PackedVector3Array();var normals=PackedVector3Array();var uv=PackedVector2Array();var indices=PackedInt32Array()
		# Three times the particle art scale gives the requested substantial meteor core.
		for i in range(0,g.Vertices.size(),3):
			vertices.append(Vector3(g.Vertices[i]-pivot[0],g.Vertices[i+2]-pivot[2],pivot[1]-g.Vertices[i+1])*.09)
			normals.append(Vector3(g.Normals[i],g.Normals[i+2],-g.Normals[i+1]))
		for i in range(0,g.TVertices[0].size(),2):uv.append(Vector2(g.TVertices[0][i],g.TVertices[0][i+1]))
		for i in range(0,g.Faces.size(),3):indices.append_array(PackedInt32Array([g.Faces[i],g.Faces[i+2],g.Faces[i+1]]))
		var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
		rock_mesh=ArrayMesh.new();rock_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var fire=ShaderMaterial.new();fire.shader=preload("res://assets/characters/warcraft/demon-hunter/missile/fire_core.gdshader")
		fire.set_shader_parameter("flame_texture",Effects.energy_texture(preload("res://assets/characters/warcraft/demon-hunter/missile/flame.png")))
		fire.set_shader_parameter("tint",Effects.energy_color(32));rock_mesh.surface_set_material(0,fire)
		rock_spin=Animation.new();rock_spin.length=float(d.duration)/1000.0;rock_spin.loop_mode=Animation.LOOP_LINEAR
		rock_spin.add_track(Animation.TYPE_ROTATION_3D)
		for sample in d.samples:
			var q:Array=sample.rotation
			rock_spin.rotation_track_insert_key(0,float(sample.time)/1000.0,Quaternion(q[0],q[2],-q[1],q[3]).normalized())
	rock=MeshInstance3D.new();rock.mesh=rock_mesh;rock.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(rock)
	for i in source.emitters.size():
		var d:Dictionary=source.emitters[i]
		if particle_meshes.size()<=i:
			var mesh=QuadMesh.new();mesh.size=Vector2.ONE*2
			var mat=material.duplicate() as StandardMaterial3D
			mat.albedo_texture=Effects.energy_texture(load("res://assets/characters/warcraft/demon-hunter/missile/"+("flame.png" if i==1 else "clouds.png")))
			mat.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES;mat.particles_anim_h_frames=d.Columns;mat.particles_anim_v_frames=d.Rows;mat.particles_anim_loop=false
			mesh.material=mat;particle_meshes.append(mesh)
		var p=CPUParticles3D.new();p.emitting=false;p.mesh=particle_meshes[i];p.local_coords=false
		p.amount=[45,50,32][i];p.lifetime=d.LifeSpan;p.one_shot=i!=2;p.explosiveness=1.0 if p.one_shot else 0.0
		p.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;p.emission_box_extents=Vector3(d.Width,0,d.Length)*.015
		p.direction=Vector3.UP;p.spread=d.Latitude;p.gravity=Vector3.DOWN*float(d.Gravity)*.03
		p.initial_velocity_min=float(d.Speed)*.03*(1.0-d.Variation);p.initial_velocity_max=float(d.Speed)*.03*(1.0+d.Variation)
		var ramp=Gradient.new();ramp.offsets=PackedFloat32Array([0,d.Time,1]);var colors=PackedColorArray()
		for j in 3:colors.append(Effects.energy_tint(32,Color(d.SegmentColor[j][0],d.SegmentColor[j][1],d.SegmentColor[j][2],float(d.Alpha[j])/255.0)))
		ramp.colors=colors;p.color_ramp=ramp
		p.scale_amount_min=float(d.ParticleScaling[0])*.03;p.scale_amount_max=p.scale_amount_min
		var curve=Curve.new();curve.max_value=8;curve.add_point(Vector2(0,1));curve.add_point(Vector2(d.Time,float(d.ParticleScaling[1])/d.ParticleScaling[0]));curve.add_point(Vector2(1,float(d.ParticleScaling[2])/d.ParticleScaling[0]));p.scale_amount_curve=curve
		p.anim_speed_min=1.0/float(d.LifeSpan);p.anim_speed_max=p.anim_speed_min
		p.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(p);p.hide();particles.append(p)
	# A local flame shroud covers the enlarged core while the original world-space trail follows behind.
	core_flames=CPUParticles3D.new();core_flames.emitting=false;core_flames.mesh=particle_meshes[1]
	core_flames.amount=24;core_flames.lifetime=.4;core_flames.preprocess=.4;core_flames.local_coords=true
	core_flames.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE;core_flames.emission_sphere_radius=1.35
	core_flames.spread=180;core_flames.gravity=Vector3.ZERO;core_flames.initial_velocity_min=.7;core_flames.initial_velocity_max=1.2
	core_flames.scale_amount_min=1.8;core_flames.scale_amount_max=2.1;core_flames.scale_amount_curve=particles[2].scale_amount_curve
	core_flames.color_ramp=particles[2].color_ramp;core_flames.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core_flames);core_flames.hide()
func restart_visual():
	age=0;resolved=false;impact_age=0;visual.show()
	rock_facing=Quaternion(Vector3.RIGHT,velocity.normalized()) if velocity.length_squared()>.00001 else Quaternion.IDENTITY
	rock.quaternion=rock_facing*rock_spin.rotation_track_interpolate(0,0);rock.set_instance_shader_parameter("playback_age",0.0);rock.show()
	core_flames.restart();core_flames.show();core_flames.emitting=true
	for p in particles:p.restart();p.emitting=false;p.hide()
	particles[2].show();particles[2].emitting=true
func retire():
	core_flames.emitting=false
	for p in particles:p.emitting=false
	super.retire()
func _physics_process(delta:float):
	if not is_instance_valid(hero) or not game.playing:retire();return
	if game.paused or game.transitioning:return
	if resolved:
		impact_age+=delta
		if impact_age>=IMPACT_TIME:retire()
		return
	var step=minf(delta,maxf(0,LIFETIME-age));age+=step
	rock.quaternion=rock_facing*rock_spin.rotation_track_interpolate(0,fmod(age,rock_spin.length))
	rock.set_instance_shader_parameter("playback_age",age)
	var end=global_position+velocity*step
	var wall=AttackChain.world_ray(self,global_position,end)
	if not wall.is_empty():end=wall.position
	var hit=AttackChain.nearest_contact(game,self,global_position,end,HIT_RADIUS*skill_factor("hit_area"))
	if not hit.is_empty():
		explode(hit.point,hit.enemy);return
	if not wall.is_empty():explode(wall.position+wall.normal*.025);return
	global_position=end
	if age>=LIFETIME:retire()

func explode(point:Vector3,direct:Ninja=null):
	if resolved:return
	resolved=true;global_position=point;visual.hide();rock.hide();particles[2].emitting=false
	core_flames.emitting=false;core_flames.hide()
	for i in 2:particles[i].show();particles[i].restart()
	var struck={};var confirmed=false
	for enemy in AttackChain.enemy_candidates(game,point,SPLASH_RADII[2]):
		if not is_instance_valid(enemy) or enemy.dead or struck.has(enemy.get_instance_id()):continue
		struck[enemy.get_instance_id()]=true
		var contact=AttackChain.segment_contact(enemy,point,point,SPLASH_RADII[2])
		if contact.is_empty() or not AttackChain.clear_line(self,point,contact.point):continue
		var distance=point.distance_to(contact.point)
		# Warcraft's 50/150/250 radii retain their 100/50/25 percent damage bands.
		var factor=1.0 if enemy==direct or distance<=SPLASH_RADII[0] else .5 if distance<=SPLASH_RADII[1] else .25
		enemy.take_hit(damage*factor,velocity.normalized(),false,attack_ticket)
		confirmed=true
		if hero.ai_controlled:game.confirm_ally_impact(enemy,contact.point,velocity.normalized(),1,true,32,false)
		else:game.confirm_impact(enemy,contact.point,velocity.normalized(),1,true,32,false)
	if not confirmed:game.sound("wc_missile_hit",.7,false,attack_ticket,32)
