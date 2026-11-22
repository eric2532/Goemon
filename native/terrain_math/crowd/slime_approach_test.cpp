#include "core.h"
#include <cassert>
#include <iostream>
using namespace army;
static KitData kits(bool boost){
 KitData d;d.slime_approach_boost=boost;d.soldier_kinds={SLIME_KIND,0};
 d.soldier_profiles={5000,3,30,7.5,6,6,192,3,11,2.5,5,2.304};
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={20,10,24,30,30};d.contact_ticks={13,14,15,18};d.melee_from={0,1,0};d.melee_to={0,1,-1.44f};d.muzzle={0,1.44f,-.864f};d.bullet_speed=8.64;d.bullet_life=3.34;d.bullet_tail=.576;d.bullet_radius=.576;
 d.slime_attacks.resize(SLIME_SKINS*8*HOUND_TIMELINE_STRIDE);
 for(size_t i=0;i<d.slime_attacks.size();i+=HOUND_TIMELINE_STRIDE){d.slime_attacks[i]=30;d.slime_attacks[i+1]=1;d.slime_attacks[i+2]=10;d.slime_attacks[i+3]=112;}
 return d;
}
// This kit-specific boost still applies to non-player targets; player pressure has its own fixture.
static ExternalTarget hero(Vec3 p={}){ExternalTarget t;t.kind=3;t.hp=100000;t.foot=t.minimum=t.maximum=p;return t;}
static Handle setup(Crowd& c,bool boost,float distance,int kind=SLIME_KIND){
 c.configure(8,8);NavigationData nav;nav.bounds_min={-500,0,-500};nav.bounds_max={500,0,500};c.set_navigation(nav);
 assert(c.combat.configure(kits(boost)));auto h=c.spawn(1,0,kind,{distance,0,0},5000,3.9);assert(h);c.combat.set_targets({hero()});return h;
}
static float pace(float distance,int hz,bool boost=true,int kind=SLIME_KIND,float slow=1){
 Crowd c;auto h=setup(c,boost,distance,kind);
 if(slow!=1){Hit hit;hit.effect=2;hit.status_seconds=10;hit.slow_factor=slow;assert(c.combat.hit(c,h,hit).accepted);}
 Vec3 before=c.unit(h)->position;c.step(1.0/hz);auto u=c.unit(h);
 float moved=length(u->position-before)*hz;
 assert(moved>0&&moved<=9*slow+.01);
 assert(std::abs(moved-u->move_speed*slow)<.04);return moved;
}
int main(){
 int checks=0;
 for(int hz:{20,30,60}){
  assert(std::abs(pace(160,hz)-9)<.01);assert(std::abs(pace(80,hz)-6)<.04);assert(std::abs(pace(20,hz)-3)<.01);checks+=3;
  float previous=10;
  for(float distance:{160,120,100,80,60,40,20}){float speed=pace(distance,hz);assert(speed<=previous+.01);previous=speed;++checks;}
  assert(std::abs(pace(160,hz,false)-3)<.01);assert(std::abs(pace(160,hz,true,0)-3)<.01);checks+=2;
  assert(std::abs(pace(160,hz,true,SLIME_KIND,.5)-4.5)<.01);assert(std::abs(pace(20,hz,true,SLIME_KIND,.5)-1.5)<.01);checks+=2;
  Crowd c;auto h=setup(c,true,160);auto u=c.unit(h);c.step(1.0/hz);
  c.combat.set_targets({hero(u->position+Vec3{-30,0,0})});c.step(1.0/hz);assert(std::abs(u->move_speed-3)<.01);++checks;
  c.combat.set_targets({hero({-100,0,0})});c.step(1.0/hz);assert(std::abs(u->move_speed-9)<.01);++checks;
  u->frozen=1;auto before=u->position;c.step(1.0/hz);assert(length(u->position-before)==0);++checks;
 }
 std::cout<<"SLIME_APPROACH_RESULT checks="<<checks<<" failures=0\n";
}
