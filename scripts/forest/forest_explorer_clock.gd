extends RefCounted
## One Explorer clock; scenery and native gameplay keep their existing owners.
const CYCLE_SECONDS=24.0*60.0
const DEFAULT_HOUR=9.0
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const TINA_VARIANTS={4200:[51005,4201],4201:[51005,4201],4208:[4208,4230],4230:[4208,4230]}
const MUSIC_VARIANTS={4417:[4417,4431],4431:[4417,4431]}
var hour=DEFAULT_HOUR
var lighting:Array=[]
var sky_state:Array=[]
var outdoor_sky:Sky
var fixed_space=false
var winter_sky=false
var update_left=0.0
var save_left=60.0

func load_hour(value):
 hour=float(value) if (value is float or value is int) and is_finite(float(value)) and value>=0 and value<24 else DEFAULT_HOUR

func night()->bool:return hour<6.0 or hour>=18.0

func phase_floor(id:int)->int:
 var source=Maps.source_id(id)
 if MUSIC_VARIANTS.has(source):return MUSIC_VARIANTS[source][int(night())]
 return TINA_VARIANTS[source][int(night())] if TINA_VARIANTS.has(source) else id

func caption()->String:
 var minutes=int(hour*60.0)%1440
 var phase="夜晚" if night() else "黎明" if hour<8.0 else "黃昏" if hour>=16.0 else "白天"
 return "%s · %02d:%02d"%[phase,minutes/60,minutes%60]

func tick(game,delta:float):
 if not game.playing or game.paused or game.ordinary_pause or game.transitioning or game.model.phase!="wave" or is_instance_valid(game.dialogue) or game.FalanTour.area(game.model).is_empty():return
 hour=fposmod(hour+maxf(0,delta)*24.0/CYCLE_SECONDS,24.0)
 update_left-=delta;save_left-=delta
 if save_left<=0:
  save_left=60.0
  if game.save_settings()!=OK:push_warning("Could not save Explorer time")
 if update_left>0:return
 update_left=.2
 update_lighting()
 var current:int=game.model.falan_floor
 var next=phase_floor(current)
 if current==next:return
 # Tina and the campus music room have distinct source day/night states.
 var at=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
 var target=Maps.state(next,game.model.seed_value)
 var cell=Vector2i(((at-target.origin)/3.0).round())
 var arrival=at if Maps.open(target.bits,target.size,cell) else game.FalanTour.Indoor.safe_point(next,at,game.model.seed_value)
 game.transitioning=true
 game.FalanTour.travel.call_deferred(game,game.FalanTour.Indoor.layout(next),{
  "arrival":arrival,
  "yaw":game.camera_rig.yaw,"velocity":game.player.velocity})

func apply(world):
 restore()
 var game=world.get_parent()
 var id:int=world.model.falan_floor
 winter_sky=Maps.generated().branch(id)=="mountain" or Maps.source_id(id)==4100
 fixed_space=id>=59500 and id<59800 and Maps.owns(id) and not Maps.outdoor(id)
 if game.FalanTour.area(world.model).is_empty() or world.model.Dungeons.roofed(world.model.falan_floor):return
 var env=world.get_world_3d().environment
 if env==null:return
 for child in world.get_children():
  if not child is DirectionalLight3D:continue
  lighting=[env,child,env.background_color,env.ambient_light_color,env.ambient_light_energy,
   env.adjustment_enabled,env.adjustment_brightness,env.adjustment_saturation,
   child.rotation,child.light_color,child.light_energy,env.fog_light_color,env.fog_light_energy,env.background_mode,env.sky]
  if fixed_space:
   env.background_mode=Environment.BG_COLOR;env.background_color=Color("02030b")
   return
  if env.background_mode!=Environment.BG_SKY:
   if outdoor_sky==null:
    var sky_material=ProceduralSkyMaterial.new()
    sky_material.sky_top_color=Color("73adcf");sky_material.sky_horizon_color=Color("dce7d3")
    sky_material.ground_bottom_color=Color("658750");sky_material.ground_horizon_color=Color("dce7d3")
    sky_material.sky_curve=.18;sky_material.sun_angle_max=8.0;sky_material.sun_curve=.12
    outdoor_sky=Sky.new();outdoor_sky.sky_material=sky_material
   env.background_mode=Environment.BG_SKY;env.sky=outdoor_sky
  if env.sky!=null and env.sky.sky_material is ProceduralSkyMaterial:
   var sky:ProceduralSkyMaterial=env.sky.sky_material
   sky_state=[sky,sky.sky_top_color,sky.sky_horizon_color,sky.ground_bottom_color,sky.ground_horizon_color]
  update_lighting()
  break

func update_lighting():
 if lighting.is_empty() or fixed_space:return
 var env:Environment=lighting[0];var sun:DirectionalLight3D=lighting[1]
 if not is_instance_valid(sun):lighting.clear();return
 var daylight=smoothstep(5.0,8.0,hour)*(1.0-smoothstep(16.0,19.0,hour))
 var twilight=4.0*daylight*(1.0-daylight)
 env.background_color=Color("101d36").lerp(lighting[2],daylight).lerp(Color("bd7769"),twilight*.45)
 env.ambient_light_color=Color("819cc6").lerp(lighting[3],daylight)
 env.ambient_light_energy=lerpf(.34,lighting[4],daylight)
 env.fog_light_color=Color("1c2c4b").lerp(lighting[11],daylight).lerp(Color("bd897a"),twilight*.25)
 env.fog_light_energy=lerpf(.35,lighting[12],daylight)
 if not sky_state.is_empty():
  var sky:ProceduralSkyMaterial=sky_state[0]
  sky.sky_top_color=Color("071126").lerp(sky_state[1],daylight)
  sky.sky_horizon_color=Color("263552").lerp(sky_state[2],daylight).lerp(Color("d18f7b"),twilight*.6)
  sky.ground_bottom_color=Color("101c28").lerp(Color("d6e5ec") if winter_sky else sky_state[3],daylight)
  sky.ground_horizon_color=sky.sky_horizon_color
 # Native palette art is emissive; exposure adjustments also light those original pixels.
 env.adjustment_enabled=true
 env.adjustment_brightness=lighting[6]*lerpf(.58,1.0,daylight)
 env.adjustment_saturation=lighting[7]*lerpf(.80,1.0,daylight)
 sun.light_color=Color("8baada").lerp(lighting[9],daylight).lerp(Color("ffb579"),twilight*.6)
 sun.light_energy=lerpf(.20,lighting[10],daylight)
 var elevation=lerpf(14.0,58.0,maxf(0,sin((hour-6.0)*PI/12.0)))
 sun.rotation_degrees=Vector3(-elevation,-110.0+(hour-6.0)*15.0,0)

func restore():
 fixed_space=false;winter_sky=false
 if lighting.is_empty():return
 var env:Environment=lighting[0];var sun:DirectionalLight3D=lighting[1]
 env.background_color=lighting[2];env.ambient_light_color=lighting[3];env.ambient_light_energy=lighting[4]
 env.adjustment_enabled=lighting[5];env.adjustment_brightness=lighting[6];env.adjustment_saturation=lighting[7]
 env.fog_light_color=lighting[11];env.fog_light_energy=lighting[12]
 if not sky_state.is_empty():
  var sky:ProceduralSkyMaterial=sky_state[0]
  sky.sky_top_color=sky_state[1];sky.sky_horizon_color=sky_state[2]
  sky.ground_bottom_color=sky_state[3];sky.ground_horizon_color=sky_state[4]
  sky_state.clear()
 env.background_mode=lighting[13];env.sky=lighting[14]
 if is_instance_valid(sun):sun.rotation=lighting[8];sun.light_color=lighting[9];sun.light_energy=lighting[10]
 lighting.clear()
