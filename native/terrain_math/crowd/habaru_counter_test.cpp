#include "core.h"
#include "instance_buffers.h"
#include <cassert>
#include <iostream>
using namespace army;
static KitData kits(bool enabled=true){
 KitData d;d.habaru_bears=enabled;d.soldier_kinds={SLIME_KIND};
 d.soldier_profiles={30000,3.8f,200,2.85f,5,1.7f};
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={48,10,36,30,30};d.contact_ticks={18.24f,18,18,18};
 d.melee_from={0,1,0};d.melee_to={0,1,-3};d.muzzle={0,1,0};
 d.bullet_speed=12;d.bullet_life=2;d.bullet_tail=.1f;d.bullet_radius=.5f;
 d.slime_attacks.resize(SLIME_SKINS*8*HOUND_TIMELINE_STRIDE);
 for(size_t i=0;i<d.slime_attacks.size();i+=HOUND_TIMELINE_STRIDE){
  d.slime_attacks[i]=48;d.slime_attacks[i+1]=2;
  d.slime_attacks[i+2]=18.24f;d.slime_attacks[i+3]=138;
  d.slime_attacks[i+4]=33.6f;d.slime_attacks[i+5]=164;
 }
 return d;
}
static ExternalTarget hero(Vec3 point={0,0,-2}){ExternalTarget t;t.id=10;t.kind=0;t.hp=100000;t.foot=point;return t;}
static Handle setup(Crowd& c,bool enabled=true){
 c.configure(32,32);NavigationData nav;nav.bounds_min={-100,0,-100};nav.bounds_max={100,0,100};c.set_navigation(nav);
 assert(c.combat.configure(kits(enabled)));auto h=c.spawn(1,0,SLIME_KIND,{0,0,0},30000,1);
 c.combat.set_targets({hero()});c.unit(h)->external_kind=0;c.unit(h)->external_target=10;return h;
}
static void damage(Crowd& c,Handle h,int source=10){Hit hit;hit.amount=1;hit.source_id=source;assert(c.combat.hit(c,h,hit).accepted);}
static void brace(Crowd& c,Handle h,double dt){
 for(int i=0;i<1000&&c.unit(h)->habaru_phase==0;++i){damage(c,h,i%6+10);c.step(dt);}
 assert(c.unit(h)->habaru_phase==1);
}
int main(){
 int checks=0;
 for(int hz:{20,30,60}){
  double dt=1.0/hz;Crowd c;auto h=setup(c);auto u=c.unit(h);
  for(int i=0;i<100;++i)damage(c,h,i%6+10);
  assert(u->habaru_phase==0&&u->habaru_pressure==0&&u->stun>0);++checks;
  for(int i=0;i<int(1.7/dt);++i){damage(c,h);c.step(dt);assert(u->habaru_phase==0);++checks;}
  brace(c,h,dt);assert(u->blocking&&u->stun==0&&u->action==HABARU_BRACE&&!u->action_active);++checks;
  auto warning=u->position;auto yaw=u->yaw;double hp=u->hp;
  Hit hit;hit.amount=100;hit.direction={0,0,1};hit.impulse={4,0,0};hit.flinch=.3;
  assert(c.combat.hit(c,h,hit).hp==hp-25&&u->stun==0&&length(u->knockback)==0);++checks;
  hit.direction={0,0,-1};hp=u->hp;assert(c.combat.hit(c,h,hit).hp==hp-100&&u->habaru_phase==1&&u->stun==0);++checks;
  c.combat.clear_events();double elapsed=0;
  while(u->habaru_phase==1){damage(c,h);c.step(dt);elapsed+=dt;assert(u->yaw==yaw&&length(u->position-warning)<.001);++checks;}
  assert(elapsed>=.85-dt-1e-8&&elapsed<=.85+dt&&u->habaru_phase==2&&!u->blocking);++checks;
  int contacts=0;
  while(u->habaru_phase==2){
   c.combat.clear_events();hp=u->hp;damage(c,h);assert(u->hp==hp-1&&u->stun==0);c.step(dt);
   for(const auto& e:c.combat.events())if(e.kind==EXTERNAL_DAMAGE){assert(e.amount==200&&e.target_id==10);++contacts;}
  }
  assert(contacts==2&&u->habaru_phase==3);++checks;
  elapsed=0;
  while(u->habaru_phase==3){damage(c,h);c.step(dt);elapsed+=dt;assert(!u->action_active);++checks;}
  assert(elapsed>=1.2-dt&&elapsed<=1.2+dt&&u->habaru_pressure==0);++checks;
  damage(c,h);assert(u->stun>0&&u->habaru_phase==0);++checks;
  for(int i=0;i<int(1.0/dt)+1;++i)c.step(dt);
  assert(u->habaru_pressure==0&&u->habaru_gap==0);++checks;
  // Repositioning after the warning commits cannot redirect either source contact.
  brace(c,h,dt);yaw=u->yaw;c.combat.set_targets({hero({0,0,2})});contacts=0;
  while(u->habaru_phase==1||u->habaru_phase==2){c.combat.clear_events();c.step(dt);assert(u->yaw==yaw);for(const auto& e:c.combat.events())contacts+=e.kind==EXTERNAL_DAMAGE;}
  assert(contacts==0);++checks;
  // Dedicated stun and freeze break the brace, including status-only tickets.
  for(int effect:{1,4}){
   u->habaru_phase=0;u->habaru_pressure=u->habaru_gap=u->habaru_left=0;u->stun=0;u->frozen=0;
   brace(c,h,dt);Hit control;control.effect=effect;control.status_seconds=2;
   assert(c.combat.hit(c,h,control).accepted&&u->habaru_phase==0&&!u->blocking&&!u->action_active);++checks;
   assert(c.combat.events().back().action_index==HABARU_RESET);++checks;
   for(int i=0;i<int(1.0/dt);++i){damage(c,h);c.step(dt);assert(u->habaru_phase==0);++checks;}
  }
  c.despawn(h);h=c.spawn(3,0,SLIME_KIND,{0,0,0},30000,1);u=c.unit(h);
  assert(u->habaru_phase==0&&u->habaru_pressure==0&&u->habaru_gap==0&&!u->blocking);++checks;
  u->pose_row=1;for(int i=0;i<int(4/dt);++i){damage(c,h);c.step(dt);assert(u->habaru_phase==0&&u->stun>0);++checks;}
  Crowd off;auto normal=setup(off,false);for(int i=0;i<int(4/dt);++i){damage(off,normal);off.step(dt);assert(off.unit(normal)->habaru_phase==0);++checks;}
 }
 {
  Crowd c;auto h=setup(c);auto u=c.unit(h);
  for(int i=0;i<180&&u->habaru_phase==0;++i){Hit hit;hit.amount=1;hit.flinch=1.0;c.combat.hit(c,h,hit);c.step(1.0/60);}
  assert(u->habaru_phase==1);++checks;
  while(u->habaru_phase==1)c.step(1.0/60);
  Hit control;control.effect=4;control.status_seconds=2;
  assert(c.combat.hit(c,h,control).accepted&&u->habaru_phase==0&&u->stun==2&&!u->action_active);++checks;
  for(int i=0;i<100;++i){damage(c,h);c.step(1.0/60);assert(u->habaru_phase==0);++checks;}
  u->stun=0;u->habaru_control_left=0;brace(c,h,1.0/60);
  Hit lethal;lethal.amount=100000;assert(c.combat.hit(c,h,lethal).dead&&!c.valid(h));++checks;
 }
 InstanceRow row;row.kind=SLIME_KIND;row.team=0;row.pose_row=0;row.flash=1;row.action=HABARU_BRACE;row.render_time=.5;row.pose_time=.5;
 auto buffer=instance_buffers({row},{});assert(buffer.valid&&buffer.batches[0].buffer[13]==6&&buffer.batches[0].buffer[14]==.5f);++checks;
 row.action=HABARU_COUNTER;buffer=instance_buffers({row},{});assert(buffer.batches[0].buffer[13]==2);++checks;
 std::cout<<"HABARU_COUNTER_RESULT checks="<<checks<<" failures=0\n";
}
