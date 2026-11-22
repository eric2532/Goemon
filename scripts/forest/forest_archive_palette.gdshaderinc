// Reuse Kai Highway's inverse filmic mapping to display the archived RGB palette.
uniform bool compensate_filmic=true;
uniform float scene_exposure=1.0;
uniform float scene_white=1.0;
float archive_filmic_white(float x){return (x*(.88*x+.06)+.002)/(x*(.88*x+.60)+.06)-1.0/30.0;}
vec3 archive_color(vec3 desired){
 if(!compensate_filmic)return desired/max(scene_exposure,.001);
 vec3 k=clamp(desired,vec3(0),vec3(1))*archive_filmic_white(max(scene_white,.001))+vec3(1.0/30.0);
 vec3 a=.88*(vec3(1)-k);vec3 b=.60*(vec3(.10)-k);vec3 c=.20*(vec3(.01)-.30*k);
 return max(vec3(0),(-b+sqrt(max(vec3(0),b*b-4.0*a*c)))/(2.0*a))/max(scene_exposure,.001);
}
