#include "terrain.h"
#include "host-height-cases.h"
#include <cmath>
#include <iostream>
#include <map>
#include <string>
using namespace army;
namespace {
constexpr float scale=1.3f;
int checks=0,failures=0;
std::map<std::string,int> categories;
void check(bool yes,const char* label,int x,int z,float radius=0){
 ++checks;if(yes)return;++failures;++categories[label];
 if(failures<=30)std::cerr<<"IL_HOST_HEIGHT_FAIL "<<label<<" source="<<x<<','<<z<<" radius="<<radius<<'\n';
}
Vec3 point(float x,float z,float high){return {(591-z*3)*scale,high*scale,(x*3-1251)*scale};}
NavigationData data(){
 NavigationData d;d.width=field_w;d.spacing=1.5f*scale;d.route_spacing=3*scale;
 d.origin=d.bounds_min={field_x*scale,0,field_z*scale};
 d.bounds_max=d.origin+Vec3{(field_w-1)*d.spacing,0,(field_w-1)*d.spacing};
 d.heights=source_heights;for(auto& h:d.heights)h*=scale;d.covered=source_covered;
 for(const auto& r:source_water){
  auto a=point(r[0]-.5f,r[1]+r[3]*.5f-.5f,2);
  float length=r[2]*3*scale,half=r[3]*1.5f*scale;
  float values[]{a.x,a.z,0,1,half,length,0,length,2*scale,2*scale};
  d.pieces.insert(d.pieces.end(),std::begin(values),std::end(values));
 }
 for(const auto& r:source_closed){
  auto a=point(r[0]-.5f,r[1]-.5f,-10),b=point(r[0]+r[2]-.5f,r[1]+r[3]-.5f,30);
  d.obstacle_min.push_back({std::min(a.x,b.x),-13,std::min(a.z,b.z)});
  d.obstacle_max.push_back({std::max(a.x,b.x),39,std::max(a.z,b.z)});
 }
 return d;
}
const Cell* find(int x,int z){for(const auto& c:source_cells)if(c.x==x&&c.z==z)return &c;return nullptr;}
}
int main(){
 Terrain terrain;terrain.configure(data());int opened=0,closed=0,interfaces=0,boundaries=0,segments=0,padding_touch_clear=0,padding_touch_count=0;
 for(const auto& c:source_cells){
  auto p=point(c.x,c.z,c.high);if(c.opened){++opened;check(std::abs(terrain.height(p.x,p.z)-p.y)<.001,"Original-open center datum",c.x,c.z);}else ++closed;
  for(float radius:{.25f,.35f,.4967896938f,.60f})check(terrain.clear(p,radius,0)==bool(c.opened),"Original source open/closed disk",c.x,c.z,radius);
 }
 for(const auto& edge:source_interfaces){
  auto a=find(edge[0],edge[1]),b=find(edge[2],edge[3]);check(a&&b&&a->opened&&b->opened,"Original interface endpoints",edge[0],edge[1]);if(!a||!b)continue;
  for(float radius:{.25f,.35f,.4967896938f,.60f}){
   check(terrain.segment(point(a->x,a->z,a->high),point(b->x,b->z,b->high),radius,0),"Host interface outward",a->x,a->z,radius);++interfaces;
   check(terrain.segment(point(b->x,b->z,b->high),point(a->x,a->z,a->high),radius,0),"Host interface return",b->x,b->z,radius);++interfaces;
  }
 }
 // Adjacent dry slopes and bank/water lips must work continuously, including
 // original blocked-water neighbours; endpoint heights alone are insufficient.
 for(const auto& a:source_cells)if(a.opened)for(const auto& axis:std::vector<std::array<int,2>>{{1,0},{0,1},{-1,0},{0,-1}}){
  auto b=find(a.x+axis[0],a.z+axis[1]);if(!b)continue;
  if(b->opened){
   if(axis[0]<0||axis[1]<0)continue;
   for(float radius:{.25f,.35f,.4967896938f,.60f}){
    check(terrain.segment(point(a.x,a.z,a.high),point(b->x,b->z,b->high),radius,0),"Every original-open adjacent segment",a.x,a.z,radius);++segments;
    check(terrain.segment(point(b->x,b->z,b->high),point(a.x,a.z,a.high),radius,0),"Every original-open adjacent return",b->x,b->z,radius);++segments;
   }
  }else{
   ++boundaries;
   for(float radius:{.25f,.35f,.4967896938f,.60f}){
    auto p=point(a.x,a.z,a.high),outside=point(b->x,b->z,b->high);float fraction=(1.5f*scale+radius+.10f)/(3*scale);
    auto inside=p+(outside-p)*(1-fraction);
    check(terrain.clear(inside,radius,0),"Body fitting inside sourceclosed edge",a.x,a.z,radius);
    check(!terrain.segment(p,outside,radius,0),"Original blocked neighbour cannot be crossed",b->x,b->z,radius);
    // The existing obstacle owner adds0.05m. Exact tangency at that padded
    // threshold varies by float32 rounding; test terrain there independently.
    auto tangent=p+(outside-p)*(1-(1.5f*scale+radius+.05f)/(3*scale));
    check(terrain.clear(tangent,radius,0,false),"Terrain remains continuous at obstacle-padding tangency",a.x,a.z,radius);
    ++padding_touch_count;padding_touch_clear+=terrain.clear(tangent,radius,0);
   }
  }
 }
 check(interfaces==77*2*4,"All77interfaces both ways/fourradii",-1,-1);
 std::cout<<"IL_HOST_HEIGHT_NATIVE checks="<<checks<<" failures="<<failures<<" source_open="<<opened<<" source_closed="<<closed<<" interface_segments="<<interfaces<<" boundary_edges="<<boundaries<<" open_segments="<<segments<<" padding_touch_clear="<<padding_touch_clear<<" padding_touch_count="<<padding_touch_count<<'\n';
 for(const auto& c:categories)std::cerr<<"FAILURE_CATEGORY "<<c.first<<" count="<<c.second<<'\n';
 return failures?1:0;
}
