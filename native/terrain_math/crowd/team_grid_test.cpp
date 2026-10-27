#include "core.h"
#include <algorithm>
#include <cassert>
#include <iostream>
using namespace army;
int main(){
 Crowd c;c.configure(4000,2000);int checks=0;
 for(int i=0;i<4000;++i){
  int team=i%2;float radius=i<2?1200:float(i%11)*.4f;
  assert(c.spawn(team?-i-1:i+1,team,0,{float(i%51)*2-50,float(i%5),float(i/51)*2-80},100,radius));
 }
 auto query=[&](Vec3 a,Vec3 b,int team){
  std::vector<Handle> expected;
  for(const auto& u:c.snapshot())if(u.team==team&&u.position.x+u.radius>=a.x&&u.position.x-u.radius<=b.x&&u.position.y+u.radius>=a.y&&u.position.y-u.radius<=b.y&&u.position.z+u.radius>=a.z&&u.position.z-u.radius<=b.z)expected.push_back(u.handle);
  std::sort(expected.begin(),expected.end(),[&](Handle x,Handle y){return c.unit(x)->logical_id<c.unit(y)->logical_id;});
  assert(c.query(a,b,team)==expected);++checks;
  auto unordered=c.query(a,b,team,false);std::sort(unordered.begin(),unordered.end());std::sort(expected.begin(),expected.end());assert(unordered==expected);++checks;
 };
 for(int pass=0;pass<4;++pass){
  for(int i=0;i<250;++i){Vec3 a{float(i%33)*4-64,-5,float(i%47)*4-90};for(int team=0;team<2;++team)query(a,a+Vec3{float(i%12),15,float(i%19)},team);}
  for(auto u:c.snapshot())if((u.logical_id+pass)%7==0)c.set_pose(u.handle,u.position+Vec3{8,0,-8},0);
 }
 // Recycled slots change team, and moving buckets must not retain old members.
 auto old=c.snapshot()[2];c.despawn(c.snapshot()[3].handle);c.despawn(old.handle);assert(c.spawn(-90000,1,0,{-1000,0,1000},100,.4));
 for(int team=0;team<2;++team){query({-1002,-5,998},{-998,5,1002},team);query({-1e7f,-5,-1e7f},{1e7f,5,1e7f},team);}
 c.clear();assert(c.query({-100,-100,-100},{100,100,100},0).empty());++checks;
 std::cout<<"ARMY_TEAM_GRID_RESULT checks="<<checks<<" failures=0\n";
}
