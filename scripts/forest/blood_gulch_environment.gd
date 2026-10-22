extends RefCounted
## Reversible map lighting. Apply only at map/style transitions, never per frame.
var world
var environment_node:WorldEnvironment
var original_environment:Environment
var sun:DirectionalLight3D
var sun_state:Array=[]
var active=false
func _init(owner_world):world=owner_world
func apply():
 if world.model.terrain_source!="blood_gulch":restore();return
 if active:return
 for node in world.get_children():
  if node is WorldEnvironment:environment_node=node
  elif node is DirectionalLight3D:sun=node
 if not is_instance_valid(environment_node):return
 original_environment=environment_node.environment
 var env:Environment=original_environment.duplicate()
 var sky_material=ProceduralSkyMaterial.new()
 sky_material.sky_top_color=Color("388bd8");sky_material.sky_horizon_color=Color("b5d9ee")
 sky_material.ground_bottom_color=Color("658750");sky_material.ground_horizon_color=Color("b5d9ee")
 sky_material.sky_curve=.18;sky_material.sun_angle_max=8.0;sky_material.sun_curve=.12
 var sky=Sky.new();sky.sky_material=sky_material
 env.background_mode=Environment.BG_SKY;env.sky=sky
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("b9d4ed");env.ambient_light_energy=.8
 env.ambient_light_sky_contribution=.5
 env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env.tonemap_exposure=1.0
 env.fog_enabled=true;env.fog_light_color=Color("b2d2e3");env.fog_light_energy=1.0;env.fog_density=.00075
 env.fog_sky_affect=0.0
 env.ssao_enabled=false
 environment_node.environment=env
 if is_instance_valid(sun):
  sun_state=[sun.rotation,sun.light_color,sun.light_energy]
  sun.rotation_degrees=Vector3(-53,-32,0);sun.light_color=Color("fff4dc");sun.light_energy=1.2
 active=true
func restore():
 if not active:return
 if is_instance_valid(environment_node):environment_node.environment=original_environment
 if is_instance_valid(sun) and not sun_state.is_empty():
  sun.rotation=sun_state[0];sun.light_color=sun_state[1];sun.light_energy=sun_state[2]
 active=false;environment_node=null;original_environment=null;sun=null;sun_state.clear()
