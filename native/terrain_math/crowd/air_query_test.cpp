#include "terrain.h"
#include <cassert>
#include <iostream>
#include <algorithm>
using namespace army;
struct Face{Vec3 a,b,c;int64_t owner;};
bool hit(Vec3 from,Vec3 motion,const Face& face){
 auto ab=face.b-face.a,ac=face.c-face.a,h=cross(motion,ac);float det=dot(ab,h);if(std::abs(det)<1e-8f)return false;
 float inv=1/det;auto s=from-face.a;float u=dot(s,h)*inv;if(u<-.00001f||u>1.00001f)return false;
 auto q=cross(s,ab);float v=dot(motion,q)*inv;if(v<-.00001f||u+v>1.00001f)return false;
 float t=dot(ac,q)*inv;return t>.00001f&&t<.99999f;
}
bool original_clear(Vec3 from,Vec3 to,const std::vector<Face>& faces,int64_t ignore=-1){
 // Reproduce the original X/Z bucket candidate rule independently. The
 // existing grid boundary is retained even for barycentric epsilon spill.
 auto cell=[](float value){return int(std::floor(value/12));};
 for(auto& f:faces){
  if(cell(std::min({f.a.x,f.b.x,f.c.x}))>cell(std::max(from.x,to.x))||cell(std::max({f.a.x,f.b.x,f.c.x}))<cell(std::min(from.x,to.x))||cell(std::min({f.a.z,f.b.z,f.c.z}))>cell(std::max(from.z,to.z))||cell(std::max({f.a.z,f.b.z,f.c.z}))<cell(std::min(from.z,to.z)))continue;
  if((ignore<0||f.owner!=ignore)&&hit(from,to-from,f))return false;
 }
 int count=std::max(1,int(std::ceil(length(to-from)/.5f)));
 for(int i=1;i<count;++i){auto p=from+(to-from)*(float(i)/count);if(p.x>=-48&&p.x<48&&p.z>=-48&&p.z<48&&p.y<-.05f)return false;}
 return true;
}
int main(){
 NavigationData data;data.width=33;data.spacing=3;data.origin={-48,0,-48};data.heights.assign(33*33,0);data.covered.assign(33*33,1);
 std::vector<Face> faces;
 for(int z=0;z<32;++z)for(int x=0;x<32;++x){Vec3 a{-48+x*3.0f,0,-48+z*3.0f},b=a+Vec3{3,0,0},c=a+Vec3{0,0,3},d=a+Vec3{3,0,3};faces.push_back({a,c,b,-1});faces.push_back({b,c,d,-1});}
 auto add=[&](Vec3 a,Vec3 b,Vec3 c,int64_t owner){data.air_faces.insert(data.air_faces.end(),{a,b,c});data.air_owner.push_back(owner);faces.push_back({a,b,c,owner});};
 add({0,0,-12},{0,10,-12},{0,10,12},77);add({0,0,-12},{0,10,12},{0,0,12},77);
 add({-3,12,-3},{-3,12,3},{3,12,3},88);add({-3,12,-3},{3,12,3},{3,12,-3},88);
 Terrain terrain;terrain.configure(data);terrain.air_profile.enabled=true;
 assert(terrain.ray_clear({-40,15,-40},{40,15,40}));
 assert(terrain.air_profile.considered<64&&terrain.air_profile.kept==0);
 uint32_t rng=71122;auto random=[&](){rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;return float(rng%100001)/100000;};
 for(int i=0;i<1000;++i){Vec3 a{-45+90*random(),-2+24*random(),-45+90*random()},b{-45+90*random(),-2+24*random(),-45+90*random()};int64_t owner=i%3==0?77:-1;assert(terrain.ray_clear(a,b,owner)==original_clear(a,b,faces,owner));}
 for(float z:{-12.00005f,-12.0f,0.0f,12.0f,12.00005f})for(float y:{0.0f,5.0f,10.00002f}){Vec3 a{-3,y,z},b{3,y,z};assert(terrain.ray_clear(a,b)==original_clear(a,b,faces));}
 bool valid=false;auto landing=terrain.landing({1,0,1},20,valid);assert(valid&&std::abs(landing.y-12)<.0001);
 landing=terrain.landing({20,0,20},20,valid);assert(valid&&std::abs(landing.y)<.0001);
 assert(!terrain.ray_clear({-3,5,0},{3,5,0}));assert(terrain.ray_clear({-3,5,0},{3,5,0},77));
 std::cout<<"ARMY_AIR_QUERY_RESULT checks=1021 failures=0\n";
}
