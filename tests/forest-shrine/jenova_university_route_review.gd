extends "res://tests/forest-shrine/west_snow_route_review.gd"
## Reuse the existing fixed-camera reviewer on the locked university corridor.
func run():
 review_root="res://build/Other Files/Asset Toolkit/Jenova University Route/"
 freeze_physics=true
 reuse_gameplay_baseline=false
 await super.run()

func basis_record(name_:String,kind:String,cell:Vector2)->Dictionary:
 var pose=super.basis_record(name_,kind,cell)
 pose.actual_floor=game.model.falan_floor
 pose.actual_source=Original.source_id(game.model.falan_floor)
 check(pose.actual_floor==int(stage.floor),"Capture stays in its labeled map "+name_)
 return pose
