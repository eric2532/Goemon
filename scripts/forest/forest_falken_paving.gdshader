shader_type spatial;

uniform sampler2D stone_grain : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 dais_bounds;
uniform vec4 slate : source_color = vec4(.29,.35,.35,1.);
uniform vec4 sea_green : source_color = vec4(.25,.38,.34,1.);
uniform vec4 limestone : source_color = vec4(.66,.65,.55,1.);
uniform vec4 bronze : source_color = vec4(.64,.46,.25,1.);
varying vec2 room_point;

void vertex() {
 room_point=VERTEX.xz;
}

float band(float value,float center,float width) {
 float aa=max(fwidth(value),.005);
 return 1.-smoothstep(width,width+aa,abs(value-center));
}

void fragment() {
 vec2 p=room_point;
 vec2 local=p-(dais_bounds.xy+dais_bounds.zw)*.5;
 vec2 edges=min(p-dais_bounds.xy,dais_bounds.zw-p);
 float inset=min(edges.x,edges.y);
 float grain=dot(texture(stone_grain,p*.32).rgb,vec3(.2126,.7152,.0722));

 vec2 slab=p/1.5;
 slab.x+=mod(floor(slab.y),2.)*.5;
 vec2 seam=min(fract(slab),1.-fract(slab));
 float mortar=1.-smoothstep(.012,.048,min(seam.x,seam.y));
 float tone=fract(sin(dot(floor(slab),vec2(12.9898,78.233)))*43758.5453);
 vec3 color=mix(slate.rgb,sea_green.rgb,.23+tone*.56);
 color*=.84+grain*.48-mortar*.25;

 if(inset>=0.) {
  if(inset<3.) {
   // Broad, jointed courses make the bevel read as cut stone.
   color=mix(slate.rgb,limestone.rgb,.52+grain*.27);
   color*=1.-.24*(band(inset,.80,.037)+band(inset,1.58,.037)+band(inset,2.32,.037));
   color*=1.-mortar*.12;
  } else {
   vec2 diamond=abs(fract(local/1.5+.5)-.5);
   float pin=1.-smoothstep(.09,.13,diamond.x+diamond.y);
   color=mix(limestone.rgb,sea_green.rgb,tone*.24+mortar*.20);
   color*=.86+grain*.40;
   color=mix(color,bronze.rgb,pin*.77);
   float border=band(inset,3.23,.075)+band(inset,3.59,.045);
   color=mix(color,bronze.rgb,clamp(border,0.,1.));
   float radial=length(local);
   float ring=band(radial,2.42,.075)+band(radial,2.75,.105);
   float medallion=1.-smoothstep(2.53,2.61,radial);
   color=mix(color,sea_green.rgb*(.74+grain*.42),medallion*.94);
   float waterline=abs(local.y-.21*sin(local.x*2.0));
   float crest=(band(waterline,0.,.065)+band(waterline,.47,.065))*(1.-smoothstep(1.48,1.62,abs(local.x)));
   color=mix(color,bronze.rgb,clamp(ring+crest,0.,1.));
  }
 }
 ALBEDO=color;
 ROUGHNESS=.83;
 SPECULAR=.23;
}
