extends HeroModel
## Geometry adapter only. The native army still draws and animates the pet.
var bounds=AABB(Vector3(-1,0,-1),Vector3(2,3,2))
var pattern={"pose":5,"duration":1.0,"contacts":[.5],"sounds":[]}
var motions={"weapon":"unarmed"}
func _ready():set_process(false)
func normal_attack_pattern()->Dictionary:return pattern
func qi_blast_chest()->Vector3:return to_global(bounds.get_center())
func qi_blast_height()->float:return bounds.size.y
