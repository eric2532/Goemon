#include "core.h"
#include <cassert>
#include <iostream>
namespace army {
struct TimedDodgeTest {
static void charges(KitData d){
 d.enemy_charge=true;
 d.soldier_kinds.push_back(1);d.soldier_profiles.insert(d.soldier_profiles.end(),{100,4,30,4,6,1.75f});
 d.skullpion={5,30};
 for(int hz:{20,30,60,120})for(int response=0;response<3;++response){
  Crowd c;c.configure(10,10);c.set_navigation({});assert(c.combat.configure(d));
  const double dt=1.0/hz;
  ExternalTarget hero;hero.kind=0;hero.hp=1000;hero.foot={0,0,-7};hero.guarding=response==1;
  auto handle=c.spawn(1,0,response==2?1:SLIME_KIND,{0,0,0},100,.6f);auto& unit=*c.unit(handle);
  unit.external_kind=0;
  auto other=c.spawn(2,0,0,{4,0,0},100,.6f);c.unit(other)->external_kind=0;
  c.combat.set_targets({hero});c.step(dt);
  assert(unit.action==ENEMY_CHARGE_WINDUP&&unit.position.z==0);
  bool warned=false;int hits=0;
  for(int i=1;i<3*hz&&unit.action!=ENEMY_CHARGE_RECOVERY;++i){
   c.step(dt);
   if((i+1)*dt<.8-1e-8)assert(unit.action==ENEMY_CHARGE_WINDUP&&unit.position.z==0);
   assert(!enemy_charge_action(c.unit(other)->action));
   const auto& warning=c.combat.hero_dodge_threat();
   if(warning.charge){
    assert(warning.source_id==1&&warning.seconds>0&&warning.seconds<=.55);
    if(response==2){hero.evading=true;c.combat.set_targets({hero});}
    warned=true;
   }
   for(const auto& event:c.combat.events())if(event.kind==EXTERNAL_DAMAGE&&event.source_id==1){
    assert(event.action_index==ENEMY_CHARGE_RUSH&&event.amount==30&&warned);++hits;
    assert(unit.action==ENEMY_CHARGE_RECOVERY&&unit.position.z>hero.foot.z);
   }
   c.combat.clear_events();
  }
  assert(warned&&unit.action==ENEMY_CHARGE_RECOVERY&&hits==(response==2?0:1));
  assert(response==2?unit.position.z<-10:unit.position.z>hero.foot.z);
  const Vec3 stopped=unit.position;c.step(.25);assert(length(unit.position-stopped)<.001f);
 }
 {
  Crowd c;c.configure(10,10);assert(c.combat.configure(d));
  ExternalTarget hero;hero.kind=0;hero.hp=1000;hero.foot={0,0,-7};c.combat.set_targets({hero});
  NavigationData wall;wall.ray_min={{-4,0,-3.1f}};wall.ray_max={{4,10,-2.9f}};wall.ray_owner={-1};
  c.set_navigation(wall);
  auto enemy=c.spawn(1,0,0,{0,0,0},100,.6f);c.unit(enemy)->external_kind=0;c.step(.1);
  assert(!enemy_charge_action(c.unit(enemy)->action)&&!c.combat.hero_dodge_threat().charge);
  c.despawn(enemy);c.set_navigation({});enemy=c.spawn(2,0,4,{0,0,12},100,18);
  c.unit(enemy)->external_kind=0;c.step(.1);
  assert(c.unit(enemy)->action==ENEMY_CHARGE_WINDUP);
  Hit stun;stun.effect=4;stun.status_seconds=1;c.combat.hit(c,enemy,stun);c.step(.1);
  assert(!enemy_charge_action(c.unit(enemy)->action)&&!c.combat.hero_dodge_threat().charge);
 }
}
static void run(){
 Crowd c;c.configure(10,10);c.set_navigation({});
 KitData d;d.soldier_kinds={0,SLIME_KIND};d.soldier_profiles={3000,4,30,4,6,1.75f,3000,4,30,4,6,1.75f};
 d.actions={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};d.status_bits={1,2,4,8,16,32,64};
 d.phase_ticks={30,10,30,30,30};d.contact_ticks={15,15,15,15};
 d.melee_from={0,1,-.3f};d.melee_to={0,1,-3.8f};d.bullet_speed=12;d.bullet_life=2;d.bullet_tail=.1f;d.bullet_radius=.5f;
 d.slime_attacks.resize(SLIME_SKINS*8*HOUND_TIMELINE_STRIDE);
 for(size_t i=0;i<d.slime_attacks.size();i+=HOUND_TIMELINE_STRIDE){d.slime_attacks[i]=30;d.slime_attacks[i+1]=3;d.slime_attacks[i+2]=3;d.slime_attacks[i+3]=131;d.slime_attacks[i+4]=15;d.slime_attacks[i+5]=135;d.slime_attacks[i+6]=24;d.slime_attacks[i+7]=138;}
 assert(c.combat.configure(d));
 ExternalTarget hero;hero.kind=0;hero.hp=100;hero.foot={0,0,-2};c.combat.set_targets({hero});
 auto handle=c.spawn(1,0,0,{0,0,0},100,.5f);auto& u=*c.unit(handle);
 u.action_active=true;u.action=1;u.external_kind=0;u.live_delta=1.0/60;
 auto warning=[&](){c.combat.hero_dodge_threat_={};c.combat.warn_melee(c,u,1.0/60);return c.combat.hero_dodge_threat().seconds;};
 assert(std::abs(warning()-(.5-1.0/60))<1e-6);
 u.phase_tick=9;assert(warning()>.18&&warning()<.2);
 u.phase_tick=15;assert(warning()<0);
 u.phase_tick=9;u.external_kind=1;assert(warning()<0);u.external_kind=0;
 u.stun=1;assert(warning()<0);u.stun=0;u.frozen=1;assert(warning()<0);u.frozen=0;
 u.attack_slow_factor=.5;assert(warning()>.38&&warning()<.4);u.attack_slow_factor=1;
 hero.foot={0,0,-20};c.combat.set_targets({hero});assert(warning()<0);
 hero.foot={0,0,-2};c.combat.set_targets({hero});
 NavigationData wall;wall.ray_min={{-4,0,-1.1f}};wall.ray_max={{4,10,-.9f}};wall.ray_owner={-1};c.set_navigation(wall);assert(warning()<0);c.set_navigation({});
 u.kind=SLIME_KIND;u.pose_row=0;u.phase_tick=4;assert(warning()>.34);u.phase_tick=16;assert(warning()>.24&&warning()<.26);
 u.counter_active=true;u.counter_contact=.4;u.action_time=.2;assert(warning()>.18&&warning()<.2);u.counter_hit=true;u.action=0;assert(warning()<0);
 Projectile shot;shot.source_id=1;shot.source_team=0;shot.position={0,1,-8};shot.direction={0,0,1};shot.speed=20;shot.life=2;shot.radius=.3;
 auto projectile=[&](){c.combat.hero_dodge_threat_={};c.combat.warn_projectile(c,shot);return c.combat.hero_dodge_threat().seconds;};
 assert(projectile()>.28&&projectile()<.3);
 shot.direction={1,0,0};assert(projectile()<0);shot.direction={0,0,1};shot.source_team=1;assert(projectile()<0);shot.source_team=0;
 wall.ray_min={{-4,0,-5.1f}};wall.ray_max={{4,10,-4.9f}};c.set_navigation(wall);assert(projectile()<0);
 wall.ray_min={{-4,0,-.1f}};wall.ray_max={{4,10,.1f}};c.set_navigation(wall);assert(projectile()>0);
 c.combat.clear();assert(c.combat.hero_dodge_threat().seconds<0);
 charges(d);
}
};
}
int main(){army::TimedDodgeTest::run();std::cout<<"Timed dodge native threat checks passed\n";}
