class_name DefenseHeroModel
extends HeroModel

# The allies carry the same rig, authored gait and procedural pipe choreography
# as Goemon. Only the imported skin changes; no approximation of his attack is
# baked into a second animation implementation.
var asset_path=""

func _ready():
	body=Node3D.new();add_child(body)
	head=driver("Head",Vector3(0,1.448719,0))
	arms.assign([driver("Arm_L",Vector3(-.406666,1.304718,0)),driver("Arm_R",Vector3(.406666,1.304718,0))])
	legs.assign([driver("Leg_L",Vector3(-.254166,.965830,0)),driver("Leg_R",Vector3(.254166,.965830,0))])
	scarf=driver("Sash",Vector3(.2,1.04,.47))
	rig_visual=load(asset_path).instantiate();body.add_child(rig_visual)
	skeleton=rig_visual.find_child("Skeleton3D",true,false) as Skeleton3D
	assert(skeleton!=null,"Imported ally requires Goemon's Skeleton3D")
	pipe=GameAssets.place(arms[1],"weapons/golden_pipe",Vector3(0,-.94,-.025))
	coin=GoldCoin.make_mesh(arms[1],.78);coin.position=Vector3(0,-.94,-.14);coin.hide()
	locomotion=HeroLocomotion.new(self)
	# The companion advances animation beside its combat clock, including pause.
	set_process(false)
	sync_skeleton()
