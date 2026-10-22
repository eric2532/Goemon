extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var m=load("res://scripts/forest/forest_model.gd").new();m.reset(42,{}, {"buildings":[],"trees":[],"deposits":[]},false);m.phase="wave";m.gold=0
 var r=m.ryo
 if not r.has_method("award_enemy_bounty"):
  check(false,"Enemy deaths must directly credit the treasury");finish();return
 var expected=0
 for kind in [0,1,2,3,4]:
  var enemy={"id":100+kind,"hp":0,"variant":kind,"pos":Vector3(180,20,-180)}
  var amount:int=r.BOUNTIES[kind];expected+=amount
  check(r.award_enemy_bounty(enemy)==amount and m.gold==expected,"Existing bounty is immediate for kind %d"%kind)
  check(r.award_enemy_bounty(enemy)==0 and m.gold==expected,"Duplicate death does not pay twice")
 check(r.drops.is_empty() and r.moving_drops.is_empty() and r.expiry_events.is_empty(),"Automatic rewards allocate no physical loot or expiry work")
 check(r.take_bounty_total()==expected and r.take_bounty_total()==0,"UI feedback coalesces rewards and drains once")
 check(r.award_enemy_bounty({"id":-1,"hp":0})==0 and r.award_enemy_bounty({"id":999,"hp":1})==0,"Invalid IDs and living enemies do not pay")
 for i in 4000:expected+=r.award_enemy_bounty({"id":1000+i,"hp":0,"variant":[0,1,3][i%3]})
 check(m.gold==expected and r.drops.is_empty(),"A mass defeat pays all4000 independent bounties without coins")
 check(r.take_bounty_total()==48000,"Mass-defeat feedback remains one accumulated total")
 r.reset();check(r.take_bounty_total()==0 and r.award_enemy_bounty({"id":100,"hp":0,"variant":0})==12,"New match resets claim IDs and pending feedback")
 finish()
func finish():print("RYO_AUTO_BOUNTY_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
