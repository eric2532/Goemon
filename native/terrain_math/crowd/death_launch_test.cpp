#include "core.h"
#include <cassert>
#include <iostream>
#include <limits>
using namespace army;
int main(){
 Crowd c;c.configure(32,32);c.set_navigation({});
 auto kill=[&](double hp,double max_hp,double amount,bool critical,Vec3 direction,int team=0){
  c.combat.clear_events();auto h=c.spawn(1,team,0,{},max_hp,.5f);assert(h);
  c.unit(h)->hp=hp;c.unit(h)->yaw=0;
  Hit hit;hit.amount=amount;hit.critical=critical;hit.direction=direction;
  auto result=c.combat.hit(c,h,hit);assert(result.accepted&&result.dead&&!c.unit(h));
  assert(c.combat.events().size()==2&&c.combat.events()[0].kind==DAMAGE);
  auto event=c.combat.events().back();assert(event.kind==DEATH&&event.amount==amount);
  assert(!c.combat.hit(c,h,hit).accepted);return event;
 };
 assert(length(kill(100,100,100,false,{1,0,0}).death_launch)==0);
 assert(length(kill(100,100,124.99,false,{1,0,0}).death_launch)==0);
 assert(kill(100,100,125,false,{4,2,0}).death_launch.x==1);
 assert(length(kill(1,100,25,false,{0,0,1}).death_launch)==0);
 assert(kill(1,100,26,false,{0,0,1}).death_launch.z==1);
 assert(kill(100,100,100,true,{-3,0,0}).death_launch.x==-1);
 assert(kill(100,100,125,false,{0,1,0}).death_launch.z==-1);
 assert(kill(100,100,125,false,{std::numeric_limits<float>::quiet_NaN(),0,0}).death_launch.z==-1);
 assert(length(kill(100,100,200,true,{1,0,0},1).death_launch)==0);
 // Slot reuse cannot carry the previous victim's flight into a normal death.
 for(int i=0;i<100;++i){assert(length(kill(100,100,125,false,{1,0,0}).death_launch)==1);assert(length(kill(100,100,100,false,{1,0,0}).death_launch)==0);}
 std::cout<<"Death launch threshold, critical, finite direction, enemy-only and lifecycle checks passed\n";
}
