#include "core.h"
#include <algorithm>
#include <cassert>
#include <iostream>
#include <random>
namespace army {
struct NearestQueryTest {
 static Handle actual(Crowd& c,Vec3 p){return c.combat.nearest_enemy(c,p);}
 static uint64_t position_reads(Crowd& c){return c.combat.nearest_position_reads_;}
 static uint64_t work(Crowd& c){return c.combat.nearest_contact_tests_;}
 static void reset(Crowd& c){c.combat.nearest_contact_tests_=0;}
};
}
using namespace army;
// Frozen expanding-box selection, independently retaining its fitted contact,
// vertical eligibility and logical-ID order. No new tree code is used here.
Handle original(Crowd& c,Vec3 origin){
 Handle chosen=0;float best=INFINITY;
 for(float r=8;r<=1e9f;r*=2){
  Vec3 pad{r,r+7,r};
  for(auto h:c.query(origin-pad,origin+pad,0)){
   auto e=c.unit(h);if(!e)continue;
   float s=std::sin(-e->yaw),co=std::cos(-e->yaw);auto d=origin+Vec3{0,1,0}-e->position;
   Vec3 p{std::clamp(co*d.x+s*d.z,-1.728f,1.728f),std::clamp(d.y,0.0f,6.048f),std::clamp(-s*d.x+co*d.z,-3.456f,3.456f)};
   s=std::sin(e->yaw);co=std::cos(e->yaw);p=e->position+Vec3{co*p.x+s*p.z,p.y,-s*p.x+co*p.z};
   float distance=length(p-origin);
   if(distance<best){best=distance;chosen=h;}
  }
  if(best<=r)return chosen;
 }
 return chosen;
}
int main(){
 Crowd c;c.configure(4000,2000);int checks=0;
 auto compare=[&](Vec3 p){auto a=NearestQueryTest::actual(c,p),b=original(c,p);if(a!=b){std::cerr<<"nearest mismatch at "<<p.x<<","<<p.y<<","<<p.z<<" actual="<<a<<" reference="<<b<<"\n";std::abort();}++checks;};
 std::mt19937 rng(71021);std::uniform_real_distribution<float> pos(-200,200),y(-20,80),yaw(-40,40);
 for(int i=0;i<2000;++i){auto h=c.spawn(2000-i,0,i%3,{pos(rng),y(rng),pos(rng)},192,3.9);auto p=c.unit(h)->position;c.set_pose(h,p,yaw(rng));}
 for(int i=0;i<500;++i)compare({pos(rng),y(rng),pos(rng)});
 // Yaw changes inside before_move do not alter root bounds or revision.
 for(const auto& row:c.snapshot())c.unit(row.handle)->yaw=yaw(rng);
 for(int i=0;i<100;++i)compare({pos(rng),y(rng),pos(rng)});
 auto rows=c.snapshot();for(int i=0;i<500;++i){c.despawn(rows[i].handle);compare({pos(rng),y(rng),pos(rng)});}
 for(int i=0;i<500;++i){auto h=c.spawn(3000+i,0,0,{pos(rng),y(rng),pos(rng)},192,3.9);c.set_pose(h,{pos(rng),y(rng),pos(rng)},yaw(rng));compare({pos(rng),y(rng),pos(rng)});}
 c.clear();compare({0,0,0});
 // Reversed insertion, equal scores and a body above the querying ally.
 c.spawn(2,0,0,{10,0,0},192,3.9);c.spawn(1,0,0,{10,0,0},192,3.9);compare({0,0,0});compare({10,60,0});
 c.set_pose(c.snapshot()[0].handle,{-20,5,0},.7);compare({0,0,0});
 // Nonstandard tiny broadphase radii retain the original eligibility fallback.
 c.clear();c.spawn(1,0,0,{10,0,0},192,.01);c.spawn(2,0,0,{0,0,7},192,.01);compare({0,0,0});
 c.clear();c.spawn(1,0,0,{99999984,0,99999984},192,3.9);compare({99999960,0,99999960});
 c.clear();for(int i=0;i<2000;++i)c.spawn(2000-i,0,0,{20+(i%40)*.1f,0,20+(i/40)*.1f},192,3.9);
 NearestQueryTest::reset(c);compare({0,0,0});auto fitted=NearestQueryTest::work(c);
 if(fitted>=128){std::cerr<<"FAIL dense nearest fits="<<fitted<<" expected<128\n";return 1;}
 // Full units have a much larger stride than a position. Copy each root
 // once, then use compact entries for all hierarchy partition/bounds passes.
 c.clear();for(int i=0;i<2000;++i)c.spawn(2000-i,0,i%3,{pos(rng),y(rng),pos(rng)},192,3.9);
 auto reads=NearestQueryTest::position_reads(c);compare({0,0,0});
 auto copied=NearestQueryTest::position_reads(c)-reads;
 if(copied!=2000){std::cerr<<"FAIL hierarchy position reads="<<copied<<" expected2000\n";return 1;}++checks;
 for(int tick=0;tick<16;++tick){
  auto live=c.snapshot();for(auto& u:live)c.set_pose(u.handle,u.position+Vec3{.1f,.01f,-.2f},yaw(rng));
  for(int i=0;i<24;++i)c.despawn(live[i].handle);
  auto ally=c.spawn(-tick-1,1,11,{0,0,0},200,.4);
  for(int i=0;i<24;++i)c.spawn(10000+tick*24+i,0,i%3,{pos(rng),y(rng),pos(rng)},192,3.9);
  for(int i=0;i<12;++i)compare({pos(rng),y(rng),pos(rng)});
  c.despawn(ally);
 }
 std::cout<<"ARMY_NEAREST_QUERY_RESULT checks="<<checks<<" fitted="<<fitted<<" failures=0\n";
}
