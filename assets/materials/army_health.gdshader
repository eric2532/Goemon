shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
varying float fill;
void vertex(){
 fill=UV2.x;vec3 local=VERTEX;
 if(fill>0.5)local.x=-.9+(local.x+.9)*INSTANCE_CUSTOM.x;
 vec3 world=MODEL_MATRIX[3].xyz+INV_VIEW_MATRIX[0].xyz*local.x+INV_VIEW_MATRIX[1].xyz*local.y+INV_VIEW_MATRIX[2].xyz*local.z;
 POSITION=PROJECTION_MATRIX*VIEW_MATRIX*vec4(world,1.0);
}
void fragment(){ALBEDO=fill>.5?vec3(.18,.78,.43):vec3(.025,.08,.065);}
