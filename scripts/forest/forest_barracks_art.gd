extends RefCounted
## Low stone fort with an open battlement deck and the towers' masonry palette.
const Stone=preload("res://scripts/forest/forest_stone_fort.gd")
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
static func build(root:Node3D):
	var deck=Profile.BARRACKS_DECK_HEIGHT
	Geo.box(root,Vector3(0,.35,0),Vector3(17.8,.7,17.8),Stone.material(Color("68796f")))
	Geo.box(root,Vector3(0,Profile.BARRACKS_BODY_HEIGHT*.5,0),Vector3(17.2,Profile.BARRACKS_BODY_HEIGHT,17.2),Stone.material())
	Geo.box(root,Vector3(0,Profile.BARRACKS_DECK_CENTER,0),Vector3(17.8,Profile.BARRACKS_DECK_THICKNESS,17.8),Stone.material(Color("adb29f"),false))
	for x in [-7.9,7.9]:
		for z in [-7.9,7.9]:
			Geo.box(root,Vector3(x,deck*.5,z),Vector3(1.4,deck,1.4),Stone.material(Color("778779")))
			Geo.box(root,Vector3(x,deck+.2,z),Vector3(1.7,.4,1.7),Stone.material(Color("b0b4a2"),false))
	for side in [-1,1]:
		Geo.box(root,Vector3(0,deck+.6,side*8.15),Vector3(17.2,1.2,.9),Stone.material(Color("8c9788")))
		Geo.box(root,Vector3(side*8.15,deck+.6,0),Vector3(.9,1.2,17.2),Stone.material(Color("8c9788")))
		for slot in [-6,-2,2,6]:
			Geo.box(root,Vector3(slot,deck+1.7,side*8.15),Vector3(2.2,1.0,1.1),Stone.material(Color("a4ad99")))
			Geo.box(root,Vector3(side*8.15,deck+1.7,slot),Vector3(1.1,1.0,2.2),Stone.material(Color("a4ad99")))
		for slot in [-4.5,4.5]:Geo.box(root,Vector3(side*8.615,3.2,slot),Vector3(.035,1.65,.28),Geo.mat("35433c"))
	Geo.box(root,Vector3(0,2.25,8.63),Vector3(4.1,4.2,.08),Geo.mat("263832"))
	for x in [-2.3,2.3]:Geo.box(root,Vector3(x,2.3,8.8),Vector3(.55,4.6,.65),Stone.material(Color("b0b4a2"),false))
	Geo.box(root,Vector3(0,4.7,8.8),Vector3(5.2,.6,.65),Stone.material(Color("b0b4a2"),false))
	for x in [-5.7,5.7]:Geo.box(root,Vector3(x,3.2,8.64),Vector3(.28,1.65,.035),Geo.mat("35433c"))
	Geo.beam(root,Vector3(6.6,deck,5.5),Vector3(6.6,10.2,5.5),.1,Geo.mat("695238"))
	Geo.box(root,Vector3(5.2,9.4,5.5),Vector3(2.8,1.55,.08),Geo.mat("b44d3d"))
	Geo.box(root,Vector3(5.2,9.4,5.56),Vector3(.42,.9,.04),Geo.mat("edce8c"))
