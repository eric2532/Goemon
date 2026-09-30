class_name EnemyCrowd
extends Node3D
# Nearby combatants retain their rigs. The rest share one animated GPU draw.
const RIG_BUDGET=32
const VIEW_DISTANCE=110.0
var game: Node
var batch: MultiMeshInstance3D
var material: ShaderMaterial
var age=0.0
var selection_clock=0.0
func _ready():
	process_priority=40
	var source=GameAssets.instantiate_model("enemies/ninja_crowd")
	var mesh=source.find_children("*","MeshInstance3D",true,false)[0].mesh
	batch=MultiMeshInstance3D.new();batch.multimesh=MultiMesh.new()
	batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D;batch.multimesh.use_custom_data=true
	batch.multimesh.mesh=mesh;batch.multimesh.instance_count=1024;batch.multimesh.visible_instance_count=0
	batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader=Shader.new();shader.code="""shader_type spatial;
render_mode cull_disabled;
uniform float clock=0.0;
varying vec4 actor_data;
mat3 rotate_x(float a){float c=cos(a);float s=sin(a);return mat3(vec3(1,0,0),vec3(0,c,s),vec3(0,-s,c));}
void vertex(){
 actor_data=INSTANCE_CUSTOM;
 float limb=round(UV.x*8.0);float phase=clock*(5.0+INSTANCE_CUSTOM.y*8.0)+INSTANCE_CUSTOM.x;
 float motion=INSTANCE_CUSTOM.y;vec3 pivot=vec3(0);float swing=0.0;
 if(limb==1.0||limb==2.0){pivot=vec3(limb==1.0?-0.25:0.25,0.91,0);swing=sin(phase+(limb==2.0?3.14159:0.0))*0.7*motion;}
 if(limb==3.0||limb==4.0){pivot=vec3(limb==3.0?-0.49:0.49,1.58,0);swing=-sin(phase+(limb==4.0?3.14159:0.0))*0.6*motion;}
 mat3 turn=rotate_x(swing);VERTEX=pivot+turn*(VERTEX-pivot);NORMAL=turn*NORMAL;
 VERTEX.y+=abs(sin(phase))*0.045*motion;
}
void fragment(){
 vec3 tint=vec3(1.0);
 if(actor_data.z>0.5&&actor_data.z<1.5)tint=vec3(0.4,1.35,1.0);
 if(actor_data.z>1.5&&actor_data.z<2.5)tint=vec3(1.5,1.1,0.45);
 if(actor_data.z>2.5)tint=vec3(1.15,0.65,1.6);
 ALBEDO=COLOR.rgb*mix(vec3(1.0),tint,1.0-smoothstep(0.25,0.7,max(COLOR.r,max(COLOR.g,COLOR.b))));ROUGHNESS=0.8;
 if(actor_data.w>0.5){ALBEDO=mix(ALBEDO,vec3(0.35,0.8,1.0),0.7);}
}"""
	material=ShaderMaterial.new();material.shader=shader;batch.material_override=material;add_child(batch);source.free()
func select_rigs():
	var candidates=[];var focus=game.player.global_position
	for enemy in game.enemies:
		if not is_instance_valid(enemy):continue
		if enemy.swarm:
			enemy.render_full=false
			continue
		var distance=enemy.global_position.distance_squared_to(focus)
		enemy.render_full=enemy.boss or enemy.practice or game.player.sky_strike.target==enemy and game.player.sky_strike.active
		if not enemy.render_full and distance<45*45:candidates.append([distance,enemy])
	candidates.sort_custom(func(a,b):return a[0]<b[0])
	for i in range(mini(RIG_BUDGET,candidates.size())):candidates[i][1].render_full=true
func _process(delta):
	if not game.playing or game.paused or game.transitioning:return
	age+=delta;selection_clock-=delta
	if selection_clock<=0:selection_clock=.2;select_rigs()
	material.set_shader_parameter("clock",age)
	var count=0;var focus=game.player.global_position
	# Resizing a MultiMesh clears its transforms. Grow before filling the buffer
	# so crossing 1,024 (or 2,048, etc.) cannot erase already-written actors.
	if game.enemies.size()>batch.multimesh.instance_count:
		var capacity=batch.multimesh.instance_count
		while capacity<game.enemies.size():capacity*=2
		batch.multimesh.instance_count=capacity
	for enemy in game.enemies:
		if not is_instance_valid(enemy):continue
		var distance=enemy.global_position.distance_squared_to(focus)
		var shown=distance<VIEW_DISTANCE*VIEW_DISTANCE or enemy.practice
		var target=game.player.sky_strike.active and game.player.sky_strike.target==enemy
		var full=(enemy.render_full or target) and shown and not enemy.swarm
		enemy.distance_asleep=not shown;enemy.visible=shown;enemy.model.visible=full
		if enemy.name_tag!=null:enemy.name_tag.visible=full and distance<18*18
		if not shown or full:continue
		var transform=enemy.global_transform
		transform.basis=transform.basis*enemy.model.basis
		batch.multimesh.set_instance_transform(count,transform)
		batch.multimesh.set_instance_custom_data(count,Color(float(enemy.get_instance_id()%100)*.13,clampf(Vector2(enemy.velocity.x,enemy.velocity.z).length()/7,0,1),float(enemy.variant),1 if enemy.frozen_left>0 else 0))
		count+=1
	batch.multimesh.visible_instance_count=count
