#include "core.h"
#include <algorithm>
#include <cassert>
#include <iostream>
#include <random>
namespace army {
struct NearestQueryTest {
 static Handle actual(Crowd& c,Vec3 p){return c.combat.nearest_enemy(c,p);}
 static Handle guard(Crowd& c,Handle h){return c.combat.guard_enemy(c,*c.unit(h));}
 static uint64_t position_reads(Crowd& c){return c.combat.nearest_position_reads_;}
 static uint64_t work(Crowd& c){return c.combat.nearest_contact_tests_;}
 static void size(Crowd& c,float value){c.combat.data_.enemy_size=value;c.combat.nearest_revision_=UINT64_MAX;}
 static Vec3 contact(Crowd& c,const Unit& u,Vec3 p){return c.combat.enemy_contact(u,p);}
 static float segment(Crowd& c,const Unit& u,Vec3 a,Vec3 b){return c.combat.enemy_segment(u,a,b,0);}
 static void reset(Crowd& c){c.combat.nearest_contact_tests_=0;}
};
}
using namespace army;
// Frozen expanding-box selection, independently retaining its fitted contact,
// vertical eligibility and logical-ID order. No new tree code is used here.
Handle original(Crowd& c,Vec3 origin,float size=1){
 Handle chosen=0;float best=INFINITY;
 for(float r=8;r<=1e9f;r*=2){
  Vec3 pad{r,r+7,r};
  for(auto h:c.query(origin-pad,origin+pad,0)){
   auto e=c.unit(h);if(!e)continue;
   float s=std::sin(-e->yaw),co=std::cos(-e->yaw);auto d=origin+Vec3{0,1,0}-e->position;
   Vec3 p{std::clamp(co*d.x+s*d.z,-0.576f*size,0.576f*size),std::clamp(d.y,0.0f,2.016f*size),std::clamp(-s*d.x+co*d.z,-1.152f*size,1.152f*size)};
   s=std::sin(e->yaw);co=std::cos(e->yaw);p=e->position+Vec3{co*p.x+s*p.z,p.y,-s*p.x+co*p.z};
   float distance=length(p-origin);
   if(distance<best){best=distance;chosen=h;}
  }
  if(best<=r)return chosen;
 }
 return chosen;
}
int main(){
 Crowd c;c.configure(4000,2000);int checks=0;float expected_size=1;
 auto compare=[&](Vec3 p){auto a=NearestQueryTest::actual(c,p),b=original(c,p,expected_size);if(a!=b){std::cerr<<"nearest mismatch at "<<p.x<<","<<p.y<<","<<p.z<<" actual="<<a<<" reference="<<b<<"\n";std::abort();}++checks;};
 std::mt19937 rng(71021);std::uniform_real_distribution<float> pos(-200,200),y(-20,80),yaw(-40,40);
 for(int i=0;i<2000;++i){auto h=c.spawn(2000-i,0,i%3,{pos(rng),y(rng),pos(rng)},192,1.3);auto p=c.unit(h)->position;c.set_pose(h,p,yaw(rng));}
 for(int i=0;i<500;++i)compare({pos(rng),y(rng),pos(rng)});
 // Yaw changes inside before_move do not alter root bounds or revision.
 for(const auto& row:c.snapshot())c.unit(row.handle)->yaw=yaw(rng);
 for(int i=0;i<100;++i)compare({pos(rng),y(rng),pos(rng)});
 auto rows=c.snapshot();for(int i=0;i<500;++i){c.despawn(rows[i].handle);compare({pos(rng),y(rng),pos(rng)});}
 for(int i=0;i<500;++i){auto h=c.spawn(3000+i,0,0,{pos(rng),y(rng),pos(rng)},192,1.3);c.set_pose(h,{pos(rng),y(rng),pos(rng)},yaw(rng));compare({pos(rng),y(rng),pos(rng)});}
 c.clear();compare({0,0,0});
 // Reversed insertion, equal scores and a body above the querying ally.
 c.spawn(2,0,0,{10,0,0},192,1.3);c.spawn(1,0,0,{10,0,0},192,1.3);compare({0,0,0});compare({10,60,0});
 c.set_pose(c.snapshot()[0].handle,{-20,5,0},.7);compare({0,0,0});
 // Nonstandard tiny broadphase radii retain the original eligibility fallback.
 c.clear();c.spawn(1,0,0,{10,0,0},192,.01);c.spawn(2,0,0,{0,0,7},192,.01);compare({0,0,0});
 c.clear();c.spawn(1,0,0,{99999984,0,99999984},192,1.3);compare({99999960,0,99999960});
 c.clear();for(int i=0;i<2000;++i)c.spawn(2000-i,0,0,{20+(i%40)*.1f,0,20+(i/40)*.1f},192,1.3);
 NearestQueryTest::reset(c);compare({0,0,0});auto fitted=NearestQueryTest::work(c);
 if(fitted>=128){std::cerr<<"FAIL dense nearest fits="<<fitted<<" expected<128\n";return 1;}
 // Full units have a much larger stride than a position. Copy each root
 // once, then use compact entries for all hierarchy partition/bounds passes.
 c.clear();for(int i=0;i<2000;++i)c.spawn(2000-i,0,i%3,{pos(rng),y(rng),pos(rng)},192,1.3);
 auto reads=NearestQueryTest::position_reads(c);compare({0,0,0});
 auto copied=NearestQueryTest::position_reads(c)-reads;
 if(copied!=2000){std::cerr<<"FAIL hierarchy position reads="<<copied<<" expected2000\n";return 1;}++checks;
 for(int tick=0;tick<16;++tick){
  auto live=c.snapshot();for(auto& u:live)c.set_pose(u.handle,u.position+Vec3{.1f,.01f,-.2f},yaw(rng));
  for(int i=0;i<24;++i)c.despawn(live[i].handle);
  auto ally=c.spawn(-tick-1,1,11,{0,0,0},200,.4);
  for(int i=0;i<24;++i)c.spawn(10000+tick*24+i,0,i%3,{pos(rng),y(rng),pos(rng)},192,1.3);
  for(int i=0;i<12;++i)compare({pos(rng),y(rng),pos(rng)});
  c.despawn(ally);
 }
 for(float size:{.25f,1.0f,3.0f}){
  c.clear();expected_size=size;NearestQueryTest::size(c,size);
  auto h=c.spawn(1,0,0,{0,0,0},192,1.3f*size);auto u=c.unit(h);
  auto point=NearestQueryTest::contact(c,*u,{10,10,10});
  assert(length(point-Vec3{.576f*size,2.016f*size,1.152f*size})<.00001f);++checks;
  assert(NearestQueryTest::segment(c,*u,{0,2.016f*size+.01f,-10},{0,2.016f*size+.01f,10})<0);++checks;
  assert(NearestQueryTest::segment(c,*u,{0,size,-10},{0,size,10})>=0);++checks;
  for(int i=0;i<1000;++i){auto enemy=c.spawn(i+2,0,0,{pos(rng),y(rng),pos(rng)},192,1.3f*size);c.set_pose(enemy,c.unit(enemy)->position,yaw(rng));}
  for(int i=0;i<200;++i)compare({pos(rng),y(rng),pos(rng)});
 }
 // Paid defenders acquire only contacts inside their post's area, even after pursuit.
 c.clear();NearestQueryTest::size(c,1);
 auto guard=c.spawn(-1,1,11,{0,0,0},200,.4);c.set_guard(guard,{0,0,0},18);
 auto distant=c.spawn(1,0,0,{60,0,0},100,1.3);
 assert(!NearestQueryTest::guard(c,guard));++checks;
 auto near=c.spawn(2,0,0,{12,0,0},100,1.3);
 assert(NearestQueryTest::guard(c,guard)==near);++checks;
 c.set_pose(guard,{40,0,0},0);
 assert(NearestQueryTest::guard(c,guard)==near);++checks;
 c.set_pose(near,{60,0,0},0);assert(!NearestQueryTest::guard(c,guard));++checks;
 c.set_pose(distant,{18.5f,0,0},0);assert(NearestQueryTest::guard(c,guard)==distant);++checks;
 c.set_pose(distant,{19,0,0},0);assert(!NearestQueryTest::guard(c,guard));++checks;
 c.set_pose(near,{0,0,18},0);assert(NearestQueryTest::guard(c,guard)==near);++checks;
 c.despawn(near);assert(!NearestQueryTest::guard(c,guard));++checks;
 std::cout<<"ARMY_NEAREST_QUERY_RESULT checks="<<checks<<" fitted="<<fitted<<" failures=0\n";
}
