class_name SpinWind
extends Node3D
# Three tapered air ribbons follow the powered spin's actual attack progress.
var hero: Hero
var ribbons: Array[MeshInstance3D]=[]
var materials: Array[StandardMaterial3D]=[]

func _ready():
	process_mode=Node.PROCESS_MODE_PAUSABLE
	add_to_group("spin_wind")
	var reach=hero.game.hero_tuning("pipe_range")*1.65*hero.melee_range_multiplier()
	for layer in range(3):
		var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var radius=reach*(.50+layer*.22)
		for i in range(36):
			var t=float(i)/36;var next=float(i+1)/36
			var a=ribbon_pair(t,radius,layer);var b=ribbon_pair(next,radius,layer)
			for point in [a[0],a[1],b[0],b[0],a[1],b[1]]:surface.add_vertex(point)
		surface.generate_normals()
		var material=StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		material.albedo_color=Color(.80,.98,1,0)
		material.emission_enabled=true;material.emission=Color(.52,.87,1);material.emission_energy_multiplier=.65
		var ribbon=Geo.mesh(self,surface.commit(),Vector3.ZERO,material)
		ribbon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ribbons.append(ribbon);materials.append(material)

func ribbon_pair(t: float,radius: float,layer: int)->Array[Vector3]:
	var angle=t*TAU*.78+layer*TAU/3
	var width=sin(t*PI)*(.12+layer*.045)
	var point=Vector3(cos(angle)*radius,.5+layer*.38+t*.8,sin(angle)*radius)
	return [point-Vector3.UP*width,point+Vector3.UP*width]

func _physics_process(_delta):
	if not is_instance_valid(hero) or hero.character_id!=1 or hero.attack_left<=0 or not hero.attack_charged or hero.weapon_slot!=1:
		queue_free();return
	if not hero.game.playing or hero.game.paused:return
	var progress=1.0-hero.attack_left/hero.attack_duration
	var strength=smoothstep(.08,.26,progress)*(1.0-smoothstep(.72,1,progress))
	for i in range(ribbons.size()):
		ribbons[i].rotation.y=-progress*TAU*(1.4+i*.2)
		ribbons[i].scale=Vector3.ONE*(.5+smoothstep(.05,.48,progress)*.5)
		materials[i].albedo_color.a=strength*(.72-i*.12)
