#include "terrain.h"
#include "il-low-source-cases.h"
#include <cmath>
#include <iostream>
using namespace army;
namespace {
int checks=0,failures=0,segments=0;
constexpr float scale=1.3f;
void check(bool yes,const char* label,int x=-1,int z=-1,float radius=0){
 ++checks;if(yes)return;++failures;
 if(failures<=20)std::cerr<<"IL_LOW_FAIL "<<label<<" cell="<<x<<','<<z<<" radius="<<radius<<'\n';
}
Vec3 point(int x,int z,float high){return {(x*3-135)*scale,high*scale,(z*3-180)*scale};}
NavigationData data(){
 NavigationData d;d.width=field_w;d.spacing=d.route_spacing=3*scale;
 d.origin=d.bounds_min={-138*scale,0,-183*scale};d.bounds_max={133.5f*scale,0,178.5f*scale};
 d.heights=source_heights;for(float& h:d.heights)h*=scale;d.covered=source_covered;
 for(const auto& row:source_floors){
  const auto& r=row.rect;float x=(r[0]*3-136.5f)*scale,z=(r[1]*3-181.5f)*scale;
  float length=r[2]*3*scale,half=r[3]*1.5f*scale,values[]{x,z+half,1,0,half,length,0,length,row.height*scale,row.height*scale};
  d.pieces.insert(d.pieces.end(),std::begin(values),std::end(values));
 }
 for(const auto& r:source_closed){
  Vec3 a{(r[0]*3-136.5f)*scale,-10*scale,(r[1]*3-181.5f)*scale};
  d.obstacle_min.push_back(a);d.obstacle_max.push_back(a+Vec3{r[2]*3*scale,40*scale,r[3]*3*scale});
 }
 return d;
}
}
int main(){
 auto d=data();Terrain terrain;terrain.configure(d);
 int open=0,closed=0,top=0,blocked_banks=0;
 for(const auto& cell:source_cells){
  int x=cell[0],z=cell[1],object=cell[3];bool opened=cell[5];
  float expected=object==252?2.f:2.1f;Vec3 p=point(x,z,expected);
  if(opened){++open;top+=z==0;check(std::isfinite(terrain.height(p.x,p.z))&&std::abs(terrain.height(p.x,p.z)-p.y)<.001,"Original-open center has its recorded inferred height",x,z);}
  else{++closed;blocked_banks+=object>=12500&&object<=12535;}
  for(float radius:{.25f,.35f,.4967896938f,.60f})check(terrain.clear(p,radius,0)==opened,"All original source centers preserve open/closed clearance",x,z,radius);
 }
 check(open==2718&&closed==8082&&top==16&&blocked_banks==4,"Exact source counts/top-border controls");
 for(const auto& c:source_contacts){
  Vec3 water=point(c[0],c[1],2),bank=point(c[2],c[3],2.1f);
  for(float radius:{.25f,.35f,.4967896938f,.60f}){
   check(terrain.segment(bank,water,radius,0),"Original bank-to-water direct segment",c[2],c[3],radius);++segments;
   check(terrain.segment(water,bank,radius,0),"Original water-to-bank direct return",c[0],c[1],radius);++segments;
  }
 }
 check(source_contacts.size()==143&&segments==143*2*4,"All143direct edges tested both ways at four world radii");
 int boundary_edges=0;
 for(const auto& cell:source_cells)if(cell[5])for(const auto& axis:std::vector<std::array<int,2>>{{-1,0},{1,0},{0,-1},{0,1}}){
  int nx=cell[0]+axis[0],nz=cell[1]+axis[1];
  if(nx>=0&&nx<source_w&&nz>=0&&nz<source_h&&source_cells[nz*source_w+nx][5])continue;
  ++boundary_edges;auto center=point(cell[0],cell[1],cell[3]==252?2.f:2.1f);
  for(float radius:{.25f,.35f,.4967896938f,.60f}){
   auto inside=center;inside.x+=axis[0]*(1.5f*scale-radius-.1f);inside.z+=axis[1]*(1.5f*scale-radius-.1f);
   auto outside=center;outside.x+=axis[0]*(1.5f*scale+.1f);outside.z+=axis[1]*(1.5f*scale+.1f);
   check(terrain.clear(inside,radius,0),"Body-fitting interior of original open/closed boundary stays open",cell[0],cell[1],radius);
   check(!terrain.clear(outside,radius,0),"Original closed/outside side of each boundary stays closed",nx,nz,radius);
  }
 }
 int outside=0;
 for(int z=-1;z<=source_h;++z)for(int x=-1;x<=source_w;++x){
  if(x>=0&&x<source_w&&z>=0&&z<source_h)continue;
  Vec3 p=point(x,z,2.1f);check(!std::isfinite(terrain.height(p.x,p.z)),"Padding outside the source rectangle remains void",x,z);
  for(float radius:{.25f,.35f,.4967896938f,.60f})check(!terrain.clear(p,radius,0),"No outside-source disk support",x,z,radius);
  ++outside;
 }
 // Also sample just beyond each physical map edge; array padding must not
 // turn the original top-row support into a full extra tile of walkable land.
 for(const auto& cell:source_cells)if(cell[5]&&cell[1]==0){
  auto p=point(cell[0],0,2.1f);p.z=(-181.5f)*scale-.01f;
  check(!std::isfinite(terrain.height(p.x,p.z))&&!terrain.clear(p,.25f,0),"Just outside an original-open top-edge tile stays void",cell[0],0);
 }
 std::cout<<"IL_LOW_NATIVE checks="<<checks<<" failures="<<failures<<" source_open="<<open<<" source_closed="<<closed<<" direct_segments="<<segments<<" original_closed_boundary_edges="<<boundary_edges<<" outside_centers="<<outside<<" top_open="<<top<<" scale="<<scale<<'\n';
 return failures?1:0;
}
