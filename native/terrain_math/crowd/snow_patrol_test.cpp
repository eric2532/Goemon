#include "core.h"
#include <cassert>
#include <iostream>

namespace army {
struct TargetDecisionTest {
 static void choose(Crowd& c,Unit& u){c.combat.choose_target(c,u);}
 static bool guard(Crowd& c,Unit& u,double dt){return c.combat.enemy_guard(c,u,dt);}
 static void begin(Crowd& c,Unit& u){c.combat.begin(u);}
 static void advance(Crowd& c,Unit& u,double dt){c.combat.advance(c,u,dt);}
};
}
using namespace army;

static KitData kits(){
 KitData d;
 d.soldier_kinds={HOUND_KIND};d.soldier_profiles={3000,4.5,60,3.2,8,2.7};
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={20,10,24,30,30};d.contact_ticks={13,14,15,18};
 d.melee_from={0,1,0};d.melee_to={0,1,-2.2f};d.muzzle={0,1.44f,-.86f};
 d.bullet_speed=8.64;d.bullet_life=3.34;d.bullet_tail=.576;d.bullet_radius=.576;
 d.hound_attacks.resize(HOUND_SKINS*8*HOUND_TIMELINE_STRIDE);
 for(size_t i=0;i<d.hound_attacks.size();i+=HOUND_TIMELINE_STRIDE){
  d.hound_attacks[i]=30;d.hound_attacks[i+1]=2;d.hound_attacks[i+2]=10;d.hound_attacks[i+3]=135;
  d.hound_attacks[i+4]=18;d.hound_attacks[i+5]=10135;
 }
 d.snow_patrol_skins={239,3};return d;
}

int main(){
 Crowd c;c.configure(64,64);
 NavigationData nav;nav.bounds_min={-60,0,-60};nav.bounds_max={60,0,60};c.set_navigation(nav);
 auto profile=kits();assert(c.combat.configure(profile));
 auto zombie=c.spawn(1,0,HOUND_KIND,{-2,0,0},1000,.4f);
 auto hound=c.spawn(2,0,HOUND_KIND,{2,0,0},1000,.4f);
 auto ally=c.spawn(-1,1,HOUND_KIND,{0,0,5},100,.4f);
 auto& z=*c.unit(zombie);auto& h=*c.unit(hound);z.pose_row=239;h.pose_row=3;
 ExternalTarget hero;hero.kind=0;hero.hp=1500;hero.foot=hero.minimum=hero.maximum={0,0,-5};
 c.combat.set_targets({hero});
 TargetDecisionTest::choose(c,z);assert(z.target_handle==ally);
 TargetDecisionTest::choose(c,h);assert(h.external_kind==0&&!h.target_handle);
 hero.hp=50;c.combat.set_targets({hero});
 TargetDecisionTest::choose(c,h);assert(h.external_kind==0); // Keep a valid pursuit.
 c.unit(ally)->hp=1500;
 h.external_kind=-1;h.target_handle=0;TargetDecisionTest::choose(c,h);assert(h.target_handle==ally);
 assert(c.combat.configure([&]{auto p=profile;p.snow_patrol_skins.clear();return p;}()));
 z.external_kind=-1;z.target_handle=0;TargetDecisionTest::choose(c,z);assert(z.external_kind==0);
 assert(c.combat.configure(profile));

 hero.hp=1500;hero.foot=hero.minimum=hero.maximum={};hero.attack_reach=8;hero.attack_facing={0,0,1};
 for(auto unit:{&z,&h}){
  unit->position={0,0,1.4f};unit->yaw=0;unit->external_kind=0;unit->external_target=0;unit->target_handle=0;
  int guards=0;
  for(int swing=1;swing<=4;++swing){
   hero.attack_serial=swing;c.combat.set_targets({hero});unit->guard_cooldown=0;
   if(!TargetDecisionTest::guard(c,*unit,.01))continue;
   assert(TargetDecisionTest::guard(c,*unit,.13)&&unit->blocking);++guards;
   Hit incoming;incoming.amount=40;incoming.direction={0,0,1};
   const double hp=unit->hp;assert(c.combat.hit(c,unit->handle,incoming).hp==hp-10);
   assert(TargetDecisionTest::guard(c,*unit,.46)&&unit->blocking);
   TargetDecisionTest::guard(c,*unit,.50);assert(!unit->blocking);
  }
  assert(guards==2);
 }
 hero.attack_serial=0;c.combat.set_targets({hero});
 {
  auto& pet=*c.unit(ally);pet.position={0,0,0};pet.hp=1000;
  h.position={0,0,1.4f};h.yaw=0;h.hp=1000;h.stun=0;h.action_active=false;h.blocking=false;
  h.guard_cooldown=0;h.guard_left=0;h.guard_pressure_hits=0;h.light_recoil_grace=0;h.target_handle=0;h.external_kind=0;h.external_target=0;
  Hit hit;hit.source_id=pet.logical_id;hit.amount=10;hit.direction={0,0,1};hit.joint_attack=hit.joint_pet=true;
  for(int i=0;i<3;++i)assert(c.combat.hit(c,h.handle,hit).accepted);
  h.stun=0;
  assert(TargetDecisionTest::guard(c,h,.01)&&h.blocking&&h.target_handle==pet.handle);
  assert(TargetDecisionTest::guard(c,h,.2)&&h.blocking);
  const double before=h.hp;assert(c.combat.hit(c,h.handle,hit).hp==before-2.5);
  TargetDecisionTest::guard(c,h,1.0);assert(!h.blocking);
  h.target_handle=0;h.external_kind=0;h.external_target=0;
 }
 for(int bag=0;bag<3;++bag){
  int special=0;
  for(int swipe=0;swipe<4;++swipe){
   c.combat.clear_events();TargetDecisionTest::begin(c,h);
   bool heavy=h.action==HABARU_DOUBLE_EDGE;special+=heavy;
   TargetDecisionTest::advance(c,h,.01);TargetDecisionTest::advance(c,h,2);
   int contacts=0,cues=0;
   for(auto& e:c.combat.events())if(e.kind==EXTERNAL_DAMAGE){
    assert(e.target_id==0&&std::abs(e.amount-(heavy?87.0:60.0))<.001);++contacts;
   }else if(e.kind==STATUS_EVENT&&e.action_index==500+135){
    if(heavy)assert(e.source_tick==10);++cues;
   }else if(e.kind==STATUS_EVENT&&e.action_index==HABARU_DOUBLE_EDGE&&e.amount>0){
    assert(e.source_tick==10&&e.position.x==0&&e.position.z==0&&std::abs(e.position.y-.8)<.001);
   }
   assert(contacts==(heavy?1:2)&&cues==contacts&&!h.action_active);
  }
  assert(special==1);
 }
 h.action=HABARU_DOUBLE_EDGE;h.action_active=true;
 const double hp=h.hp;
 Hit incoming;incoming.amount=40;assert(c.combat.hit(c,hound,incoming).hp==hp-50);
 TargetDecisionTest::begin(c,z);assert(z.action!=HABARU_DOUBLE_EDGE);
 c.clear();
 const auto breaker=c.spawn(3,0,HOUND_KIND,{0,0,1.4f},1000,.4f);
 auto& snow=*c.unit(breaker);snow.pose_row=3;snow.external_kind=0;snow.external_target=0;
 hero.guarding=true;c.combat.set_targets({hero});c.combat.clear_events();
 c.step(1.0/60);assert(snow.action==ENEMY_GUARD_BREAK_WINDUP);
 for(int frame=0;frame<100&&snow.action_active;++frame)c.step(1.0/60);
 int strikes=0;
 for(const auto& event:c.combat.events())if(event.kind==EXTERNAL_DAMAGE){
  assert(event.action_index==GUARD_BREAK_HIT&&event.amount==72);
  ++strikes;
 }
 assert(!snow.action_active&&strikes==1);
 std::cout<<"SNOW_PATROL_PASS target preference, stable pursuit, guard bags, timed contacts, exposed windup and guard break\n";
}
