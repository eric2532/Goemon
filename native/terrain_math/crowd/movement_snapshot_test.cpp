#include "core.h"
#include <algorithm>
#include <cassert>
#include <iostream>
#include <map>
using namespace army;
// Scalar pre-cache avoidance over the original combat records, preserving
// bucket insertion order, duplicate visits and the twelve-contact cutoff.
std::vector<Vec3> reference(const std::vector<Unit>& units,float dt){
 std::map<std::pair<int,int>,std::array<std::vector<size_t>,2>> grid;
 auto cell=[](float p){return int(std::floor(p/8));};
 for(size_t i=0;i<units.size();++i){
  const auto& u=units[i];int x0=cell(u.position.x-u.radius),x1=cell(u.position.x+u.radius),z0=cell(u.position.z-u.radius),z1=cell(u.position.z+u.radius);
  if(int64_t(x1-x0+1)*(z1-z0+1)>256)continue;
  for(int x=x0;x<=x1;++x)for(int z=z0;z<=z1;++z)grid[{x,z}][u.team].push_back(i);
 }
 Terrain ground;NavigationData nav;ground.configure(nav);std::vector<Vec3> result;
 std::vector<unsigned> visited(units.size());unsigned visit=0;
 for(size_t i=0;i<units.size();++i){
  auto u=units[i];Vec3 avoidance{};int considered=0;++visit;
  for(int x=cell(u.position.x)-1;x<=cell(u.position.x)+1&&considered<12;++x)
   for(int z=cell(u.position.z)-1;z<=cell(u.position.z)+1&&considered<12;++z){
    auto found=grid.find({x,z});if(found==grid.end())continue;
    for(auto index:found->second[u.team]){
     if(index==i||visited[index]==visit)continue;visited[index]=visit;
     const auto& other=units[index];if(other.team!=u.team||std::abs(other.position.y-u.position.y)>2)continue;
     Vec3 offset=u.position-other.position;offset.y=0;float distance=length(offset),reach=u.radius+other.radius;
     if(distance>=reach||reach<=0)continue;
     if(distance<.001f){
      float angle=float((std::min(u.logical_id,other.logical_id)*2654435761ull)&1023)*.006135923f;
      float sign=u.logical_id<other.logical_id?1.0f:-1.0f;
      distance=.001f;offset={std::sin(angle)*distance*sign,0,std::cos(angle)*distance*sign};
     }
     avoidance=avoidance+offset*((reach-std::min(distance,reach))/std::max(.01f,reach*distance));
     if(++considered>=12)break;
    }
   }
  float strength=length(avoidance);if(strength>0)avoidance=avoidance*(std::min(strength,u.move_speed*.25f)/strength);
  result.push_back(ground.move(u.position,u.goal,u.move_speed*u.slow_factor,dt,u.radius,u.support_layer,u.routing,avoidance));
 }
 return result;
}
int main(){
 Crowd c;c.configure(4000,2000);NavigationData nav;c.set_navigation(nav);int checks=0;
 for(int i=0;i<4000;++i){
  float radii[]={0,.00001f,.4f,1.3f,3.9f,6.8f};Vec3 p{float(i%67)*.8f-27,0,float(i/67)*.8f-24};
  if(i%17==0)p={0,0,0};if(i%31==0)p.y=2.0001f;
  auto h=c.spawn(i%2?-i-1:i+1,i%2,0,p,192,radii[i%6]);assert(h);c.set_goal(h,{float(i%11-5),0,float(i%17-8)},3);
 }
 auto step=[&]{
  auto before=c.snapshot();auto expected=reference(before,float(1.0/60));c.step(1.0/60);auto actual=c.snapshot();assert(actual.size()==before.size());
  for(size_t i=0;i<actual.size();++i){
   assert(actual[i].position.x==expected[i].x&&actual[i].position.y==expected[i].y&&actual[i].position.z==expected[i].z);
   Vec3 velocity=(expected[i]-before[i].position)*(1/float(1.0/60));assert(actual[i].velocity.x==velocity.x&&actual[i].velocity.y==velocity.y&&actual[i].velocity.z==velocity.z);++checks;
  }
  // Movement's shared deduplication scratch must leave combat queries intact.
  for(int team=0;team<2;++team){
   std::vector<Handle> expected_hits;
   for(const auto& u:actual)if(u.team==team&&u.position.x+u.radius>=-10&&u.position.x-u.radius<=10&&u.position.y+u.radius>=-3&&u.position.y-u.radius<=4&&u.position.z+u.radius>=-10&&u.position.z-u.radius<=10)expected_hits.push_back(u.handle);
   std::sort(expected_hits.begin(),expected_hits.end(),[&](Handle a,Handle b){return c.unit(a)->logical_id<c.unit(b)->logical_id;});
   assert(c.query({-10,-3,-10},{10,4,10},team)==expected_hits);++checks;
  }
 };
 for(int tick=0;tick<30;++tick){
  if(tick==10){auto u=c.snapshot()[6];c.set_pose(u.handle,{0,0,0},0);c.unit(u.handle)->radius=6.8f;}
  if(tick==20){
   auto rows=c.snapshot();c.despawn(rows[4].handle);c.despawn(rows[5].handle);
   for(int team=0;team<2;++team){auto h=c.spawn(90000+team,team,0,{0,0,0},192,.4);assert(h);c.set_goal(h,{4,0,4},3);}
  }
  step();
 }
 c.clear();c.configure(2,2);c.set_navigation(nav);
 for(int i=0;i<2;++i){auto h=c.spawn(i+1,0,0,{0,0,0},100,1.3);assert(h);c.set_goal(h,{4,0,0},3);}
 step();
 std::cout<<"ARMY_MOVEMENT_SNAPSHOT_RESULT checks="<<checks<<" failures=0\n";
}
