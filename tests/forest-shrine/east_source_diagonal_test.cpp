#include "terrain.h"
#include <algorithm>
#include <cmath>
#include <cstring>
#include <iostream>
#include <random>

namespace army {
struct TerrainClearanceTest {
 static bool ready(const Terrain& t){return t.ready_;}
 static const std::vector<Vec3>& faces(const Terrain& t){return t.air_->faces;}
 static size_t topologies(const Terrain& t){return t.topologies_.size();}
 static bool same_air(const Terrain& a,const Terrain& b){return a.air_==b.air_;}
};
}
using namespace army;
static int checks=0,failures=0;
static void check(bool ok,const char* message){++checks;if(!ok){++failures;std::cerr<<message<<'\n';}}
static NavigationData field(int w,float spacing=1){
 NavigationData d;d.width=w;d.spacing=spacing;d.route_spacing=1;d.origin={0,0,0};d.heights.assign(w*w,0);d.covered.assign(w*w,1);return d;
}
static uint64_t hash=1469598103934665603ULL;
template<class T>static void pin(T value){const auto* p=reinterpret_cast<const unsigned char*>(&value);for(size_t i=0;i<sizeof(T);++i)hash=(hash^p[i])*1099511628211ULL;}
static void default_contract(){
 auto d=field(9,3);d.origin={-12,0,-12};
 for(int z=0;z<9;++z)for(int x=0;x<9;++x)d.heights[z*9+x]=float(std::sin(x*.6)*.16+std::cos(z*.3)*.13+x*z*.001);
 d.covered[4*9+4]=0;d.pieces={-2,2,1,0,.7f,3,0,3,.2f,.3f};
 Terrain t;t.configure(d);check(TerrainClearanceTest::ready(t),"Default field ready");
 for(int z=0;z<47;++z)for(int x=0;x<47;++x){
  float px=-11.5f+x*.49f,pz=-11.5f+z*.49f;double h=t.height(px,pz);pin(std::isfinite(h));if(std::isfinite(h))pin(h);
  for(float r:{0.f,.25f,.4967896938f,.60f})pin(t.clear({px,0,pz},r,0));
 }
 for(int i=0;i<200;++i){float x=-10.f+(i%40)*.5f,z=-10.f+(i/40)*4.f;pin(t.segment({x,0,z},{x+1.3f,0,z+.9f},.25f,0));}
 check(true,"Default fingerprint complete");
}
#ifdef DIAGONAL_CANDIDATE
static void mask_all(NavigationData& d){d.diagonal_flips.assign(d.width*d.width,0);for(int z=0;z<d.width-1;++z)for(int x=0;x<d.width-1;++x)d.diagonal_flips[z*d.width+x]=1;}
static void rotated_contract(){
 auto n=field(5),e=n;
 for(int z=0;z<5;++z)for(int x=0;x<5;++x){float h=float(x*x*.13+z*.17+x*z*.19);n.heights[z*5+x]=h;e.heights[x*5+4-z]=h;}
 mask_all(e);Terrain north,east;north.configure(n);east.configure(e);
 for(int iz=1;iz<32;++iz)for(int ix=1;ix<32;++ix){
  float x=ix*.125f,z=iz*.125f;
  check(std::abs(north.height(x,z)-east.height(4-z,x))<1e-12,"Quarter-turn preserves source triangle height");
 }
 auto t0=field(2);t0.heights={0,2,3,9};Terrain t;t.configure(t0);check(t.height(.5f,.5f)==2.5,"Legacy diagonal asymmetric centre");
 mask_all(t0);t.configure(t0);check(t.height(.5f,.5f)==4.5,"Flipped diagonal asymmetric centre");
 const auto& f=TerrainClearanceTest::faces(t);
 check(f.size()==6&&f[1].x==1&&f[1].z==1&&f[1].y==9,"Native air faces use alternate diagonal");
 check(f.size()==6&&f[4].x==0&&f[4].z==1&&f[4].y==3,"Native second triangle has matching source split");
}
static void validation_contract(){
 for(int kind=0;kind<7;++kind){
  auto d=field(3);d.diagonal_flips.assign(9,0);
  if(kind==0)d.diagonal_flips.resize(8);
  if(kind==1)d.diagonal_flips[0]=2;
  if(kind==2)d.diagonal_flips[2]=1;
  if(kind==3)d.diagonal_flips[6]=1;
  if(kind==4)d.width=0;
  if(kind==5)d.width=-3;
  if(kind==6)d.diagonal_flips.resize(10);
  Terrain t;t.configure(d);check(!TerrainClearanceTest::ready(t)&&std::isnan(t.height(.5f,.5f)),"Malformed mask fails closed");
 }
 auto d=field(6);Terrain t,a;t.configure(d);check(t.prepare_routes({.25f}),"Default topology prepared");
 check(TerrainClearanceTest::topologies(t)>0,"Topology exists before mask revision");
 mask_all(d);t.configure(d);check(TerrainClearanceTest::topologies(t)==0,"Mask revision invalidates topology");
 a.configure(d,&t);check(TerrainClearanceTest::same_air(a,t),"Same mask shares immutable air geometry");
 d.diagonal_flips.clear();a.configure(d,&t);check(!TerrainClearanceTest::same_air(a,t),"Different mask cannot share air geometry");
}
static bool old_cut_segment(const Terrain& t,Vec3 from,Vec3 to,float radius){
 float distance=std::hypot(to.x-from.x,to.z-from.z);int count=std::max(1,int(std::ceil(distance/.7f)));double previous=t.height(from.x,from.z);if(!std::isfinite(previous))return false;Vec3 old=from;
 for(int i=1;i<=count;++i){auto p=from+(to-from)*(float(i)/count);double h=t.height(p.x,p.z);float travel=std::hypot(p.x-old.x,p.z-old.z);if(!std::isfinite(h)||std::abs(h-previous)>.15+travel*.35||!t.clear(p,radius,0,false))return false;old=p;previous=h;}
 const Vec3 offsets[]={{0,0,0},{radius,0,0},{-radius,0,0},{0,0,radius},{0,0,-radius},{.707f*radius,0,.707f*radius},{-.707f*radius,0,.707f*radius},{.707f*radius,0,-.707f*radius},{-.707f*radius,0,-.707f*radius}};
 for(auto offset:offsets)for(int axis=0;axis<3;++axis){
  auto coordinate=[&](Vec3 p){double x=double(p.x)+offset.x,z=double(p.z)+offset.z;return axis==0?x:axis==1?z:x+z;};
  double a=coordinate(from),b=coordinate(to);
  for(double edge=std::floor(std::min(a,b))+1;edge<std::max(a,b);++edge){auto p=from+(to-from)*float((edge-a)/(b-a));double h=t.height(p.x,p.z),foot=t.height(p.x+offset.x,p.z+offset.z);if(!std::isfinite(h)||!std::isfinite(foot)||std::abs(h-foot)>.15+radius*.35)return false;}
 }
 return true;
}
static int new_cut_rejections=0;
static void segment_contract(){
 std::mt19937 rng(970032);std::uniform_real_distribution<float> h(0,.95f),p(1.05f,3.95f);auto d=field(6);d.diagonal_flips.assign(36,0);
 for(int z=0;z<5;++z)for(int x=0;x<5;++x)d.diagonal_flips[z*6+x]=(x+z)%2;
 for(int revision=0;revision<8;++revision){
  for(float& value:d.heights)value=h(rng);Terrain t;t.configure(d);
  for(int i=0;i<500;++i){Vec3 a{p(rng),0,p(rng)},b{p(rng),0,p(rng)};float radius=i%2?.25f:.4967896938f;
   if(!t.clear(a,radius,0,false))continue;
   if(std::hypot(b.x-a.x,b.z-a.z)<=.7f)continue;
   bool actual=t.segment(a,b,radius,0,false),old=old_cut_segment(t,a,b,radius);
   if(old&&!actual)++new_cut_rejections;
   if(!actual)continue;
   bool dense=true;for(int j=0;j<=1500;++j){auto at=a+(b-a)*(float(j)/1500);if(!t.clear(at,radius,0,false)){dense=false;std::cerr<<"sweep_case "<<revision<<' '<<i<<" start "<<a.x<<','<<a.z<<" end "<<b.x<<','<<b.z<<" radius "<<radius<<" distance "<<std::hypot(b.x-a.x,b.z-a.z)<<" miss_t "<<float(j)/1500<<'\n';break;}}
   check(dense,"Accepted mixed-mask segment remains clear along dense independent sweep");
  }
 }
 check(new_cut_rejections>0,"Alternate-diagonal boundary checks catch cases missed by old x+z cuts");
}
#endif
int main(){
 default_contract();
#ifdef DIAGONAL_CANDIDATE
 rotated_contract();validation_contract();segment_contract();
 std::cout<<"{\"checks\":"<<checks<<",\"failures\":"<<failures<<",\"new_cut_rejections\":"<<new_cut_rejections<<",\"default_fingerprint\":\""<<std::hex<<hash<<"\"}\n";
#else
 std::cout<<"{\"checks\":"<<checks<<",\"failures\":"<<failures<<",\"default_fingerprint\":\""<<std::hex<<hash<<"\"}\n";
#endif
 return failures?1:0;
}
