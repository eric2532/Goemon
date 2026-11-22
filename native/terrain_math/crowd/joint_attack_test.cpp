#include "core.h"
#include <cassert>
#include <iostream>
namespace army {
struct JointAttackTest {
static void run(){
 for(double dt:{1.0/20,1.0/30,1.0/60}){
  Crowd c;c.configure(32,32);c.set_navigation({});KitData d;
  d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
  d.phase_ticks={30,10,30,30,30};d.contact_ticks={15,15,15,15};
  d.soldier_kinds={0};d.soldier_profiles={100000,4,30,4,6,1.75f};
  d.bullet_speed=12;d.bullet_life=2;d.bullet_radius=.5f;
  assert(c.combat.configure(d));
  auto spawn=[&](){return c.spawn(1,0,0,{0,0,0},100000,.5f);};
  auto target=spawn();
  auto hit=[&](int64_t source,double amount,bool eligible=true,bool pet=true){Hit h;h.source_id=source;h.amount=amount;h.joint_attack=eligible;h.joint_pet=source!=0&&pet;h.provoke=false;auto r=c.combat.hit(c,target,h);assert(r.accepted);return r;};
  auto reset=[&](){c.despawn(target);target=spawn();c.combat.clear_events();};
  hit(0,100);assert(c.unit(target)->hp==99900&&c.combat.events().back().joint_count==0);
  hit(-1,50);assert(c.unit(target)->hp==99820&&c.combat.events().back().joint_count==2&&c.combat.events().back().joint_total==180);
  hit(-2,50);assert(c.unit(target)->hp==99740&&c.combat.events().back().joint_count==3);
  hit(-2,50);assert(c.unit(target)->hp==99675&&c.combat.events().back().joint_count==3);
  reset();hit(-1,50);hit(0,100);assert(c.unit(target)->hp==99820);
  reset();hit(-1,50);hit(-2,50);assert(c.unit(target)->hp==99900&&c.combat.events().back().joint_count==0);
  hit(0,100);assert(c.unit(target)->hp==99740);
  reset();hit(0,100);for(int i=0;i<int(.35/dt)+2;++i)c.combat.joint_clock_+=dt;hit(-1,50);assert(c.unit(target)->hp==99850&&c.combat.events().back().joint_count==0);
  reset();hit(0,100,false);hit(-1,50);assert(c.unit(target)->hp==99850);
  reset();hit(0,100);hit(42,50,true,false);assert(c.unit(target)->hp==99850);
  reset();Hit shot;shot.source_id=-1;shot.amount=50;shot.joint_attack=shot.joint_pet=shot.projectile=true;hit(0,100);c.combat.hit(c,target,shot);assert(c.unit(target)->hp==99850);
  reset();shot.projectile=false;shot.counter=true;hit(0,100);c.combat.hit(c,target,shot);assert(c.unit(target)->hp==99850);
  reset();c.unit(target)->blocking=true;c.unit(target)->guard_left=1;Hit guarded;guarded.amount=100;guarded.joint_attack=true;guarded.direction={0,0,1};c.combat.hit(c,target,guarded);
  guarded.source_id=-1;guarded.amount=50;guarded.joint_pet=true;c.combat.hit(c,target,guarded);assert(c.unit(target)->hp==99955);
  reset();hit(0,10);for(int i=1;i<10;++i)hit(-i,10);assert(c.unit(target)->hp==99800&&c.combat.events().back().joint_count==10);
  hit(-10,10);assert(c.unit(target)->hp==99790&&c.combat.events().back().joint_count==0);
  reset();c.unit(target)->hp=160;hit(0,100);auto lethal=hit(-1,50);
  assert(lethal.dead&&!c.unit(target));int damages=0,deaths=0;
  for(const auto& event:c.combat.events()){damages+=event.kind==DAMAGE;deaths+=event.kind==DEATH;if(event.kind==DEATH)assert(event.source_id==-1&&event.joint_count==2);}
  assert(damages==2&&deaths==1);Hit stale;stale.amount=100;assert(!c.combat.hit(c,target,stale).accepted);
  reset();assert(c.unit(target)->joint_count==0);hit(-1,50);assert(c.unit(target)->hp==99950);
  auto pet_handle=c.spawn(-1000000,1,HOUND_KIND,{0,0,1},1000,.4f);auto& pet=*c.unit(pet_handle);pet.target_handle=target;
  reset();pet.target_handle=target;hit(0,100);c.combat.deliver(c,pet,50,false,pet.position);assert(c.unit(target)->hp==99820);
  reset();pet.target_handle=target;pet.pet_skill=2;hit(0,100);c.combat.deliver(c,pet,50,false,pet.position);assert(c.unit(target)->hp==99850);
  reset();pet.target_handle=target;pet.pet_skill=0;pet.kind=BEAR_KIND;hit(0,100);c.combat.deliver(c,pet,50,false,pet.position);assert(c.unit(target)->hp==99820);
  auto other=c.spawn(2,0,0,{5,0,0},100000,.4f);Hit separate;separate.amount=50;separate.source_id=-2;separate.joint_attack=separate.joint_pet=true;c.combat.hit(c,other,separate);assert(c.unit(other)->hp==99950&&c.unit(other)->joint_count==1);
 }
}
};
}
int main(){army::JointAttackTest::run();std::cout<<"Joint attack native formula, eligibility, lifecycle and bounded-state checks passed at 20/30/60 Hz\n";}
