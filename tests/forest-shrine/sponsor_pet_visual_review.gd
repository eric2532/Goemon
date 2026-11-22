extends "res://tests/forest-shrine/bear_reward_pet_visual_review.gd"
func reward_category()->String:return "贊助"
func reward_count()->int:return 56
func review_output()->String:return "res://build/Other Files/Asset Toolkit/Sponsor Pets/Rendered/"
func capture_sheet(filename:String,rows:Array):
 await super.capture_sheet(filename,rows)
 if filename!=review_output()+"00-18.png":return
 var entries=[]
 for frame in [8,9,10,14]:
  entries.append({"source":Pets,"skin":Pets.skin("joy-ex:963"),"name":"雷公 · death frame "+str(frame),"state":36,"clock":float(frame)/15.0})
 await super.capture_sheet(review_output()+"raikou-death.png",[{"title":"雷公 · original death sequence / direction 1","entries":entries}])
