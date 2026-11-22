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
 if world.model.terrain_source not in ["blood_gulch","wind_meadow"]:restore();return
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
 if world.model.terrain_source=="wind_meadow":
  env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.tonemap_exposure=.85;env.ambient_light_energy=.35;env.ambient_light_color=Color("bdcfc6");env.fog_density=.0008/world.model.terrain_scale;env.fog_light_color=Color("b4ccd0");env.fog_sky_affect=.2
  sky_material.sky_top_color=Color("73adcf");sky_material.sky_horizon_color=Color("dce7d3");sky_material.ground_horizon_color=Color("dce7d3")
 if world.model.terrain_detail==world.model.Arena.ID:
  env.background_mode=Environment.BG_SKY;env.fog_enabled=false
  sky_material.ground_bottom_color=Color("383129");sky_material.ground_horizon_color=Color("c7c2ac")
  env.ambient_light_energy=.65;env.ambient_light_color=Color("d7d2c3")
 environment_node.environment=env
 if is_instance_valid(sun):
  sun_state=[sun.rotation,sun.light_color,sun.light_energy]
  sun.rotation_degrees=Vector3(-53,-32,0);sun.light_color=Color("fff4dc");sun.light_energy=1.0 if world.model.terrain_source=="wind_meadow" else 1.2
  if world.model.terrain_source=="wind_meadow":sun.rotation_degrees.x=-38;sun.light_color=Color("fff0dc")
 active=true
func restore():
 if not active:return
 if is_instance_valid(environment_node):environment_node.environment=original_environment
 if is_instance_valid(sun) and not sun_state.is_empty():
  sun.rotation=sun_state[0];sun.light_color=sun_state[1];sun.light_energy=sun_state[2]
 active=false;environment_node=null;original_environment=null;sun=null;sun_state.clear()
