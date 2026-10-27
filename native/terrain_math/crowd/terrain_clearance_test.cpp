#include "terrain.h"
#include <cassert>
#include <chrono>
#include <iostream>
#include <random>
namespace army {
struct TerrainClearanceTest {
 static bool reference(const Terrain& t,Vec3 p,float r,int layer){
  double h=t.height(p.x,p.z,layer);if(!std::isfinite(h))return false;
  const Vec3 axes[]={{1,0,0},{-1,0,0},{0,0,1},{0,0,-1},{.707f,0,.707f},{-.707f,0,.707f},{.707f,0,-.707f},{-.707f,0,-.707f}};
  for(auto a:axes){double v=t.height(p.x+a.x*r,p.z+a.z*r,layer);if(!std::isfinite(v)||std::abs(v-h)>.15+r*.35)return false;}
  p.y=float(h);return t.obstacles_clear(p,r);
 }
};
}
using namespace army;
int main(){
 Terrain t;std::mt19937 random(71021);std::uniform_real_distribution<float> coord(-112,112);int checks=0;
 const float radii[]={0,.00001f,.4f,1.3f,3.9f,6,8.5f,14.75f};
 uint64_t fast_heights=0,old_heights=0;double fast_ms=0,old_ms=0;
 for(int fixture=0;fixture<6;++fixture){
  NavigationData n;n.width=71;n.origin={-105,0,-105};n.bounds_min={-104,0,-103};n.bounds_max={104,0,102};n.heights.resize(71*71);n.covered.assign(71*71,1);
  for(int z=0;z<71;++z)for(int x=0;x<71;++x){
   n.heights[z*71+x]=fixture%2?float((x/7)%3)*3+z*.001f:float(x/19)*.025f;
   if(fixture==2&&(x==34||z==27))n.covered[z*71+x]=0;
   if(fixture==3)n.heights[z*71+x]=float((x+z)%2)*10;
  }
  n.obstacle_min={{-12,0,-25},{20,4,20}};n.obstacle_max={{-8,5,25},{26,12,26}};
  n.layer_min={{-20,8,-20}};n.layer_max={{20,8,20}};
  if(fixture==4)n.pieces={0,0,1,0,7,20,-5,25,0,12};
  if(fixture==5)n.width=0;
  t.configure(n);t.navigation_profile={true};
  std::vector<Vec3> points;for(int i=0;i<10000;++i)points.push_back({coord(random),0,coord(random)});
  // Include triangle/certificate borders and their immediate float neighbours.
  for(float x:{-105.f,-104.f,-99.f,-3.f,0.f,3.f,99.f,102.f,104.f,105.f})for(float z:{-103.f,-99.f,0.f,3.f,102.f})for(float offset:{-.00001f,0.f,.00001f})points.push_back({x+offset,0,z});
  for(float r:radii)for(int layer:{0,1}){
   std::vector<bool> expected;auto start=std::chrono::steady_clock::now();auto count=t.navigation_profile.heights;
   for(auto p:points)expected.push_back(TerrainClearanceTest::reference(t,p,r,layer));
   old_ms+=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();old_heights+=t.navigation_profile.heights-count;
   start=std::chrono::steady_clock::now();count=t.navigation_profile.heights;
   for(size_t i=0;i<points.size();++i){assert(t.clear(points[i],r,layer)==expected[i]);++checks;}
   fast_ms+=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();fast_heights+=t.navigation_profile.heights-count;
  }
 }
 assert(fast_heights<old_heights);++checks;
 std::cout<<"ARMY_TERRAIN_CLEARANCE_RESULT checks="<<checks<<" failures=0 heights="<<fast_heights<<" reference_heights="<<old_heights<<" ms="<<fast_ms<<" reference_ms="<<old_ms<<"\n";
}
