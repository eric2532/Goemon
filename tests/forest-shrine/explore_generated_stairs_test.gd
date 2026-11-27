extends "res://tests/forest-shrine/original_maps_test.gd"
## A valid arrival must leave the stair without crossing its own return trigger.
func run():
 var generated=Original.generated();var bad=[];var floors=0
 var seeds=[0,1,2,3,17,341,20261127,1795780251]
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--more-seeds="):
   for i in int(arg.trim_prefix("--more-seeds=")):seeds.append(65537*(i+1)+108)
 for seed_ in seeds:
  for key in generated.SPECS:
   for n in [1,generated.count(key,seed_)]:
    var id:int=generated.floor_id(key,n);var row=Original.state(id,seed_);var doors=generated.doors(id,seed_)
    for entry in 2:
     var arrival:Vector2i=doors[entry];var other:Vector2i=doors[1-entry]
     var seen={other:true};var queue=[other];var cursor=0
     while cursor<queue.size():
      var at:Vector2i=queue[cursor];cursor+=1
      for direction in [Vector2i.DOWN,Vector2i.RIGHT,Vector2i.UP,Vector2i.LEFT]:
       var next=at+direction
       if next==arrival or seen.has(next) or not Original.open(row.bits,row.size,next):continue
       seen[next]=true;queue.append(next)
     var valid=Original.open(row.bits,row.size,arrival) and [Vector2i.DOWN,Vector2i.RIGHT,Vector2i.UP,Vector2i.LEFT].any(func(step):return seen.has(arrival+step))
     check(valid,"Generated stair reaches the opposite stair: %s map=%d seed=%d arrival=%s other=%s"%[key,id,seed_,arrival,other])
     if not valid:bad.append({"branch":key,"map":id,"seed":seed_,"arrival":str(arrival),"other":str(other),"size":str(row.size),"template":row.get("native_path","")})
    floors+=1
  Original.states.clear()
 var file=FileAccess.open("res://build/Other Files/Asset Toolkit/Explore Access/generated-stair-connectivity.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"seeds":seeds,"floors":floors,"failures":bad},"  "));file.close()
 print("EXPLORE_GENERATED_STAIRS_RESULT checks=",checks," failures=",failures)
 finish()
